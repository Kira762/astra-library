#!/bin/sh
# End-to-end integrity tests for the signed loader channel:
#   loader.luau + version-1.luau + version-1.luau.sig
#
# Every case assembles a self-contained Luau file (fixtures embedded as
# long-bracket strings, HttpGet stubbed to serve them) and asserts either:
#   real — the loader returns the genuine Astra API table
#   stub — the loader returns the quiet no-op stub (silent fail-closed)
#
# Cases:
#   1  valid bundle + valid signature            → real
#   2  tampered bundle, original signature       → stub
#   3  valid bundle, corrupted signature         → stub
#   4  valid bundle, missing signature           → stub
#   5  valid bundle, wrong public key in loader  → stub
#   6  valid bundle, stale version in loader     → stub
#   7  HttpGet throws for everything             → stub
#   8  closure-count canary tripped, freshly
#      re-signed with a throwaway key            → stub   (needs node)
#   9  degraded pin mode, honest second origin   → real
#  10  degraded pin mode, wrong record           → stub
#  11  valid bundle/sig, HttpSpy artifacts present → stub (preflight)
#  12  same artifacts, SPY_PREFLIGHT="off" loader   → real (escape hatch)
#
# Case 8 is the only one that re-signs; it proves the bootstrap canary path
# independently of the signature layer. Without node it is skipped (exit 0).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/version-1.luau"
SIG="$ROOT/version-1.luau.sig"
LOADER="$ROOT/loader.luau"
STUBS="$ROOT/scripts/smoke_stubs.luau"
VERSION="$(cat "$ROOT/ASTRA_VERSION")"
cd "$ROOT" || exit 1

for f in "$BUNDLE" "$SIG" "$LOADER" "$STUBS"; do
	if [ ! -f "$f" ]; then
		echo "missing: $f" >&2
		exit 1
	fi
done

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
WORK="$TMPDIR_LOCAL/astra_loader_integrity_$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# Long-bracket level that appears nowhere in the embedded fixtures.
bracket_level() {
	n=1
	while [ "$n" -lt 16 ]; do
		sep="$(printf '%*s' "$n" '' | tr ' ' '=')"
		if ! grep -qF "]${sep}[" "$BUNDLE" "$LOADER" 2>/dev/null; then
			printf '%s' "$sep"
			return 0
		fi
		n=$((n + 1))
	done
	echo "no safe long-bracket level found" >&2
	return 1
}
BR="$(bracket_level)" || exit 1
OPEN="[${BR}["
CLOSE="]${BR}]"

# run_case <name> <expect: real|stub> <loader_file> <bundle_file> <sig_hex|"missing"> [pin_record]
run_case() {
	name="$1"
	expectation="$2"
	loader_file="$3"
	bundle_file="$4"
	sig_value="$5"
	pin_value="${6-}"

	assembled="$WORK/case_$name.luau"

	{
		# Executor API stubs first (valid loads run the bundle for real),
		# then the file-serving HttpGet the loader will call.
		cat "$STUBS"
		echo "HttpGet = function(__url)"
		if [ "$sig_value" = "missing" ]; then
			echo "	if tostring(__url):match(\"%.sig$\") then return nil end"
		else
			echo "	if tostring(__url):match(\"%.sig$\") then return \"$sig_value\" end"
		fi
		if [ -n "$pin_value" ]; then
			echo "	if tostring(__url):match(\"pin%.example%.test\") then return [[$pin_value]] end"
		fi
		echo "	return $OPEN"
		cat "$bundle_file"
		echo "$CLOSE"
		echo "end"
		echo "local __Astra = (function()"
		cat "$loader_file"
		echo "end)()"
		cat <<ASSERTIONS
local function expect(cond, message)
	if not cond then
		error("INTEGRITY FAIL [$name]: " .. tostring(message), 0)
	end
end

expect(type(__Astra) == "table", "loader returned a table")
local coreType = type(__Astra.Core)
ASSERTIONS
		if [ "$expectation" = "real" ]; then
			cat <<ASSERTIONS
expect(type(__Astra.CreateWindow) == "function", "real API: CreateWindow is a function, got " .. type(__Astra.CreateWindow))
expect(coreType == "table", "real API: Astra.Core must be a table, got " .. coreType)
expect(type(__Astra.Icons) == "table", "real API: Icons present")
expect(__Astra.Icons.Lucide == "lucide", "real API: icon constants intact")
ASSERTIONS
		else
			cat <<ASSERTIONS
-- stub: every index and call resolves to the stub table; nothing raises.
-- Discriminator vs the real API: CreateWindow is a *table* here (function
-- on the real Astra).
expect(type(__Astra.CreateWindow) == "table", "stub: CreateWindow must be the stub table, got " .. type(__Astra.CreateWindow))
local ok1, w = pcall(function()
	return __Astra:CreateWindow({ name = "x" })
end)
expect(ok1, "stub: CreateWindow must not raise")
expect(type(w) == "table", "stub: CreateWindow returns the stub table")
local ok2 = pcall(function()
	w:CreateTab({ name = "t" }):Select()
end)
expect(ok2, "stub: chained calls must not raise")
local ok3, deep = pcall(function()
	return __Astra.SomeMissingThing.andDeeper(1, 2, 3)
end)
expect(ok3, "stub: deep missing access must not raise")
expect(type(deep) == "table", "stub: deep access resolves to the stub")
local ok4 = pcall(function()
	__Astra.Settings.readPersisted("x")
end)
expect(ok4, "stub: Settings.readPersisted-style chain must not raise")
ASSERTIONS
		fi
		cat <<ASSERTIONS
print("case $name: ok")
ASSERTIONS
	} > "$assembled"

	if "$LUAU_BIN" "$assembled" > "$WORK/case_$name.out" 2>&1; then
		if grep -q "case $name: ok" "$WORK/case_$name.out"; then
			printf '  ok    %s\n' "$name"
			return 0
		fi
	fi
	echo "  FAIL  $name" >&2
	sed 's/^/          /' "$WORK/case_$name.out" | tail -20 >&2
	return 1
}

