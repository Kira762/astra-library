#!/bin/sh
# Runtime test for the window changelog panel: the topbar action + divider, the
# lazy exclusive view, the Set/Add/Clear data API, the option-A redirect for
# Tab:CreateChangelog, and the red unread dot with its own seen-state file.
#
# Assembles: mini Roblox stubs + in-memory filesystem stubs + bundle (wrapped
# in a function to keep `local` scoping) + assertions, writes it to a temp
# file, and runs it under the Luau CLI from PATH if available, else /tmp/luau.
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
OUT="$TMPDIR_LOCAL/astra_changelog_panel_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/profile_image_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/changelog_panel_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "CHANGELOG PANEL TEST PASSED"
	exit 0
else
	echo "CHANGELOG PANEL TEST FAILED (see above)" >&2
	exit 1
fi
