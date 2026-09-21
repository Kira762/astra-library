# Changelog

Dated entries, newest first. Each entry explains the cause and the behaviour
change, then names the files it touched.

## 2026-09-21 — Anti Duplicate Window no longer unloads a window mid-construction

The spam-execute guard destroyed the previous window the moment a new
`CreateWindow` claimed the slot. Construction yields at pacing checkpoints,
so a re-executed script could land while the previous one's constructors
were suspended at one of those checkpoints — or had built half an element —
and the destroy pulled the tree out from under them: the resumed checkpoint
asserted ("Window unloaded during construction"), and a constructor that had
yielded mid-element then wrote into instances that were already destroyed.

Destruction of a replaced window now never interrupts active construction:

- A window with a constructor thread suspended at a checkpoint is marked
  unloaded and vanishes from the screen at once, but its tree is only
  destroyed once that construction has gone quiet (two consecutive frames
  with no suspended checkpoint and no pacing activity).
- A window overtaken while still inside `Window.new` is marked superseded
  instead of being unloaded on the spot: the host that received it keeps
  adding controls to a live window, the window is never shown, and it
  unloads once its construction goes quiet.
- Constructors that still outlive the destruction finish harmlessly instead
  of crashing: pacing checkpoints on an unloaded window neither yield nor
  assert, and `Window:Create` builds into a detached throwaway container
  instead of the destroyed tree (a repeat `Unload` clears the container).
- A configuration load stops applying values once the window is unloaded,
  and `Tab:Select` becomes a no-op on an unloaded window, so a superseded
  script's final selection call cannot write into destroyed chrome.

- `components/window/teardown.luau` — two-phase unload: the soft half
  (unloaded flag, off-screen, queues stopped) runs at once; `_destroyTree`
  runs immediately or, while `_constructionBusy > 0`, via
  `_destroyWhenConstructionQuiet`.
- `components/window/startup.luau` — `_paceBudget` and `_loadCheckpoint`
  never pace or assert on an unloaded window.
- `components/window/theme.luau` — `Window:Create` detaches post-unload
  construction into a per-window graveyard container.
- `library_entrypoint.luau` — an overtaken construction marks its window
  `_superseded`; the reveal thread unloads it at quiet instead of the old
  synchronous unload.
- `utilities/persistenceConfig.luau` — the apply loop stops on an unloaded
  window.
- `elements/tab.luau` — `Tab:Select` bails out on an unloaded window like
  the other runtime APIs, so a superseded script's final selection call
  cannot write into destroyed chrome.
- `scripts/anti_duplicate_window_test.luau` — regression coverage for
  replacing a window while a host thread is suspended at a checkpoint and
  for overtaking a construction mid-`Window.new` whose host keeps adding
  elements.
- `scripts/startup_test.luau` — the in-flight-builder case now expects the
  builder to finish detached and error-free instead of being stopped.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — Anti Duplicate Window survives spam-execute

The guard only remembered the last *finished* window, and only one of them.
`Window.new` yields at construction checkpoints, so executing the script again
while the previous shell was still building saw an empty store, created another
window, and never unloaded the one that was still in flight. Rapid re-entry
left duplicate windows on screen.

`CreateWindow` now claims a generation token in the `getgenv()` store before
construction can yield, tracks every live window (not just the last one),
unloads every replaceable predecessor immediately, and unloads itself if a
later claim overtook it while it was still building. Per-window opt-out
(`settings.antiWindowDuplicate = false`) and the persisted setting still
disable the guard.

- `library_entrypoint.luau` — generation token, live-window list, post-construction self-unload.
- `scripts/anti_duplicate_window_test.luau`, `scripts/anti_duplicate_window_test.sh` — sequential replace, opt-out, and overlapping re-entry.
- `MODULES.md` — documents the race-safe guard.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — A corner scale: the UI is no longer square

