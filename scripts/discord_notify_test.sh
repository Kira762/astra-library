#!/bin/sh
# Test for the Discord push notification: `.github/scripts/discord-embed.jq`
# (the event -> embed mapping) and `.github/scripts/discord-notify.sh` (the
# guards around posting it).
#
# Fixtures are synthetic GitHub `push` events. Each one is run through the real
# filter, and what comes back is checked against what Discord will accept: the
# neutral accent colour, the layout, the per-field size limits, the escaping of
# hostile commit messages, and the sender's own refusal paths - driven end to
# end against a stubbed `curl` so nothing leaves the machine.
#
# Needs sh, jq, curl-free (curl is stubbed). No Luau toolchain involved.
#   sh scripts/discord_notify_test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMBED_FILTER="$ROOT/.github/scripts/discord-embed.jq"
NOTIFY="$ROOT/.github/scripts/discord-notify.sh"
WORKFLOW="$ROOT/.github/workflows/discord-notify.yml"

for required in "$EMBED_FILTER" "$NOTIFY" "$WORKFLOW"; do
	if [ ! -f "$required" ]; then
		echo "missing: $required" >&2
		exit 1
	fi
done

if ! command -v jq >/dev/null 2>&1; then
	echo "jq not found on PATH - this suite cannot run without it." >&2
	exit 2
fi

WORK="${TMPDIR:-/tmp}/astra_discord_notify_$$"
mkdir -p "$WORK" || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

checks=0
failures=0

section() {
	echo ""
	echo "--- $1"
}

# check <label> <got> <want>
check() {
	checks=$((checks + 1))
	if [ "$2" != "$3" ]; then
		echo "FAIL  $1" >&2
		echo "        got:  $2" >&2
		echo "        want: $3" >&2
		failures=$((failures + 1))
	fi
}

# check_status <label> <got-status> <want-status>
check_status() {
	checks=$((checks + 1))
	if [ "$2" != "$3" ]; then
		echo "FAIL  $1 (exit $2, wanted $3)" >&2
		failures=$((failures + 1))
	fi
}

# jqf <file> <filter>
jqf() { jq -r "$2" "$1"; }

# build <fixture> <out>   — the filter reads its colour from the environment
build() {
	jq -c -f "$EMBED_FILTER" "$1" >"$2"
}

