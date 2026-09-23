--[[
Astra signed loader — verifies version-1.luau before it is ever executed.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/loader.luau"))()

Contract
--------
1. Fetch the bundle and its detached signature (Ed25519 over a
   version-bound SHA-256 record: "ASTRA-BUNDLE-V1|<version>|<sha256hex>").
2. Hash the fetched bundle bytes; build the record with the version this
   loader was built for; verify the signature against the embedded public
   key. The public key is asymmetric: this file can verify, never forge.
3. Only on success, loadstring the EXACT bytes that were verified —
   nothing is appended, stripped, or rewritten, so the bundle's internal
   error line mapping stays intact.
4. On any failure — network, missing/short/malformed signature, digest
   mismatch, compile error, non-table result — return a quiet no-op stub.
   No prints, no loud errors, nothing that announces a check happened.

Trust model (read before extending)
-----------------------------------
* Protects: the official distribution channel. A hand-edited or repacked
  bundle cannot produce a signature that verifies under PUBLIC_KEY, and
  swapping PUBLIC_KEY for an attacker key means writing this loader —
  which is always possible, and is the documented out-of-scope boundary.
* Does NOT protect, and cannot: an attacker who replaces THIS file,
  hooks loadstring/HttpGet underneath it, or runs the raw bundle directly.
  The executor process belongs to whoever runs it. Anything that must be
  enforced (keys, purchases, permissions) needs a server.
* The private signing key exists only in CI (Actions secret) and the
  maintainer's key file — never in this repository, never in this file.

Development hooks
-----------------
Set the global ASTRA_LOADER_NO_AUTORUN to true before running this file to
receive the internals table { sha256hex, sha512hex, ed25519_verify,
makeRecord, quietStub, main, ... } instead of autorunning. Tests use this;
it exposes no secrets (everything here is already public source) — it just
skips the fetch/verify/load sequence.
]]

-- ===========================================================================
-- configuration (scripts/sign_bundle.js keeps EXPECTED_BUNDLE_VERSION and
-- PUBLIC_KEY in sync with ASTRA_VERSION and the signing key)
-- ===========================================================================

local BUNDLE_URL = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"
local SIG_URL = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau.sig"
local EXPECTED_BUNDLE_VERSION = "1.0.0"
local PUBLIC_KEY = "c666130c6377b6f54e437ab42c06ccac9975dafac67fd05191584e8631deadf0"

-- Verification mode. The official loader ships "signature" and never
-- downgrades itself: a failed signature check always fails closed, there is
-- no automatic fallback to any weaker mode. "pin" is an explicit, labeled
-- DEGRADED mode for deployments that publish the record
-- (ASTRA-BUNDLE-V1|<version>|<sha256hex>) on a second origin this repository
-- does not control — integrity then rests on that origin's isolation instead
-- of on Ed25519, which is why it must be opted into by editing this config.
-- An unknown mode value fails closed as well.
local VERIFICATION_MODE = "signature" -- "signature" | "pin" (degraded)
local SECONDARY_PIN_URL = "" -- pin mode only; serves the record as plain text

local RECORD_PREFIX = "ASTRA-BUNDLE-V1"

-- ===========================================================================
-- bit / hex / byte helpers
-- ===========================================================================

local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local bnot = bit32.bnot
local lshift = bit32.lshift
local rshift = bit32.rshift
-- Luau/Roblox expose `rrotate`; Lua 5.2-style `ror` does not exist there.
local ror = bit32.rrotate or bit32.ror

local MOD32 = 4294967296

local function isHex(s)
	return type(s) == "string" and #s > 0 and #s % 2 == 0 and not s:find("[^0-9a-fA-F]")
end

local function hexToBytes(hex)
	local n = #hex / 2
	local out = {}
	for i = 1, n do
		out[i] = tonumber(hex:sub(i * 2 - 1, i * 2), 16)
	end
	return out
end

local function bytesToHex(bytes)
	local parts = {}
	for i = 1, #bytes do
		parts[i] = string.format("%02x", bytes[i])
	end
	return table.concat(parts)
end

local function bytesToString(bytes)
	local parts = {}
	for i = 1, #bytes do
		parts[i] = string.char(bytes[i])
	end
	return table.concat(parts)
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ===========================================================================
-- SHA-256 (FIPS 180-4) — pure Luau on bit32; produces the bundle digest.
-- ===========================================================================

