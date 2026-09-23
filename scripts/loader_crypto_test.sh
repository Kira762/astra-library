#!/bin/sh
# Crypto unit tests for the signed loader (loader.luau).
#
# Covers the three primitives the loader's verification path depends on:
#   - SHA-256   (bundle digest)          — FIPS 180-4 published vectors
#   - SHA-512   (Ed25519 challenge hash) — FIPS 180-4 published vectors
#   - Ed25519   (signature verify)       — RFC 8032 test vectors + a
#     freshly Node-signed record (differential check against an independent
#     implementation), plus tamper negatives for each
#
# Assembles: ASTRA_LOADER_NO_AUTORUN + loader wrapped in a function (the
# loader ends in a top-level `return`, so nothing may follow it in the same
# chunk) + assertions. Runs under the Luau CLI from PATH, else /tmp, else
# /usr/local/bin.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOADER="$ROOT/loader.luau"

if [ ! -f "$LOADER" ]; then
	echo "loader missing: $LOADER" >&2
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
CRYPTO="$TMPDIR_LOCAL/astra_loader_crypto_$$.luau"
trap 'rm -f "$CRYPTO"' EXIT

# Fresh Node-signed record so the Ed25519 path is checked against an
# independent implementation every run. Skipped when node is absent (the
# RFC vectors still cover the primitive itself).
CROSS_FIXTURES="$TMPDIR_LOCAL/astra_loader_cross_$$.lua"
trap 'rm -f "$CRYPTO" "$CROSS_FIXTURES"' EXIT
: > "$CROSS_FIXTURES"
if command -v node >/dev/null 2>&1; then
	node -e '
const { generateKeyPairSync, sign } = require("crypto");
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const msg = "ASTRA-BUNDLE-V1|1.0.0|cross-" + Date.now();
const sig = sign(null, Buffer.from(msg, "ascii"), privateKey);
const x = publicKey.export({ format: "jwk" }).x;
const lines = [
  `local CROSS_PUB = "${Buffer.from(x, "base64url").toString("hex")}"`,
  `local CROSS_SIG = "${sig.toString("hex")}"`,
  `local CROSS_MSG = "${msg}"`,
];
require("fs").writeFileSync(process.argv[1], lines.join("\n") + "\n");
' "$CROSS_FIXTURES" || : > "$CROSS_FIXTURES"
fi

{
	echo 'ASTRA_LOADER_NO_AUTORUN = true'
	echo 'local Loader = (function()'
	cat "$LOADER"
	echo 'end)()'
	cat <<'ASSERTIONS'
local sha256hex = Loader.sha256hex
local sha512hex = Loader.sha512hex
local ed25519_verify = Loader.ed25519_verify
local makeRecord = Loader.makeRecord

local function expect(cond, message)
	if not cond then
		error("CRYPTO FAIL: " .. tostring(message), 0)
	end
end

expect(type(Loader) == "table", "loader exposes internals under NO_AUTORUN")
expect(type(sha256hex) == "function", "sha256hex exported")
expect(type(sha512hex) == "function", "sha512hex exported")
expect(type(ed25519_verify) == "function", "ed25519_verify exported")

-- ===== SHA-256 (FIPS 180-4) =====
expect(sha256hex("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256 empty")
expect(sha256hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 abc")
expect(
	sha256hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
		== "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
	"sha256 multi-block"
)
-- long input crosses many chunks
local longA = string.rep("a", 1000)
expect(
	sha256hex(longA)
		== "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3",
	"sha256 1000xa"
)

-- ===== SHA-512 (FIPS 180-4) =====
expect(
	sha512hex("")
		== "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
	"sha512 empty"
)
expect(
	sha512hex("abc")
		== "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
	"sha512 abc"
)

-- ===== Ed25519 (RFC 8032 test vectors) =====
-- TEST 1: empty message
local pub1 = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
local sig1 = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
expect(ed25519_verify("", sig1, pub1), "rfc8032 test1 valid")
expect(not ed25519_verify("x", sig1, pub1), "rfc8032 test1 wrong message")
expect(not ed25519_verify("", string.rep("00", 64), pub1), "rfc8032 test1 zero signature")
expect(not ed25519_verify("", sig1, string.rep("00", 32)), "rfc8032 test1 bad public key")

-- TEST 2: message 0x72
local pub2 = "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"
local sig2 = "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
expect(ed25519_verify("r", sig2, pub2), "rfc8032 test2 valid")
expect(not ed25519_verify("", sig2, pub2), "rfc8032 test2 wrong message")

-- shape rejects (malformed input must never verify)
expect(not ed25519_verify("", "abcd", pub1), "short signature hex rejected")
expect(not ed25519_verify("", sig1, "abcd"), "short public key hex rejected")
expect(not ed25519_verify("", string.rep("zz", 64), pub1), "non-hex signature rejected")

-- record format is what sign_bundle.js produces
expect(makeRecord("1.0.0", "ab") == "ASTRA-BUNDLE-V1|1.0.0|ab", "record format")

ASSERTIONS

	# differential fixture (node-signed), appended only when present
	if [ -s "$CROSS_FIXTURES" ]; then
		cat "$CROSS_FIXTURES"
		cat <<'ASSERTIONS'
expect(ed25519_verify(CROSS_MSG, CROSS_SIG, CROSS_PUB), "node-signed record verifies")
expect(not ed25519_verify(CROSS_MSG .. "tampered", CROSS_SIG, CROSS_PUB), "tampered node record rejected")
ASSERTIONS
	fi

	cat <<'ASSERTIONS'
print("LOADER CRYPTO TEST PASSED")
ASSERTIONS
} > "$CRYPTO"

if "$LUAU_BIN" "$CRYPTO"; then
	exit 0
else
	echo "LOADER CRYPTO TEST FAILED (see above)" >&2
	exit 1
fi