# check_limits <label> <payload> — every Discord size limit at once
check_limits() {
	over="$(jqf "$2" '
	  [.embeds[] as $e
	   | ($e.title // "" | length) > 256,
	     ($e.description // "" | length) > 4096,
	     ($e.footer.text // "" | length) > 2048,
	     ($e.author.name // "" | length) > 256,
	     ($e.fields[]? | (.name | length) > 256),
	     ($e.fields[]? | (.value | length) > 1024)]
	  | map(select(.)) | length')"
	check "$1: inside Discord's size limits" "$over" "0"

	nulls="$(jqf "$2" '[.. | nulls] | length')"
	check "$1: no null values anywhere" "$nulls" "0"
}

# ---------------------------------------------------------------- fixtures ---

cat >"$WORK/basic.json" <<'JSON'
{
  "ref": "refs/heads/main",
  "before": "9049f1265b7d61be4a8904a9a27120d2064dab3b",
  "after": "0d1a26e67d8f5eaf1f6ba5c57fc3c7d91ac0fd1c",
  "created": false,
  "deleted": false,
  "forced": false,
  "compare": "https://github.com/Kira762/astra-version-1/compare/9049f12...0d1a26e",
  "repository": {
    "name": "astra-version-1",
    "full_name": "Kira762/astra-version-1",
    "html_url": "https://github.com/Kira762/astra-version-1",
    "owner": {"login": "Kira762", "avatar_url": "https://avatars.githubusercontent.com/u/322647714?v=4"}
  },
  "pusher": {"name": "Kira762", "email": "322647714+Kira762@users.noreply.github.com"},
  "sender": {"login": "Kira762", "avatar_url": "https://avatars.githubusercontent.com/u/322647714?v=4", "html_url": "https://github.com/Kira762"},
  "commits": [
    {"id": "aa11bb22cc33dd44ee55ff667788990011223344", "message": "Fix the webhook layout\n\nA body that belongs on its own lines.\nAnd another.", "timestamp": "2026-09-20T10:11:12+02:00", "url": "https://github.com/Kira762/astra-version-1/commit/aa11bb22cc33dd44ee55ff667788990011223344", "author": {"name": "Kira762", "username": "Kira762"}, "added": ["scripts/discord_notify_test.sh"], "removed": [], "modified": [".github/workflows/discord-notify.yml", "CHANGELOG.md"]},
    {"id": "bb22cc33dd44ee55ff6677889900112233445566", "message": "Tidy the embed builder", "timestamp": "2026-09-20T10:12:00+02:00", "url": "https://github.com/Kira762/astra-version-1/commit/bb22cc33dd44ee55ff6677889900112233445566", "author": {"name": "Kira762", "username": "Kira762"}, "added": [], "removed": [], "modified": [".github/scripts/discord-embed.jq"]},
    {"id": "cc33dd44ee55ff66778899001122334455667788", "message": "Drop the green accent", "timestamp": "2026-09-20T10:13:00+02:00", "url": "https://github.com/Kira762/astra-version-1/commit/cc33dd44ee55ff66778899001122334455667788", "author": {"name": "Kira762", "username": "Kira762"}, "added": [], "removed": ["scripts/old_notify.sh"], "modified": []}
  ],
  "head_commit": {"id": "0d1a26e67d8f5eaf1f6ba5c57fc3c7d91ac0fd1c", "message": "Drop the green accent", "timestamp": "2026-09-20T10:13:00+02:00", "url": "https://github.com/Kira762/astra-version-1/commit/0d1a26e67d8f5eaf1f6ba5c57fc3c7d91ac0fd1c", "author": {"name": "Kira762", "username": "Kira762"}}
}
JSON

# A commit message that would break a hand-built payload: quotes, backslashes,
# Markdown link syntax, an emoji, tabs, a body, and a subject far too long.
cat >"$WORK/nasty.json" <<'JSON'
{
  "ref": "refs/heads/feature/a-very-long-branch-name-that-keeps-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-and-going-past-the-title-limit",
  "before": "1111111111111111111111111111111111111111",
  "after": "2222222222222222222222222222222222222222",
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1", "owner": {"avatar_url": "https://avatars.githubusercontent.com/u/322647714?v=4"}},
  "sender": {"login": "Kira762", "html_url": "https://github.com/Kira762"},
  "commits": [
    {"id": "3333333333333333333333333333333333333333", "message": "Say \"hello\"\t[not a link](https://evil) \\ backslash\n\nbody line with \"quotes\" and \u00e9\u00e8\u00ea \ud83d\ude80 and a really long subject that keeps going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going and going", "author": {"name": "Kira \"The Bracket]\" 762", "username": "Kira762"}, "added": [], "removed": [], "modified": ["a.luau"]}
  ],
  "head_commit": {"id": "2222222222222222222222222222222222222222", "message": "Say \"hello\"", "timestamp": "not-a-timestamp", "author": {"name": "Kira762"}}
}
JSON

jq -n '{
  ref: "refs/heads/main",
  repository: {full_name: "Kira762/astra-version-1", html_url: "https://github.com/Kira762/astra-version-1"},
  sender: {login: "Kira762"},
  commits: [range(0; 40) | {
    id: ("0123456789abcdef0123456789abcdef0123456" + (. | tostring)),
    message: ("Commit number " + (. | tostring)),
    url: ("https://github.com/Kira762/astra-version-1/commit/" + (. | tostring)),
    author: {name: "Kira762"},
    added: [], removed: [], modified: [("element" + (. | tostring) + ".luau")]
  }],
  head_commit: {id: "2222222222222222222222222222222222222222", timestamp: "2026-09-20T10:13:00Z", author: {name: "Kira762"}}
}' >"$WORK/many.json"

cat >"$WORK/tag.json" <<'JSON'
{
  "ref": "refs/tags/v1.2.0",
  "created": true,
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1", "owner": {"avatar_url": "https://avatars.githubusercontent.com/u/322647714?v=4"}},
  "sender": {"login": "Kira762"},
  "commits": [
    {"id": "4444444444444444444444444444444444444444", "message": "v1.2.0", "author": {"name": "Kira762"}, "added": [], "removed": [], "modified": ["CHANGELOG.md"]}
  ],
  "head_commit": {"id": "4444444444444444444444444444444444444444", "timestamp": "2026-09-20T10:13:00Z", "author": {"name": "Kira762"}}
}
JSON

cat >"$WORK/delete.json" <<'JSON'
{
  "ref": "refs/heads/feature/old",
  "before": "5555555555555555555555555555555555555555",
  "after": "0000000000000000000000000000000000000000",
  "created": false,
  "deleted": true,
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1"},
  "sender": {"login": "Kira762"},
  "commits": [],
  "head_commit": null
}
JSON

cat >"$WORK/create.json" <<'JSON'
{
  "ref": "refs/heads/new-thing",
  "created": true,
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1"},
  "sender": {"login": "Kira762"},
  "commits": [
    {"id": "6666666666666666666666666666666666666666", "message": "Start the new thing", "author": {"name": "Kira762"}, "added": ["new.luau"], "removed": [], "modified": []},
    {"id": "7777777777777777777777777777777777777777", "message": "Continue it", "author": {"name": "Kira762"}, "added": [], "removed": [], "modified": ["new.luau"]}
  ],
  "head_commit": {"id": "7777777777777777777777777777777777777777", "timestamp": "2026-09-20T10:13:00Z", "author": {"name": "Kira762"}}
}
JSON

cat >"$WORK/force.json" <<'JSON'
{
  "ref": "refs/heads/main",
  "forced": true,
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1"},
  "sender": {"login": "Kira762"},
  "commits": [
    {"id": "8888888888888888888888888888888888888888", "message": "Rewritten history, part one", "author": {"name": "Kira762"}, "added": [], "removed": [], "modified": ["a.luau"]},
    {"id": "9999999999999999999999999999999999999999", "message": "Rewritten history, part two", "author": {"name": "Kira762"}, "added": [], "removed": [], "modified": ["b.luau"]}
  ],
  "head_commit": {"id": "9999999999999999999999999999999999999999", "timestamp": "2026-09-20T10:13:00Z", "author": {"name": "Kira762"}}
}
JSON

cat >"$WORK/empty.json" <<'JSON'
{
  "ref": "refs/heads/main",
  "before": "0000000000000000000000000000000000000000",
  "after": "0000000000000000000000000000000000000000",
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1"},
  "sender": {"login": "Kira762"},
  "commits": [],
  "head_commit": null
}
JSON

cat >"$WORK/single.json" <<'JSON'
{
  "ref": "refs/heads/main",
  "repository": {"full_name": "Kira762/astra-version-1", "html_url": "https://github.com/Kira762/astra-version-1"},
  "sender": {"login": "Kira762"},
  "commits": [
    {"id": "abcdefabcdefabcdefabcdefabcdefabcdefabcd", "message": "A single push, where the whole first line of the message fits comfortably inside the wider subject budget", "author": {"name": "Kira762"}, "added": [], "removed": [], "modified": ["version-1.luau"]}
  ],
  "head_commit": {"id": "abcdefabcdefabcdefabcdefabcdefabcdefabcd", "timestamp": "2026-09-20T10:13:00Z", "author": {"name": "Kira762"}}
}
JSON

echo '{}' >"$WORK/minimal.json"

# ------------------------------------------------------------- the embed -----

section "a normal push"
build "$WORK/basic.json" "$WORK/basic.out"
check "one embed" "$(jqf "$WORK/basic.out" '.embeds | length')" "1"
check "accent colour is Discord's dark embed background" \
	"$(jqf "$WORK/basic.out" '.embeds[0].color')" "2829617"
check "title names the count and the branch" \
	"$(jqf "$WORK/basic.out" '.embeds[0].title')" 'Pushed 3 commits to `main`'
check "title links to the compare view" \
	"$(jqf "$WORK/basic.out" '.embeds[0].url')" \
	"https://github.com/Kira762/astra-version-1/compare/9049f12...0d1a26e"
check "author is the repository" \
	"$(jqf "$WORK/basic.out" '.embeds[0].author.name')" "Kira762/astra-version-1"
check "author carries the repository avatar" \
	"$(jqf "$WORK/basic.out" '.embeds[0].author.icon_url')" \
	"https://avatars.githubusercontent.com/u/322647714?v=4"
check "three fields, in order" \
	"$(jqf "$WORK/basic.out" '[.embeds[0].fields[].name] | join(",")')" "Branch,Commit,Files"
check "all three inline, so they share one row" \
	"$(jqf "$WORK/basic.out" '[.embeds[0].fields[].inline] | all')" "true"
check "branch field links to the branch" \
	"$(jqf "$WORK/basic.out" '.embeds[0].fields[0].value')" \
	'[`main`](https://github.com/Kira762/astra-version-1/tree/main)'
check "commit field links to the head commit" \
	"$(jqf "$WORK/basic.out" '.embeds[0].fields[1].value')" \
	'[`0d1a26e`](https://github.com/Kira762/astra-version-1/commit/0d1a26e67d8f5eaf1f6ba5c57fc3c7d91ac0fd1c)'
check "file churn counts unique paths" \
	"$(jqf "$WORK/basic.out" '.embeds[0].fields[2].value')" "5 files · 1 added · 1 deleted"
check "footer names who pushed" \
	"$(jqf "$WORK/basic.out" '.embeds[0].footer.text')" "Pushed by Kira762"
check "timestamp is the head commit's" \
	"$(jqf "$WORK/basic.out" '.embeds[0].timestamp')" "2026-09-20T10:13:00+02:00"
check "mentions stay off" \
	"$(jqf "$WORK/basic.out" '.allowed_mentions.parse | length')" "0"
check "one log line per commit" \
	"$(jqf "$WORK/basic.out" '.embeds[0].description | split("\n") | length')" "3"
check "the log keeps the short sha and the author" \
	"$(jqf "$WORK/basic.out" '.embeds[0].description | split("\n")[0]')" \
	"- [\`aa11bb2\`](https://github.com/Kira762/astra-version-1/commit/aa11bb22cc33dd44ee55ff667788990011223344) Fix the webhook layout — Kira762"
check "a commit body stays out of the log line" \
	"$(jqf "$WORK/basic.out" '.embeds[0].description | test("own lines")')" "false"
check_limits "normal push" "$WORK/basic.out"

section "accent colour"
DISCORD_EMBED_COLOR=15922165 build "$WORK/basic.json" "$WORK/light.out"
check "the colour is configurable for a light-theme channel" \
	"$(jqf "$WORK/light.out" '.embeds[0].color')" "15922165"
DISCORD_EMBED_COLOR="not a colour" build "$WORK/basic.json" "$WORK/badcolor.out"
check "garbage in the variable falls back, it does not break the payload" \
	"$(jqf "$WORK/badcolor.out" '.embeds[0].color')" "2829617"

section "a commit message that wants to break the payload"
build "$WORK/nasty.json" "$WORK/nasty.out"
check "the message stays on one line" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].description | split("\n") | length')" "1"
check "the subject is clamped" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].description | length <= 200')" "true"
check "quotes survive as text, not as syntax" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].description | contains("Say \"hello\"")')" "true"
check "the commit link survives a message full of Markdown" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].description | contains("[`3333333`](https://github.com/Kira762/astra-version-1/commit/3333333333333333333333333333333333333333)")')" "true"
check "an author with brackets in their name stays readable" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].description | contains("The Bracket")')" "true"
check "an over-long title is clamped and marked" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].title | length')" "240"
check "an unusable timestamp falls back to now" \
	"$(jqf "$WORK/nasty.out" '.embeds[0].timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")')" "true"
