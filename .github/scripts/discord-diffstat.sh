#!/bin/sh
# Collect the per-file line churn of a push for the Discord embed.
#
#   usage: discord-diffstat.sh [event.json] > diffstat.json
#
# The `push` payload GitHub hands a workflow lists the paths a commit touched
# but never the lines inside them. The counts live behind the REST API:
#
#   1. GET /repos/{repo}/compare/{before}...{after}   the whole push in one
#                                                     call - the normal path
#   2. GET /repos/{repo}/commits/{sha}                per commit, for a push
#                                                     with no `before` to
#                                                     compare against (a
#                                                     branch's first push, or
#                                                     one the API cannot line
#                                                     up against its past)
#   3. `{"files": []}`                                no counts at all - the
#                                                     embed falls back to the
#                                                     paths in the event itself
#
# stdout is the JSON document and nothing else: no progress, no warnings, so a
# redirect into a file cannot be corrupted by a log line. Everything the script
# has to say goes to stderr.
#
# Env:
#   GITHUB_TOKEN / GH_TOKEN  optional but wanted. Anonymous callers see public
#                            repositories only, at 60 requests an hour from an
#                            IP shared with every other job on the runner. The
#                            workflow passes secrets.GITHUB_TOKEN.
#   GITHUB_API_URL           optional. Defaults to https://api.github.com.
#   GITHUB_REPOSITORY        optional. Defaults to repository.full_name.
#   DISCORD_DIFFSTAT_MAX_COMMITS
#                            optional, default 30. Ceiling on the per-commit
#                            fallback, so one 500-commit push cannot turn into
#                            500 API calls.
#
# Exit codes: 0 with a complete document on stdout - including "the API said
# no, here is an empty diffstat" - or 2 when the inputs are unusable and
# nothing could be printed at all. The notification is decoration, so callers
# should ignore the exit code and treat an empty file as "no line counts".
set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
NORMALIZER="$SELF_DIR/discord-diffstat.jq"
API_BASE="${GITHUB_API_URL:-https://api.github.com}"
API_BASE="${API_BASE%/}"
# /compare stops listing files at 300. A full page means there are probably
# more of them, so the totals under it are a floor rather than a sum.
API_FILE_LIMIT=300
MAX_COMMITS="${DISCORD_DIFFSTAT_MAX_COMMITS:-30}"
case "$MAX_COMMITS" in
	'' | *[!0-9]* | 0) MAX_COMMITS=30 ;;
esac
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
EMPTY='{"files":[],"total_files":0,"total_additions":0,"total_deletions":0,"truncated":false}'

# Both talkers write to stderr: stdout carries the document.
say() { printf 'discord-diffstat: %s\n' "$1" >&2; }
warn() { printf 'discord-diffstat: %s\n' "$1" >&2; }
die() {
	warn "$1"
	exit "${2:-1}"
}

EVENT="${1:-${GITHUB_EVENT_PATH:-}}"

# --- inputs ------------------------------------------------------------------

[ -n "$EVENT" ] || die "no event payload: pass a path or set GITHUB_EVENT_PATH." 2
[ -r "$EVENT" ] || die "cannot read the event payload at $EVENT." 2
[ -f "$NORMALIZER" ] || die "missing the normalizer: $NORMALIZER." 2

command -v jq >/dev/null 2>&1 || die "jq is required to read the payload." 2
command -v curl >/dev/null 2>&1 || die "curl is required to call the API." 2

jq -e . "$EVENT" >/dev/null 2>&1 || die "the event payload at $EVENT is not JSON." 2

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
	REPO="$(jq -r '.repository.full_name // ""' "$EVENT")"
fi
if [ -z "$REPO" ]; then
	warn "the payload names no repository; posting without line counts."
	printf '%s\n' "$EMPTY"
	exit 0
fi

BEFORE="$(jq -r '.before // "" | tostring' "$EVENT")"
AFTER="$(jq -r '.after // "" | tostring' "$EVENT")"
DELETED="$(jq -r 'if .deleted == true then "yes" else "no" end' "$EVENT")"

# A payload carries the all-zero placeholder for "this ref did not exist yet"
# (a brand new branch) or "this ref is gone now" (a delete). Neither is a
# commit to compare against.
is_sha() {
	[ "${#1}" -ge 7 ] || return 1
	case "$1" in
		*[!0-9a-fA-F]*) return 1 ;;
		*[!0]*) return 0 ;;
	esac
	return 1
}

short_sha() { printf '%.7s' "$1"; }

# --- working space -----------------------------------------------------------

umask 077
WORK="$(mktemp -d "${TMPDIR:-/tmp}/astra-discord-diffstat.XXXXXX")" || die "cannot create a temp directory." 2
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/commits"
RAW="$WORK/raw.json"
printf '{"files":[],"truncated":false}\n' >"$RAW"
COLLECTED=0

# The token goes into a config file rather than the command line: everything in
# argv is readable by any process on the runner.
CURL_CONFIG="$WORK/curlrc"
if [ -n "$TOKEN" ]; then
	printf '%s\n' "--header \"Authorization: Bearer $TOKEN\"" >"$CURL_CONFIG"
else
	: >"$CURL_CONFIG"
	warn "no GITHUB_TOKEN: asking the anonymous API, which cannot see private repositories and shares its rate limit with every job on this runner."
fi
chmod 600 "$CURL_CONFIG"

API_STATUS="000"

