# Astra Modular Architecture

This document is the record of the Phase 1 audit, the migration map used for the
refactor, the dependency rules, and the validation performed. Source modules are
the source of truth; `version-1.luau` is a generated distribution artifact
(Phase 11) and must not be hand-edited.

> Post-refactor updates are documented in `CHANGELOG.md` (v1.1 patch set,
> Luau minification, settings-card fix). The sections below describe the
> original modular refactor as performed.

## Current tree (post-settings-rebuild)

Since the v1.1 patch set, the tree has changed in the following ways
(see `CHANGELOG.md`, 2026-09-11):

- `elements/changelog.luau` + `Tab:CreateChangelog` — new release-history
  element (`+`/`-`/`~` symbols, `Set`/`Refresh`/`Add`/`Clear`).
- `layouts/` folder — per-mode bar-layout builders (`Topbar`, `Sidebar`,
  `SidebarCollapsed`) split out of the window; `utilities/layouts.luau`
  dispatches to them (`get`/`implementation`/`railWidthFor`).
- Settings UI rebuilt: the single settings card + `Window:AddSettingsTab`
  sub-tab API is gone. The window now builds six built-in settings tabs
  itself (`Window:_buildSettingsUI`: General, Appearance, Behavior,
  Performance, Persistence, About), toggled by the topbar gear action into a
  settings mode that shows only settings tabs. The `activeSubTab` registry
  key is retained and still round-trips through the settings JSON for
  compatibility.
- `utilities/persistence.luau` — facade over `persistenceConfig` +
  `persistenceSettings`, the single persistence entrypoint for the window
  and `settings/`.
- `icons/init.luau` — pack entries are repo-relative PNG paths
  (`assets/icons/<pack>-pack/…`) mapped onto the repo's raw-GitHub base URL
  at resolve time, with an executor `getcustomasset` override; no `rbxassetid`
  lookups. A bare name searches the packs in priority order (lazily),
  `"pack:name"` addresses one pack exactly, and the executor's `custom_asset`
  folder is indexed once and checked before any pack.
- `library_entrypoint.luau` — the active-window / anti-duplicate guard is
  backed by a `getgenv()`-backed global store in addition to the module
  local; in secure mode `CreateWindow` preloads window images and swaps in
  the brand fonts.
- `example.client.luau` — rewritten as a 20-tab example (multi-tab, tags,
  every element, `CreateChangelog`) loaded through `game:HttpGet` +
  `loadstring`.

Dependency direction and the rest of this document remain accurate;
`version-1.luau` is regenerated from this tree (includes `layouts/` and
`elements/changelog.luau`).

## v1.1 patch set (avatar/profile/settings fixes + settings sub-tabs)

Post-refactor patch set applied on top of the modular tree. Intentionally
diverging modules relative to the pre-patch snapshot:

- `components/sidebar.luau` — avatar reveal race fix (`setProfileShown` no
  longer gates on `profile.Visible`; nil-safe targets; themed plate fallback
  when the avatar URI never resolves, tracked in the weak-keyed `avatarReady`
  side table). Top-layout profile unified: right-anchored container in the
  topbar; `profileSubtitle` now created in every layout branch; `reflowProfile`
  handles top mode visibility.
- `components/window.luau` — `SettingsCard` overlay (Fix 3): settings pages get
  an element-styled card (`StyleElementBody`) and the rail no longer gets stuck
  hidden (`_applySettingsLayout(false)` restores rail visibility independent of
  `elements.Visible`; the sidebar frame itself stays visible during settings).
  New public API: `Window:AddSettingsTab({ name, icon })` builds settings
  sub-tabs (strip + pages inside the card, element registration reusing the
  rfSettings tab pipeline, persisted active index). Defensive `localPlayer`
  late-resolution hook after profile build (2s capped RenderStepped poll).
- `settings/*`, `utilities/persistenceSettings.luau` — new `activeSubTab`
  setting (registry definition, default 1, appearance-domain validation,
  persisted/read in the settings JSON).
- Bundle: regenerated from the modular tree; only the modules above plus
  LineOffsets differ from the pre-patch bundle.

## v1.2 patch set (profile card rebuild)

`components/profilePanel.luau` was rewritten as a native part of the window
shell and `components/window.luau` follows it:

