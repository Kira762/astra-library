#!/bin/sh
# Post a GitHub push event to a Discord webhook as one embed.
#
#   usage: discord-notify.sh [event.json]
#
#   DISCORD_WEBHOOK_URL            required. https://discord.com/api/webhooks/...
#   DISCORD_EMBED_COLOR            optional decimal accent colour for the embed's
#                                  left bar. Defaults to 2829617 (#2B2D31),
#                                  which is Discord's dark-theme embed
#                                  background - the bar blends in instead of
#                                  drawing a green stripe down the channel.
#                                  Light theme background is 15922165.
#   DISCORD_ALLOW_ANY_WEBHOOK_URL  optional. Set to 1 to post somewhere that is
#                                  not a discord.com webhook URL (a relay, a
#                                  self-hosted proxy). Without it a URL that
#                                  does not look like a Discord webhook is
#                                  refused, so a typo cannot quietly ship the
#                                  repository's commit log to a stranger.
#
# Reads the event from the argument, or from $GITHUB_EVENT_PATH when there is
# no argument. The payload itself is built by discord-embed.jq beside this
# file; this script only checks its inputs, calls jq, and posts the result.
#
# Exit codes: 0 sent (or skipped, no secret configured), 1 refused or failed,
# 2 unusable inputs (missing file, no jq, bad colour).
set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
EMBED_FILTER="$SELF_DIR/discord-embed.jq"
DEFAULT_COLOR=2829617

say() { printf 'discord-notify: %s\n' "$1"; }
warn() { printf 'discord-notify: %s\n' "$1" >&2; }
die() {
	warn "$1"
	exit "${2:-1}"
}

EVENT="${1:-${GITHUB_EVENT_PATH:-}}"
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
COLOR="${DISCORD_EMBED_COLOR:-$DEFAULT_COLOR}"
TMPDIR_LOCAL="${TMPDIR:-/tmp}"

# --- inputs ------------------------------------------------------------------

[ -n "$EVENT" ] || die "no event payload: pass a path or set GITHUB_EVENT_PATH." 2
[ -r "$EVENT" ] || die "cannot read the event payload at $EVENT." 2
[ -f "$EMBED_FILTER" ] || die "missing the embed filter: $EMBED_FILTER." 2

command -v jq >/dev/null 2>&1 || die "jq is required to build the payload." 2
command -v curl >/dev/null 2>&1 || die "curl is required to post the payload." 2

# A repository without the secret configured should not fail every push: the
# notification is decoration, not part of the build. Loud, but green.
if [ -z "$WEBHOOK_URL" ]; then
	say "DISCORD_WEBHOOK_URL is not set - skipping the notification."
	say "Add the repository secret to turn these notifications on."
	exit 0
fi

case "$COLOR" in
	'' | *[!0-9]*)
		die "DISCORD_EMBED_COLOR must be a decimal number, got '$COLOR'." 2
		;;
esac

# Anything that is not a Discord webhook URL is refused unless the caller opts
# out: the payload carries commit messages, author names and repository URLs.
is_discord_url() {
	case "$1" in
		https://discord.com/api/webhooks/*) return 0 ;;
		https://discordapp.com/api/webhooks/*) return 0 ;;
		https://canary.discord.com/api/webhooks/*) return 0 ;;
		https://ptb.discord.com/api/webhooks/*) return 0 ;;
	esac
	return 1
}

if ! is_discord_url "$WEBHOOK_URL"; then
	if [ "${DISCORD_ALLOW_ANY_WEBHOOK_URL:-0}" = "1" ]; then
		warn "posting to a non-Discord URL because DISCORD_ALLOW_ANY_WEBHOOK_URL=1."
	else
		die "the webhook URL is not a https://discord.com/api/webhooks/... address.
Set DISCORD_ALLOW_ANY_WEBHOOK_URL=1 to post there anyway."
	fi
fi

# --- build -------------------------------------------------------------------

WORK="$(mktemp -d "$TMPDIR_LOCAL/astra-discord-notify.XXXXXX")" || die "cannot create a temp directory." 2
trap 'rm -rf "$WORK"' EXIT INT TERM
PAYLOAD="$WORK/payload.json"
RESPONSE="$WORK/response.txt"

if ! DISCORD_EMBED_COLOR="$COLOR" jq -c -f "$EMBED_FILTER" "$EVENT" >"$PAYLOAD"; then
	die "could not build a payload from $EVENT."
fi

[ -s "$PAYLOAD" ] || die "the payload came back empty from $EMBED_FILTER."

# --- post --------------------------------------------------------------------

# --fail is deliberately absent: the response body is what explains a 400, and
# --fail would throw it away. The status code is checked by hand instead.
status="$(
	curl \
		--silent \
		--show-error \
		--retry 3 \
		--retry-delay 2 \
		--max-time 30 \
		--header 'Content-Type: application/json' \
		--output "$RESPONSE" \
		--write-out '%{http_code}' \
		--data-binary @"$PAYLOAD" \
		"$WEBHOOK_URL" 2>"$WORK/curl.log"
)" || status="000"

# A retried transfer can emit the write-out more than once; the last one is the
# attempt that decided the outcome.
status="$(printf '%s\n' "$status" | tail -n 1)"

case "$status" in
	200 | 204)
		say "sent to Discord (${status})."
		exit 0
		;;
esac

warn "Discord answered HTTP ${status}."
if [ -s "$WORK/curl.log" ]; then
	sed -n '1,5p' "$WORK/curl.log" >&2
fi
if [ -s "$RESPONSE" ]; then
	say "response body:"
	sed -n '1,20p' "$RESPONSE" >&2
fi
exit 1