# GET $1, leaving the body in $WORK/api.json and the status in $API_STATUS.
# Never fails the script: the caller decides what a bad status means.
api_get() {
	API_STATUS="000"
	curl \
		--silent \
		--show-error \
		--retry 2 \
		--retry-delay 2 \
		--max-time 30 \
		--header 'Accept: application/vnd.github+json' \
		--header 'X-GitHub-Api-Version: 2022-11-28' \
		--user-agent 'astra-discord-diffstat' \
		--config "$CURL_CONFIG" \
		--output "$WORK/api.json" \
		--write-out '%{http_code}' \
		"$API_BASE/$1" >"$WORK/status.txt" 2>"$WORK/curl.log" || true

	# A retried transfer can print the write-out more than once; the last one
	# is the attempt that decided the outcome.
	API_STATUS="$(tail -n 1 "$WORK/status.txt")"
	[ -n "$API_STATUS" ] || API_STATUS="000"
}

is_file_list() {
	jq -e '(.files | type) == "array"' "$WORK/api.json" >/dev/null 2>&1
}

# Only the three fields the embed needs survive the response. /compare hands
# back a `patch` per file, and holding a few megabytes of diff in a temp file -
# thirty times over, on the per-commit path - is how a notification ends up
# costing more than the push did.
FILES_ONLY='[(.files // [])[] | {filename: (.filename // ""), additions: (.additions // 0), deletions: (.deletions // 0)}]'

# --- 1. the whole push, one call ---------------------------------------------

# A walk through the commits costs one request each, so it is worth deciding
# whether the API is in a state to answer before starting it.
PER_COMMIT=yes

if [ "$DELETED" = "yes" ]; then
	say "the ref was deleted: there is no diff to count."
elif is_sha "$BEFORE" && is_sha "$AFTER"; then
	say "reading $(short_sha "$BEFORE")...$(short_sha "$AFTER") from the compare API."
	api_get "repos/$REPO/compare/$BEFORE...$AFTER"
	if [ "$API_STATUS" = "200" ] && is_file_list; then
		jq -c "$FILES_ONLY" "$WORK/api.json" >"$WORK/files.json"
		# `-s` wraps the single stripped list in an array, so it reads as .[0].
		jq -s -c --argjson limit "$API_FILE_LIMIT" \
			'{files: .[0], truncated: ((.[0] | length) >= $limit)}' \
			"$WORK/files.json" >"$RAW"
		COLLECTED=1
	elif [ "$API_STATUS" = "404" ] || [ "$API_STATUS" = "422" ]; then
		# Nothing to compare - a branch whose history the API cannot line up -
		# so the commits are still worth asking about one at a time.
		warn "the compare API has nothing to compare for $(short_sha "$BEFORE")...$(short_sha "$AFTER") (HTTP $API_STATUS); falling back to per-commit diffs."
	elif [ "$API_STATUS" = "200" ]; then
		warn "the compare API answered 200 without a file list; falling back to per-commit diffs."
	else
		# A 5xx, a rate limit or no network at all: thirty more calls would
		# only be thirty more failures, a few seconds apart.
		warn "the compare API answered HTTP $API_STATUS; leaving the line counts out."
		PER_COMMIT=no
	fi
else
	say "no previous commit to compare against: a first push, or a ref that has gone away."
fi

# --- 2. per commit -----------------------------------------------------------

if [ "$COLLECTED" = "0" ] && [ "$PER_COMMIT" = "yes" ] && [ "$DELETED" != "yes" ]; then
	TOTAL_COMMITS="$(jq -r '[(.commits // [])[] | (.id // "") | tostring | select(length > 0)] | length' "$EVENT")"
	case "$TOTAL_COMMITS" in
		'' | *[!0-9]*) TOTAL_COMMITS=0 ;;
	esac

	if [ "$TOTAL_COMMITS" -gt 0 ]; then
		say "reading up to $MAX_COMMITS of $TOTAL_COMMITS commit(s)."
		index=0
		jq -r '[(.commits // [])[] | (.id // "") | tostring | select(length > 0)] | .[]' "$EVENT" |
			while read -r sha; do
				[ "$index" -lt "$MAX_COMMITS" ] || break
				index=$((index + 1))
				api_get "repos/$REPO/commits/$sha"
				if [ "$API_STATUS" = "200" ] && is_file_list; then
					jq -c "$FILES_ONLY" "$WORK/api.json" >"$WORK/commits/$index.json"
				else
					warn "the API answered HTTP $API_STATUS for commit $(short_sha "$sha"); its line counts are missing."
				fi
			done

		# `-s` turns the one file per commit into one array of file arrays, so
		# the whole push is a single `.[][]` - and a path touched twice is
		# summed by the normalizer, not counted twice.
		if [ -f "$WORK/commits/1.json" ]; then
			fetched="$(ls "$WORK/commits" | wc -l | tr -d '[:space:]')"
			if [ "$fetched" -lt "$TOTAL_COMMITS" ]; then
				warn "counted $fetched of $TOTAL_COMMITS commit(s); the totals cover only those."
				truncated=true
			else
				truncated=false
			fi
			jq -s -c --argjson truncated "$truncated" \
				'{files: [.[][]], truncated: $truncated}' \
				"$WORK"/commits/*.json >"$RAW"
			COLLECTED=1
		fi
	fi
fi

if [ "$COLLECTED" = "0" ]; then
	say "no line counts: the embed will list the paths from the event and nothing more."
fi

# --- 3. shape it -------------------------------------------------------------

if ! jq -c -f "$NORMALIZER" "$RAW"; then
	warn "could not turn $RAW into a diffstat; posting without line counts."
	printf '%s\n' "$EMPTY"
fi
