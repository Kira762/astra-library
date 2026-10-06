#!/bin/sh
# Prove scripts/strip_luau.js cannot change what the code means.
#
# The published bundle is stripped (comments and indentation removed) to cut
# what a `loadstring` has to download and parse. That is only acceptable if
# the result is the same program. "Looks the same" is not evidence, so this
# test asks the compiler:
#
#   for every published module, compile it with luau-compile --binary before
#   and after stripping and require the two blobs to be byte-identical.
#
# Bytecode is the whole program -- instructions, constants, prototypes and,
# at the default debug level, the line table. Two files that compile to the
# same bytes cannot differ in behaviour, and identical line tables are
# exactly the property the bundle's LineOffsets error mapping depends on.
# This catches every class of stripper bug at once: a `--` swallowed inside
# a string, an unterminated long comment, a backtick interpolated string
# mis-lexed, or a line quietly moved.
#
# Needs node and the Luau toolchain on PATH. Missing toolchain = exit 2
# ("not checked"), never a silent pass.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

if ! command -v node >/dev/null 2>&1; then
	echo "node not found; skipping strip equivalence check" >&2
	exit 2
fi

LUAU_COMPILE="$(command -v luau-compile || true)"
if [ -z "$LUAU_COMPILE" ]; then
	for candidate in /tmp/luau-compile /usr/local/bin/luau-compile; do
		if [ -x "$candidate" ]; then
			LUAU_COMPILE="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_COMPILE" ]; then
	echo "no luau-compile found (looked in PATH, /tmp, /usr/local/bin)" >&2
	echo "Build one with:  sh scripts/install_luau.sh" >&2
	exit 2
fi

WORK="${TMPDIR:-/tmp}/astra_strip_equivalence_$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

FILES=""
for dir in core components elements settings cache functions layouts images windowIcons icons themes utilities; do
	if [ -d "$dir" ]; then
		FILES="$FILES $(find "$dir" -name '*.luau' | sort)"
	fi
done
FILES="$FILES library_entrypoint.luau Types.luau example.client.luau changelog.example.luau loader.luau"

checked=0
failed=0
for file in $FILES; do
	[ -f "$file" ] || continue
	if ! node scripts/strip_luau.js "$file" "$WORK/stripped.luau" 2>"$WORK/strip.log"; then
		echo "  FAIL  $file (stripper refused)" >&2
		sed -n '1,4p' "$WORK/strip.log" >&2
		failed=$((failed + 1))
		continue
	fi
	if ! "$LUAU_COMPILE" --binary "$file" >"$WORK/before.bin" 2>/dev/null; then
		echo "  FAIL  $file (original does not compile)" >&2
		failed=$((failed + 1))
		continue
	fi
	if ! "$LUAU_COMPILE" --binary "$WORK/stripped.luau" >"$WORK/after.bin" 2>/dev/null; then
		echo "  FAIL  $file (stripped output does not compile)" >&2
		failed=$((failed + 1))
		continue
	fi
	if ! cmp -s "$WORK/before.bin" "$WORK/after.bin"; then
		echo "  FAIL  $file (bytecode differs after stripping)" >&2
		failed=$((failed + 1))
		continue
	fi
	checked=$((checked + 1))
done

if [ "$failed" -ne 0 ]; then
	echo "" >&2
	echo "STRIP EQUIVALENCE FAILED: $failed of $((checked + failed)) file(s) changed meaning." >&2
	echo "The bundle is published stripped, so a stripper bug ships to every" >&2
	echo "user as a silently different library. Fix scripts/strip_luau.js." >&2
	exit 1
fi

echo "STRIP EQUIVALENCE PASSED ($checked file(s) compile to identical bytecode with and without stripping)"
exit 0