check_limits "hostile push" "$WORK/nasty.out"

section "a push with more commits than fit"
build "$WORK/many.json" "$WORK/many.out"
kept="$(jqf "$WORK/many.out" '[.embeds[0].description | split("\n")[] | select(startswith("- ["))] | length')"
dropped="$(jqf "$WORK/many.out" '.embeds[0].description | capture("and (?<n>[0-9]+) more") | .n')"
check "the log is capped well inside the description limit" \
	"$(jqf "$WORK/many.out" '.embeds[0].description | length <= 3000')" "true"
check "every commit is accounted for: kept + dropped = sent" \
	"$((kept + dropped))" "40"
check "the overflow line says how many were left out" \
	"$(jqf "$WORK/many.out" '.embeds[0].description | contains("more commit(s) — open the compare link above")')" "true"
check_limits "large push" "$WORK/many.out"

section "the other kinds of push"
build "$WORK/tag.json" "$WORK/tag.out"
check "a new tag reads as published" \
	"$(jqf "$WORK/tag.out" '.embeds[0].title')" 'Published tag `v1.2.0`'
check "the ref field is called Tag" \
	"$(jqf "$WORK/tag.out" '.embeds[0].fields[0].name')" "Tag"
check_limits "tag push" "$WORK/tag.out"

build "$WORK/delete.json" "$WORK/delete.out"
check "a deleted branch says so" \
	"$(jqf "$WORK/delete.out" '.embeds[0].title')" 'Deleted branch `feature/old`'
check "a deleted branch explains itself" \
	"$(jqf "$WORK/delete.out" '.embeds[0].description')" \
	'Branch `feature/old` was deleted from `Kira762/astra-version-1`.'
check "an all-zero after is not a commit" \
	"$(jqf "$WORK/delete.out" '.embeds[0].fields[1].value')" "No commit in this push."
check "no Files field with nothing to count" \
	"$(jqf "$WORK/delete.out" '[.embeds[0].fields[].name] | join(",")')" "Branch,Commit"
check_limits "branch deletion" "$WORK/delete.out"

build "$WORK/create.json" "$WORK/create.out"
check "a new branch reports its commit count" \
	"$(jqf "$WORK/create.out" '.embeds[0].title')" 'Created branch `new-thing` with 2 commits'
check "a file touched twice still counts once" \
	"$(jqf "$WORK/create.out" '.embeds[0].fields[2].value')" "1 file · 1 added · 0 deleted"
check_limits "branch creation" "$WORK/create.out"

build "$WORK/force.json" "$WORK/force.out"
check "a force push says it was forced" \
	"$(jqf "$WORK/force.out" '.embeds[0].title')" 'Force-pushed 2 commits to `main`'
check "one commit is singular" \
	"$(build "$WORK/single.json" /dev/stdout | jq -r '.embeds[0].title')" 'Pushed 1 commit to `main`'
check "a lone commit gets the longer subject budget" \
	"$(build "$WORK/single.json" /dev/stdout | jq -r '.embeds[0].description | contains("the whole first line of the message fits")')" "true"
check_limits "force push" "$WORK/force.out"

build "$WORK/empty.json" "$WORK/empty.out"
check "an empty push does not claim commits" \
	"$(jqf "$WORK/empty.out" '.embeds[0].title')" 'Updated branch `main`'
check "an empty push explains itself" \
	"$(jqf "$WORK/empty.out" '.embeds[0].description')" "This push carried no commits."
check_limits "empty push" "$WORK/empty.out"

build "$WORK/minimal.json" "$WORK/minimal.out"
check "an event with nothing in it still produces a payload" \
	"$(jqf "$WORK/minimal.out" '.embeds | length')" "1"
check "a missing ref is labelled, not blank" \
	"$(jqf "$WORK/minimal.out" '.embeds[0].fields[0].value')" '[`unknown-ref`](https://github.com/tree/unknown-ref)'
check "a missing sender is labelled, not blank" \
	"$(jqf "$WORK/minimal.out" '.embeds[0].footer.text')" "Pushed by unknown"
check_limits "empty event" "$WORK/minimal.out"

# --------------------------------------------------------------- the sender --

section "discord-notify.sh"

mkdir -p "$WORK/bin"
cat >"$WORK/bin/curl" <<'STUB'
#!/bin/sh
# Stand-in for curl: records what it was asked to do and answers a canned
# status, so the suite never touches the network.
: >"$CURL_LOG"
prev=""
for arg in "$@"; do
	printf '%s\n' "$arg" >>"$CURL_LOG"
	if [ "$prev" = "--output" ] && [ -n "${CURL_RESPONSE_BODY:-}" ]; then
		printf '%s' "$CURL_RESPONSE_BODY" >"$arg"
	fi
	case "$arg" in
		@*) cp "${arg#@}" "$CURL_BODY" ;;
	esac
	prev="$arg"
