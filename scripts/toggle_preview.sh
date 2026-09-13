#!/bin/sh
# Offline visual preview of the switch (toggle): builds real elements from the
# bundle under the mini Roblox stubs, dumps both states as JSON, then (when
# Pillow is available) renders assets/toggle-preview-off.png and
# assets/toggle-preview-on.png so the switch can be reviewed without launching
# Roblox.
#
#   sh scripts/toggle_preview.sh
#
# Regenerate the bundle first if the source changed: node scripts/generate_bundle.js
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
OUT="$TMPDIR_LOCAL/astra_toggle_preview_$$.luau"
DUMP="$TMPDIR_LOCAL/astra_toggle_preview_$$.json"
trap 'rm -f "$OUT" "$DUMP"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/toggle_preview.luau"
} > "$OUT"

if ! "$LUAU_BIN" "$OUT" > "$DUMP"; then
	echo "TOGGLE PREVIEW DUMP FAILED" >&2
	exit 1
fi

echo "dump written to $DUMP"

if ! command -v python3 > /dev/null; then
	echo "python3 not found; skipping the render" >&2
	exit 0
fi

python3 "$ROOT/scripts/render_toggle_preview.py" "$DUMP" "$ROOT/assets" || {
	echo "PREVIEW RENDER FAILED (is Pillow installed? pip install pillow)" >&2
	exit 1
}
