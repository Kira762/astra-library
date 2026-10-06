# Astra Release Process

This document specifies how a version of Astra is cut, verified and published: what a version number binds together, which files have to agree, what a tag produces, and how a consumer pins to it. Source of truth:

- `ASTRA_VERSION` — the version number; everything else is derived from or checked against it
- `scripts/release.sh` — the local release flow (bump, regenerate, sign, resync, preflight) and the release-notes generator
- `scripts/check_release_consistency.sh` — the gate that holds every version claim against the bundle digest
- `scripts/sign_bundle.js` — digest, Ed25519 signing, loader pin sync (`--verify`, `--print-digest`)
- `.github/workflows/_verify.yml` — the reusable verification template both pipelines call
- `.github/workflows/sign-bundle.yml` — push/PR gate and production re-signing on `main`
- `.github/workflows/publish.yml` — tag-driven release
- `loader.luau` — `EXPECTED_BUNDLE_VERSION` and `PUBLIC_KEY`, the runtime end of the contract

## 1. What a version binds

A version number is not a label on a commit. It is the middle field of the record the loader checks at runtime:

```
ASTRA-BUNDLE-V1|<ASTRA_VERSION>|<sha256(version-1.luau) in lowercase hex>
```

The signature in `version-1.luau.sig` covers exactly that ASCII string. Because the version is inside the signed bytes, a `.sig` cannot be replayed against a loader that expects a different version — rolling the signature back without rolling the loader back fails the check and resolves to the silent stub.

Five places state or depend on the version, and all five have to agree:

| Claim | Lives in | Checked by |
|---|---|---|
| the version itself | `ASTRA_VERSION` | — (the source) |
| the version clients will accept | `EXPECTED_BUNDLE_VERSION` in `loader.luau` | `check_release_consistency.sh`, `sign_bundle.js --verify` |
| the key clients will accept | `PUBLIC_KEY` in `loader.luau` | `check_release_consistency.sh` (shape), `sign_bundle.js --verify` (signature) |
| the bytes users are told to expect | the `sha256(version-1.luau) = …` line in `README.md` | `check_release_consistency.sh` |
| the version a release carries | the git tag `v<ASTRA_VERSION>` | `check_release_consistency.sh --tag`, `publish.yml` |

A mismatch in any of them is a shipping bug, not a cosmetic one: a stale README checksum tells a reader to trust bytes that are no longer published, and a tag that disagrees with `ASTRA_VERSION` publishes assets that every client rejects as stale.

## 2. Cutting a release

### 2.1 Local preflight

```sh
sh scripts/release.sh --version 1.1.0 --stamp
```

In order, this:

1. writes `1.1.0` to `ASTRA_VERSION` (rejects a leading `v`, and anything that is not `MAJOR.MINOR.PATCH`);
2. with `--stamp`, rewrites the leading run of `## Unreleased — …` changelog headings to `## YYYY-MM-DD (v1.1.0) — …`, which is both the house heading style and the marker the notes generator uses to find a release's entries later;
3. regenerates `version-1.luau` from the source tree (`scripts/generate_bundle.js`);
4. signs it and syncs the loader pin (`scripts/sign_bundle.js`);
5. rewrites the README checksum line from the digest it just computed;
6. runs `scripts/check_release_consistency.sh --tag v1.1.0` and fails if anything disagrees.

Omit `--version` to preflight the current version without bumping. Omit `--stamp` to leave the changelog alone.

**On keys.** With no `SIGNING_KEY` / `SIGNING_KEY_FILE` in the environment, step 4 signs with the gitignored dev key and rewrites `PUBLIC_KEY` in `loader.luau`. That is the normal local path — the Sign bundle workflow re-signs with the production key once the change lands on `main`. Never tag a dev-key signature: clients pin the production key and would reject the release wholesale.

### 2.2 Land it, then tag it

```sh
sh scripts/check_all.sh            # syntax, static checks, every runtime test
git diff                           # bundle, signature, loader pin, README
# commit, push, merge to main; the Sign bundle workflow re-signs
git tag v1.1.0 && git push origin v1.1.0
```

Tagging is the publish action. Nothing else triggers a release, and no release is ever created from an untagged push.

