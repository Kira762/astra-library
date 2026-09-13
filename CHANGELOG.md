# Changelog

All notable changes to Astra v1. Dates use 2026.

## 2026-09-13 — Profile card: window-backed surface, copy feedback, Job ID row, tier icon fix

- **The card's background is the window's background, not a lookalike.**
  `Window:StyleWindowSurface(frame)` now owns the window's own surface — base
  colour, the `WindowColor` theme token, gradient rotation/offset and the
  opacity the frame shows at — and both the window frame and the card's plate
  are built through it, so there is one definition instead of two copies that
  can drift. The card is the window's height and top-aligned with it, so the
  shared gradient also lands on the same shade at the same row: a theme change
  and the theme's live gradient animation (`LiveAnimation`) move the two
  together, and the plate now fades with the window on show/hide instead of
  sitting solid beside a half-faded frame. A card rebuilt mid-animation picks
  up the window's current gradient state.
- **Copy buttons confirm in words as well as in the icon.** The press still
  writes through the executor clipboard and swaps the glyph for the green
  `Success` check for ~1.2s; the button now also carries its own accessible
  label and hover tooltip — "Copy Place ID" / "Copy Job ID" / "Copy User ID"
  while idle, "Copied" while the check is up — both resolved through the locale
  layer. A repeat press cancels the pending restore and restarts the flash, so
  one button never has two timers racing for its icon.
- **The server row is labelled "Job ID".** The value is `DataModel.JobId`, so
  the row, its copy label and the tooltips say so; `window.profileServerIdValue`
  and the `ServerId` row name are unchanged for hosts and saved state.
- **The tier pill's icon renders in every icon pack.** The pill asked for
  lucide-only names, so FREEMIUM drew a word with a blank square beside it on
  every other pack and PREMIUM lost its crown on heroicons/feather/material. The
  card now resolves its icons against the window's active pack (crown, else
  star; badge-check, else check-badge / seal-check / verified, else award), and
  every other icon on the card resolves the same way. The default pack's icons
  are unchanged.
- Suites: the new `scripts/profile_ui_test.sh` pins all four (window-matched
  surface, copy feedback and its timer, the `Job ID` wording and the absence of
  "Server ID", and the tier icon on all six packs in both states).

## 2026-09-12 — Profile card: window-matched styling, real game name, tier pill, clipboard feedback

- **The card now speaks the window's visual language verbatim.** Section
  plates are built with `Window:StyleElementBody` — the same `ElementGradient`
  body, `ElementCornerRadius` and `ElementStroke` (at `ElementStrokeTransparency`)
  every window element uses — instead of flat `CardSurface` boxes with a faded
  hairline. Headings are the Section element's own look (16px `ContentColor`
  icon at 0.65 beside a 15px `ContentColor` title at 0.6, normal case:
  `Account`, `Current Game`, `Server`, `User Session`), rows reuse the element
  text colour (`ContentColor` icons/labels/values, labels muted at 0.45) and
  the `@username` line uses the window's secondary-text treatment
  (`TitlingColor` at 0.7). The game thumbnail's ring is the element stroke too.