done
printf '%s' "${CURL_STATUS:-204}"
STUB
chmod +x "$WORK/bin/curl"

CURL_LOG="$WORK/curl-args.txt"
CURL_BODY="$WORK/posted.json"
GOOD_URL="https://discord.com/api/webhooks/1234567890/abcdefghijklmnop"

post() {
	# post <url> [VAR=value ...] — runs the sender with curl stubbed out
	: >"$CURL_LOG"
	rm -f "$CURL_BODY"
	url="$1"
	shift
	env PATH="$WORK/bin:$PATH" CURL_LOG="$CURL_LOG" CURL_BODY="$CURL_BODY" \
		CURL_STATUS="${CURL_STATUS:-204}" CURL_RESPONSE_BODY="${CURL_RESPONSE_BODY:-}" \
		DISCORD_WEBHOOK_URL="$url" "$@" \
		sh "$NOTIFY" "$WORK/basic.json" >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
}

post "$GOOD_URL"
check_status "posts to a Discord webhook URL" "$?" "0"
check "it really posted the embed the filter built" \
	"$(jqf "$CURL_BODY" '.embeds[0].title')" 'Pushed 3 commits to `main`'
check "it posted to the webhook URL" \
	"$(grep -c -F "$GOOD_URL" "$CURL_LOG" || true)" "1"
