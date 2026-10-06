#!/bin/sh
# Cut a release in one command.
#
# Publishing used to be a memorised sequence -- bump ASTRA_VERSION, regenerate
# the bundle, re-sign it, hand-edit the checksum in the README, hope the tag
# matches -- with no single place that said whether the result was coherent.
# This script is that place. It performs the writes in dependency order and
# then refuses to finish unless scripts/check_release_consistency.sh agrees.
#
#   sh scripts/release.sh                      # preflight the current version
#   sh scripts/release.sh --version 1.1.0      # bump, then preflight
#   sh scripts/release.sh --version 1.1.0 --stamp
#                                              # also date the Unreleased
#                                              # changelog entries as 1.1.0
#   sh scripts/release.sh --notes              # print release notes (CI uses
#                                              # this for the release body)
#
# Nothing here talks to GitHub. It prints the exact tag command to run; the
# tag is what triggers .github/workflows/publish.yml.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

if [ -d "$ROOT/.tools/bin" ]; then
	PATH="$ROOT/.tools/bin:$PATH"
	export PATH
fi

NEW_VERSION=""
STAMP=0
NOTES_ONLY=0

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		shift
		NEW_VERSION="${1:-}"
		;;
	--version=*) NEW_VERSION="${1#--version=}" ;;
	--stamp) STAMP=1 ;;
	--notes) NOTES_ONLY=1 ;;
	-h | --help)
		sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

version() { tr -d ' \t\n\r' <ASTRA_VERSION; }

# --------------------------------------------------------------- release notes
# What is new since the last release is exactly the run of `## Unreleased`
# sections at the top of the changelog: --stamp rewrites them to `## vX.Y.Z`
# when a release is cut, so the next release's run starts clean. On a tag
# build the stamping already happened, so fall back to this version's own
# sections.
changelog_titles() {
	awk -v ver="$1" -v cap=30 '
		function emit(h,   t) {
			t = h
			sub(/^## /, "", t)
			sub(/^Unreleased/, "", t)
			sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/, "", t)
			sub(/^[[:space:]]*\(v[^)]*\)/, "", t)
			sub(/^[[:space:]]*(—|–|-)?[[:space:]]*/, "", t)
			if (t != "") print "- " t
		}
		/^## / {
			# Leading run of Unreleased sections = everything since the last
			# release. Once that run ends, keep scanning for this version own
			# stamped sections, which is what a tag build sees.
			if (phase == 0) {
				if ($0 ~ /^## Unreleased/) { unreleased[++nu] = $0; next }
				phase = 1
			}
			if (index($0, "(v" ver ")") > 0) stamped[++ns] = $0
		}
		END {
			n = (nu > 0) ? nu : ns
			for (i = 1; i <= n && i <= cap; i++) emit((nu > 0) ? unreleased[i] : stamped[i])
			if (n > cap) printf "- ...and %d more, see CHANGELOG.md\n", n - cap
		}
	' CHANGELOG.md
}

print_notes() {
	VER="$(version)"
	DIGEST="$(node scripts/sign_bundle.js --print-digest 2>/dev/null | tr -d ' \n\r')"
	TITLES="$(changelog_titles "$VER")"

	echo "## What changed"
	echo ""
	if [ -n "$TITLES" ]; then
		echo "$TITLES"
	else
		echo "- See [CHANGELOG.md](CHANGELOG.md)."
	fi
	echo ""
	echo "## Verify these bytes"
	echo ""
	echo "The loader checks \`SHA-256(bundle)\` inside an Ed25519-signed record"
	echo "before handing the bundle to \`loadstring\`. The same values are"
	echo "reproducible from the assets below:"
	echo ""
	echo '```'
	echo "version                    $VER"
	echo "sha256(version-1.luau)     $DIGEST"
	echo "signed record              ASTRA-BUNDLE-V1|$VER|$DIGEST"
	echo '```'
	echo ""
	echo "\`version-1.luau\`, \`version-1.luau.sig\` and \`loader.luau\` are attached"
	echo "to this release as immutable copies of the files published at the tag."
	echo ""
	echo "Full detail: [CHANGELOG.md](CHANGELOG.md) · [docs/release-process.md](docs/release-process.md)"
}

if [ "$NOTES_ONLY" -eq 1 ]; then
	print_notes
	exit 0
fi

step() {
	echo ""
	echo "=============================================================="
	echo "$1"
	echo "=============================================================="
}

