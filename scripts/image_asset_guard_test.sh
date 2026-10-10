#!/bin/sh
# Catalog icons must render when HttpGuard's layer-C heuristics fire (a
# __namecall hook installed by another script, an executor whose `request` is
# a Lua wrapper) while an actual HTTP-spy artifact must still refuse the
# fetch. Numeric window glyphs rendering while every catalog icon stayed
# blank is the bug this pins.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${ASTRA_BUNDLE:-$ROOT/version-1.luau}"

if [ ! -f "$BUNDLE" ]; then
	echo "bundle missing: $BUNDLE" >&2
	exit 1
fi

LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
	for candidate in "$ROOT/.tools/bin/luau" /tmp/luau /usr/local/bin/luau; do
		if [ -x "$candidate" ]; then
			LUAU_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_BIN" ]; then
	echo "luau CLI not found (looked in PATH, .tools/bin, /tmp, /usr/local/bin)" >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
OUT="$TMPDIR_LOCAL/astra_image_asset_guard_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/image_asset_guard_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/image_asset_guard_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "IMAGE ASSET GUARD TEST PASSED"
	exit 0
else
	echo "IMAGE ASSET GUARD TEST FAILED (see above)" >&2
	exit 1
fi
