#!/bin/sh
# Exhaustive regression guard — lock tiers, text/locale, layout/corners.
# See skills/mova-guard/SKILL.md and skills/mova-guard/references/*.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${MOVA_BUNDLE:-${ASTRA_BUNDLE:-$ROOT/version-1.luau}}"
if [ ! -f "$BUNDLE" ]; then echo "bundle missing: $BUNDLE" >&2; exit 1; fi
LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
	for candidate in /tmp/luau /usr/local/bin/luau "$ROOT/.tools/bin/luau"; do
		if [ -x "$candidate" ]; then LUAU_BIN="$candidate"; break; fi
	done
fi
if [ -z "$LUAU_BIN" ]; then echo "luau CLI not found (looked in PATH, /tmp, /usr/local/bin, .tools/bin)" >&2; exit 2; fi
TMPDIR_LOCAL="${TMPDIR:-/tmp}"
OUT="$TMPDIR_LOCAL/mova_guard_invariants_$$.luau"
trap 'rm -f "$OUT"' EXIT
{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	echo ""
	echo "Mova = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/guard_invariants_test.luau"
} > "$OUT"
if "$LUAU_BIN" "$OUT"; then
	echo "GUARD INVARIANTS TEST PASSED"
	exit 0
else
	echo "GUARD INVARIANTS TEST FAILED (see above)" >&2
	exit 1
fi
