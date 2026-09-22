#!/bin/sh
# Runtime test for the standalone key gate: geometry and corner scale, wrong /
# right submits, saved-key passthrough, the attempt budget, theme overlays,
# remote keys, the get-key copy note and dismissal.
#
# Assembles: mini Roblox stubs + in-memory executor filesystem + bundle
# (wrapped in a function to keep `local` scoping) + assertions, writes it to
# a temp file, and runs it under the Luau CLI from PATH if available, else
# /tmp/luau.
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
OUT="$TMPDIR_LOCAL/astra_key_system_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/filesystem_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/key_system_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "KEY SYSTEM TEST PASSED"
	exit 0
else
	echo "KEY SYSTEM TEST FAILED (see above)" >&2
	exit 1
fi