check "it sends JSON" \
	"$(grep -c -F 'Content-Type: application/json' "$CURL_LOG" || true)" "1"
check "it sends the payload as a file, not an argument" \
	"$(grep -c -F -- '--data-binary' "$CURL_LOG" || true)" "1"
check "it retries" \
	"$(grep -c -x -F -- '--retry' "$CURL_LOG" || true)" "1"
check "it reports success" \
	"$(grep -c -F 'sent to Discord (204)' "$WORK/stdout.txt" || true)" "1"

post "https://evil.example.invalid/api/webhooks/1/x"
check_status "refuses a URL that is not a Discord webhook" "$?" "1"
check "a refused URL receives nothing" \
	"$(wc -c <"$CURL_LOG" | tr -d ' ')" "0"
check "the refusal explains the opt-out" \
	"$(grep -c -F 'DISCORD_ALLOW_ANY_WEBHOOK_URL=1' "$WORK/stderr.txt" || true)" "1"

post "https://relay.example.invalid/hook" DISCORD_ALLOW_ANY_WEBHOOK_URL=1
check_status "posts elsewhere when explicitly allowed" "$?" "0"
check "the opt-out warns" \
	"$(grep -c -F 'non-Discord URL' "$WORK/stderr.txt" || true)" "1"

post ""
check_status "skips quietly with no secret configured" "$?" "0"
check "an unconfigured secret posts nothing" \
	"$(wc -c <"$CURL_LOG" | tr -d ' ')" "0"
