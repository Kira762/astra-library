#!/bin/sh
# Runtime test for the Stat element's text readout: a string value that opts
# out of the letter badge (letter = false) builds one TextLabel carrying the
# whole value instead of the digit odometer, in both the full and the compact
# card, reveals and hides with the card, and is what Set / SetText /
# ResetBaseline write to. Numeric stats and the letter-badge default are
# asserted unchanged.
#
# Assembles: mini Roblox stubs + bundle (wrapped in a function to keep
# `local` scoping) + assertions, writes it to a temp file, and runs it under
# the Luau CLI from PATH if available, else /tmp/luau.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${ASTRA_BUNDLE:-$ROOT/version-1.luau}"

if [ ! -f "$BUNDLE" ]; then
	echo "bundle missing: $BUNDLE" >&2
	exit 1
fi

LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
	for candidate in /tmp/luau /usr/local/bin/luau; do
		if [ -x "$candidate" ]; then
			LUAU_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_BIN" ]; then
	echo "luau CLI not found (looked in PATH, /tmp, /usr/local/bin)" >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
OUT="$TMPDIR_LOCAL/astra_stat_text_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/stat_text_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "STAT TEXT TEST PASSED"
	exit 0
else
	echo "STAT TEXT TEST FAILED (see above)" >&2
	exit 1
fi
