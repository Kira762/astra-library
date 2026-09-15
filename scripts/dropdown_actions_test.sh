#!/bin/sh
# Runtime test for the multi-select dropdown's bulk-action row: only a
# multi-select dropdown carries it, the checkbox answers for the options the
# list is showing (on when every visible one is selected), Select all toggles
# that set, Clear removes only what the filter shows, the box follows picks and
# filters, the taller row is in the open height, and the bin is a real icon.
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
OUT="$TMPDIR_LOCAL/astra_dropdown_actions_$$.luau"
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
	cat "$ROOT/scripts/dropdown_actions_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "DROPDOWN ACTIONS TEST PASSED"
	exit 0
else
	echo "DROPDOWN ACTIONS TEST FAILED (see above)" >&2
	exit 1
fi
