#!/bin/sh
# Runtime test for the Footer element (CreateFooter): the centred inline
# text-and-icon strip. Covers run order, the centring layout, icon scaling,
# the reveal path on selected and unselected tabs, Set() replacement,
# unresolved-name dropping, the shorthand forms, Group and declarative
# Collapsible Group construction, the empty run, the move API, and the
# transparency regression — a theme pass or a bar-layout switch must never
# paint the footer's transparent container.
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
OUT="$TMPDIR_LOCAL/astra_footer_$$.luau"
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
	cat "$ROOT/scripts/footer_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "FOOTER TEST PASSED"
	exit 0
else
	echo "FOOTER TEST FAILED (see above)" >&2
	exit 1
fi
