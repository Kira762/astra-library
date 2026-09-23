# Astra v1 — full repository analysis

Analysed 2026-09-19 on branch `arena/01a0bb09-astra-version-1` at `fde5eff`, working tree
clean. Every number below came from a command run in this checkout; the commands are
listed in the last section so any figure can be reproduced.

---

## 1. What this repository is

Astra v1 is a **Roblox/Luau UI library for executor scripts** — one `loadstring` line, one
`Astra:CreateWindow()` call, then tabs of elements. It ships as **two artifacts built from
one source**:

| Artifact | What it is | Size |
|---|---|---|
| `version-1.luau` | generated single-file bundle, the thing users `loadstring` | 25,773 lines / 1,041,455 bytes / 102 modules |
| modular tree (`core/`, `components/`, `elements/`, …) | the source the bundle is generated from; also a Rojo + wax project | 104 modules / 24,379 lines |

Lineage is visible in the code: **Rayfield → Sirius (Haijo12) → Astra (Kira762)**. Config
files still use the `.rfld` extension, the settings About panel still credits Haijo and
names Rayfield, and the default window icon is still `Sirius` (see §5).

### Shape of the checkout

| Metric | Value |
|---|---|
| Tracked files | 15,183 |
| Checkout size / icon PNGs | 79 MB / 61 MB |
| PNG files | 14,860 (13,715 icon catalog entries + variants + branding) |
| `.luau` files | 142 (104 source, 36 test scripts, 1 skill asset, 1 bundle) |
| Docs | README 1,041 w · USAGE 4,819 w · MODULES 6,343 w · CHANGELOG 20,179 w · PERF 1,175 w |
| Tooling | 34 `scripts/*.sh`, 5 `.py`, 3 `.js` |

The repo is also an **Agent Skill** source (`skills/astra/`, published via
`npx skills add Kira762/astra-version-1`) and vendors 9 third-party agent skills under
`.agents/skills/`, symlinked into `.claude/skills/` — all 9 symlinks resolve.

### Layer map (Luau lines)

| Layer | Modules | Lines | Notes |
|---|---|---|---|
| `components/` | 13 | 9,772 | `window.luau` alone is 3,212 lines; also profilePanel 2,428, popup, tooltip, search, drag, notification, overlayQueue, chrome, tabSelector, action, sidebar |
| `elements/` | 17 | 6,515 | dropdown 1,531, stat 846, slider 594, toggle 479, tab 464, changelog 418, collapsibleGroup 399 + baseCard/description/infoHelper/section/tabSection/text/divider/button/input/group |
| `utilities/` | 25 | 2,915 | motion, persistence (5 modules), fontManager 450, filesystem, assetResolver, odometer, locale, log, services, enums, windowSizing |
| `icons/` | 9 | 2,048 | 7 lazy packs + `packBuilder` + resolver |
| `themes/` | 11 | 818 | 10 named themes + resolution engine |
| `settings/` | 8 | 381 | registry / manager / defaults / persistence / 4 domain modules |
| `cache/`, `functions/`, `images/`, `layouts/`, `core/` | 15 | 1,182 | |

### Design patterns worth knowing

- **Lazy everywhere it matters for startup.** Icon packs are `[==[ name list ]==]` strings
  expanded per-lookup by `icons/packBuilder.luau` (so a startup showing 20 icons builds 20
  URL strings, not 13,715). Themes load by name via `themesFolder:FindFirstChild`. The
  profile card builds zero instances until enabled.
- **Cooperative construction pacing.** `components/window.luau` yields at object boundaries
  against a 3 ms / 48-instance per-frame budget; reveal happens on the next frame instead of
  a fixed 1 s deadline. Measured: `shell instances=67, peak allocations/frame=57, build
  frames=42`.
- **Executor-only runtime surface.** `getgenv`, `writefile`/`readfile`/`isfile`/`delfile`,
  `listfiles`, `getcustomasset`, `request`. A `getgenv().ASTRA_SECURE` flag switches on
  "secure mode" (icon preload, brand-font swap) and suppresses all logging via
  `utilities/log.luau`.
- **Path sanitisation before persistence.** `utilities/persistencePaths.luau` routes every
  config/settings path through `pathUtil.sanitizeFile` / `sanitizeFolder`.

