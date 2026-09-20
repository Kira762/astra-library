#!/bin/sh
# Build the Luau toolchain (luau, luau-compile, luau-analyze) from source into
# .tools/bin, so the syntax gate and the runtime tests have something to run.
#
# Why build instead of download: the prebuilt CLIs live on
# release-assets.githubusercontent.com, which is unreachable from some CI and
# sandbox environments (the download fails with an SSL/connect error rather
# than a 404). The source tarball comes from codeload.github.com, which is
# generally reachable, and the build needs nothing but a C++17 compiler and
# make -- both already required for any Luau work.
#
# Usage:
#   sh scripts/install_luau.sh          # build if missing
#   sh scripts/install_luau.sh --force  # rebuild from scratch
#   LUAU_VERSION=0.640 sh scripts/install_luau.sh
#
# Then put the tools on PATH for the session:
#   export PATH="$PWD/.tools/bin:$PATH"
#
# scripts/check_syntax.sh and the *_test.sh scripts already look in PATH,
# /tmp and /usr/local/bin, so exporting PATH is all they need.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${LUAU_VERSION:-0.640}"
BIN="$ROOT/.tools/bin"
SRC="$ROOT/.tools/src"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if [ "$FORCE" -eq 0 ] && [ -x "$BIN/luau" ] && [ -x "$BIN/luau-compile" ]; then
	echo "Luau toolchain already present in .tools/bin (use --force to rebuild)."
	echo "Add it to PATH:  export PATH=\"$ROOT/.tools/bin:\$PATH\""
	exit 0
fi

for tool in g++ make curl tar; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "missing required build tool: $tool" >&2
		exit 1
	}
done

JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2) )"

mkdir -p "$BIN" "$SRC"
cd "$SRC"

if [ ! -d "luau-$VERSION" ]; then
	echo "Fetching Luau $VERSION source..."
	curl -sSL --max-time 300 -o "luau-$VERSION.tar.gz" \
		"https://codeload.github.com/luau-lang/luau/tar.gz/refs/tags/$VERSION"
	tar xzf "luau-$VERSION.tar.gz"
	rm -f "luau-$VERSION.tar.gz"
fi

cd "luau-$VERSION"
echo "Building luau, luau-compile and luau-analyze with $JOBS job(s)..."
echo "(luau-analyze links the whole type checker and is the slow one.)"
make -j"$JOBS" config=release luau luau-compile luau-analyze

cp build/release/luau build/release/luau-compile build/release/luau-analyze "$BIN/"
echo ""
echo "Installed into $BIN:"
ls -1 "$BIN"
echo ""
echo "Add it to PATH:  export PATH=\"$ROOT/.tools/bin:\$PATH\""
echo "Then:            sh scripts/check_all.sh"