# --- loader variants -------------------------------------------------------
# 64 hex chars of 0x11: structurally valid, cryptographically wrong
sed 's/local PUBLIC_KEY = "[0-9a-fA-F]*"/local PUBLIC_KEY = "1111111111111111111111111111111111111111111111111111111111111111"/' \
	"$LOADER" > "$WORK/loader_wrongkey.luau"
sed 's/local EXPECTED_BUNDLE_VERSION = "[^"]*"/local EXPECTED_BUNDLE_VERSION = "9.9.9-stale"/' \
	"$LOADER" > "$WORK/loader_stale.luau"
# Explicit degraded pin mode: second-origin record comparison, no signature.
# The mode is only ever chosen by editing this config (no silent downgrade).
sed 's/local VERIFICATION_MODE = "signature"/local VERIFICATION_MODE = "pin"/' "$LOADER" |
	sed 's|local SECONDARY_PIN_URL = ""|local SECONDARY_PIN_URL = "https://pin.example.test/record"|' 		> "$WORK/loader_pin.luau"

# Spy-preflight escape hatch: identical loader with the scan disabled.
sed 's/local SPY_PREFLIGHT = "strict"/local SPY_PREFLIGHT = "off"/' \
	"$LOADER" > "$WORK/loader_spyoff.luau"

# --- bundle / signature variants ------------------------------------------
SIG_HEX="$(tr -d '[:space:]' < "$SIG")"
# corrupt one hex digit of the signature (flip first char to its complement)
case "$SIG_HEX" in
	0*) SIG_BAD="1${SIG_HEX#?}" ;;
	*) SIG_BAD="0${SIG_HEX#?}" ;;
esac
cp "$BUNDLE" "$WORK/bundle_tampered.luau"
printf '\n-- hand-edited payload\n' >> "$WORK/bundle_tampered.luau"

# throwing HttpGet loader context: handled inside run_case? We need HttpGet to
# error — assemble a dedicated variant by pre-seeding a flag the stubs read.
# Simplest: a tiny loader wrapper file is not needed; we serve a marker bundle
# and override HttpGet BEFORE the stubs via the assembled file order. Do it
# with a dedicated case below.

failures=0

echo "loader integrity cases:"

# 1 — happy path
if run_case valid real "$LOADER" "$BUNDLE" "$SIG_HEX"; then :; else failures=$((failures + 1)); fi

# 2 — bundle tampered after signing
if run_case bundle_tampered stub "$LOADER" "$WORK/bundle_tampered.luau" "$SIG_HEX"; then :; else failures=$((failures + 1)); fi

# 3 — signature corrupted
if run_case sig_corrupted stub "$LOADER" "$BUNDLE" "$SIG_BAD"; then :; else failures=$((failures + 1)); fi

# 4 — signature missing
if run_case sig_missing stub "$LOADER" "$BUNDLE" "missing"; then :; else failures=$((failures + 1)); fi

