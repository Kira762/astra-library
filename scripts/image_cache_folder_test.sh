#!/bin/sh
# Runtime test for the workspace ImageCache leftover: Astra never creates
# that folder (configs stay under Astra/config, images under Astra/assets),
# an empty executor ImageCache created by getcustomasset is discarded, and
# a non-empty one is left alone.
#
# Assembles: mini Roblox stubs + folder-tracking filesystem + bundle
# (wrapped in a function to keep `local` scoping) + assertions.
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
OUT="$TMPDIR_LOCAL/astra_image_cache_folder_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/workspace_fs_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/image_cache_folder_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "IMAGE CACHE FOLDER TEST PASSED"
	exit 0
else
	echo "IMAGE CACHE FOLDER TEST FAILED (see above)" >&2
	exit 1
fi