- The card is still a sibling of `main` in the same ScreenGui, but it is now
  a 260x420 plate built from the shared tokens (WindowColor gradient,
  `CornerRoundness`, SurfaceStroke, ShadowColor glow) whose interior reuses
  the window's element language verbatim: section plates are
  `Window:StyleElementBody` bodies (`ElementGradient`, `ElementCornerRadius`,
  `ElementStroke` at `ElementStrokeTransparency`), headings are Section
  elements (16px `ContentColor` icon at 0.65 beside a 15px `ContentColor`
  title at 0.6) and rows use the element text colour, with a pinned header
  (avatar + presence dot, display name, `@username`, tier pill) over a 1px
  divider and a vertically scrolling detail region (Account, Current Game,
  Server, User Session). The scrollbar is theme-thin and only appears when
  the content is taller than the region, so the card never grows past the
  window's height and nothing overflows the frame. The card carries no
  settings gear: the window's topbar gear is the only settings entry point.
- Live rows come from real sources only: `MembershipType` (the tier pill's
  PREMIUM / FREEMIUM, or the host's own `tier` word), `AccountAge` (join date
  + age), Roblox's official two-step game-name API (place id -> universe id
  -> the games list's `name`, with `DataModel.Name` as the until-then label),
  `#Players:GetPlayers()` / `Players.MaxPlayers`, `game.JobId` and
  `os.clock()` for the session timer, refreshed by a 1s Heartbeat while the
  card is shown (`window.profileRefreshConnection`). Anything unavailable
  reads `—`, `Unknown` or `Not available` instead of a invented value;
  identifying values stay masked behind "Reveal profile details", and every
  COPY action writes through the executor's clipboard (`setclipboard`) with
  a green check that returns to the copy icon.
- `Window:SetProfile` keeps its legacy string/`nil` form (subtitle only) and
  accepts a table payload (`{ subtitle, key, tier, whitelist = { status,
  daysLeft | expiresAt } }`) for the license rows and the tier pill; omitted
  fields clear to the placeholder. Astra ships no key store, so those two
  rows stay `—` until a host supplies them.