- **The game name is the real one.** The card follows Roblox's official
  two-step flow — `apis.roblox.com/universes/v1/places/{PlaceId}/universe`
  converts the place id to its universe id, then
  `games.roblox.com/v1/games?universeIds={UniverseId}` supplies the `name`
  field — with per-place caching and in-flight queuing, so `DataModel.Name`
  (the current place's title) only fills the label until the platform
  answers. The same universe resolution (`DataModel.GameId` first, official
  lookup second) now feeds the thumbnail fetch.
- **Copy actions use the executor clipboard and confirm visually.** Every
  identifier row (User ID, Place ID, Server ID, Key) carries a COPY button
  that writes through `setclipboard` (with the common executor aliases and a
  `Clipboard` table as fallbacks); a successful copy swaps the icon to a
  green `Success` check for ~1.2s and then returns to the copy icon. Buttons
  stay hidden while their value is masked, and a missing/failing clipboard
  function means no feedback rather than a false success.
- **The tier pill is always present.** It reads the host's `tier` from
  `Window:SetProfile` (uppercased) or falls back to PREMIUM / FREEMIUM from
  `MembershipType`, so a free account is labelled instead of undecorated.
  PREMIUM keeps the accent crown; other tiers read muted with a
  `badge-check` icon, and the pill width re-measures itself from its word.
- **Removed from the card:** the settings gear and its `_toggleSettingsMode`
  action (the topbar gear is now the only settings entry point), the SERVER
  UPTIME row (`workspace.DistributedGameTime`), and the FRIENDS / FOLLOWERS
  rows together with their friends-endpoint fetch. The header's name and
  subtitle reclaim the width the gear used to reserve.
- **Verification:** `profile_details_test` now asserts the element-body
  plates (gradient/corner/stroke tokens), Section-style headings, the
  element row colours, the always-present tier pill (PREMIUM, FREEMIUM and a
  host override) and the clipboard flash cycle (E7/E8); `profile_compact_test`
  asserts the removed rows/gear are gone; `sidebar_tab_sizing_test` drops its
  gear expectation. The offline preview (`scripts/profile_panel_preview.sh`)
  re-renders both card states.

## 2026-09-12 — Compact profile card: exactly the window's height (240x420)

- **The profile card is now 240px wide x 420px high** — slimmer, and exactly
  the default window's height, so the window + 12px gap + card pair reads as
  one centred unit. No information was removed: the avatar, display name,
  username, PREMIUM badge, user ID + COPY, join date / account age, friends,
  followers, current game (icon, name, place ID) and the settings gear all
  remain. The interior is compacted instead — 12px horizontal padding (was
  16), a 56px avatar (was 72), tightened gaps between every row, a 48px game
  card (was 56, with a 32px thumbnail), reduced bottom spacing, and 13px
  value text so nothing wraps, overlaps or clips in the narrower card.
- **All dependent geometry follows the constants**: the room check
  (`hasRoom`), the pair clamp (`pairHalfSize`), the off-centre rest
  (`shiftFor` is now `(240 + 12) / 2 = 126px`), the side placement in
  `layout`, the recenter paths and the cramped-viewport notification
  (now "240px beside the window and 420px of height") — everything reads
  `profilePanel.width` / `profilePanel.height`, so the 240/12/420 dimensions
  apply to centring, screen bounds, visibility and the saved-settings
  normalisation alike.
- **Toggle behaviour is unchanged and re-verified**: "Show profile" shows
  the card on the selected side and centres the pair as one group, hiding it
  recentres the window alone; "Reveal profile details" is still refused
  while "Show profile" is off (setting off, switch rolled back, "Show
  profile is required" notification), and turning "Show profile" off — or
  loading a stale configuration — clears an active reveal and re-masks the
  display name, username, user ID and place ID.
- **Verification:** new runtime suite `scripts/profile_compact_test.sh`
  (+ `profile_compact_test.luau`, D1–D8) covers the exact 240x420
  dimensions, the preserved 12px gap, right- and left-side placement,
  field completeness, no clipping/overlap, the "Show profile" show/centre/
  hide/recentre cycle from a dragged position, the full reveal dependency
  (refusal + notification, auto-clear + remasking), stale saved
  configuration normalisation through `Window:LoadSettings`, and viewport
  changes (responsive window resize, card stays attached and centred,
  portrait viewports hide the card). `profile_centering_test` and
  `sidebar_tab_sizing_test` now assert the 240/420 geometry;
  `profile_reveal_test` and the smoke test are unchanged and still pass.

## 2026-09-12 — Window + profile card centre as one unit, and "Reveal profile details" now requires "Show profile"

- **The window and its profile card are auto-centred together, and both are
  kept in view.** The pair was already meant to rest centred (window + 12px
  gap + card, so the window sits 146px off the screen centre), but three
  paths showed it un-centred or let the card hang off the screen:
  - `_firstShow` showed the frame wherever the build had left it. A window
    built before `Players.LocalPlayer` exists is built with the card
    disabled, so it rests at the plain centre; when the player turns up
    before the deferred first show, the card appears and nothing re-centred
    it (the late-player waiter bails because the player is already there,
    and a recenter that runs while the window is hidden only parks
    `_restorePosition`). The first show now re-derives the resting centre
    while the frame is still at its anchored `0.5/0.5` spot.
  - `_quickRestore` fell back to `UDim2.new(0.5, 0, 0.5, 0)` and trusted a
    `_restorePosition` recorded before the panel state changed. An anchored
    restore is now re-derived from `_profileCenterPosition()`, and the
    restore re-clamps after `_fadeSurfaces` brings the card back.
  - "Keep window on screen" clamped the window alone, so a drag — or a
    capsule dragged into a corner and expanded — could leave the card off
    the edge while the window itself stayed legal. The clamp, and the topbar
    drag that shares its math, now measure the pair through the new
    `profilePanel.pairHalfSize(window, width?, height?)`: the card's side
    gains `280 + 12`px and the vertical half-extent becomes
    `max(windowHeight / 2, 250)`, because the 500px card out-talls a short
    window. `pairHalfSize` asks the new `profilePanel.isShown(window)`
    (enabled *and* the window visible), so a minimised capsule is not shoved
    around by a card that is not there, and `ToggleMinimise`'s expand
    re-clamps once the card is visible again.
  A position the user dragged to is still respected — the re-centring only
  fires while the frame is at its anchored resting spot — and
  **Reset Window Position** remains the explicit way back to the centre.
- **"Reveal profile details" is refused while "Show profile" is off.** The
  toggle unmasks the display name, username, user ID and place ID *on the
  card*, so with the card off it was an active switch over nothing, and it
  would silently unmask identity data the moment the card came back.
  `profilePanel.setReveal(window, enabled)` is now the single driver:
  flipping the toggle on without the card keeps `showFullUsername` off,
  re-masks the card, raises a **"Show profile is required"** notification
  explaining the dependency, and returns `false` so the settings row rolls
  its switch back (silently — the work is already done). The switch is only
  accepted once "Show profile" is on.
- **The dependency holds in both directions and across saves.** Turning
  "Show profile" off switches an active reveal off with it
  (`profilePanel.setEnabled` clears it, says why in a notification and
  returns `revealCleared` so the row rolls back), and `Window:LoadSettings`
  runs the new `profilePanel.syncReveal(window)` so a settings file written
  before this rule — or edited by hand — cannot come back with reveal = on
  and the card off. `profilePanel.revealAllowed(window)` is the predicate
  both paths share, and `settings/registry.luau` records the dependency on
  the `showFullUsername` definition. Both rows' descriptions in
  Settings → Appearance now state it.
- **Verification:** new runtime suite `scripts/profile_centering_test.sh`
  (+ `profile_centering_test.luau`, C1–C6) covers the pair's resting centre
  (both edges symmetric about the screen centre, card flush with the window
  and vertically centred on it), the late-player first show, hide/show round
  trips including a dragged position being left alone, the pair-aware clamp
  with the card on either side, the card-off fallback to the plain window
  clamp, and the expand re-clamp. `scripts/profile_reveal_test.luau` gains P7
  for the refused / accepted / cleared reveal dependency and its
  notifications. Each was checked against a deliberately broken build (the
  first-show recenter removed, the clamp reverted to the window's own
  halves, the expand re-clamp removed, `revealAllowed` stubbed to `true`) to
  confirm the assertions actually fail. `smoke_test_bundle.sh`,
  `sidebar_tab_sizing_test.sh`, `check_requires.py` and
  `check_instance_fields.py` all pass under the Luau CLI 0.738, and the
  bundle is regenerated (100 modules).

## 2026-09-12 — Profile card: fixed the card that never appeared + one reveal toggle for every identity field

- **Fixed: the profile card stayed invisible even with "Show profile" on.**
  A window built before `Players.LocalPlayer` exists parks a RenderStepped
  waiter that fills the card in and fades it up when the player turns up.
  That waiter died twice over: it was registered with
  `self:Connect(connection)` — `Window:Connect` takes a *signal* and calls
  `:Connect` on it, so passing an existing connection threw
  (`attempt to call missing method 'Connect' of table`) — and, inside the
  callback, `profilePanel.refreshName` called `sidebar.mask_username`,
  which does not exist (the helper is `sidebar.maskUsername`), throwing
  `attempt to call a nil value` on every frame before `setShown` ran. Both
  are gone: the connection is adopted into `self.connections` directly and
  the mask call is fixed.
- **Changed: "Reveal full username" is now "Reveal profile details" and
  drives all four identifying values on the card** — display name
  (headline), `@username` (subtitle), user ID (ACCOUNT DETAILS) and place
  ID (CURRENT GAME). Off masks everything: names through the existing
  `sidebar.maskUsername` (`Tes****`), the two IDs as a fixed-width
  `••••••` block so neither value nor length leaks. The persisted key
  stays `showFullUsername`, so saved settings keep working; only the label,
  the description and the registry wording changed.
- **New `profilePanel.applyIdentity(window)`** is the single writer for
  those fields (plus `profilePanel.revealEnabled(window)`), called at the
  end of `build`, by the toggle and by the late-player waiter.
  `refreshName` is kept as an alias and `setSubtitle` routes through it, so
  no public signature changed. New instance handles:
  `window.profileUserIdValue`, `window.profileCopyUserId`,
  `window.profilePlaceId`.
- **Fixed: the card used to show the display name unmasked.** `build` wrote
  `player.DisplayName` straight into the headline and nothing masked it
  unless the late-player waiter happened to run, while the user ID and
  place ID were baked in at full length regardless of the toggle. The
  headline is now created empty and filled by `applyIdentity`, so the first
  frame already respects the setting.
- **The user ID's COPY action follows the reveal state:** hidden while the
  ID is masked, and the callback refuses to copy a masked value (it reads
  `state.localPlayer` at click time rather than the player captured at
  build). An explicit `Window:SetProfile` subtitle is developer copy, not
  identity data, so the toggle leaves it alone; `SetProfile(nil)` restores
  the generated `@username` line.
- **"Show profile" now explains itself when the card cannot fit.** The card
  is gated on screen room (280px beside the window, 500px of height) as
  well as on the toggle, so a cramped viewport used to leave an active
  toggle and no card. `profilePanel.setEnabled` raises a notification with
  the reason when the player is known but `hasRoom` fails (a missing player
  is still handled silently by the late-player waiter).
- **Verification:** new runtime suite `scripts/profile_reveal_test.sh`
  (+ `profile_reveal_test.luau`) covers the masked default, the toggle
  revealing/re-masking all four fields, custom-subtitle precedence, the
  late-player regression (card appears once the player turns up) and the
  no-room notification. Ran green
  under a locally built Luau CLI 0.738 — the earlier entries could not run
  the runtime suites at all; `smoke_test_bundle.sh`,
  `sidebar_tab_sizing_test.sh` (T15 extended to the masked subtitle),
  `check_requires.py` and `check_instance_fields.py` all pass, and the
  bundle is regenerated (100 modules).

## 2026-09-12 — Profile panel: fixed card layout per the design mock

- **The panel is now a content-sized card (280x500) instead of a full-window-height
  strip.** It rests vertically centred beside the window, and its interior stacks
  top-to-bottom in one flow so nothing can overlap at any window size: 72px avatar
  with presence dot, centred display name, centred @username, centred PREMIUM
  badge, divider, ACCOUNT DETAILS (User ID with the COPY action on the value row,
  Join date with account age, Friends / Followers on their own rows), divider,
  CURRENT GAME card, and the bottom-pinned settings gear.
- **Four rendering bugs from the reverted layout are gone.** The card surface is
  actually visible now (it was created with `BackgroundTransparency = 1`, leaving
  the text floating over the 3D world); the name / subtitle no longer vertically
  centre into the details stack on tall windows; the PREMIUM badge no longer lands
  on the first divider; and the CURRENT GAME plate uses the dark `CardSurface`
  theme key instead of the light `ContentColor` text colour (the white box).
- **`hasRoom` now checks vertical room too** (the card's 500px height plus margins),
  and `layout` positions the fixed-size card centred on the window centre; the
  interior is static, so drags/resizes never reflow it.
- **Scope:** presentation only — no public API change; `setSubtitle`,
  `refreshName`, `setEnabled`, `setSide`, `setShown` keep their signatures.
- **Verification:** T15 in `scripts/sidebar_tab_sizing_test.luau` updated to the
  real geometry (280 wide / 12 gap / 500 tall, panel centred on the window centre);
  static require + instance-field checkers pass; bundle regenerated (100 modules).
  The runtime smoke/sizing suites need the Luau CLI, which this sandbox could not
  download (release-asset hosts are TLS-blocked), so they were not executed here.

## 2026-09-12 — Profile system: the profile panel beside the window

- **The profile now lives in a panel beside the window, not inside it.**
  New `components/profilePanel.luau` builds a 96px-wide companion card as a
  sibling of the window frame (same ScreenGui): 48px circular avatar
  (theme plate fallback + the existing `images.image.avatar` loading with a
  generation guard), 16px name (masked as before, or full via "Reveal full
  username"), optional 14px subtitle (`Window:SetProfile` keeps its
  signature), and a bottom-pinned settings gear that opens the settings
  screen (same behavior as the topbar gear, via a shared
  `Window:_toggleSettingsMode`). The panel wears the window's surface
  treatment (WindowColor gradient, corner roundness, SurfaceStroke stroke,
  ShadowColor shadow), has a subtle hover pill on the gear, and follows
  the window on drags/restores/resizes through Position/Size
  property-change signals — no per-frame loop.
- **The window recentres so the pair is even.** Window + 8px gap + panel are
  centred on screen as one unit: at rest the window sits 52px —
  (96+8)/2 — off the screen centre, on the opposite side of the panel, so
  neither side looks cramped. Applied on first show, by "Reset Window
  Position", and live (animated) when the panel is toggled or re-sided;
  while the window is hidden the remembered restore position is updated
  instead so the next restore lands centred.
- **New "Profile side" option (Right / Left)** in the Appearance settings,
  persisted with the existing `showProfile` / `showFullUsername` settings
  (`settings.profileSide`, default `"right"`).
- **The in-window profile variants are retired** (sidebar footer, topbar
  strip, collapsed avatar-only). The responsive rail no longer reserves its
  60px profile footer (tabs get that space back), the topbar loses its 48px
  profile strip, and the old `reflowProfile` mis-detection on
  content-sized rails disappears with the code.
- **Scope:** profile placement/presentation only — no new public API, no
  animation-system changes. The panel hides whenever the screen lacks
  horizontal room for window + gap + panel (e.g. a portrait phone) and
  shows again when there is room (wide phones in landscape included); it
  hides with hide/minimise/close.
- **Verification:** the sizing suite's new T15 section asserts the panel
  geometry (sibling of the frame, ±52px window shift, flush panel edge,
  full window height), name masking, `SetProfile` subtitle, rail footer
  release, live recentering on side flips and show/hide toggles, and the
  room-based visibility (portrait phone hidden, wide landscape phone
  shown + recentred, desktop restored). A behavior probe covers the gear
  → settings round trip, hide/restore, and minimise/restore. The harness
  stubs gained Roblox-faithful name-based child indexing and default
  instance Names. Bundle regenerated (100 modules).

## 2026-09-12 — Faster window startup: lazy settings content + deferred auto-show

- **Settings tab content is now built lazily.** `CreateWindow` previously
  built all six settings tabs *and* every one of their elements
  synchronously (~600 of the ~760 instances created at window
  construction, in the example layout). Window construction now creates
  only the tab shells (rows + pages); each tab's elements are created the
  first time that tab is opened (`Tab:Select` →
  `Window:_buildSettingsContent`, exactly once per tab, pcalled so one bad
  element can't take the window down). The visible behavior is
  unchanged — content exists the instant a settings tab is opened — but
  synchronous startup instance creation drops from 764 to 169 in the
  harness (the user's own tabs are unaffected).
- **The auto-show is deferred by one tick.** `CreateWindow` showed the
  window before the calling script could create its tabs, so the window
  appeared empty and then filled in. The show now happens in a
  `task.defer`: a script that builds its tabs synchronously finishes
  first, so the window appears once, fully populated. Scripts that yield
  are unaffected (the show lands one tick after creation), and an
  explicit `Hide()` before the tick cancels the auto-show.
- **Scope:** startup timing only — no visual, animation, or API changes
  (the opening animation and staggered element reveal are untouched).
  Icon/font preloading was already async and disk-cached, so first-run
  icon downloads were left alone.
- **Verification:** the sizing test now asserts lazy settings content
  (empty before first open, built on first open, built exactly once, full
  element counts per tab on the correct page) alongside the existing
  assertions; the harness measures 169 instances at `CreateWindow`
  (was 764). Bundle regenerated (99 modules).

## 2026-09-12 — Settings screen: rail order and empty Persistence tab

- **Opening Settings now highlights the first rail row.** The rail rows
  (and the content pages) are ordered by each tab's `customOrder`, but
  the About tab was created with `customOrder = 1000` — lower than
  General's `1001` — so About sorted to the top and the gear action
  (which always opens General) highlighted the **second** row. About now
  uses `1006`, after Persistence, so the rail reads General, Appearance,
  Behavior, Performance, Persistence, About.
- **The Persistence tab is no longer empty.** Its content (Configurations
  section, Saved Configurations dropdown, name input, Save/Load/Delete
  group) was gated behind `next(self.configuration) ~= nil`, which is only
  true when the window is created with a `configuration`
  prop (autoSave/autoLoad/fileName). Windows created without it — including
  the example client — got a blank tab. The content is now built like every
  other settings tab; config save/load already works without the prop
  (paths fall back to the window name), and the dropdown shows its
  "No saved configurations" placeholder when there is nothing saved.
- **Verification:** `scripts/sidebar_tab_sizing_test.sh` now asserts the
  settings rail order (General first, About last), that opening settings
  via the gear path selects General and shows General's page in the
  content area, and that the Persistence tab builds its content for a
  window created without a `configuration` prop. The test fails against
  the pre-change tree. Bundle regenerated (99 modules).

## 2026-09-12 — Responsive sidebar rail follows the longest tab name

- **The responsive sidebar (`Sidebar (Responsive)` bar layout) now sizes its
  rail from the tab names.** The longest visible row in the current rail
  group (tabs or settings tabs, whichever mode the rail shows) determines the
  group's natural width via the existing `functions.textWidth` measurement of
  the row title (icon + spacing + paddings + row insets included). The rail
  itself takes that width, and the rows keep their original full-rail,
  side-aligned size (`scale 1, offset -rowInset*2`) — so every tab in the
  rail is exactly as wide as the longest one, with no floating/centered rows.
- **The window's available space is the cap, not a constant.** Rail width is
  `min(longest natural width, floor(window width / 2))` — no new fixed pixel
  value, and the elements area always keeps at least half of the window.
  The existing `Sidebar.ApplyWidth` already gives the elements area
  `(1, -railWidth, ...)`, so it automatically takes back whatever space the
  rail frees. When a very long name would exceed the cap, the rows hold the
  available width and that title label is constrained to the remaining slot,
  where its existing `TextWrapped` keeps the name readable.
- **Narrow windows are unchanged:** below `railCollapseBelow` the rail still
  collapses to the icon-only width (`railCollapsedWidth`), and the rail is
  considered collapsed only while it is at that icon-only width (a
  content-sized rail below the old fixed 219px still shows titles).
- **The width is re-derived whenever the visible rail group or its inputs
  change:** tab create/remove, layout-mode switch, settings-mode toggle,
  viewport/rail width changes, locale changes (translated titles measure
  differently) and theme changes (title font).
- **Scope:** only the responsive sidebar path (`Window:_railWidth` /
  `Window:_applyContentRailWidth` in `components/window.luau`,
  `tabSelector.railContentWidth` + label wrap in
  `components/tabSelector.luau`, the collapsed check in
  `components/sidebar.luau`, and a re-derive hook in
  `elements/tab.luau`). The topbar layout's per-pill `AutomaticSize.X`
  sizing, the collapsed sidebar's fixed icon-only rail, all tab styles,
  animations, selection and scrolling behavior are untouched.
  `setRowCollapsed` additionally skips rows whose rail was already destroyed
  mid-layout-switch (a destroyed instance must not have properties written
  to it).
- **Verification:** new `scripts/sidebar_tab_sizing_test.sh` (Luau CLI
  harness with a mini Roblox environment, `sidebar_sizing_stubs.luau`)
  exercises the real bundle: identical short names, short/long mixes, one
  very long name (cap + wrapped title + elements keep half the window),
  multiple long names, narrow/wide window (collapse/expand round-trip),
  settings-mode rail, icon-less and `neglectSelector` tabs, locale changes,
  and confirms the topbar and collapsed-sidebar layouts keep their existing
  sizing. The test fails against the pre-change tree (negative control).
  Bundle regenerated (99 modules).

## 2026-09-11 — Window sizing: 600x420 default, fixed mobile profile

- **Default window size is now `600x420`** (was `720x600`) in both bar-layout
  profiles (`top`, `sidebar`) in `utilities/windowSizing.luau`. The responsive
  caps were rebalanced around the new default (`maxSize` 720x480 top /
  760x500 sidebar, `widthCompensation` 100 → 80); the minimum protections are
  unchanged (500x330 top, 540x360 sidebar). No other 720x600 default remains.
- **Desktop/PC stays responsive:** `windowSizing.fit` keeps the existing
  tiered viewport-occupancy fit, so a normal desktop targets exactly 600x420,
  smaller/shorter screens shrink responsively (width compensation kicks in on
  short viewports), and large/ultrawide screens stay capped instead of growing
  into an oversized window. The viewport watcher, `_applyWindowSize`,
  dragging/collapsing and the public API in `components/window.luau` are
  unchanged (comments only).
- **Mobile now uses a fixed size/profile:** touch-only devices (phones —
  `TouchEnabled` with no hardware keyboard) whose short side is below Astra's
  existing 700px phone breakpoint get a per-mode fixed profile instead of live
  occupancy math: `316x318` (top) / `331x280` (sidebar), derived from the
  existing phone-tier fit evaluated once at a 360x390 reference (narrowest
  mainstream phone width × the reference short side `scaleForViewport`
  documents), so the fixed window fits a phone in portrait and landscape
  without clipping. Rotation, the on-screen keyboard and inset changes no
  longer resize the window; tablets, desktops and narrow desktop viewports
  keep the responsive fit.
- **New helper:** `windowSizing.isMobileViewport(viewport)`. `UIScale`
  (`scaleForViewport`) is unchanged and still applied on both paths, so the
  fixed mobile window keeps its per-device perceived scale. Bundle
  regenerated (99 modules).

## 2026-09-11 — New themes (emerald, gold, crimson, onyx) + frost redesign

- **Four new built-in themes:** `emerald` (dark forest, green accent),
  `gold` (dark bronze, gold accent), `crimson` (dark maroon, red accent),
  `onyx` (near-black, monochrome silver accent). Each defines the full
  65-key surface (surfaces, strokes, text, gradients, slider/toggle/field
  styling); omitted keys inherit from the `default` clone in
  `themes/init.luau`.
- **`frost` redesigned (kept, not removed):** was a near-white light theme
  (WindowSurface 250,252,253) — too bright. Rebuilt as a dark "arctic night"
  palette: deep navy surfaces (16,21,28), bright ice-blue accent
  (86,197,235), ice tab-stroke gradient. Same key set, same theme name, so
  persisted `theme = "frost"` picks up the new look automatically.
- Theme registration updated in both places: the settings-UI theme table +
  dropdown options in `components/window.luau` (now 10 entries) and the
  persisted-theme whitelist in `utilities/persistenceSettings.luau`.
- All other themes (`default`, `amethyst`, `cobalt`, `ember`, `rose`)
  unchanged. Bundle regenerated (99 modules).

## 2026-09-11 — Changelog element, settings rebuild, multi-tab example (`d1339ec`)

- **New element — `Tab:CreateChangelog`:** scrollable release history with
  `+` (added) / `-` (removed) / `~` (changed) symbols in green/red/amber,
  entry fade-in, and `Set` / `Refresh` / `Add(entry, prepend?)` / `Clear`.
  Types added: `ChangelogEntry`, `ChangelogChange`, `ChangelogProps`,
  `Changelog`.
- **Built-in settings rebuilt:** the v1.1 settings card +
  `Window:AddSettingsTab` sub-tab API is retired. The window now builds six
  settings tabs (`Window:_buildSettingsUI`): **General** (keybind, cursor,
  welcome toast), **Appearance** (theme + Bar Layout pickers with popup
  confirm, profile, window position), **Behavior** (duplicate-window guard),
  **Performance** (haptics), **Persistence** (saved-config Save/Load/Delete,
  only when `configuration` is passed), **About**. The topbar gear action
  toggles a settings mode that shows only settings tabs; the `activeSubTab`
  registry key is retained and still persisted for compatibility.
- **`layouts/` folder:** per-mode bar-layout builders (`Topbar`, `Sidebar`,
  `SidebarCollapsed`) extracted from the window; `utilities/layouts.luau`
  dispatches (`get` / `implementation` / `railWidthFor`).
- **`CreateWindow` props extended:** `showName`, `showIcon`,
  `showIconOnly` (minimised capsule), `fallbackFont`, `translator`
  (PascalCase aliases accepted); element props gained `description` and
  `icon` across the board; `Progress` gained `steps` / `text` / `format` /
  `showValue` / `indeterminate` props and `Get` / `GetPercentage` /
  `Remove`; `Toast` gained `subtitleAbove` / `avatar` / `minWidth`;
  `Popup` gained `subtitle` / `icon` / `dismissable`; `Console` gained
  `Copy`; `Tag` gained `Set` / `SetColor` / `SetText` / `SetIcon` /
  `Remove`.
- **New window runtime helpers:** `Close()` (animated close → `Unload`,
  wired to the topbar Close action with a confirm popup), `Create`
  (instance factory with theme/locale binding), `Connect` / `ConnectFor` /
  `Disconnect` / `DisconnectMany`, `DestroySubtree` / `DestroySubtrees`,
  `CreateGlow`, `CreateHoverOverlay`, `StyleElementBody` /
  `StyleElementPanel`, `SaveSettings` / `LoadSettings`, `SetProfile`.
- **Entrypoint:** active-window / anti-duplicate guard now also backed by a
  `getgenv()`-backed global store (`__ASTRA_ACTIVE_WINDOW_V1`); in secure
  mode `CreateWindow` preloads window images (failure notification) and
  swaps in the brand fonts.
- **Icon resolution:** pack entries are repo-relative PNG paths under
  `assets/icons/<pack>-pack/`; `icons/init.luau` maps them onto the repo's
  raw-GitHub base URL at resolve time, honours an executor
  `getcustomasset` override, and passes numeric asset ids through.
- **Persistence facade:** new `utilities/persistence.luau` consolidates the
  config + settings persistence surface.
- **Example rewritten:** `example.client.luau` loads the bundle via
  `game:HttpGet` + `loadstring` and builds a 20-tab window (Home, Controls,
  Appearance, Information, Changelog, Updates + 15 labelled test tabs)
  exercising tags, every element, groups, and the new Changelog element.
- Bundle regenerated from the modular tree (includes `layouts/` and
  `elements/changelog.luau`).

## 2026-09-06 — Settings card ColorSequence crash fix (`2ecd628`)

Opening the Settings tab crashed the window:
`Unable to assign property BackgroundColor3. Color3 expected, got ColorSequence`.

- **Cause:** `_buildSettingsCard` in `components/window.luau` themed the card
  with `BackgroundColor3 = "WindowColor"` — but `WindowColor` is a
  `ColorSequence` (a gradient), and `BackgroundColor3` only accepts a `Color3`.
- **Fix:** new `CardSurface` theme key (`Color3`) added to all six built-in
  themes (`default`, `amethyst`, `cobalt`, `ember`, `frost`, `rose`), matching
  each theme's element base color. The card now uses
  `BackgroundColor3 = "CardSurface"`. Custom theme tables inherit the key from
  `default` via `themes/init.luau`'s clone.
- Bundle regenerated and `luau-compile` verified on all changed files.

## 2026-09-06 — Luau minification (`7fa2d09`)

All 93 modular `.luau` sources + regenerated bundle minified:

- Stripped all comments and collapsed whitespace.
- Renamed locals safely inside function bodies (AST-driven, public API names,
  Roblox property keys, and icon-name strings untouched).
- Icon packs: data-only, no renames.
- `version-1.luau`: regenerated from minified sources (1,974,324 → 1,912,889
  bytes; the remaining comment lines are the Wax generator's own preamble and
  the required `WAX BUNDLED DATA BELOW` marker).
- Total: 93 files changed, −124 KB. Verified with `luau-compile`,
  `scripts/check_requires.py`, `scripts/check_instance_fields.py`.
- Minification tooling lives in `tools/minify/` (not bundled).

## 2026-09-05 — v1.1 patch set (`e779bed`)

Four bug fixes + one feature, public API unchanged:

- **Fix 1 — profile avatar not rendering:** `setProfileShown` no longer
  early-returns on `profile.Visible` (uses the `shown` argument), skips nil
  targets, and falls back to a themed plate circle when the avatar URI never
  resolves (tracked in the weak-keyed `avatarReady` side table). Empty avatar
  callback assigns a transparent placeholder instead of a broken image.
  Defensive `localPlayer` late-resolution hook in `Window.new` (2s-capped
  RenderStepped poll).
- **Fix 2 — profile layout unification:** top-mode profile is right-anchored
  in the topbar; `profileSubtitle` created in all three layout branches;
  `reflowProfile`/`applyWidth` handle the unified structure.
- **Fix 3 — settings card + rail race:** new `SettingsCard` overlay
  (`Window:_buildSettingsCard`, element-styled via `StyleElementBody`); rail
  visibility restored independently of `elements.Visible` so it can't get
  stuck hidden.
- **Fix 4 — settings sub-tabs:** new public `Window:AddSettingsTab({ name,
  icon })` builds compact sub-tabs inside the settings card; content delegates
  to the normal element registration/persistence pipeline; `activeSubTab` is
  persisted (registry, defaults, appearance validation, JSON persistence).
- **Fix 5 (SettingsManager wiring) intentionally deferred.**

See `ARCHITECTURE.md` for the full pre-v1.1 modular-refactor history.