# 5 — wrong public key embedded in loader
if run_case wrong_pubkey stub "$WORK/loader_wrongkey.luau" "$BUNDLE" "$SIG_HEX"; then :; else failures=$((failures + 1)); fi

# 6 — loader built for a different bundle version (rollback / stale pin)
if run_case stale_version stub "$WORK/loader_stale.luau" "$BUNDLE" "$SIG_HEX"; then :; else failures=$((failures + 1)); fi

# 7 — network layer hostile: HttpGet always throws
{
	cat "$STUBS"
	cat <<'EOF'
HttpGet = function()
	error("network down")
end
local __Astra = (function()
EOF
	cat "$LOADER"
	cat <<'EOF'
end)()
local function expect(cond, message)
	if not cond then
		error("INTEGRITY FAIL [fetch_error]: " .. tostring(message), 0)
	end
end
expect(type(__Astra) == "table", "loader returned a table")
expect(type(__Astra.CreateWindow) == "table", "fetch failure must yield the quiet stub (CreateWindow is a table, not a function)")
local ok = pcall(function()
	__Astra:CreateWindow({})
end)
expect(ok, "stub must not raise")
print("case fetch_error: ok")
EOF
} > "$WORK/case_fetch.luau"
if "$LUAU_BIN" "$WORK/case_fetch.luau" > "$WORK/case_fetch.out" 2>&1 \
	&& grep -q "case fetch_error: ok" "$WORK/case_fetch.out"; then
	printf '  ok    %s\n' "fetch_error"
else
	echo "  FAIL  fetch_error" >&2
	sed 's/^/          /' "$WORK/case_fetch.out" | tail -20 >&2
	failures=$((failures + 1))
fi

# 8 — canary trip with a VALID signature: patch ExpectedClosureCount in the
# bundle, re-sign with a throwaway key, point the loader at that key. Proves
# the bootstrap canary fails closed independently of the signature layer.
if command -v node >/dev/null 2>&1; then
	# Bump the closure count literal (valid Lua: `111 + 1`) so the signed
	# bundle compiles and verifies, but the bootstrap count check must trip.
	canary_ok=0
	sed 's/^local ExpectedClosureCount = \([0-9][0-9]*\);$/local ExpectedClosureCount = \1 + 1 -- tampered/' \
		"$BUNDLE" > "$WORK/bundle_canary.luau"
	if grep -q "ExpectedClosureCount = [0-9][0-9]* + 1 -- tampered" "$WORK/bundle_canary.luau"; then
		if node -e '
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const root = process.argv[1];
const work = process.argv[2];
const bundlePath = path.join(work, "bundle_canary.luau");
const version = fs.readFileSync(path.join(root, "ASTRA_VERSION"), "utf8").trim();
const digest = crypto.createHash("sha256").update(fs.readFileSync(bundlePath)).digest("hex");
const record = "ASTRA-BUNDLE-V1|" + version + "|" + digest;
const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
const sig = crypto.sign(null, Buffer.from(record, "ascii"), privateKey);
fs.writeFileSync(path.join(work, "canary.sig"), sig.toString("hex") + "\n");
const x = publicKey.export({ format: "jwk" }).x;
const pubHex = Buffer.from(x, "base64url").toString("hex");
let loader = fs.readFileSync(path.join(root, "loader.luau"), "utf8");
loader = loader.replace(/local PUBLIC_KEY = "[0-9a-fA-F]*"/, "local PUBLIC_KEY = \"" + pubHex + "\"");
loader = loader.replace(/local EXPECTED_BUNDLE_VERSION = "[^"]*"/, "local EXPECTED_BUNDLE_VERSION = \"" + version + "\"");
fs.writeFileSync(path.join(work, "loader_canary.luau"), loader);
' "$ROOT" "$WORK"; then
			if grep -q 'local PUBLIC_KEY = "[0-9a-fA-F]\{64\}"' "$WORK/loader_canary.luau" \
				&& [ -s "$WORK/canary.sig" ]; then
				canary_ok=1
			fi
		fi
	fi
	if [ "$canary_ok" -eq 1 ]; then
		if run_case canary_trip stub "$WORK/loader_canary.luau" "$WORK/bundle_canary.luau" "$(tr -d '[:space:]' < "$WORK/canary.sig")"; then
			:
		else
			failures=$((failures + 1))
		fi
	else
		echo "  FAIL  canary_trip (setup)" >&2
		failures=$((failures + 1))
	fi
else
	echo "  skip  canary_trip (node not available)"
fi

