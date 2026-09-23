#!/bin/sh
# Test the About card: header, data-row geometry and cap, description, the
# optional action band, the setters, reveal/theme paths and the lock.
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
OUT="$TMPDIR_LOCAL/astra_about_card_$$.luau"
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
	cat "$ROOT/scripts/about_card_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "ABOUT CARD TEST PASSED"
	exit 0
else
	echo "ABOUT CARD TEST FAILED (see above)" >&2
	exit 1
fi
