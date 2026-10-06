#!/bin/sh
# Runtime test for the dropdown search filter: case-insensitive matching, a
# renamed row filtering on its new name, the select-all row answering for the
# filtered set rather than the whole option list, and the open panel height
# tracking the number of visible rows.
#
# These are the behaviours that the single-pass filter refactor could break,
# so they are pinned here rather than left to the eye.
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
OUT="$TMPDIR_LOCAL/astra_dropdown_filter_$$.luau"
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
	cat "$ROOT/scripts/dropdown_filter_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "DROPDOWN FILTER TEST PASSED"
	exit 0
else
	echo "DROPDOWN FILTER TEST FAILED (see above)" >&2
	exit 1
fi