# 9/10 - explicit degraded pin mode: record must equal the computed digest.
# Honest second origin -> real API; wrong record -> silent stub. The official
# loader never enters this mode on its own (config edit required).
if command -v sha256sum >/dev/null 2>&1; then
	BUNDLE_SHA="$(sha256sum "$BUNDLE" | cut -d" " -f1)"
	PIN_GOOD="ASTRA-BUNDLE-V1|${VERSION}|${BUNDLE_SHA}"
	PIN_BAD="ASTRA-BUNDLE-V1|${VERSION}|$(printf '00%.0s' $(seq 1 32))"
	if grep -q 'VERIFICATION_MODE = "pin"' "$WORK/loader_pin.luau"; then
		if run_case pin_match real "$WORK/loader_pin.luau" "$BUNDLE" "missing" "$PIN_GOOD"; then
			:
		else
			failures=$((failures + 1))
		fi
		if run_case pin_mismatch stub "$WORK/loader_pin.luau" "$BUNDLE" "missing" "$PIN_BAD"; then
			:
		else
			failures=$((failures + 1))
		fi
	else
		echo "  FAIL  pin loader variant not built" >&2
		failures=$((failures + 1))
	fi
else
	echo "  skip  pin_match/pin_mismatch (sha256sum not available)"
fi

# 11/12 - spy preflight: HttpSpy artifacts (a hook primitive plus the
# genv API table) served alongside a VALID bundle and signature. The strict
# loader must refuse to fetch (quiet stub); the SPY_PREFLIGHT="off" variant
# must load the real API (the documented escape hatch).
SPY_PRELUDE="$WORK/spy_prelude.luau"
cat > "$SPY_PRELUDE" <<'EOF'
hookfunction = function(fn) return fn end
getgenv = function()
	return {
		HttpSpy = {
			OnRequest = {},
			HookSynRequest = function() end,
			BlockUrl = function() end,
		},
	}
end
EOF
run_spy_case() {
	name="$1"
	expectation="$2"
	loader_file="$3"
	assembled="$WORK/case_$name.luau"
	{
		cat "$STUBS"
		cat "$SPY_PRELUDE"
		echo "HttpGet = function(__url)"
		echo "	if tostring(__url):match(\"%.sig$\") then return \"$SIG_HEX\" end"
		echo "	return $OPEN"
		cat "$BUNDLE"
		echo "$CLOSE"
		echo "end"
		echo "local __Astra = (function()"
		cat "$loader_file"
		echo "end)()"
		cat <<ASSERTIONS
local function expect(cond, message)
	if not cond then
		error("INTEGRITY FAIL [$name]: " .. tostring(message), 0)
	end
end
expect(type(__Astra) == "table", "loader returned a table")
ASSERTIONS
		if [ "$expectation" = "real" ]; then
			cat <<ASSERTIONS
expect(type(__Astra.CreateWindow) == "function", "preflight off: real API loads despite artifacts")
expect(type(__Astra.Core) == "table", "preflight off: Core present")
ASSERTIONS
		else
			cat <<ASSERTIONS
expect(type(__Astra.CreateWindow) == "table", "preflight: spy artifacts must yield the quiet stub")
local spyOk = pcall(function()
	__Astra:CreateWindow({ name = "x" })
end)
expect(spyOk, "stub must not raise")
ASSERTIONS
		fi
		echo "print(\"case $name: ok\")"
	} > "$assembled"
	if "$LUAU_BIN" "$assembled" > "$WORK/case_$name.out" 2>&1 \
		&& grep -q "case $name: ok" "$WORK/case_$name.out"; then
		printf '  ok    %s\n' "$name"
	else
		echo "  FAIL  $name" >&2
		sed 's/^/          /' "$WORK/case_$name.out" | tail -20 >&2
		return 1
	fi
}
if grep -q 'local SPY_PREFLIGHT = "off"' "$WORK/loader_spyoff.luau"; then
	if run_spy_case spy_preflight stub "$LOADER"; then :; else failures=$((failures + 1)); fi
	if run_spy_case spy_preflight_off real "$WORK/loader_spyoff.luau"; then :; else failures=$((failures + 1)); fi
else
	echo "  FAIL  spyoff loader variant not built" >&2
	failures=$((failures + 1))
fi

echo ""
if [ "$failures" -ne 0 ]; then
	echo "LOADER INTEGRITY TEST FAILED ($failures case(s))" >&2
	exit 1
fi
echo "LOADER INTEGRITY TEST PASSED"
exit 0
