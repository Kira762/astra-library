#!/bin/sh
# Syntax gate for every published .luau file (modular tree, example, bundle).
#
# Why this exists: a stray syntax error in a published file does not surface as
# a syntax error for the person loading it. `loadstring` does not throw when the
# text will not compile - it returns nil plus the error - so the user's
# `loadstring(source)()` dies with "attempt to call a nil value" at line 1 of a
# randomly named chunk, a message that names neither the file nor the line that
# is actually broken. This is the gate that catches it here instead.
#
# Toolchain, same lookup the runtime test scripts use (PATH, then /tmp, then
# /usr/local/bin): `luau-compile` from the Luau releases is preferred; the `luau`
# CLI works too when it supports `--compile`. Both absent means "not checked"
# (exit 2), never a silent pass.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

find_tool() {
	local name="$1"
	local found
	found="$(command -v "$name" || true)"
	if [ -n "$found" ]; then
		echo "$found"
		return
	fi
	for dir in /tmp /usr/local/bin; do
		if [ -x "$dir/$name" ]; then
			echo "$dir/$name"
			return
		fi
	done
}

LUAU_COMPILE="$(find_tool luau-compile)"
LUAU_BIN="$(find_tool luau)"
if [ -z "$LUAU_COMPILE" ] && [ -n "$LUAU_BIN" ] && ! "$LUAU_BIN" --help 2>&1 | grep -q -- "--compile"; then
	LUAU_BIN=""
fi
if [ -z "$LUAU_COMPILE" ] && [ -z "$LUAU_BIN" ]; then
	echo "no compile-only Luau tool found (looked for luau-compile, and luau --compile," >&2
	echo "in PATH, /tmp and /usr/local/bin)." >&2
	echo "Get one from https://github.com/luau-lang/luau/releases - the same CLI the" >&2
	echo "runtime test scripts in this folder expect." >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
WORK="$TMPDIR_LOCAL/astra_syntax_$$"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out"

# compile_one <file> — silent on success, prints the tool's diagnostics otherwise.
# luau-compile writes bytecode to stdout (it has no --output flag), so the
# blob is redirected into the work dir; only the exit code matters.
compile_one() {
	if [ -n "$LUAU_COMPILE" ]; then
		"$LUAU_COMPILE" --binary "$1" >"$WORK/out/blob" 2>"$WORK/log"
	else
		"$LUAU_BIN" --compile=binary "$1" >"$WORK/blob" 2>"$WORK/log"
	fi
}

FILES=""
for dir in core components elements settings cache functions layouts images icons themes utilities; do
	if [ -d "$dir" ]; then
		FILES="$FILES $(find "$dir" -name '*.luau' | sort)"
	fi
done
FILES="$FILES library_entrypoint.luau Types.luau example.client.luau changelog.example.luau version-1.luau loader.luau"

checked=0
failed=0
for file in $FILES; do
	if [ ! -f "$file" ]; then
		echo "MISSING  $file" >&2
		failed=$((failed + 1))
		continue
	fi
	if ! compile_one "$file"; then
		echo "SYNTAX   $file"
		sed -n '1,8p' "$WORK/log"
		failed=$((failed + 1))
	fi
	checked=$((checked + 1))
done

if [ "$failed" -ne 0 ]; then
	echo ""
	echo "SYNTAX CHECK FAILED: $failed of $checked file(s) will not compile." >&2
	echo "A file like this cannot be loadstring'd, so callers only ever see" >&2
	echo "'attempt to call a nil value'. Fix the reported line, then regenerate" >&2
	echo "the bundle: node scripts/generate_bundle.js" >&2
	exit 1
fi

echo "SYNTAX CHECK PASSED ($checked file(s) compile)"
exit 0
