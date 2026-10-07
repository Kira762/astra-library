#!/bin/sh
# Runtime test for the title-bar search field's reveal: the pill is built
# flat and hidden, opening grows it from right to left into the free space
# between the title and the toolbar actions, closing folds it back and only
# hides it when the movement ends, a reversal mid-flight continues from the
# width showing, and with motion off both directions land on the spot. The
# resting width is automatic — the whole free space — so it follows the
# title/subtitle: a title that changes while the field is open re-fits it.
#
# The pill's tween is held (Play swapped for a no-op) so the assertions can
# read the frame a real open shows before its movement advances -- the same
# trick the capsule suite uses for the window's own fold.
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
OUT="$TMPDIR_LOCAL/astra_search_reveal_$$.luau"
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
	cat "$ROOT/scripts/search_reveal_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "SEARCH REVEAL TEST PASSED"
	exit 0
else
	echo "SEARCH REVEAL TEST FAILED (see above)" >&2
	exit 1
fi