## 3. What CI does

### 3.1 The verification template

`_verify.yml` is a `workflow_call` template, not a workflow anyone triggers directly. It checks out a ref, installs Node and the Luau CLI, and runs:

1. `check_release_consistency.sh` (first — no point compiling bytes whose version story is already broken)
2. `sign_bundle.js --verify`
3. `check_syntax.sh`
4. `loader_crypto_test.sh`
5. `loader_integrity_test.sh` — the end-to-end matrix: tampered bundle, missing signature, wrong key, stale version, fetch failure and canary trip must all resolve to the silent stub; a valid bundle must return the real API

It outputs `version` and `digest` so callers can name assets and write notes without recomputing them.

Both pipelines call it, so the gate a release passes is byte-for-byte the gate a pull request passes:

| Caller | Ref verified | Extra |
|---|---|---|
| `sign-bundle.yml` | the pushed branch / PR head | re-signs with `SIGNING_KEY` on `main`, then re-checks consistency |
| `publish.yml` | the tag | passes `--tag`, so a tag that disagrees with `ASTRA_VERSION` fails before anything is published |

### 3.2 The release

Pushing `v*` runs `publish.yml`:

1. **Resolve tag** — rejects anything that is not `v<number>…`.
2. **Verify** — `_verify.yml` against the tagged tree, with the tag cross-checked against `ASTRA_VERSION`.
3. **Create release** — stages the assets, generates the body with `sh scripts/release.sh --notes`, and creates the GitHub release.

A tag containing `-` (`v1.1.0-rc.1`) is published as a prerelease. Re-running against an existing tag updates the notes and re-uploads the assets rather than failing.

`workflow_dispatch` publishes an existing tag manually, defaulting to a draft.

### 3.3 Release assets

| Asset | What it is |
|---|---|
| `version-1.luau` | the signed bundle, exactly as published at the tag |
| `version-1.luau.sig` | the detached Ed25519 signature (128 hex chars) |
| `loader.luau` | the verifying loader as it stood at the tag, including its pins |
| `ASTRA_VERSION` | the version number |
| `SHA256SUMS` | `sha256sum -c SHA256SUMS` over the three files above |
| `SIGNED_RECORD` | the exact `ASTRA-BUNDLE-V1|…` string the signature covers |

## 4. Pinning as a consumer

The documented one-liner loads `loader.luau` from `main`, which is a moving target by design — users get fixes without changing anything. Three stricter options exist, in increasing order of paranoia:

1. **Pin the tag.** Load `loader.luau` from a `v*` ref instead of `main`, if the distribution repository carries the same tag. Immutable, still self-verifying.
2. **Vendor the release assets.** Download `version-1.luau`, `version-1.luau.sig` and `loader.luau` from the release and host them yourself. The signature travels with the bundle, so the loader's check still works from any origin.
3. **Check out of band.** Compare `sha256sum version-1.luau` against `SHA256SUMS` and the README checksum before you ship.

What none of this gives you is authorization. Verification proves the bundle is the one this repository published; it does not authenticate the client, the executor, the user, or any server. Treat it as tamper evidence for the delivery channel. See the README's integrity section for the full scope statement.

## 5. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `README.md publishes <hex> but the bundle is <hex>` | the bundle was regenerated without resyncing the README | `sh scripts/release.sh` |
| `loader.luau pins 'X' but ASTRA_VERSION is 'Y'` | `ASTRA_VERSION` was edited by hand | `node scripts/sign_bundle.js` (syncs the pin), or `sh scripts/release.sh` |
| `signature does NOT verify` | the bundle changed after signing, or the key changed | `node scripts/sign_bundle.js` and re-check |
| `tag 'vX' does not match ASTRA_VERSION` | tagged before bumping, or bumped after tagging | delete the tag, fix `ASTRA_VERSION`, re-run the preflight, re-tag |
| `sha256sum says X, sign_bundle.js says Y` | the digest tooling disagrees with a plain hasher | do not publish; `scripts/sign_bundle.js` is wrong or the file changed mid-read |
| release notes say only "See CHANGELOG.md" | no leading `## Unreleased` entries and no sections stamped for this version | add changelog entries, or run the preflight with `--stamp` |
