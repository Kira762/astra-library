#!/usr/bin/env node
/**
 * Sign version-1.luau with an Ed25519 key and sync loader.luau.
 *
 * What it produces
 *   version-1.luau.sig   128 hex chars (64-byte Ed25519 signature) + newline
 *   loader.luau          EXPECTED_BUNDLE_VERSION / PUBLIC_KEY kept in sync
 *
 * The signed record is ASCII and version-bound (rollback of the .sig alone
 * against a different loader version fails):
 *
 *   ASTRA-BUNDLE-V1|<ASTRA_VERSION>|<sha256(bundle) in lowercase hex>
 *
 * Key sources, in priority order:
 *   1. SIGNING_KEY         env var — PEM (PKCS#8) content of the private key
 *   2. SIGNING_KEY_FILE    env var — path to a PEM file
 *   3. scripts/dev_signing_key.pem — local development key (created on first
 *      run, gitignored). NEVER commit this; CI must set SIGNING_KEY.
 *
 * Usage:
 *   node scripts/sign_bundle.js                 # sign + sync loader
 *   node scripts/sign_bundle.js --verify        # verify existing .sig only
 *   node scripts/sign_bundle.js --print-digest  # print sha256 of the bundle
 *   node scripts/sign_bundle.js --gen-key       # write a fresh keypair PEM
 *                                               # (prints the public key hex)
 *
 * CI: set SIGNING_KEY from the repository secret, run this script, commit
 * the resulting .sig (and loader.luau if it synced). The private key never
 * exists in the repository.
 */

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const BUNDLE_PATH = path.join(ROOT, "version-1.luau");
const SIG_PATH = path.join(ROOT, "version-1.luau.sig");
const LOADER_PATH = path.join(ROOT, "loader.luau");
const VERSION_PATH = path.join(ROOT, "ASTRA_VERSION");
const DEV_KEY_PATH = path.join(ROOT, "scripts", "dev_signing_key.pem");

const RECORD_PREFIX = "ASTRA-BUNDLE-V1";

function readVersion() {
  return fs.readFileSync(VERSION_PATH, "utf8").trim();
}

function bundleDigest() {
  const bundle = fs.readFileSync(BUNDLE_PATH);
  return crypto.createHash("sha256").update(bundle).digest("hex");
}

function makeRecord(version, digestHex) {
  return `${RECORD_PREFIX}|${version}|${digestHex}`;
}

function publicKeyHex(privateKey) {
  const jwk = privateKey.export({ format: "jwk" });
  return Buffer.from(jwk.x, "base64url").toString("hex");
}

function loadPrivateKey({ allowDevKey = true } = {}) {
  if (process.env.SIGNING_KEY) {
    return { privateKey: crypto.createPrivateKey(process.env.SIGNING_KEY), source: "SIGNING_KEY" };
  }
  if (process.env.SIGNING_KEY_FILE) {
    const pem = fs.readFileSync(process.env.SIGNING_KEY_FILE, "utf8");
    return { privateKey: crypto.createPrivateKey(pem), source: process.env.SIGNING_KEY_FILE };
  }
  if (allowDevKey && fs.existsSync(DEV_KEY_PATH)) {
    const pem = fs.readFileSync(DEV_KEY_PATH, "utf8");
    return { privateKey: crypto.createPrivateKey(pem), source: "dev key (gitignored)" };
  }
  return null;
}

function syncLoader(version, pubHex) {
  let loader = fs.readFileSync(LOADER_PATH, "utf8");
  const before = loader;
  loader = loader.replace(
    /local EXPECTED_BUNDLE_VERSION = "[^"]*"/,
    `local EXPECTED_BUNDLE_VERSION = "${version}"`
  );
  loader = loader.replace(/local PUBLIC_KEY = "[0-9a-fA-F]*"/, `local PUBLIC_KEY = "${pubHex}"`);
  if (loader !== before) {
    fs.writeFileSync(LOADER_PATH, loader);
    return true;
  }
  return false;
}