# ------------------------------------------------------------------ 1. version
if [ -n "$NEW_VERSION" ]; then
	case "$NEW_VERSION" in
	v*)
		echo "pass the bare version, not the tag: --version ${NEW_VERSION#v}" >&2
		exit 1
		;;
	[0-9]*.[0-9]*.[0-9]*) ;;
	*)
		echo "--version must be MAJOR.MINOR.PATCH, got '$NEW_VERSION'" >&2
		exit 1
		;;
	esac
	step "1/5  version -> $NEW_VERSION"
	printf '%s\n' "$NEW_VERSION" >ASTRA_VERSION
	echo "ASTRA_VERSION written"
else
	step "1/5  version -> $(version) (unchanged)"
fi
VER="$(version)"

# --------------------------------------------------------------- 2. changelog
if [ "$STAMP" -eq 1 ]; then
	step "2/5  stamp the Unreleased changelog entries as v$VER"
	TODAY="$(date -u +%Y-%m-%d)"
	# House style for a landed entry is "## YYYY-MM-DD — title"; the release
	# it shipped in goes in parentheses so a reader can map an entry to a tag
	# without the headings sorting differently from the existing history.
	awk -v ver="$VER" -v today="$TODAY" '
		BEGIN { stamped = 0; done = 0 }
		/^## / && !done {
			if ($0 ~ /^## Unreleased/) {
				rest = $0
				sub(/^## Unreleased[[:space:]]*/, "", rest)
				print "## " today " (v" ver ")" (rest == "" ? "" : " " rest)
				stamped++
				next
			}
			done = 1
		}
		{ print }
		END { printf "stamped %d entr%s\n", stamped, (stamped == 1 ? "y" : "ies") > "/dev/stderr" }
	' CHANGELOG.md >"${TMPDIR:-/tmp}/astra_changelog.$$" &&
		mv "${TMPDIR:-/tmp}/astra_changelog.$$" CHANGELOG.md
else
	step "2/5  changelog (not stamped; pass --stamp to date the entries)"
fi

# ------------------------------------------------------------------ 3. bundle
step "3/5  regenerate version-1.luau from the source tree"
node scripts/generate_bundle.js >/dev/null || exit 1
echo "bundle regenerated"

# --------------------------------------------------------------------- 4. sign
step "4/5  sign the bundle and sync the loader pin"
if [ -z "${SIGNING_KEY:-}" ] && [ -z "${SIGNING_KEY_FILE:-}" ]; then
	echo "NOTE: no SIGNING_KEY/SIGNING_KEY_FILE in the environment, so this"
	echo "      signs with the gitignored dev key and rewrites PUBLIC_KEY in"
	echo "      loader.luau. That is expected locally -- the Sign bundle"
	echo "      workflow re-signs with the production key once this lands on"
	echo "      main. Do not tag a dev-key signature as a release."
	echo ""
fi
node scripts/sign_bundle.js || exit 1

DIGEST="$(node scripts/sign_bundle.js --print-digest | tr -d ' \n\r')"
# The README publishes a checksum users are told to compare against. Derive
# it instead of trusting anyone to remember.
if grep -q '^sha256(version-1\.luau) = ' README.md; then
	sed "s|^sha256(version-1\.luau) = .*|sha256(version-1.luau) = $DIGEST|" README.md \
		>"${TMPDIR:-/tmp}/astra_readme.$$" &&
		mv "${TMPDIR:-/tmp}/astra_readme.$$" README.md
	echo "README checksum synced to $DIGEST"
else
	echo "WARNING: README.md has no checksum line to sync" >&2
fi

# ------------------------------------------------------------------- 5. verify
step "5/5  consistency gate"
sh scripts/check_release_consistency.sh --tag "v$VER" || exit 1

cat <<EOF

--------------------------------------------------------------
Preflight passed for v$VER.

Still to do by hand (they are judgement calls, not automation):

  1. sh scripts/check_all.sh          full gate: syntax + every runtime test
  2. review 'git diff'                bundle, signature, loader pin, README
  3. commit and push to your branch, then merge to main so the Sign bundle
     workflow re-signs with the production key
  4. git tag v$VER && git push origin v$VER

Step 4 is what publishes: the tag starts .github/workflows/publish.yml,
which re-runs verification against the tagged tree and creates the GitHub
release with version-1.luau, version-1.luau.sig, loader.luau and SHA256SUMS
attached.
--------------------------------------------------------------
EOF
