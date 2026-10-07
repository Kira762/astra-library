#!/bin/sh
# Runtime test for the Changelog's nested entry surface: an entry card reads as
# a recess in the changelog card (window surface, no outline of its own) rather
# than as a second frame, so a changelog wears one lit line however many
# releases it lists — while a panel that floats over other content (a Dropdown
# list) keeps the edge `StyleElementPanel` gives it. Assembles mini Roblox
# stubs + bundle (wrapped in a function to keep `local` scoping) + assertions,
# writes it to a temp file, and runs it under the Luau CLI from PATH if
# available, else /tmp/luau.
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
OUT="$TMPDIR_LOCAL/astra_changelog_entry_surface_$$.luau"
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
	cat "$ROOT/scripts/changelog_entry_surface_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "CHANGELOG ENTRY SURFACE TEST PASSED"
	exit 0
else
	echo "CHANGELOG ENTRY SURFACE TEST FAILED (see above)" >&2
	exit 1
fi