Every radius the library shipped was zero. The three theme tokens
(`CornerRoundness`, `ElementCornerRadius`, `PillCornerRadius`) were all
`UDim.new(0, 0)` in `themes/default.luau`, no other theme overrode them, and
eleven more surfaces baked `UDim.new(0, 0)` into their own `UICorner` — so 34
of the 35 corner sites in the tree drew a hard 90-degree edge. The one exception
was the dropdown's option rows, which rounded at 12px/7px inside an otherwise
square UI. The switch's own metrics comment already called the track and knob
"pills", and the drag handle's called itself "the pill in the reference
screenshot"; neither was round.

The library now works on three nested tiers, each one step inside the tier above
so the arcs stay concentric instead of fighting:

- **12px `CornerRoundness`** — the shell. The window silhouette and the three
  bands that mirror its corners (topbar top pair, rail bottom-left, elements
  bottom-right), the bottom fade, notifications and popups.
- **8px `ElementCornerRadius`** — everything inside the shell: element cards,
  field boxes, hover overlays, lock scrims, tab rows, dropdown panels, tooltips,
  the search bar, popup buttons and the About card's tiles.
- **32px `PillCornerRadius`** — the folded states. Half the 64px chrome height,
  so the minimised bar reads as a full pill; the 50px capsule clamps to its own
  half-height and comes out a pill too (a circle in the icon-only size).

Controls whose shape is inherently round derive a half-height radius from their
own metrics rather than reading a token, so no theme can square them off: the
switch (11px track, 9px knob), the slider (7px track and fill, 10px handle), the
drag pill (1.5px on a 3px bar) and the unread dot (a 4px circle on an 8px
badge). The dropdown's row tiers are now read from the theme — the outer tier is
the panel's own `ElementCornerRadius`, because the rows sit 6px inside the panel
that clips them, so a row's arc lands inside the clip instead of being cut by it
— with the seam where two rows meet 4px below it. Its search field rounds at 6px
and the multi-select checkbox at a quarter of its 12px box.

All eleven baked zeros are gone: the surfaces that belong to a family now bind
to that family's token, so `ChangeTheme` restyles them too.

- `themes/default.luau` — the three tokens, with the scale written down beside
  them.
- `utilities/layouts.luau` — `rowCornerRadius` 0 -> 8 (the rail's rows are inset
  chips, not full-bleed bands).
- `elements/toggle.luau`, `elements/slider.luau`, `components/drag.luau`,
  `components/action.luau` — geometry-derived pill/circle radii, with the
  metrics named (`handleThickness`, `trackSize`, `badgeSize`) instead of inline.
- `elements/dropdown.luau` — `rowTiers(window)` replaces the baked 12/7
  constants; `rowInset` names the 6px the rows were already inset; the search
  field and checkbox round.
- `components/search.luau`, `components/tooltip.luau`, `components/popup.luau` —
  bound to `ElementCornerRadius`; the dead `buttonCorner` local is gone.
- `scripts/dropdown_rows_test.luau` — D3 reads both tiers from the theme instead
  of pinning 12 and 7.
- `USAGE.md`, `MODULES.md`, `README.md` — the corner scale, documented where a
  host writing a custom theme table will look for it.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — Compact About rows and working changelog entry point

The About card's original width-aware packing treated its three status items as
large standalone cards. At the normal sidebar width, Version and Build occupied
the first line while Author wrapped into an oversized full-width tile below.
Those inset tiles also used `WindowColor`, making them much darker than the
surrounding element UI. The demo's **View Changelog** action only raised a
notification, and the Isolated header listened to `GuiButton.Activated`, which
some executor input bridges do not forward.

About data tiles are now a compact 48px status line with smaller 28px badges,
8px insets/gaps and compact label/value type. One to three tiles divide that
single line evenly, so the standard Version / Build / Author set remains three
columns and never leaves one row below the others. Tiles and the action band now
use `ElementSurface` with the existing element stroke rather than the dark
window gradient. Theme changes continue to update those fills.