---

## 2. Verification actually run

The repo's own gates were blocked on a missing Luau CLI, so I built **Luau 0.739 from
source** (`git clone` + `make`, → `luau-compile`, `luau-analyze`, `luau` in `/tmp`) — the
official release ZIPs are unreachable from this sandbox (`release-assets.githubusercontent.com`
fails TLS; `github.com`, `pypi.org`, `registry.npmjs.org` all return 200). With the
toolchain present:

| Gate | Result |
|---|---|
| `sh scripts/check_syntax.sh` | **PASS — 105 files compile** (was exit 2 "not checked" before the build) |
| `python3 scripts/check_requires.py` | **PASS — 99 files, 305 edges, no cycles** |
| `python3 scripts/check_instance_fields.py` | **PASS — no custom-field writes on Instances** |
| `node scripts/generate_bundle.js` | 102 modules / 25,773 lines / 1,041,455 bytes — **`git diff` empty, bundle is in sync with source** |
| `sh scripts/smoke_test_bundle.sh` | **PASS** |
| 32 runtime suites (`scripts/*_test.sh`) | **31 PASS, 1 FAIL** |
| `scripts/instance_budget_test.sh` | PASS — page used 256 instances |
| `scripts/startup_test.sh` | PASS — shell instances=67, peak alloc/frame=57, build frames=42, controls at reveal=3 |
| icon catalog integrity (custom check) | **13,715 names, 0 missing PNGs** — every name's derived PascalCase path exists |

### The one failing suite

```
COMPACT FAIL: D8 the window resized responsively (width) (got 600, want 608)
```

`scripts/profile_compact_test.luau:417` sets a 900×500 viewport and expects a 608 px window.
Tracing `utilities/windowSizing.luau`: occupancy 0.72 → target 648 → `fitSidebar` clamps to
`defaultSize.X` = **600**, and the height does come out at the expected 410. So the
expectation, not the height math, is the stale part.

