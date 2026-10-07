#!/bin/sh
# Runtime test for a letter Stat inside a row Group. A row builds every child
# on the compact card, which has no glyph badge to show a letter in, so the
# value has to read out through the compact card's own readout — and the show /
# hide path has to reveal that card, its accent fill and its title. Assembles
# mini Roblox stubs + bundle (wrapped in a function to keep `local` scoping) +
# assertions, writes it to a temp file, and runs it under the Luau CLI from
# PATH if available, else /tmp/luau.
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
OUT="$TMPDIR_LOCAL/astra_stat_letter_row_$$.luau"
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
	cat "$ROOT/scripts/stat_letter_row_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "STAT LETTER ROW TEST PASSED"
	exit 0
else
	echo "STAT LETTER ROW TEST FAILED (see above)" >&2
	exit 1
fi
