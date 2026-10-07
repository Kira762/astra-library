#!/bin/sh
# Runtime test for the capsule's double tap: the pill folds into the
# icon-only circle and back, the shape change keeps the pill's left edge (so
# it travels right to left), the face follows, a single tap still restores
# the window once the gesture window passes, a drag or an already-shown
# window drops a parked restore, and a capsule built icon-only starts as the
# circle.
#
# The gesture is driven through the stub's input services (a press on the
# capsule plus a service InputEnded), the same pair components/chrome.luau
# binds; the parked restore is observed by pumping the harness's virtual
# clock, and a held main-frame tween pins the mid-movement state.
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
OUT="$TMPDIR_LOCAL/astra_capsule_double_tap_$$.luau"
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
	cat "$ROOT/scripts/capsule_double_tap_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "CAPSULE DOUBLE TAP TEST PASSED"
	exit 0
else
	echo "CAPSULE DOUBLE TAP TEST FAILED (see above)" >&2
	exit 1
fi