- Reveal now unmasks the job ID (the row reads "Job ID" — it shows
  `DataModel.JobId`) and the license key as well; the settings
  copy (`components/window.luau`, `settings/registry.luau`) and `USAGE.md`
  say so. The card's off-centre rest shift follows the new width (`(260 +
  12) / 2 = 136px`).
- The card's surface is no longer a copy of the window's background styling:
  `Window:StyleWindowSurface(frame)` owns it (base colour, `WindowColor`
  gradient token, rotation/offset, opacity) and both the window frame and the
  card's plate are built through it, so a theme change and the theme's live
  gradient animation move the two together instead of leaving the card a shade
  behind. The card also resolves its icons against the window's active pack,
  so no icon (tier pill included) depends on the pack shipping the lucide name.
- Bundle regenerated: `node scripts/generate_bundle.js` (100 modules).
  Suites: `scripts/profile_{compact,centering,reveal,details,ui}_test.sh`,
  `scripts/sidebar_tab_sizing_test.sh`, `scripts/smoke_test_bundle.sh`,
  `scripts/check_requires.py` and `scripts/check_instance_fields.py` all
  green.

## v1.3 patch set (motion service + hot-path animation cleanup)

New `utilities/motion.luau` is the single owner of the library's animation
timing; the window's hot paths now go through it:

- Named specs are created once and shared (`motion.spec`), so a site that
  animates at 0.25s Quint/Out no longer walks its own `TweenInfo.new`.
- `motion.tween(instance, props, spec, onCompleted)` drops properties already
  at their target (no tween at all when every property is satisfied) and
  cancels an in-flight tween it would fight over the same property — one
  writer per property, which removes the stray/twin tweens a fast hover in/out
  used to leave behind. `onCompleted` is connected *before* `Play`, so a
  synchronous completion (the test stubs) cannot skip a settle path.
- The window's entrance rides `motion.spec("pop")` (the same 0.38s with a
  small Back/Out overshoot); hover, element reveal, result flash, guard
  failure and the ambient gradient drift all moved onto the service.
- `_revealElements` paces its cascade with `motion.step(stepDelay)`: a relaxed
  profile spreads the reveal, `instant` reveals every element on one frame.
- The window's new "Animation speed" setting (`motionSpeed`: relaxed / normal
  / snappy / instant) drives `motion.setProfile`; the value round-trips through
  the settings JSON and is validated against `motion.profiles` in both the
  live validator and the loader. Profile applied on build and on every
  `LoadSettings`.
- `Astra.Motion` exposes the service (specs, `tween`, `cancel`, `step`,
  `setProfile`, `setTimeScale`, `setEnabled`).
- Drive-by: `settings/manager.luau` never created `values`/`listeners`, so
  `Astra.Settings.newManager()` raised on first `:set`/`:get`; both are now
  initialised (found by the new suite).
- Bundle regenerated (101 modules at that point - motion added a module while
  the ColorPicker still existed; its removal in the instance-budget pass below
  takes the tree to 100). Measured against the previous bundle with
  the stub harness: redundant hover states 720 -> 24 tween creations, rapid
  hover in/out cancels 432 overlapping tweens that used to keep running,
  hide/show round trips cancel 161 — with the suite set unchanged and green.
  Suites: `scripts/motion_test.sh` added; profile/sidebar/smoke suites,
  `scripts/check_requires.py` and the bundle equivalence check all green.

## Instance budget (frame time)

Instance count is the library's main frame-time lever: Roblox renders and sorts
every GUI instance it holds, so a page's instance count is the closest offline
proxy for what the menu costs while it is open. Two rules keep it down:

- **Nothing invisible is built.** The odometer (`utilities/odometer.luau`)
  materialises reel rows per transition (`_row`/`_rows`) instead of pre-filling
  all 20 rows of every digit; a readout that shows one digit builds one row. The
  dropdown (`elements/dropdown.luau`) builds its option rows on the first open
  (`_materialiseOptions`/`_buildOptionAt`), so a closed list costs nothing
  however long its option list is; `Refresh`/`Add`/`Remove`/`Set` update the
  option list while the rows do not exist and the rows are built from it at the
  next open.
- **Tabs nobody opened are not walked.** The window marks a tab whose elements
  are hidden (`Window:_markTabElementsPending`) and shows them when the player
  opens it (`tab:Select`) or when the search renders them on its own page; a
  show/hide cycle touches the tab on screen instead of every tab. Element
  registration does the same for a single element (show it if the window is
  visible, mark the tab if not).
- **A closed element does not build the furniture of its open state.** A
  dropdown builds its option rows and its search bar on the first open, and the
  glows that only appear in a state a user has to enter (a switch turned on, a
  field validation flash) are built when that state arrives.
- **Elements are sized by `scripts/instance_budget_test.sh`**, which fails if an
  element or a realistic 16-element page grows past its ceiling. Current page:
  **281 instances** (322 before the lazy dropdown rows, 550 before the odometer
  change).

`elements/colorpicker.luau` was removed in this pass (unused); `Tab` no longer
exposes `CreateColorPicker`.

## Switch geometry (toggle element)

`elements/toggle.luau` builds the track and the knob from one block of metrics
(`switchTrackWidth/Height`, `switchKnobWidth/Height`, `switchInset`) and derives
the two resting positions from them (`switchKnobActive`, `switchKnobRest`), so
the "on" and "off" states are exact mirrors and the clearance at the parked end
equals the clearance above and below. `_animateIndicator` animates to those same
two values, and `_minWidth` reserves the track's width. The theme's sheen
overlay draws at ZIndex 1 and the knob at ZIndex 2: at equal ZIndex the sheen
used to land on top of the knob and wash its lower half. Pinned by
`scripts/toggle_switch_test.sh`; `scripts/toggle_preview.sh` renders both states
offline.

## Phase 1 audit summary

Audit covered every existing `.luau` file (68 source modules + entrypoint +
example + generated bundle). Findings:

| File | Responsibility | Problem | Action |
|---|---|---|---|
| `library_entrypoint.luau` | public API, exports, window lifecycle, anti-duplicate | mixes core singleton logic with API surface | KEEP (root) + delegate internals to `core/` and `settings/` |
| `Types.luau` | all public types | fine at root | KEEP (root) |
| `example.client.luau` | usage example | fine at root | KEEP (root) |
| `ui/window.luau` (2875 ln) | window class **plus** theme resolution, reveal/hide engine, element styling helpers, lock engine, connection lifecycle | doing many unrelated jobs | SPLIT: window → `components/window.luau`; theme resolution → `themes/init.luau`; reveal/styling/lock/connection helpers stay as Window methods (tightly coupled, single consumer graph) |
| `ui/action, chrome, drag, search, sidebar, tabSelector` | window furniture | belong with window | MOVE → `components/` |
| `ui/button … text` (19 files) | elements | fine | MOVE → `elements/` |
| `ui/notification, toast, popup` | window-level overlays | belong with window | MOVE → `components/` |
| `utilities/icons.luau` (10625 ln) | 6 icon packs + resolver | **the entire catalog loads eagerly** at startup via `constants`/`window` requires | SPLIT → `icons/` one module per pack, lazy-loaded and cached (Phase 6) |
| `utilities/image.luau` | image loading/assignment | UI-adjacent service | MOVE → `images/` (Phase 7) |
| `utilities/imageCache.luau` | disk/remote cache | duplicates cache layer concept | MOVE → `cache/imageCache.luau` |
| `utilities/windowIcons.luau` | built-in icon registry | images domain | MOVE → `images/windowIcons.luau` |
| `utilities/persistence*.luau` (5 files) | config + settings persistence | settings domain | settings split → `settings/persistence.luau`; config split stays in `utilities/` (it is window-config, not settings); shared atomic write stays in `utilities/persistenceWrite.luau` |
| `utilities/variables.luau` | runtime singletons (services, fs manager, font manager) | shared state | MERGE into `core/state.luau` |
| `utilities/runtime.luau` | service singletons | shared state | MERGE into `core/state.luau` |
| `utilities/constants.luau` | static constants | fine as constants | MOVE → `utilities/constants.luau` (KEEP, window icon refs come from `images/windowIcons`) |
| `utilities/functions.luau` | re-export shim | thin wrapper | SPLIT → `functions/` real modules; shim retained for API compat (Phase 8) |
| `utilities/colors.luau`, `textMetrics.luau`, `flagNames.luau` | generic helpers | fine | MOVE → `functions/` |
| `utilities/locale.luau`, `log.luau`, `path.luau`, `enums.luau`, `ordering.luau`, `moveable.luau`, `lockable.luau`, `layouts.luau`, `windowSizing.luau`, `HapticEngine.luau`, `odometer.luau` | small focused helpers | fine | KEEP in `utilities/` |
| `utilities/filesystem.luau`, `filesystemManager.luau`, `assetResolver.luau`, `network.luau`, `services.luau` | platform/filesystem layer | fine | KEEP in `utilities/` |
| `themes/*.luau` (6) | theme tables | fine | KEEP + add `themes/init.luau` (resolution engine extracted from window) |
| `version-1.luau` | generated Wax bundle | artifact | REGENERATE with project's generator (Phase 11) |

Dependency direction (Phase 2), enforced and verified:

```
library_entrypoint → core → components → elements → functions/cache/settings/utilities
```

No module outside `core/` requires `core/state` upward; `functions/`, `cache/`,
`images/`, `icons/` never require UI modules. The two-way edges that existed
(window ⇄ tab ⇄ group ⇄ element) are **preserved as-is** because they are the
existing public behavior (elements require their tab/window instances at
runtime, modules resolve peers lazily through `require(script.Parent[name])`).

## Target structure

See repository tree. `core/init.luau` is the small core service entrypoint,
`core/state.luau` holds shared runtime state, `core/registry.luau` the internal
module registry, `core/loader.luau` controlled lazy loading. `settings/` is an
internal configuration system (registry → defaults → manager → persistence)
consumed by the window UI; it is not a UI element itself.

## Phase 6 icon architecture

- `icons/init.luau` — public API surface (`get`, `resolve`, `getByPack`,
  `list`, `packs`, `count`, `isPack`, `priority`, `loaded`, `refreshCustom`,
  pack name constants) — API-compatible with the old `utilities/icons.luau`.
- Lookup rules: a bare name walks `PACK_ORDER` (lucide, material, tabler,
  phosphor, heroicons, feather) and stops at the first pack that has it;
  `"pack:name"` and the `pack` argument are strict (an explicit pack is never
  overruled by the order, which is what the profile card's alias chain
  depends on); names and pack names are case-sensitive and never corrected.
- Custom assets are a folder (`custom_asset/`), read once with `listfiles`
  and looked up by key (probe fallback with memoised misses where the
  executor has no listing), subfolders allowed, one `getcustomasset` per used
  path; `refreshCustom()` re-reads it.
- `icons/lucide.luau`, `icons/material.luau`, … — one module per pack, each a
  pure data table. Packs are required lazily: the catalog loads on first
  lookup for that pack, then stays cached (module-level require cache).
- No icon data is loaded during Astra startup unless a window actually
  resolves an icon from a pack. Window chrome uses asset IDs from
  `images/windowIcons.luau` and never touches the packs.
- `Icons.lucide` etc. remain accessible through lazy metatables so existing
  direct table access (`Astra.Icons.lucide`) keeps working, but each access
  loads only that pack.

## Phase 10 startup notes

Eager startup graph before refactor: entrypoint + Types + variables(+runtime,
services, filesystemManager, assetResolver, fontManager, constants,
windowIcons) + image(+imageCache) + locale + constants + icons (all 10.6k
lines) + persistenceSettings (+filesystem, paths, write, enums).

After refactor: identical behavior, but `icons/` is out of the eager graph —
icon packs load only on first pack lookup. `themes/init.luau` only requires
`default.luau` eagerly; other themes load on demand by name. Everything else
keeps its original load timing. No waits, safety checks, or features were
removed.

## Validation performed

1. `luau` syntax compile of every module (63/63 pass) — see validation notes.
2. `require()` path audit: every require resolves to an existing file.
3. Cycle check over the module graph.
4. Public API preserved: `library_entrypoint` exports unchanged, element
   classes keep `new/_setShown/_refreshTheme/...` contracts, `astra.Icons`
   surface unchanged, persistence + settings behavior unchanged.
5. Bundle regenerated from source and verified: module set complete, no
   duplicate implementations, standalone loader contract intact.
6. Bundle equivalence audit (`scripts/verify_bundle_equivalence.py` +
   `scripts/triage_bundle_diff.py`): every module body from the pre-refactor
   monolith is accounted for in the regenerated bundle. 58/69 bodies are
   byte-identical after require-path canonicalization; the remaining 11 are
   the documented intentional transformations:
   - entrypoint (old[2]): core/settings service wiring, settings-backed
     antiWindowDuplicate read, `astra.Core`/`astra.Settings` additions
   - chrome (old[15]): hide-transition generation guard (pre-existing fix,
     carried into components/chrome.luau)
   - sidebar (old[30]): profile rebuild generation guard + collapsedSidebar
     handling (pre-existing fix from 6db1e08, carried over)
   - window (old[40]): theme helpers delegate to `themes/init.luau`
   - functions shim (old[51]): comment + real-module requires
   - icons split (old[52]): catalog split into per-pack data modules
   - layout defaults (old[55]): `profileHeight = 48` constant addition
   - log (old[58]): inlined secure-mode source to keep `log` a leaf module
   - runtime/variables merge (old[69], old[72]): superseded by `core/state.luau`
   - vendored wax (old[74]): formatting/line-offset realignment only

## Runtime fix: avatar generation marker

The 6db1e08 sidebar fix stored its per-build generation marker directly on the
avatar ImageLabel (`window.profileAvatar._profileGeneration = ...`). Roblox
instances reject unknown members, so the first bundle that shipped that code
crashed in CreateWindow with "_profileGeneration is not a valid member of
ImageLabel" (the pre-refactor bundle predated that commit, which is why it
never surfaced there). The marker now lives in a weak-keyed side table
(`avatarGenerations`) in components/sidebar.luau; the stale-callback guard
behavior is unchanged. `scripts/check_instance_fields.py` lints this entire
bug class (custom-field writes on values created via `:Create` /
`Instance.new`).

## Rojo/Wax init-folder semantics (late fix)

A folder with an `init.luau` file syncs as a single ModuleScript — the init
file IS the folder's module, and sibling files become its children. Three
consequences were caught and fixed during final verification:

1. Init files (`core`, `settings`, `cache`, `functions`, `images`, `icons`,
   `themes`) required siblings via `script.Parent.<name>`; corrected to
   `script.<name>` (and `themes/init.luau` now uses `local themesFolder = script`).
2. `components/window.luau` held the themes Instance directly instead of
   requiring the module; corrected to `require(script.Parent.Parent.themes)`.
3. The bundle generator (`scripts/generate_bundle.js`) emitted init-folders as
   Folders with a phantom `init` child; it now emits them as ModuleScripts
   whose closure is the init file, with real siblings as children.

A migration typo (`utility.Parent.Parent.core.state`, one `.Parent` too many,
in 21 component/element files) was also corrected to
`utility.Parent.core.state` and both validation scripts
(`scripts/check_requires.py`, `scripts/eager_graph.py`) were upgraded to model
alias chains and init-file `script` anchoring, so this class of bug can no
longer pass the audit.

## Bundle regeneration (final)

`node scripts/generate_bundle.js` rebuilt `version-1.luau` from the modular
tree: 91 module closures + 5 folders (assets, components, elements,
utilities, root) = 96 refIds with no gaps, LineOffsets aligned 1:1 with
closures, zero occurrences of the pre-fix require patterns, and the standalone
loader contract (`return LoadScript(MainModule)`) intact.
