#!/bin/sh
# One gate for "the version story adds up".
#
# Five files independently claim what the current release is, and nothing
# used to compare them: ASTRA_VERSION, the loader's EXPECTED_BUNDLE_VERSION
# pin, the detached signature, the README's published checksum, and (at
# release time) the git tag. Any one of them can drift silently -- a stale
# README checksum tells a user to trust bytes that are no longer published,
# and a tag that disagrees with ASTRA_VERSION produces a release whose
# assets the loader will reject as the wrong version.
#
# This check makes the bundle digest the single source of truth and holds
# everything else against it.
#
#   sh scripts/check_release_consistency.sh              # repo state
#   sh scripts/check_release_consistency.sh --tag v1.0.0 # also check a tag
#
# Exit 0 = consistent, 1 = at least one mismatch, 2 = cannot run (no node).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

TAG=""
while [ $# -gt 0 ]; do
	case "$1" in
	--tag)
		shift
		TAG="${1:-}"
		;;
	--tag=*)
		TAG="${1#--tag=}"
		;;
	-h | --help)
		sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "unknown argument: $1" >&2
		exit 2
		;;
	esac
	shift
done

if ! command -v node >/dev/null 2>&1; then
	echo "node is required (it computes the canonical digest); skipping" >&2
	exit 2
fi

failures=0
fail() {
	echo "  FAIL  $1" >&2
	failures=$((failures + 1))
}
ok() {
	printf '  ok    %s\n' "$1"
}

# ---------------------------------------------------------------- the facts
VERSION="$(tr -d ' \t\n\r' <ASTRA_VERSION 2>/dev/null || true)"
DIGEST="$(node scripts/sign_bundle.js --print-digest 2>/dev/null | tr -d ' \n\r')"
LOADER_VERSION="$(sed -n 's/^local EXPECTED_BUNDLE_VERSION = "\([^"]*\)".*/\1/p' loader.luau | head -1)"
LOADER_KEY="$(sed -n 's/^local PUBLIC_KEY = "\([0-9a-fA-F]*\)".*/\1/p' loader.luau | head -1)"
README_DIGEST="$(sed -n 's/^sha256(version-1\.luau) = \([0-9a-fA-F]\{64\}\).*/\1/p' README.md | head -1)"
SIG="$(tr -d ' \t\n\r' <version-1.luau.sig 2>/dev/null || true)"

echo "release consistency"
echo "  version  ${VERSION:-<missing>}"
echo "  digest   ${DIGEST:-<missing>}"
echo ""

# 1. ASTRA_VERSION is a usable version number.
case "$VERSION" in
"") fail "ASTRA_VERSION is empty or missing" ;;
*[!0-9.a-zA-Z+-]* | *' '*) fail "ASTRA_VERSION '$VERSION' contains unexpected characters" ;;
[0-9]*.[0-9]*.[0-9]*) ok "ASTRA_VERSION is '$VERSION'" ;;
*) fail "ASTRA_VERSION '$VERSION' is not MAJOR.MINOR.PATCH" ;;
esac

# 2. The digest is computable, i.e. the bundle exists and node agrees.
case "$DIGEST" in
[0-9a-f][0-9a-f]*) ok "bundle digest computed from version-1.luau" ;;
*) fail "could not compute sha256(version-1.luau)" ;;
esac

# 3. A second, independent hasher must agree with node -- a one-line guard
#    against a broken or substituted sign_bundle.js.
INDEPENDENT=""
if command -v sha256sum >/dev/null 2>&1; then
	INDEPENDENT="$(sha256sum version-1.luau 2>/dev/null | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
	INDEPENDENT="$(shasum -a 256 version-1.luau 2>/dev/null | cut -d' ' -f1)"
fi
if [ -z "$INDEPENDENT" ]; then
	echo "  --    no sha256sum/shasum on PATH; skipping cross-check"
elif [ "$INDEPENDENT" = "$DIGEST" ]; then
	ok "sha256sum agrees with scripts/sign_bundle.js"
else
	fail "sha256sum says $INDEPENDENT, sign_bundle.js says $DIGEST"
fi

# 4. The loader pin must name the version we are publishing, or every client
#    rejects the bundle as stale.
if [ -z "$LOADER_VERSION" ]; then
	fail "loader.luau has no EXPECTED_BUNDLE_VERSION"
elif [ "$LOADER_VERSION" = "$VERSION" ]; then
	ok "loader.luau pins version '$LOADER_VERSION'"
else
	fail "loader.luau pins '$LOADER_VERSION' but ASTRA_VERSION is '$VERSION'"
fi

# 5. The pinned public key has to look like an Ed25519 key at all.
if [ "${#LOADER_KEY}" -eq 64 ]; then
	ok "loader.luau pins a 64-hex PUBLIC_KEY"
else
	fail "loader.luau PUBLIC_KEY is ${#LOADER_KEY} chars, expected 64"
fi

# 6. The signature is the right shape before we ask crypto to judge it.
if [ "${#SIG}" -eq 128 ]; then
	ok "version-1.luau.sig is 128 hex chars"
else
	fail "version-1.luau.sig is ${#SIG} chars, expected 128"
fi

# 7. The README publishes a checksum users are told to trust. It must be the
#    checksum of the bundle that is actually in the tree.
if [ -z "$README_DIGEST" ]; then
	fail "README.md has no 'sha256(version-1.luau) = <hex>' line"
elif [ "$README_DIGEST" = "$DIGEST" ]; then
	ok "README.md publishes the current checksum"
else
	fail "README.md publishes $README_DIGEST but the bundle is $DIGEST"
fi

# 8. The signature verifies over ASTRA-BUNDLE-V1|<version>|<digest> under the
#    pinned key. This is the check the loader itself performs at runtime.
if node scripts/sign_bundle.js --verify >/dev/null 2>&1; then
	ok "signature verifies under the pinned key"
else
	fail "signature does NOT verify (node scripts/sign_bundle.js --verify)"
fi

# 9. At release time the tag has to agree with ASTRA_VERSION, so that
#    v1.2.3 can only ever carry the bundle that calls itself 1.2.3.
if [ -n "$TAG" ]; then
	if [ "$TAG" = "v$VERSION" ]; then
		ok "tag '$TAG' matches ASTRA_VERSION"
	else
		fail "tag '$TAG' does not match ASTRA_VERSION (expected 'v$VERSION')"
	fi
fi

echo ""
if [ "$failures" -ne 0 ]; then
	echo "RELEASE CONSISTENCY FAILED ($failures problem(s))" >&2
	echo "Re-run 'sh scripts/release.sh' to regenerate, re-sign and resync." >&2
	exit 1
fi
echo "release consistency OK"
exit 0