local SHA256_K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function sha256_bytes(msg)
	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	local len = #msg
	local bits = len * 8
	local hiBits = math.floor(bits / MOD32)
	local loBits = bits % MOD32
	local padLen = (56 - (len + 1) % 64) % 64

	local function be32(n)
		return string.char(band(rshift(n, 24), 255), band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
	end

	local padded = msg .. "\128" .. string.rep("\0", padLen) .. be32(hiBits) .. be32(loBits)

	local w = {}
	for chunk = 1, #padded, 64 do
		for t = 0, 15 do
			local o = chunk + t * 4
			local b1, b2, b3, b4 = padded:byte(o, o + 3)
			w[t] = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
		end
		for t = 16, 63 do
			local w15 = w[t - 15]
			local w2 = w[t - 2]
			local s0 = bxor(ror(w15, 7), ror(w15, 18), rshift(w15, 3))
			local s1 = bxor(ror(w2, 17), ror(w2, 19), rshift(w2, 10))
			w[t] = (w[t - 16] + s0 + w[t - 7] + s1) % MOD32
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for t = 0, 63 do
			local s1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (h + s1 + ch + SHA256_K[t + 1] + w[t]) % MOD32
			local s0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
			local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
			local t2 = (s0 + maj) % MOD32
			h = g
			g = f
			f = e
			e = (d + t1) % MOD32
			d = c
			c = b
			b = a
			a = (t1 + t2) % MOD32
		end
		h0 = (h0 + a) % MOD32
		h1 = (h1 + b) % MOD32
		h2 = (h2 + c) % MOD32
		h3 = (h3 + d) % MOD32
		h4 = (h4 + e) % MOD32
		h5 = (h5 + f) % MOD32
		h6 = (h6 + g) % MOD32
		h7 = (h7 + h) % MOD32
	end

	return {
		band(rshift(h0, 24), 255), band(rshift(h0, 16), 255), band(rshift(h0, 8), 255), band(h0, 255),
		band(rshift(h1, 24), 255), band(rshift(h1, 16), 255), band(rshift(h1, 8), 255), band(h1, 255),
		band(rshift(h2, 24), 255), band(rshift(h2, 16), 255), band(rshift(h2, 8), 255), band(h2, 255),
		band(rshift(h3, 24), 255), band(rshift(h3, 16), 255), band(rshift(h3, 8), 255), band(h3, 255),
		band(rshift(h4, 24), 255), band(rshift(h4, 16), 255), band(rshift(h4, 8), 255), band(h4, 255),
		band(rshift(h5, 24), 255), band(rshift(h5, 16), 255), band(rshift(h5, 8), 255), band(h5, 255),
		band(rshift(h6, 24), 255), band(rshift(h6, 16), 255), band(rshift(h6, 8), 255), band(h6, 255),
		band(rshift(h7, 24), 255), band(rshift(h7, 16), 255), band(rshift(h7, 8), 255), band(h7, 255),
	}
end

local function sha256hex(msg)
	return bytesToHex(sha256_bytes(msg))
end

-- ===========================================================================
-- SHA-512 — Ed25519's challenge hash. 64-bit words are (hi, lo) pairs of
-- 32-bit values because Luau numbers are doubles.
-- ===========================================================================

-- K as interleaved hi/lo pairs: round i lives at indices 2i+1, 2i+2
local SHA512_K = {
	0x428a2f98, 0xd728ae22, 0x71374491, 0x23ef65cd, 0xb5c0fbcf, 0xec4d3b2f, 0xe9b5dba5, 0x8189dbbc,
	0x3956c25b, 0xf348b538, 0x59f111f1, 0xb605d019, 0x923f82a4, 0xaf194f9b, 0xab1c5ed5, 0xda6d8118,
	0xd807aa98, 0xa3030242, 0x12835b01, 0x45706fbe, 0x243185be, 0x4ee4b28c, 0x550c7dc3, 0xd5ffb4e2,
	0x72be5d74, 0xf27b896f, 0x80deb1fe, 0x3b1696b1, 0x9bdc06a7, 0x25c71235, 0xc19bf174, 0xcf692694,
	0xe49b69c1, 0x9ef14ad2, 0xefbe4786, 0x384f25e3, 0x0fc19dc6, 0x8b8cd5b5, 0x240ca1cc, 0x77ac9c65,
	0x2de92c6f, 0x592b0275, 0x4a7484aa, 0x6ea6e483, 0x5cb0a9dc, 0xbd41fbd4, 0x76f988da, 0x831153b5,
	0x983e5152, 0xee66dfab, 0xa831c66d, 0x2db43210, 0xb00327c8, 0x98fb213f, 0xbf597fc7, 0xbeef0ee4,
	0xc6e00bf3, 0x3da88fc2, 0xd5a79147, 0x930aa725, 0x06ca6351, 0xe003826f, 0x14292967, 0x0a0e6e70,
	0x27b70a85, 0x46d22ffc, 0x2e1b2138, 0x5c26c926, 0x4d2c6dfc, 0x5ac42aed, 0x53380d13, 0x9d95b3df,
	0x650a7354, 0x8baf63de, 0x766a0abb, 0x3c77b2a8, 0x81c2c92e, 0x47edaee6, 0x92722c85, 0x1482353b,
	0xa2bfe8a1, 0x4cf10364, 0xa81a664b, 0xbc423001, 0xc24b8b70, 0xd0f89791, 0xc76c51a3, 0x0654be30,
	0xd192e819, 0xd6ef5218, 0xd6990624, 0x5565a910, 0xf40e3585, 0x5771202a, 0x106aa070, 0x32bbd1b8,
	0x19a4c116, 0xb8d2d0c8, 0x1e376c08, 0x5141ab53, 0x2748774c, 0xdf8eeb99, 0x34b0bcb5, 0xe19b48a8,
	0x391c0cb3, 0xc5c95a63, 0x4ed8aa4a, 0xe3418acb, 0x5b9cca4f, 0x7763e373, 0x682e6ff3, 0xd6b2b8a3,
	0x748f82ee, 0x5defb2fc, 0x78a5636f, 0x43172f60, 0x84c87814, 0xa1f0ab72, 0x8cc70208, 0x1a6439ec,
	0x90befffa, 0x23631e28, 0xa4506ceb, 0xde82bde9, 0xbef9a3f7, 0xb2c67915, 0xc67178f2, 0xe372532b,
	0xca273ece, 0xea26619c, 0xd186b8c7, 0x21c0c207, 0xeada7dd6, 0xcde0eb1e, 0xf57d4f7f, 0xee6ed178,
	0x06f067aa, 0x72176fba, 0x0a637dc5, 0xa2c898a6, 0x113f9804, 0xbef90dae, 0x1b710b35, 0x131c471b,
	0x28db77f5, 0x23047d84, 0x32caab7b, 0x40c72493, 0x3c9ebe0a, 0x15c9bebc, 0x431d67c4, 0x9c100d4c,
	0x4cc5d4be, 0xcb3e42b6, 0x597f299c, 0xfc657e2a, 0x5fcb6fab, 0x3ad6faec, 0x6c44198c, 0x4a475817,
}

local function add64(ah, al, bh, bl)
	local lo = al + bl
	local carry = 0
	if lo >= MOD32 then
		lo = lo - MOD32
		carry = 1
	end
	return (ah + bh + carry) % MOD32, lo
end

local function rotr64(h, l, n)
	if n == 32 then
		return l, h
	end
	if n < 32 then
		return bor(rshift(h, n), lshift(l, 32 - n)), bor(rshift(l, n), lshift(h, 32 - n))
	end
	local m = n - 32
	return bor(rshift(l, m), lshift(h, 32 - m)), bor(rshift(h, m), lshift(l, 32 - m))
end

local function shr64(h, l, n)
	if n == 32 then
		return 0, h
	end
	if n < 32 then
		return rshift(h, n), bor(rshift(l, n), lshift(h, 32 - n))
	end
	return 0, rshift(h, n - 32)
end

local function sha512_bytes(msg)
	local H = {
		0x6a09e667, 0xf3bcc908, 0xbb67ae85, 0x84caa73b,
		0x3c6ef372, 0xfe94f82b, 0xa54ff53a, 0x5f1d36f1,
		0x510e527f, 0xade682d1, 0x9b05688c, 0x2b3e6c1f,
		0x1f83d9ab, 0xfb41bd6b, 0x5be0cd19, 0x137e2179,
	}

	local len = #msg
	local bits = len * 8
	local hiLen = math.floor(len / 2305843009213693952) -- floor(len / 2^61)
	local padLen = (112 - (len + 1) % 128) % 128

	local function be32(n)
		return string.char(band(rshift(n, 24), 255), band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
	end

	local loHi = math.floor(bits / MOD32)
	local loLo = bits % MOD32
	-- 128-bit big-endian bit length: high64 = hiLen (split into two words), low64 = bits
	local padded = msg .. "\128" .. string.rep("\0", padLen) .. be32(0) .. be32(hiLen) .. be32(loHi) .. be32(loLo)

	local wH, wL = {}, {}
	for chunk = 1, #padded, 128 do
		for t = 0, 15 do
			local o = chunk + t * 8
			local b1, b2, b3, b4, b5, b6, b7, b8 = padded:byte(o, o + 7)
			wH[t] = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
			wL[t] = b5 * 16777216 + b6 * 65536 + b7 * 256 + b8
		end
		for t = 16, 79 do
			local h2, l2 = rotr64(wH[t - 2], wL[t - 2], 19)
			local h2b, l2b = rotr64(wH[t - 2], wL[t - 2], 61)
			local h2c, l2c = shr64(wH[t - 2], wL[t - 2], 6)
			local s1h, s1l = bxor(h2, h2b, h2c), bxor(l2, l2b, l2c)

			local h15, l15 = rotr64(wH[t - 15], wL[t - 15], 1)
			local h15b, l15b = rotr64(wH[t - 15], wL[t - 15], 8)
			local h15c, l15c = shr64(wH[t - 15], wL[t - 15], 7)
			local s0h, s0l = bxor(h15, h15b, h15c), bxor(l15, l15b, l15c)

			local nh, nl = s1h, s1l
			nh, nl = add64(nh, nl, wH[t - 7], wL[t - 7])
			nh, nl = add64(nh, nl, s0h, s0l)
			-- w[t] = σ1(w[t-2]) + w[t-7] + σ0(w[t-15]) + w[t-16]
			wH[t], wL[t] = add64(nh, nl, wH[t - 16], wL[t - 16])
		end

		local aH, aL = H[1], H[2]
		local bH, bL = H[3], H[4]
		local cH, cL = H[5], H[6]
		local dH, dL = H[7], H[8]
		local eH, eL = H[9], H[10]
		local fH, fL = H[11], H[12]
		local gH, gL = H[13], H[14]
		local hH, hL = H[15], H[16]

		for t = 0, 79 do
			-- Sigma1(e) = rotr(e,14) ^ rotr(e,18) ^ rotr(e,41)
			local r14h, r14l = rotr64(eH, eL, 14)
			local r18h, r18l = rotr64(eH, eL, 18)
			local r41h, r41l = rotr64(eH, eL, 41)
			local S1h, S1l = bxor(r14h, r18h, r41h), bxor(r14l, r18l, r41l)
			-- Ch(e,f,g)
			local chH = bxor(band(eH, fH), band(bnot(eH), gH))
			local chL = bxor(band(eL, fL), band(bnot(eL), gL))
			-- T1 = h + Sigma1(e) + Ch + K + W
			local t1h, t1l = hH, hL
			t1h, t1l = add64(t1h, t1l, S1h, S1l)
			t1h, t1l = add64(t1h, t1l, chH, chL)
			t1h, t1l = add64(t1h, t1l, SHA512_K[t * 2 + 1], SHA512_K[t * 2 + 2])
			t1h, t1l = add64(t1h, t1l, wH[t], wL[t])
			-- Sigma0(a) = rotr(a,28) ^ rotr(a,34) ^ rotr(a,39)
			local r28h, r28l = rotr64(aH, aL, 28)
			local r34h, r34l = rotr64(aH, aL, 34)
			local r39h, r39l = rotr64(aH, aL, 39)
			local S0h, S0l = bxor(r28h, r34h, r39h), bxor(r28l, r34l, r39l)
			-- Maj(a,b,c) = (a&b) ^ (a&c) ^ (b&c)
			local majH = bxor(bxor(band(aH, bH), band(aH, cH)), band(bH, cH))
			local majL = bxor(bxor(band(aL, bL), band(aL, cL)), band(bL, cL))
			local t2h, t2l = add64(S0h, S0l, majH, majL)

			hH, hL = gH, gL
			gH, gL = fH, fL
			fH, fL = eH, eL
			eH, eL = add64(dH, dL, t1h, t1l)
			dH, dL = cH, cL
			cH, cL = bH, bL
			bH, bL = aH, aL
			aH, aL = add64(t1h, t1l, t2h, t2l)
		end

		H[1], H[2] = add64(H[1], H[2], aH, aL)
		H[3], H[4] = add64(H[3], H[4], bH, bL)
		H[5], H[6] = add64(H[5], H[6], cH, cL)
		H[7], H[8] = add64(H[7], H[8], dH, dL)
		H[9], H[10] = add64(H[9], H[10], eH, eL)
		H[11], H[12] = add64(H[11], H[12], fH, fL)
		H[13], H[14] = add64(H[13], H[14], gH, gL)
		H[15], H[16] = add64(H[15], H[16], hH, hL)
	end

	local out = {}
	for i = 1, 8 do
		local hi, lo = H[i * 2 - 1], H[i * 2]
		out[#out + 1] = band(rshift(hi, 24), 255)
		out[#out + 1] = band(rshift(hi, 16), 255)
		out[#out + 1] = band(rshift(hi, 8), 255)
		out[#out + 1] = band(hi, 255)
		out[#out + 1] = band(rshift(lo, 24), 255)
		out[#out + 1] = band(rshift(lo, 16), 255)
		out[#out + 1] = band(rshift(lo, 8), 255)
		out[#out + 1] = band(lo, 255)
	end
	return out
end

local function sha512hex(msg)
	return bytesToHex(sha512_bytes(msg))
end

-- ===========================================================================
-- Ed25519 (RFC 8032) verification — pure Luau.
--
-- Field elements: 16 limbs of 16 bits (little-endian), p = 2^255 - 19.
-- Points: extended twisted Edwards coordinates (X, Y, Z, T), a = -1.
-- Not constant-time — by design: verification runs on the untrusted client,
-- which already sees every intermediate value. The goal is only "cannot
-- forge a valid signature under the embedded public key".
-- ===========================================================================

local EXP_P3_8 = "feffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f" -- (p+3)/8, LE
local EXP_P_MINUS_2 = "ebffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f" -- p-2, LE
local D_HEX = "a3785913ca4deb75abd841414d0a700098e879777940c78c73fe6f2bee6c0352"
local TWO_D_HEX = "59f1b226949bd6eb56b183829a14e00030d1f3eef2808e19e7fcdf56dcd90624"
local SQRT_M1_HEX = "b0a00e4a271beec478e42fad0618432fa7d7fb3d99004d2b0bdfc14f8024832b"
local BASE_COMPRESSED = "5866666666666666666666666666666666666666666666666666666666666666"
local ORDER_HEX = "edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010" -- L, LE

local function limbsFromBytes32(bytes)
	local limbs = {}
	for i = 0, 15 do
		local o = i * 2 + 1
		limbs[i + 1] = bytes[o] + bytes[o + 1] * 256
	end
	return limbs
end

local function bytes32FromLimbs(l)
	local out = {}
	for i = 1, 16 do
		local v = l[i]
		out[i * 2 - 1] = v % 256
		out[i * 2] = math.floor(v / 256) % 256
	end
	return out
end

local function isGE_P(l)
	-- geq p?  p limbs: 0xffed, 0xffff (x14), 0x7fff
	if l[16] ~= 0x7fff then
		return l[16] > 0x7fff
	end
	for i = 15, 2, -1 do
		if l[i] ~= 0xffff then
			return l[i] > 0xffff
		end
	end
	return l[1] >= 0xffed
end

local function subP(l)
	local out = {}
	local borrow = 0
	for i = 1, 16 do
		local pPart
		if i == 1 then
			pPart = 0xffed
		elseif i == 16 then
			pPart = 0x7fff
		else
			pPart = 0xffff
		end
		local v = l[i] - pPart - borrow
		if v < 0 then
			v = v + 65536
			borrow = 1
		else
			borrow = 0
		end
		out[i] = v
	end
	return out
end

local function freduce(l)
	local out = l
	while isGE_P(out) do
		out = subP(out)
	end
	return out
end

--- Normalize `r` (array, length `n`) to base-2^16 limbs, fold limb positions
--- above 16 back down with ×38 (2^256 mod p; see inside), then reduce below p.
--- Returns a fresh 16-limb fully reduced element.
local function ffold(r, n)
	local carry = 0
	for k = 1, n do
		local v = (r[k] or 0) + carry
		local lo = v % 65536
		carry = (v - lo) / 65536
		r[k] = lo
	end
	if carry > 0 then
		n = n + 1
		r[n] = carry
	end

	while n > 16 do
		local maxT = math.max(16, n - 16)
		local t = {}
		for k = 1, 16 do
			t[k] = r[k]
		end
		for k = 17, n do
			local hv = r[k]
			if hv ~= 0 then
				local idx = k - 16
				-- limbs ≥ 17 begin at bit 256; 2^256 = 2·2^255 ≡ 2·19 = 38 (mod p).
				-- (×19 would only be correct for a split at bit 255.)
				t[idx] = (t[idx] or 0) + hv * 38
			end
		end
		local c2 = 0
		for k = 1, maxT do
			local v = (t[k] or 0) + c2
			local lo = v % 65536
			c2 = (v - lo) / 65536
			t[k] = lo
		end
		for k = 1, maxT do
			r[k] = t[k]
		end
		for k = maxT + 1, n do
			r[k] = nil
		end
		if c2 > 0 then
			n = maxT + 1
			r[n] = c2
		else
			n = maxT
		end
	end

	local out = {}
	for k = 1, 16 do
		out[k] = r[k] or 0
	end
	return freduce(out)
end

local function fmul(a, b)
	local r = {}
	for i = 1, 32 do
		r[i] = 0
	end
	for i = 1, 16 do
		local ai = a[i]
		if ai ~= 0 then
			for j = 1, 16 do
				local bj = b[j]
				if bj ~= 0 then
					local k = i + j - 1
					r[k] = r[k] + ai * bj
				end
			end
		end
	end
	return ffold(r, 32)
end

local function fadd(a, b)
	local r = {}
	for i = 1, 16 do
		r[i] = a[i] + b[i]
	end
	return ffold(r, 16)
end

local function fsub(a, b)
	local r = {}
	local borrow = 0
	for i = 1, 16 do
		local v = a[i] - b[i] - borrow
		if v < 0 then
			v = v + 65536
			borrow = 1
		else
			borrow = 0
		end
		r[i] = v
	end
	if borrow == 1 then
		-- a - b underflowed: add p back (result lands in [1, p-1])
		local carry = 0
		local v1 = r[1] + 0xffed
		carry = math.floor(v1 / 65536)
		r[1] = v1 % 65536
		for i = 2, 15 do
			local v = r[i] + 0xffff + carry
			carry = math.floor(v / 65536)
			r[i] = v % 65536
		end
		local v16 = r[16] + 0x7fff + carry
		carry = math.floor(v16 / 65536)
		r[16] = v16 % 65536
		-- A carry out of limb 16 here is the 2^256 wrap of the underflowed
		-- (a - b) subtraction. Adding p already compensated it exactly —
		-- limbs now hold a - b + p ∈ [0, p) — so the carry must be DROPPED.
		-- Folding it (×38) would add a bogus modular term.
		if carry > 1 then
			return nil -- unreachable for reduced inputs; fail loudly in tests
		end
		return freduce(r)
	end
	return ffold(r, 16)
end

local function feq(a, b)
	for i = 1, 16 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function fpow(base, expHex)
	local exp = hexToBytes(expHex)
	local r = { 1 }
	for i = 2, 16 do
		r[i] = 0
	end
	for byteIdx = 32, 1, -1 do
		local bv = exp[byteIdx]
		for bit = 7, 0, -1 do
			r = fmul(r, r)
			if band(bv, lshift(1, bit)) ~= 0 then
				r = fmul(r, base)
			end
		end
	end
	return r
end

local FZERO = (function()
	local r = {}
	for i = 1, 16 do
		r[i] = 0
	end
	return r
end)()

local FONE = (function()
	local r = { 1 }
	for i = 2, 16 do
		r[i] = 0
	end
	return r
end)()

local FD = freduce(limbsFromBytes32(hexToBytes(D_HEX)))
local FTWO_D = freduce(limbsFromBytes32(hexToBytes(TWO_D_HEX)))
local FSQRT_M1 = freduce(limbsFromBytes32(hexToBytes(SQRT_M1_HEX)))

local function finv(a)
	return fpow(a, EXP_P_MINUS_2)
end

-- points: {x=, y=, z=, t=} field elements
local function pIdentity()
	return { x = FZERO, y = FONE, z = FONE, t = FZERO }
end

local function padd(P, Q)
	-- unified addition on a = -1 extended coordinates (EFD add-2008-hwcd-3)
	local A = fmul(fsub(P.y, P.x), fsub(Q.y, Q.x))
	local B = fmul(fadd(P.y, P.x), fadd(Q.y, Q.x))
	local C = fmul(fmul(P.t, FTWO_D), Q.t)
	local Dz = fmul(fadd(P.z, P.z), Q.z)
	local E = fsub(B, A)
	local F = fsub(Dz, C)
	local G = fadd(Dz, C)
	local H = fadd(B, A)
	return {
		x = fmul(E, F),
		y = fmul(G, H),
		t = fmul(E, H),
		z = fmul(F, G),
	}
end

local function pdouble(P)
	return padd(P, P)
end

local function smul(scalar32, P)
	-- double-and-add, MSB first (not constant-time; see header note)
	local R = pIdentity()
	for bitPos = 255, 0, -1 do
		R = pdouble(R)
		local byte = scalar32[math.floor(bitPos / 8) + 1]
		if band(byte, lshift(1, bitPos % 8)) ~= 0 then
			R = padd(R, P)
		end
	end
	return R
end

local BASE_POINT = nil

local function pdecompress(bytes)
	local sign = band(bytes[32], 128) ~= 0
	local cleared = {}
	for i = 1, 31 do
		cleared[i] = bytes[i]
	end
	cleared[32] = band(bytes[32], 127)
	local y = freduce(limbsFromBytes32(cleared))

	local yy = fmul(y, y)
	local u = fsub(yy, FONE)
	local v = fadd(fmul(FD, yy), FONE)
	local xv = fmul(u, finv(v))
	local x = fpow(xv, EXP_P3_8)
	if not feq(fmul(x, x), xv) then
		x = fmul(x, FSQRT_M1)
		if not feq(fmul(x, x), xv) then
			return nil
		end
	end
	if feq(x, FZERO) then
		if sign then
			return nil -- x = 0 with sign bit set is non-canonical
		end
	else
		local xOdd = x[1] % 2 == 1
		if xOdd ~= sign then
			x = fsub(FZERO, x)
		end
	end
	return { x = x, y = y, z = FONE, t = fmul(x, y) }
end

local ORDER = hexToBytes(ORDER_HEX)

local function scalarLessThanOrder(s) -- s:32 bytes LE; true iff s < L
	for i = 32, 1, -1 do
		if s[i] > ORDER[i] then
			return false
		end
		if s[i] < ORDER[i] then
			return true
		end
	end
	return false -- s == L is invalid
end

local function scalarModL(bytes) -- arbitrary-length LE bytes → 32 bytes LE
	-- bit-by-bit restoring reduction: acc = (acc*2 + bit) mod L
	local acc = {}
	for i = 1, 33 do
		acc[i] = 0
	end
	local bitLength = #bytes * 8
	for pos = bitLength - 1, 0, -1 do
		local carry = band(bytes[math.floor(pos / 8) + 1], lshift(1, pos % 8)) ~= 0 and 1 or 0
		for i = 1, 33 do
			local v = acc[i] * 2 + carry
			if v >= 256 then
				acc[i] = v - 256
				carry = 1
			else
				acc[i] = v
				carry = 0
			end
		end
		-- if acc >= L then acc -= L
		local ge
		if acc[33] > 0 then
			ge = true
		else
			ge = true
			for i = 32, 1, -1 do
				if acc[i] > ORDER[i] then
					ge = true
					break
				end
				if acc[i] < ORDER[i] then
					ge = false
					break
				end
				if i == 1 then
					ge = true
				end
			end
		end
		if ge then
			local borrow = 0
			for i = 1, 32 do
				local v = acc[i] - ORDER[i] - borrow
				if v < 0 then
					v = v + 256
					borrow = 1
				else
					borrow = 0
				end
				acc[i] = v
			end
			acc[33] = acc[33] - borrow
			if acc[33] < 0 then
				return nil -- unreachable if the comparison is right
			end
		end
	end
	local out = {}
	for i = 1, 32 do
		out[i] = acc[i]
	end
	return out
end

local function getBasePoint()
	if not BASE_POINT then
		BASE_POINT = pdecompress(hexToBytes(BASE_COMPRESSED))
	end
	return BASE_POINT
end

local function pointsEqual(P, Q)
	return feq(fmul(P.x, Q.z), fmul(Q.x, P.z)) and feq(fmul(P.y, Q.z), fmul(Q.y, P.z))
end

--- Verify an Ed25519 signature (RFC 8032) over `msg`.
--- @param msg string raw message bytes
--- @param sig string 64 raw signature bytes
--- @param pub string 32 raw public key bytes
--- @return boolean
local function ed25519_verify_bytes(msg, sig, pub)
	if type(msg) ~= "string" or type(sig) ~= "string" or #sig ~= 64 or type(pub) ~= "string" or #pub ~= 32 then
		return false
	end

	local sigBytes = { sig:byte(1, 64) }
	local pubArr = { pub:byte(1, 32) }

	local S = {}
	for i = 1, 32 do
		S[i] = sigBytes[i + 32]
	end
	if not scalarLessThanOrder(S) then
		return false
	end

	local A = pdecompress(pubArr)
	if not A then
		return false
	end
	local R = pdecompress(sigBytes)
	if not R then
		return false
	end

	-- k = SHA-512(R || A || msg), reduced mod L; R is the FIRST 32 bytes
	-- of the signature (the encoded point), not the whole 64-byte blob.
	local hashInput = sig:sub(1, 32) .. pub .. msg
	local k = scalarModL(sha512_bytes(hashInput))
	if not k then
		return false
	end

	local base = getBasePoint()
	if not base then
		return false
	end

	-- check [S]B == R + [k]A
	local lhs = smul(S, base)
	local rhs = padd(R, smul(k, A))
	return pointsEqual(lhs, rhs)
end

local function ed25519_verify(msg, sigHex, pubHex)
	if type(sigHex) ~= "string" or #sigHex ~= 128 or not isHex(sigHex) then
		return false
	end
	if type(pubHex) ~= "string" or #pubHex ~= 64 or not isHex(pubHex) then
		return false
	end
	return ed25519_verify_bytes(msg, bytesToString(hexToBytes(sigHex)), bytesToString(hexToBytes(pubHex)))
end

-- ===========================================================================
-- quiet stub — returned on every failure path. Callable, indexable, silent.
-- ===========================================================================

local function quietStub()
	-- Every index and every call resolves back to the stub itself, so both
	-- `Astra:CreateWindow(...)` and pure index chains like
	-- `Astra.Settings.readPersisted` (or deeper) stay silent: nothing here
	-- is ever a function value, so it can never be "called wrong" either.
	-- (That also makes `type(CreateWindow) == "table"` the outside signal
	-- that a stub was returned instead of the real API — the real Astra's
	-- CreateWindow is a function.)
	local stub = {}
	return setmetatable(stub, {
		__index = function()
			return stub
		end,
		__call = function()
			return stub
		end,
		__newindex = function(t, k, v)
			rawset(t, k, v)
		end,
	})
end

-- ===========================================================================
-- fetch — global HttpGet, then game:HttpGet, then HttpService:GetAsync.
-- Every path is pcall-wrapped and must produce a non-empty string.
-- ===========================================================================

local function tryFetch(url)
	if type(HttpGet) == "function" then
		local ok, res = pcall(HttpGet, url)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
	end
	if game ~= nil then
		local ok, res = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
		ok, res = pcall(function()
			return game:GetService("HttpService"):GetAsync(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
	end
	return nil
end

-- ===========================================================================
-- main — fetch, verify, execute the exact signed bytes. Fail → stub.
-- ===========================================================================

local function makeRecord(version, digestHex)
	return RECORD_PREFIX .. "|" .. version .. "|" .. digestHex
end

local function main()
	local bundle = tryFetch(BUNDLE_URL)
	if type(bundle) ~= "string" or #bundle == 0 then
		return quietStub()
	end

	local digest = sha256hex(bundle)
	local record = makeRecord(EXPECTED_BUNDLE_VERSION, digest)

	if VERIFICATION_MODE == "signature" then
		local sigText = tryFetch(SIG_URL)
		if type(sigText) ~= "string" then
			return quietStub()
		end
		local sigHex = trim(sigText)
		if not isHex(sigHex) or #sigHex ~= 128 then
			return quietStub()
		end
		if not ed25519_verify(record, sigHex, PUBLIC_KEY) then
			return quietStub()
		end
	elseif VERIFICATION_MODE == "pin" then
		-- Labeled degraded mode (see config): the second origin serves the
		-- record as plain text; it must equal the locally computed one.
		local pinText = tryFetch(SECONDARY_PIN_URL)
		if type(pinText) ~= "string" then
			return quietStub()
		end
		if trim(pinText) ~= record then
			return quietStub()
		end
	else
		return quietStub()
	end

	-- Exact verified bytes go to loadstring — no wrapping, no mutation.
	local fn = loadstring(bundle, "AstraBundle")
	if type(fn) ~= "function" then
		return quietStub()
	end

	local ok, api = pcall(fn)
	if not ok or type(api) ~= "table" then
		return quietStub()
	end
	return api
end

-- ===========================================================================
-- autorun (tests set ASTRA_LOADER_NO_AUTORUN to inspect internals instead)
-- ===========================================================================

local function debugStages(msg, sigHex, pubHex)
	-- Test-only: expose intermediate values of the verify pipeline so the
	-- differential test against a reference implementation can bisect bugs.
	local out = {}
	local ok, err = pcall(function()
		local sigBytes = hexToBytes(sigHex)
		local pubArr = hexToBytes(pubHex)
		local A = pdecompress(pubArr)
		local R = pdecompress(sigBytes)
		out.A = A and { x = bytesToHex(bytes32FromLimbs(A.x)), y = bytesToHex(bytes32FromLimbs(A.y)), z = bytesToHex(bytes32FromLimbs(A.z)) } or "nil"
		out.R = R and { x = bytesToHex(bytes32FromLimbs(R.x)), y = bytesToHex(bytes32FromLimbs(R.y)), z = bytesToHex(bytes32FromLimbs(R.z)) } or "nil"
		local S = {}
		for i = 1, 32 do
			S[i] = sigBytes[i + 32]
		end
		out.S_lt_L = scalarLessThanOrder(S)
		local rp = {}
		for i = 1, 32 do rp[i] = sigBytes[i] end
		local hashInput = bytesToString(rp) .. bytesToString(pubArr) .. msg
		out.k_raw = bytesToHex(sha512_bytes(hashInput))
		local k = scalarModL(sha512_bytes(hashInput))
		out.k = k and bytesToHex(k) or "nil"
		local base = getBasePoint()
		out.base = base and { x = bytesToHex(bytes32FromLimbs(base.x)), y = bytesToHex(bytes32FromLimbs(base.y)) } or "nil"
		if base and A and R and k then
			local lhs = smul(S, base)
			local rhs = padd(R, smul(k, A))
			out.lhs = { x = bytesToHex(bytes32FromLimbs(lhs.x)), z = bytesToHex(bytes32FromLimbs(lhs.z)) }
			out.rhs = { x = bytesToHex(bytes32FromLimbs(rhs.x)), z = bytesToHex(bytes32FromLimbs(rhs.z)) }
			out.eq = pointsEqual(lhs, rhs)
			-- affine y = Y/Z for both
			local ly = fmul(lhs.y, finv(lhs.z))
			local ry = fmul(rhs.y, finv(rhs.z))
			out.lhs_affine_y = bytesToHex(bytes32FromLimbs(ly))
			out.rhs_affine_y = bytesToHex(bytes32FromLimbs(ry))
		end
		out.fd_check = bytesToHex(bytes32FromLimbs(fmul(FD, finv(FD))))
		out.fone_check = bytesToHex(bytes32FromLimbs(fadd(FZERO, FONE)))
		out.fone_sq = bytesToHex(bytes32FromLimbs(fmul(FONE, FONE)))
		local baseRaw = hexToBytes(BASE_COMPRESSED)
		local Bp = pdecompress(baseRaw)
		out.base_decompress = Bp and "ok" or "FAIL"
		if Bp then
			out.base_x = bytesToHex(bytes32FromLimbs(Bp.x))
			out.base_y = bytesToHex(bytes32FromLimbs(Bp.y))
		end
	end)
	out.ok = ok
	out.err = tostring(err)
	return out
end

local function debugField()
	local out = {}
	out.FD = bytesToHex(bytes32FromLimbs(FD))
	out.fpow_one_fd = bytesToHex(bytes32FromLimbs(fpow(FD, "0100000000000000000000000000000000000000000000000000000000000000")))
	out.fpow_one = bytesToHex(bytes32FromLimbs(fpow(FONE, EXP_P_MINUS_2)))
	local finv_FD = finv(FD)
	out.finv_FD = bytesToHex(bytes32FromLimbs(finv_FD))
	out.fd_times_inv = bytesToHex(bytes32FromLimbs(fmul(FD, finv_FD)))
	-- FD^2 via square-multiply vs via fmul directly
	local fd2_pow = fpow(FD, "0200000000000000000000000000000000000000000000000000000000000000")
	out.fd2_pow = bytesToHex(bytes32FromLimbs(fd2_pow))
	out.fd2_mul = bytesToHex(bytes32FromLimbs(fmul(FD, FD)))
	-- big multiply round trip: random-ish product fold sanity
	local a = freduce(limbsFromBytes32(hexToBytes("fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe")))  -- p-1 = -1
	out.am1 = bytesToHex(bytes32FromLimbs(a))
	out.am1_times_fd = bytesToHex(bytes32FromLimbs(fmul(a, FD))) -- should be -FD = p-FD
	local pfd = fsub(FZERO, FD)
	out.neg_fd = bytesToHex(bytes32FromLimbs(pfd))
	return out
end

local internals = {
	sha256hex = sha256hex,
	sha512hex = sha512hex,
	ed25519_verify = ed25519_verify,
	ed25519_verify_bytes = ed25519_verify_bytes,
	debugStages = debugStages,
	debugField = debugField,
	makeRecord = makeRecord,
	quietStub = quietStub,
	tryFetch = tryFetch,
	main = main,
	BUNDLE_URL = BUNDLE_URL,
	SIG_URL = SIG_URL,
	EXPECTED_BUNDLE_VERSION = EXPECTED_BUNDLE_VERSION,
	PUBLIC_KEY = PUBLIC_KEY,
	VERIFICATION_MODE = VERIFICATION_MODE,
	SECONDARY_PIN_URL = SECONDARY_PIN_URL,
	RECORD_PREFIX = RECORD_PREFIX,
}

-- Read the bare global (NOT rawget(_G, ...)): in Luau, script-level global
-- assignments are visible to bare reads but do not necessarily land in the
-- `_G` table, so a rawget probe misses them.
local noAuto = false
pcall(function()
	noAuto = ASTRA_LOADER_NO_AUTORUN == true
end)
if noAuto then
	return internals
end

local ok, result = pcall(main)
if not ok or type(result) ~= "table" then
	return quietStub()
end
return result