check "an unconfigured secret says why" \
	"$(grep -c -F 'skipping the notification' "$WORK/stdout.txt" || true)" "1"

post "$GOOD_URL" DISCORD_EMBED_COLOR=banana
check_status "rejects a colour that is not a number" "$?" "2"
check "a bad colour posts nothing" \
	"$(wc -c <"$CURL_LOG" | tr -d ' ')" "0"

post "$GOOD_URL" DISCORD_EMBED_COLOR=15922165
check_status "accepts a configured colour" "$?" "0"
check "the configured colour reaches the payload" \
	"$(jqf "$CURL_BODY" '.embeds[0].color')" "15922165"

CURL_STATUS=400 CURL_RESPONSE_BODY='{"message": "Invalid Form Body"}' post "$GOOD_URL"
check_status "fails loudly on a 400" "$?" "1"
check "a 400 shows Discord's explanation" \
	"$(grep -c -F 'Invalid Form Body' "$WORK/stderr.txt" || true)" "1"
unset CURL_STATUS CURL_RESPONSE_BODY

env PATH="$WORK/bin:$PATH" CURL_LOG="$CURL_LOG" CURL_BODY="$CURL_BODY" \
	DISCORD_WEBHOOK_URL="$GOOD_URL" sh "$NOTIFY" "$WORK/does-not-exist.json" \
	>"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
check_status "fails on an unreadable event file" "$?" "2"
check "an unreadable event file is named in the error" \
	"$(grep -c -F 'does-not-exist.json' "$WORK/stderr.txt" || true)" "1"

# ------------------------------------------------------------- the workflow --

section "the workflow"
check "the workflow runs the script in the repository" \
	"$(grep -c -F 'sh .github/scripts/discord-notify.sh "$GITHUB_EVENT_PATH"' "$WORKFLOW" || true)" "1"
check "the workflow checks the repository out first" \
	"$(grep -c -F 'actions/checkout' "$WORKFLOW" || true)" "1"
check "the workflow exposes the colour as a repository variable" \
	"$(grep -c -F 'vars.DISCORD_EMBED_COLOR' "$WORKFLOW" || true)" "1"
check "the workflow keeps contents:read only" \
	"$(grep -c -F 'contents: read' "$WORKFLOW" || true)" "1"
check "no jq program is left inline in the workflow" \
	"$(grep -c -F 'embeds: [' "$WORKFLOW" || true)" "0"

# ------------------------------------------------------------------ report ---

echo ""
if [ "$failures" -ne 0 ]; then
	echo "DISCORD NOTIFY TEST FAILED: $failures of $checks checks" >&2
	exit 1
fi
echo "DISCORD NOTIFY TEST PASSED ($checks checks)"
exit 0
