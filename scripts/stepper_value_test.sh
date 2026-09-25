#!/bin/sh
# Runtime test for the Stepper (Value Configuration) element: the 0 default,
# per-click ±step with the display following, the 0 floor (a (−) tap there is
# a no-op with no callback), the optional max ceiling, typed commits clamping
# into range with unparseable text restoring the old value, the callback
# firing only on real changes, an inert description prop, the field's neutral
# SurfaceStroke hairline (tightened by focus) and the title/pill centre line.
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
OUT="$TMPDIR_LOCAL/astra_stepper_value_$$.luau"
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
	cat "$ROOT/scripts/stepper_value_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "STEPPER VALUE TEST PASSED"
	exit 0
else
	echo "STEPPER VALUE TEST FAILED (see above)" >&2
	exit 1
fi
