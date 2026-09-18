# Astra v1 — Repository workflow

For work *inside* this repository (`Kira762/astra-version-1`). The library ships as
both a modular tree (source of truth) and a generated single-file bundle (what
scripts load).

## Layout

| Path | Role |
|---|---|
| `version-1.luau` | **Generated** bundle — the artifact users load with `loadstring`. Never hand-edit; regenerate. |
| `library_entrypoint.luau` | Public API singleton (`CreateWindow`, `Icons`, `Core`, `Settings`, `Motion`). |
| `Types.luau` | Typed public surface (`export type …`). |
| `core/` | `state` (runtime singletons, `secureMode`), `registry`, `loader`. |
| `components/` | `window`, `sidebar`, `chrome`, `drag`, `notification`, `overlayQueue`, `popup`, `profilePanel`, `search`, `settings`, `tabSelector`, `action`. |
| `elements/` | One module per element plus `tab`, `group`, `section`, `tabSection`, `baseCard`, `description`. |
| `settings/` | `defaults`, `manager`, `registry`, `appearance`, `behavior`, `performance`, `persistence`. |
| `themes/` | `init` resolver + one module per built-in theme. |
| `utilities/` | Motion, haptics, persistence pieces, icon/asset resolution, text metrics, layouts, locale, locks/ordering. |
| `icons/` | Seven icon packs, `packBuilder`, custom-asset resolution. |
| `scripts/` | Build, syntax gate, static checkers and runtime tests. |
| `skills/astra/` | The Agent Skill published to skills.sh (this folder). |
| `website/` | The docs site: Next.js static export → GitHub Pages. Its navigation, on-page contents, search index and `sitemap.xml` all derive from `website/lib/docs.ts`; adding a page means adding it to `NAV` there. Never part of the Rojo tree or the bundle. |
| `default.project.json`, `wax.project.json` | Rojo / Wax project mapping for Studio. |

Function bodies in the tree are minified (locals renamed `a1`, `a2`, …); top-level
locals keep meaningful names. `MODULES.md` documents what each numbered local holds.

## Build and verify

Run these from the repository root, in this order, after touching the tree:

```sh
node scripts/generate_bundle.js     # rebuild version-1.luau from the modular tree
sh scripts/check_syntax.sh          # compile every published .luau file
python3 scripts/check_requires.py   # require paths exist, no dependency cycles
python3 scripts/check_instance_fields.py   # no custom Lua fields written on Instances
sh scripts/smoke_test_bundle.sh     # runtime smoke test of the generated bundle
sh scripts/<feature>_test.sh        # the per-feature runtime tests
```

- `scripts/generate_bundle.js` refuses to write if fewer than ~60 modules are found,
  emits the Wax-style ObjectTree / ClosureBindings / LineOffsets bundle, and prints
  module count, line count and byte size.
- `check_syntax.sh` resolves `luau-compile` (preferred) or `luau --compile` from
  `PATH`, `/tmp`, `/usr/local/bin`; with neither present it exits **2 — "not checked",
  never a silent pass**. The same toolchain lookup is used by the runtime tests.
- Runtime tests assemble mini Roblox stubs + the bundle (wrapped in a function so the
  bundle's own error-line mapping survives) + assertions, then run them under the
  Luau CLI. `ASTRA_BUNDLE=/path/to/bundle` points a test at another build.
- `python3 scripts/eager_graph.py` reports the eager transitive module graph and is
  the tool behind the startup numbers in `PERFORMANCE_CHANGES.md`.
- Files outside the gate's fixed list (for example a new `.luau` under `skills/`)
  can be compiled directly with the same tool: `luau-compile --binary --output /tmp/out file.luau`.

## Documentation discipline

A behaviour change is not finished until the docs that describe it are updated:

| Change | Update |
|---|---|
| Anything user-visible | `CHANGELOG.md` — a new dated section at the top: a prose title, a paragraph explaining the cause and the fix, then bullets that name the files touched and the new behaviour. |
| Public API / usage | `USAGE.md` — the author-facing guide; keep examples copy-pasteable and honest about defaults. |
| Module structure or locals | `MODULES.md` — per-file reference, including the meaning of minified locals. |
| Startup cost, instance budget, bundle size | `PERFORMANCE_CHANGES.md` — measured with `scripts/startup_test.sh` / `eager_graph.py`. |
| Typed surface | `Types.luau`, kept in step with `library_entrypoint.luau` and the constructors. |
| New per-feature test | `scripts/<feature>_test.luau` + `scripts/<feature>_test.sh` wrapper following the existing pairs. |

Style in the tree: header comments in the `-- [[…]]` bracket form, 4-space
indentation, tabs in shell scripts, one module per file mirroring its Roblox name
(`init.luau` = the folder ModuleScript).

## Publisher-facing notes

- The raw GitHub URL in every example
  (`https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau`)
  points at `main`. A change is only live for users once the regenerated bundle is
  committed to `main` — a syntax error in the bundle surfaces for users as
  `attempt to call a nil value` at line 1, not as a syntax error, which is exactly
  why `check_syntax.sh` exists.
- `skills/` is the discovery root used by the `skills` CLI: `skills/astra/SKILL.md`
  is what `npx skills add Kira762/astra-version-1` installs.
- The library is published as one bundle; do not switch examples or loaders to the
  modular tree or to per-file raw URLs.

## Verification expectations

Never publish a bundle that does not compile, and never claim a fix verified in
Studio if it was only reasoned about: the runtime tests are the evidence. When the
Luau CLI is unavailable, state plainly that the gate was skipped (exit 2) instead of
reporting a pass. Syntax can still be sanity-checked by any Luau parser available in
the environment, but that is not a substitute for `check_syntax.sh`.
