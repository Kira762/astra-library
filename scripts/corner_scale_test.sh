#!/bin/sh
# Runtime test for the corner scale: the three nested theme tiers (shell,
# elements, folds), the controls that derive a half-height pill from their own
# metrics, the dropdown's theme-read row tiers, a theme change reaching every
# bound surface, the corners that stay square on purpose, and a sweep that fails
# if any painted surface is left with an all-zero corner.
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
	for candidate in /tmp/luau /usr/local/bin/luau "$ROOT/.tools/bin/luau"; do
		if [ -x "$candidate" ]; then
			LUAU_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_BIN" ]; then
	echo "luau CLI not found (looked in PATH, /tmp, /usr/local/bin, .tools/bin)" >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
OUT="$TMPDIR_LOCAL/astra_corner_scale_$$.luau"
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
	cat "$ROOT/scripts/corner_scale_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "CORNER SCALE TEST PASSED"
	exit 0
else
	echo "CORNER SCALE TEST FAILED (see above)" >&2
	exit 1
fi