function verifyOnly() {
  if (!fs.existsSync(SIG_PATH)) {
    console.error("verify: version-1.luau.sig missing");
    process.exit(1);
  }
  const loader = fs.readFileSync(LOADER_PATH, "utf8");
  const pubMatch = loader.match(/local PUBLIC_KEY = "([0-9a-fA-F]{64})"/);
  const verMatch = loader.match(/local EXPECTED_BUNDLE_VERSION = "([^"]*)"/);
  if (!pubMatch || !verMatch) {
    console.error("verify: loader.luau is missing PUBLIC_KEY/EXPECTED_BUNDLE_VERSION");
    process.exit(1);
  }
  const version = readVersion();
  if (verMatch[1] !== version) {
    console.error(`verify: loader expects version ${verMatch[1]}, ASTRA_VERSION is ${version}`);
    process.exit(1);
  }
  const record = makeRecord(version, bundleDigest());
  const sig = Buffer.from(fs.readFileSync(SIG_PATH, "utf8").trim(), "hex");
  if (sig.length !== 64) {
    console.error(`verify: signature is ${sig.length} bytes, expected 64`);
    process.exit(1);
  }
  const key = crypto.createPublicKey({
    key: {
      kty: "OKP",
      crv: "Ed25519",
      x: Buffer.from(pubMatch[1], "hex").toString("base64url"),
    },
    format: "jwk",
  });
  const ok = crypto.verify(null, Buffer.from(record, "ascii"), key, sig);
  if (!ok) {
    console.error("verify: signature does NOT match the current bundle+version");
    process.exit(1);
  }
  console.log(`verify OK: version ${version}, sha256 ${bundleDigest()}`);
}

function genKey() {
  const { privateKey } = crypto.generateKeyPairSync("ed25519");
  fs.writeFileSync(DEV_KEY_PATH, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
  console.log(`wrote ${DEV_KEY_PATH}`);
  console.log(`public key (loader PUBLIC_KEY): ${publicKeyHex(privateKey)}`);
}

function sign() {
  if (!fs.existsSync(BUNDLE_PATH)) {
    console.error("version-1.luau missing — run: node scripts/generate_bundle.js");
    process.exit(1);
  }
  const loaded = loadPrivateKey();
  let privateKey;
  let source;
  if (loaded) {
    ({ privateKey, source } = loaded);
  } else {
    ({ privateKey } = crypto.generateKeyPairSync("ed25519"));
    fs.writeFileSync(DEV_KEY_PATH, privateKey.export({ type: "pkcs8", format: "pem" }), {
      mode: 0o600,
    });
    source = "NEW dev key (gitignored) — CI must set SIGNING_KEY for real releases";
    console.error(`note: no signing key configured; created ${DEV_KEY_PATH}`);
  }

  const version = readVersion();
  const record = makeRecord(version, bundleDigest());
  const sig = crypto.sign(null, Buffer.from(record, "ascii"), privateKey);
  if (sig.length !== 64) {
    console.error("unexpected signature length");
    process.exit(1);
  }
  fs.writeFileSync(SIG_PATH, sig.toString("hex") + "\n");

  const pubHex = publicKeyHex(privateKey);
  const synced = syncLoader(version, pubHex);

  console.log(`signed version-1.luau`);
  console.log(`  version: ${version}`);
  console.log(`  sha256:  ${bundleDigest()}`);
  console.log(`  key:     ${source}`);
  console.log(`  sig:     version-1.luau.sig (${sig.length} bytes, hex)`);
  if (synced) console.log("  loader:  EXPECTED_BUNDLE_VERSION + PUBLIC_KEY synced");
}

const args = process.argv.slice(2);
if (args.includes("--verify")) {
  verifyOnly();
} else if (args.includes("--print-digest")) {
  console.log(bundleDigest());
} else if (args.includes("--gen-key")) {
  genKey();
} else if (args.includes("--record")) {
  // print the exact record string (debugging / external signing)
  console.log(makeRecord(readVersion(), bundleDigest()));
} else {
  sign();
}
