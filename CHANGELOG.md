# Changelog

Dated entries, newest first. Each entry explains the cause and the behaviour
change, then names the files it touched.

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