Isolated headers now use `MouseButton1Click`, matching Astra's other full-row
controls while retaining touch-tap support. Both published examples wire the
About action to the actual Isolated handle: tapping it expands the changelog and
scrolls its header into view instead of showing a dead-end notification.

- `elements/aboutCard.luau`, `elements/isolated.luau` — compact single-line data
  geometry, regular element fills and the reliable Isolated click signal.
- `example.client.luau`, `skills/astra/assets/example-window.luau` — action to
  Isolated expansion and scrolling.
- `scripts/about_card_test.luau`, `scripts/isolated_test.luau` — compact geometry,
  surface/theme and primary-click regression coverage.
- `USAGE.md`, `MODULES.md`, and the Astra skill docs — updated behavior and
  examples; `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — About card

The Settings → About tab was three prose Text cards that described the library
in the abstract, and there was no element a host could use to build the card the
design reference actually shows: a brand header, a row of data tiles, a
description paragraph and a changelog entry point, all in one container. Every
host that wanted that page had to assemble it out of Text, Stat and Isolated
children and keep the geometry in step by hand.

`tab:CreateAboutCard({ ... })` adds the card as one reusable, configurable
element. `elements/aboutCard.luau` builds four blocks from a single props table:
a header (leading icon, title, subtitle), one to three data rows (each a badge
icon with a label above its value), a wrapped description paragraph, and an
optional trailing action band carrying an icon, a label, a subtitle and the
card's built-in chevron. Surfaces stay inside the shared theme tokens — the card
is the standard element body, a tile and the band use the window surface with
the element corner and stroke, a badge uses the content surface — so the card
themes itself like every other element.

The tiles are packed against the width the card actually has: as many rows as
fit share one line (split evenly, gaps out of the slice) and the rest wrap
underneath at full width, so a narrow window stacks them instead of truncating
their values and a wide one puts them side by side. A fourth row is refused at
construction with
`Astra:CreateAboutCard — at most 3 data rows are supported, got N`: the action
band is the card's trailing row. Optional parts drop out of the layout rather
than rendering blank (a row without an icon loses its badge; a card without
rows, description or action simply has fewer blocks). Reveal, hide and theme
passes run over one tracked part list, so every label, glyph and stroke moves
together and a `ChangeTheme` re-reads all of them.

- `elements/aboutCard.luau` — new element (`__type = "AboutCard"`), with
  `SetTitle`, `SetSubtitle`, `SetIcon`, `SetRow(index, row)` and
  `SetDescription` setters plus the move and lock API. The action band is the
  card's only tappable surface: a tap anywhere on it fires `callback` once, with
  a haptic click, and the trailing chevron is fixed with no setter.
- `elements/tab.luau` — `tab:CreateAboutCard(props)`, tab-only like
  `CreateIsolated` and `CreateChangelog`.
- `components/settings.luau` — the About tab now renders one About card
  (the Astra mark, `Version` / `Build` / `Author` rows and the description
  paragraph) from the module's `aboutVersion`, `aboutBuild` and `aboutAuthor`
  strings, which a release bumps. The card's action band is left off there
  because the tab has no changelog to open.
- `Types.luau`, `library_entrypoint.luau` — `AboutCardProps`, `AboutCardRow`,
  `AboutCardAction` and the `AboutCard` handle type, plus `CreateAboutCard` on
  the `Tab` type.
- `scripts/about_card_test.luau`, `scripts/about_card_test.sh` — runtime test
  covering the header recipe, the row packing (one line when the tiles fit, the
  wrap when they do not, and the "no tile below its own copy" invariant across
  widths), the four-row guard, the description, the action band and its tap, the
  setters, the reveal/hide and theme passes, and the lock.
- Docs: `USAGE.md` (About card section), `MODULES.md` (module entry and the
  Settings About builder), `README.md` (element list), and the published skill's
  `SKILL.md` cheat sheet and `references/elements.md`. `example.client.luau` and
  `skills/astra/assets/example-window.luau` build the card end to end.
