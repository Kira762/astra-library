#!/bin/sh
# Runtime test for the window's surface hierarchy and flush spacing:
# the topbar, tab rail and elements area each carry their own theme surface
# (darkest → lightest from chrome to content, on the default palette), sit
# flush against each other, the selected tab row is painted with the
# elements-area colour, the capsule state folds the topbar surface away and
# the minimised bar keeps it, and the bottom fade blends into the elements
# surface.
#
# Assembles: mini Roblox stubs + bundle (wrapped in a function to keep
# `local` scoping) + assertions, writes it to a temp file, and runs it under
# the Luau CLI from PATH if available, else /tmp/luau.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/version-1.luau"

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
OUT="$TMPDIR_LOCAL/astra_surface_hierarchy_$$.luau"
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
	cat "$ROOT/scripts/surface_hierarchy_test.luau"
} > "$OUT"

"$LUAU_BIN" "$OUT" && echo "SURFACE HIERARCHY TEST PASSED"
