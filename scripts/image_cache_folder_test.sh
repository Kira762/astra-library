#!/bin/sh
# Runtime test for the workspace ImageCache leftover: Mova never creates
# that folder (configs stay under Mova/config, images under Mova/assets),
# an empty executor ImageCache created by getcustomasset is discarded, and
# a non-empty one is left alone.
#
# Assembles: mini Roblox stubs + folder-tracking filesystem + bundle
# (wrapped in a function to keep `local` scoping) + assertions.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${MOVA_BUNDLE:-${ASTRA_BUNDLE:-$ROOT/version-1.luau}}"

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
OUT="$TMPDIR_LOCAL/mova_image_cache_folder_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/workspace_fs_stubs.luau"
	cat <<'LUAU'
makefolder("Astra/config")
writefile("Astra/config/legacy.txt", "legacy-config")
writefile("Astra/config/shared.txt", "old-astra-data")
makefolder("Mova/config")
writefile("Mova/config/shared.txt", "new-mova-data")
makefolder("Astra/keys")
writefile("Astra/keys/legacy.txt", "legacy-key")
makefolder("Astra/settings")
writefile("Astra/settings/astra.txt", "{\"migrationProbe\":\"legacy-settings\"}")
LUAU
	echo ""
	echo "Mova = (function()"
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