This is **pre-existing and already documented**: CHANGELOG.md line 61 ("fails identically at
the previous head and predates this change") and line 118 ("fails identically at `620e73c` in
a clean worktree"). My run reproduces their numbers exactly. Either the test needs `600` or
`fitSidebar` needs to stop clamping at `defaultSize.X` — that is a product decision, not a
mechanical fix.

### Icon catalog check (corrected)

All 7 packs are exact: lucide 1,776 · material 1,133 · tabler 5,130 · phosphor 1,512 ·
heroicons 648 · feather 287 · remix 3,229 = **13,715**, and `packBuilder`'s
kebab→PascalCase rule resolves every single one to a PNG that exists in `assets/`. The
`icons/README.md` counts match too.

> Correction to my own first pass: my initial script reported "1,372 missing". That was my
> regex sweeping words out of each pack's `--[[ ... ]]` header comment into the name set.
> Matching only the `[==[ ]==]` key list gives 0 missing. The 0 figure is the real one.

---

## 3. Findings, most consequential first

### 3.1 `website/` is documented everywhere but does not exist

`ls -d website` → *No such file or directory*; `git ls-files | grep -c '^website/'` → **0**.
Yet it is referenced by:

- `README.md` — 11 mentions, including a documentation-table row linking
  `[website/](website/README.md)` (a dead link) and a whole "Docs website (GitHub Pages)"
  section describing `website/lib/docs.ts`
- `package.json` — **all 5 scripts** run `--prefix website` (`install:website`, `dev`,
  `build`, `build:pages`, `check:devices`) → every one fails
- `.gitignore` — 3 entries for `website/node_modules`, `website/.next`, `website/out`
- `.github/workflows/deploy-pages.yml` — checks out and builds `website/`

The live URL <https://kira762.github.io/astra-version-1/> therefore cannot be built from
this tree. Either the directory was never pushed or it was deleted; either way the README,
package.json and the workflow all promise something the repo does not contain.

### 3.2 `library_entrypoint.luau` uses an unbound `types` in 44 type annotations

The file has 8 `require`s (`core`, `core.state`, `images.image`, `utilities.locale`,
`utilities.constants`, `icons`, `utilities.motion`, `settings`) and **none binds `types`**,
yet `types.Window`, `types.WindowProps`, `types.Astra`, … appear 44 times (lines 10–118).
`MODULES.md` even documents the require that is missing:

> Requires — `core` (state/registry/loader), `core.state`, `images.image`,
> `utilities.locale`, `utilities.constants`, `icons`, `settings`, **`Types`**.

`luau-analyze` confirms it: `TypeError: Unknown type 'types.Window'`, `types.WindowProps`,
`types.Astra`, … So the public API's whole typed surface — the 40 `export type`
re-exports at the top of the file — resolves to nothing for any editor or type checker
(luau-lsp, Studio's script analysis).

**Runtime is unaffected**: type annotations erase at compile, the syntax gate compiles the
file, and the smoke test passes. This is a developer-experience/API-surface defect, not a
crash. `Types.luau` ends in `return {}`, so adding `local types = require(script.Types)`
is safe at runtime — but I could not verify that the annotations then *resolve*, because
bare `luau-analyze` cannot resolve `script`-relative requires outside Roblox (I tried a
minimal two-file repro both ways and the CLI reported the same error with and without the
binding). That half is unchecked.

### 3.3 `PERFORMANCE_CHANGES.md` numbers have drifted from the code

| Metric | doc "After" | measured now |
|---|---|---|
| Instances before first shell reveal | 66 | **67** |
| Peak allocations in one frame | 64 | **57** (better than claimed) |
| Bundle bytes | 987,741 | **1,041,455** (+5.4%) |

The doc also pins "the same numbers on Luau CLI 0.669 and 0.738"; I measured on 0.739.
Since the doc's whole value is that the numbers are measured, three stale ones undercut it.

### 3.4 Upstream branding and a dead constant survived the fork

- `icons/init.luau:29` — `icons.BASE = "https://raw.githubusercontent.com/Haijo12/sisys_ididh/main"`,
  pointing at the *previous* author's repo. It is **never read anywhere** (only assignment in
  the tree); the live resolver uses `assetBase` (`.../Kira762/astra-version-1/main/`) at
  `icons/init.luau:179`. Dead, and misleading.
- `components/settings.luau:185-186` — the About panel ships `"Customized by Haijo"` /
  `"Originally from Rayfield, Astra is customized, refined, and maintained by Haijo."`
- `components/window.luau:157` + `icons/init.luau:134` — default window icon is `Sirius`
  (`assets/Sirius.png`), not Astra.
- Persistence writes `.rfld` files (Rayfield's extension).

None of these break anything. All of them are user-visible or repo-identity noise.

### 3.5 10 of 34 `scripts/*.sh` lack the git executable bit

`git ls-files -s` shows 24 at `100755` and 10 at `100644` — including
`smoke_test_bundle.sh` and `startup_test.sh`, the two the README names in its Development
block. `sh scripts/foo.sh` works (that is how I ran them); `./scripts/foo.sh` gives
permission denied on a fresh clone.

### 3.6 Minified locals are still in 11 shipped modules

Inherited from the upstream bundle and documented in `MODULES.md` ("minified as `a17`"):
`elements/dropdown.luau` 134 distinct `a<num>` locals, `utilities/fontManager.luau` 91,
`elements/stat.luau` 55, `slider.luau` 28, `tab.luau` 25, `group.luau` 23, `divider.luau` 12,
`input.luau` 11, `toggle.luau` 5, `tabSection.luau` 3, `text.luau` 1. Field names
(`self.x`) are readable; locals are not. This is a deliberate, documented trade-off, but it
is where most future maintenance cost sits — `dropdown.luau` is both the largest element and
the most opaque.

### 3.7 `core/registry.luau` + `core/loader.luau` are an abstraction with no callers

`grep` finds no use of `registry.get/register/registerFactory/names` or
`loader.load/service` anywhere outside `core/` itself; `core/init.luau` merely re-exports
them, and the only consumer is the smoke test asserting `Astra.Core.state` exists. The
registry knows 2 modules (`state`, `registry`). It is a generic service locator built for a
future that the rest of the tree does not use — modules `require` each other directly.

---

## 4. What is in good shape

- **The generate → gate → test loop genuinely works** and the bundle is provably in sync
  with its source (zero diff after regeneration).
- **Icon data integrity is perfect** — 13,715/13,715 catalog entries resolve to real files,
  and the derivation rule that removed thousands of table constructors holds for every one.
- **The test suite is real**, not decorative: 32 suites drive the actual bundle against a
  stubbed Roblox environment and assert geometry, layering, input, persistence and
  lifecycle. The harness was recently hardened so an invented `Enum` member fails instead of
  silently passing (CHANGELOG, 2026-09-19) — that is the right instinct.
- **No debug leftovers**: zero `TODO`/`FIXME`/`HACK` in shipped source; the 10 `print(` hits
  are all behind `utilities/log.luau`, which suppresses under secure mode and guards
  `warn` for non-Roblox runtimes.
- **Docs are unusually honest** — CHANGELOG records its own regressions and names the
  commit where a failure predates the change.

---

## 5. Suggested order of work

1. **Restore or remove `website/`.** It is the only finding where the repo actively
   misleads (dead README link, 5 broken npm scripts, a workflow that cannot build).
2. **Decide `profile_compact_test` D8** — fix the expectation to 600 or widen
   `fitSidebar`'s clamp. A permanently red suite trains people to ignore red.
3. **Bind `types`** in `library_entrypoint.luau` (and update `MODULES.md` to match whichever
   way it goes) so the public API has a typed surface again.
4. **Refresh the three `PERFORMANCE_CHANGES.md` numbers**, and add the exec bit to the 10
   shell scripts (`git update-index --chmod=+x`).
5. **Drop `icons.BASE`** and settle the branding (About text, `Sirius` default icon, `.rfld`).
6. **Either use or delete `core/registry.luau` + `core/loader.luau`.**

---

## 6. Commands used

```sh
# toolchain (release ZIPs blocked, so build from source)
git clone --depth 1 --branch 0.739 https://github.com/luau-lang/luau.git /tmp/luau-src
cd /tmp/luau-src && make -j$(nproc) luau-compile luau-analyze luau
cp build/debug/{luau,luau-compile,luau-analyze} /tmp/

# the repo's own gates
sh  scripts/check_syntax.sh                 # PASS, 105 files
python3 scripts/check_requires.py           # 99 files, 305 edges, no cycles
python3 scripts/check_instance_fields.py    # clean
node scripts/generate_bundle.js && git diff --stat   # empty diff → bundle in sync
for t in scripts/*_test.sh; do sh "$t"; done         # 31 pass, 1 fail

# checks I wrote
/tmp/luau-analyze library_entrypoint.luau   # Unknown type 'types.*' × 44 annotations
git ls-files -s scripts/*.sh | awk '{print $1}' | sort | uniq -c   # exec bits
# icon catalog: parse each pack's [==[ ]==] key list, apply packBuilder's
# pascalCase rule, assert the derived path exists in assets/ → 13,715 / 0 missing
```

---

## 7. Outcome of the first round of fixes

Findings **3.1**, **3.2**, **3.4 (partly)**, **3.5** and **3.7** are now fixed;
**3.3** and the rest of **3.4** are still open pending a decision. Recorded in
CHANGELOG.md under 2026-09-19.

| Finding | Action | Verified by |
|---|---|---|
| 3.1 `website/` referenced but absent | Removed the README table row + "Docs website" section + layout line; deleted `package.json` (all 5 scripts were broken) and `.github/workflows/deploy-pages.yml`; cleaned `.gitignore`; dropped the row in `skills/astra/references/repo-workflow.md` | 0 `website` refs outside `.agents/`, `.claude/`, this file and the CHANGELOG entry that documents the removal |
| 3.2 unbound `types` | Added `local types = require(script.Parent.Types)` to `library_entrypoint.luau` | Negative control: rewriting it to `script.Parent.TypesBogus` makes `startup_test.sh` **fail**; the real bundle passes 31 suites + smoke. `Types` confirmed a sibling of `Astra` in `default.project.json`, exactly where `core` sits |
| 3.4 dead `icons.BASE` | Deleted the constant (pointed at `Haijo12/sisys_ididh`) | `grep` for `BASE` in shipped source now returns nothing |
| 3.5 exec bits | `git update-index --chmod=+x` + `chmod +x` on the working tree | 34/34 at `100755` in the index and `-rwxr-xr-x` on disk; `./scripts/smoke_test_bundle.sh` now runs directly |
| 3.7 dead `core/registry` + `core/loader` | Deleted both; `core/init.luau` now exposes only `core.state`; MODULES.md and repo-workflow.md updated | `registry.get` had no callers, so nothing could read a registered factory; `Astra.Core.state` (13 uses in the suites) is untouched |

### Gate results after the changes

| Gate | Before | After |
|---|---|---|
| `check_syntax.sh` | 105 files | **103 files, PASS** (two modules deleted) |
| `check_requires.py` | 99 files / 305 edges | **97 files / 304 edges, no cycles** |
| `check_instance_fields.py` | clean | clean |
| `generate_bundle.js` | 102 modules / 1,041,455 B | **100 modules / 25,680 lines / 1,039,811 B** |
| runtime suites | 31 pass / 1 fail | **31 pass / 1 fail** (same D8, unrelated) |
| `smoke_test_bundle.sh` | PASS | PASS |

### Honest gap on 3.2

`luau-analyze` reports the same **46** `Unknown type 'types.*'` errors before and
after the change, so it does not confirm the fix. That is a limitation of the CLI,
not evidence against it: this build cannot resolve *any* require path — a
`require("./Types.luau")` string in a two-file repro failed the same way. The
binding is verified for the **runtime** (negative control above) and verified
**structurally** for Rojo (Types sits where `core` does, and the seven existing
`script.Parent.*` requires already work in Studio). Whether luau-lsp/Studio now
resolves the 40 re-exported types is **unchecked** — it needs a Studio session.

### Still open

- **3.3** `PERFORMANCE_CHANGES.md` numbers (and its bundle figure is now further
  out: measured 1,039,811 bytes).
- **3.4** branding — `Customized by Haijo` / `Originally from Rayfield` in the
  About panel, `Sirius` as the default window icon, the `.rfld` config extension.
  These are attribution and backward-compatibility calls, not mechanical ones.
- **3.6** minified locals (a documented, deliberate trade-off).
- The **D8** failure — fix the expectation to 600 or widen `fitSidebar`'s clamp.

---

## 8. Second and third rounds

Everything in the "Still open" list above was subsequently actioned, and the
profile card was removed on top of it. Full detail in CHANGELOG.md under the
three 2026-09-19 entries.

| Item | Outcome |
|---|---|
| 3.3 perf doc | Refreshed: 66→**67** shell instances, 64→**57** peak, 987,741→**1,039,418** bytes. Wall-time row dropped as not comparable; two rows the harness no longer emits marked `—` |
| 3.4 branding | Configs `.rfld`→`.txt` (incl. the `sub(-5)`→`sub(-4)` fix), About panel rewritten, `Sirius`→`Astra` and the asset deleted, `Gen2`/`Rayfield` comments de-branded |
| D8 | Resolved by removing the feature that owned it |
| profile card | `components/profilePanel.luau` (2,428 lines) deleted, with `Window:SetProfile`, the three settings keys, the Appearance "Profile" group, six test suites and the docs |

### Gate results, end of session

| Gate | Start of session | End |
|---|---|---|
| `check_syntax.sh` | 105 files (after installing the Luau CLI) | **102 files, PASS** |
| `check_requires.py` | 99 files / 305 edges | **96 files / 294 edges, no cycles** |
| `check_instance_fields.py` | clean | clean |
| `generate_bundle.js` | 102 modules / 1,041,455 B | **99 modules / 23,023 lines / 931,398 B** |
| runtime suites | 31 pass / **1 fail** | **26 pass / 0 fail** |
| `smoke_test_bundle.sh` | PASS | PASS |

Six suites were deleted with the profile card, which is why the total went from
32 to 26; the one that used to fail was among them.

### Two things worth remembering about this codebase

1. **The runtime suites load `version-1.luau`, not the modular tree.** Editing
   source and running the tests proves nothing until
   `node scripts/generate_bundle.js` has run. An intermediate result in this
   session reported "sidebar_tab_sizing_test PASSED" against a bundle that still
   contained the deleted feature — a green run that meant nothing.
2. **`scripts/profile_image_stubs.luau` was not profile infrastructure.** It was
   the shared filesystem stub; deleting it by name pattern broke
   `config_preferences_test`. It is now `scripts/filesystem_stubs.luau`.
