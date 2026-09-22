#!/bin/sh
# One gate that runs everything: static require graph, instance-field safety,
# dangling path references, syntax/compile of every published file, then the
# whole runtime test suite. This is the command to run before publishing a
# change to version-1.luau.
#
# Needs the Luau toolchain on PATH. If it is missing:
#   sh scripts/install_luau.sh && export PATH="$PWD/.tools/bin:$PATH"
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# Prefer a locally built toolchain without forcing the caller to export PATH.
if [ -d "$ROOT/.tools/bin" ]; then
	PATH="$ROOT/.tools/bin:$PATH"
	export PATH
fi

failures=0
section() {
	echo ""
	echo "=============================================================="
	echo "$1"
	echo "=============================================================="
}

section "1/6  static require graph"
if python3 scripts/check_requires.py; then
	echo "requires OK"
else
	echo "REQUIRE GRAPH FAILED" >&2
	failures=$((failures + 1))
fi

section "2/6  no custom fields written on Instances"
if python3 scripts/check_instance_fields.py; then
	:
else
	echo "INSTANCE-FIELD CHECK FAILED" >&2
	failures=$((failures + 1))
fi

section "3/6  no dangling repo path references"
if python3 scripts/check_dangling_refs.py; then
	:
else
	echo "DANGLING-REFERENCE CHECK FAILED" >&2
	failures=$((failures + 1))
fi

section "4/6  bundle is up to date with the source tree"
if command -v node >/dev/null 2>&1; then
	cp version-1.luau "${TMPDIR:-/tmp}/astra_bundle_check.$$" 2>/dev/null
	node scripts/generate_bundle.js >/dev/null 2>&1
	if diff -q "${TMPDIR:-/tmp}/astra_bundle_check.$$" version-1.luau >/dev/null 2>&1; then
		echo "bundle matches the source tree"
	else
		echo "BUNDLE IS STALE: version-1.luau did not match the source tree." >&2
		echo "It has now been regenerated -- commit the result." >&2
		failures=$((failures + 1))
	fi
	rm -f "${TMPDIR:-/tmp}/astra_bundle_check.$$"
else
	echo "node not found; skipping bundle freshness check" >&2
fi

section "5/6  syntax / compile gate"
if sh scripts/check_syntax.sh; then
	:
else
	status=$?
	if [ "$status" -eq 2 ]; then
		echo "" >&2
		echo "No Luau toolchain found. Build one with:" >&2
		echo "  sh scripts/install_luau.sh" >&2
	fi
	failures=$((failures + 1))
fi

section "6/6  runtime tests"
pass=0
fail=0
for test in scripts/*_test.sh; do
	[ -f "$test" ] || continue
	name="$(basename "$test" .sh)"
	if output="$(sh "$test" 2>&1)"; then
		pass=$((pass + 1))
		printf '  ok    %s\n' "$name"
	else
		fail=$((fail + 1))
		printf '  FAIL  %s\n' "$name"
		echo "$output" | sed 's/^/          /' | tail -12
	fi
done
echo ""
echo "runtime tests: $pass passed, $fail failed"
[ "$fail" -ne 0 ] && failures=$((failures + 1))

echo ""
if [ "$failures" -ne 0 ]; then
	echo "CHECK FAILED ($failures section(s) with problems)" >&2
	exit 1
fi
echo "ALL CHECKS PASSED"
exit 0
