# Astra v1 — Module & Local Reference

A guide to every module in the modular tree and the meaning of its important
locals. After the minification pass, locals inside function bodies are renamed
to short names (`a1`, `a2`, … `a275`); this document explains what each
numbered local holds, per file, so future reviews don't have to reverse-engineer
the names. Top-level (file-scope) locals keep meaningful names — only
function-body locals were shortened.

Legend: locals are listed in declaration order per file/function. `self`
fields (`self.x`) are named as-is and not minified.

---

## Root

### `Types.luau`
Type definitions only (`export type ...`). No runtime locals.

### `library_entrypoint.luau`
Public API singleton. Key top-level locals:
- Requires — `core` (state/registry/loader), `core.state`, `images.image`, `utilities.locale`, `utilities.constants`, `icons`, `settings`, `Types`.
- Singleton bookkeeping: existing-window guard backed by a module-local `activeWindow` **and** a `getgenv()`-backed global store so the anti-duplicate guard survives across `loadstring`ed instances. The store keeps the last window (`__ASTRA_ACTIVE_WINDOW_V1`), every still-live window (`__ASTRA_LIVE_WINDOWS_V1`), and a generation token (`__ASTRA_WINDOW_GENERATION_V1`) claimed *before* `Window.new` can yield, so overlapping spam-executes still collapse to one window. Replacement never interrupts active construction: a predecessor whose constructors are still running is unloaded without pulling its tree out from under them (the teardown defers destruction until that construction goes quiet), and a construction that is overtaken while still inside `Window.new` marks its window `_superseded` — never shown, still usable by the host that received it, unloaded by its reveal thread once its construction goes quiet. The `CreateWindow` dispatcher (pcall around `components.window.new`, re-throws on failure); the export table.
Exported names (typed surface is `Types.luau`'s `Astra`): `CreateWindow`, `Icons`; `Core` and `Settings` are also assigned on the table at runtime. There is no top-level `ChangeTheme`/`SetLocale`/`SetTranslator`/`RegisterTranslations`/`Unload` — those are window methods.
`CreateWindow` side effects: enforces the anti-duplicate guard (persisted `antiWindowDuplicate` setting, per-window opt-out via `settings.antiWindowDuplicate`; generation token + live-window list so rapid overlapping constructions still collapse to one window), in secure mode preloads window images (`Image.preload` → failure `Notify`) and swaps in the brand fonts via `ChangeTheme({ Font, TitleFont })` once the entrance has landed (a theme pass over every instance the window owns is not something to spend while the window is still arriving; `FONT_SETTLE_BUDGET` bounds the wait so a window that never shows still gets its font), then auto-`Show()`s the window on the next frame (a `task.defer` plus one heartbeat, so a script's first synchronous `CreateTab` calls land before the shell appears; remaining constructors stream in behind it in small budget-limited batches until the build goes quiet, and an explicit `Hide()` before that tick cancels it via `_autoShowCancelled`). The two secure-mode branches (optional-icon preload, brand-font swap) run as sibling threads under one guard.

### `example.client.luau`
Usage example (not minified). Loads the published bundle and opens it through the standalone key gate: `Astra:CreateKeySystem` shows the card first (demo key `ASTRA-STUDIO-2026`, `saveKey` remembering it at `Astra/keys/Astra-Example.txt`) and the whole studio builds inside its `onSuccess` as `buildStudio(unlockedKey)`; `keyGate`, `window`, `overview` and the build-quiet seam `studioReady` are file-scope locals so `scripts/example_test.luau` can drive the gate through `_submit` (wrong key first, padded right key second) and wait for the streamed build before asserting. The studio then creates ten purpose-based tabs: Overview (About Card, guide Text, an activity Changelog every other tab writes to, Links, Isolated history, Footer), Player (Humanoid edits, JumpRequest hook, respawn Keybind), Combat (roster Dropdown with Refresh/Add/Remove, simulated-engagement Stats), Visuals (Lighting and Camera writes, ColorCorrection/BlurEffect), World (coordinate Inputs, teleport, waypoints), Live Stats (Heartbeat sampler through `window:Connect`, hardware report), Elements (every handle: Set, Add/Remove/Refresh, Capture, MoveTo*, Lock), Configs (`Save`/`Load`/`DeleteConfig`/`ListConfigs`/`GetPath`/`Flags`), Window (`ChangeTheme`, corner tokens, `Astra.Motion`, visibility, overlays, `ShowTooltip`, `Unload`) and a locked Premium tab that Window unlocks. Roblox services are resolved through a nil-safe helper block at the top, so the same file runs in an executor, in Studio and under `scripts/example_test.luau`. It ends with `overview:Select()` followed by the `studioReady` flip; all information lives on the first tab. The skill starter stays a smaller three-tab version.

---

## core/

### `core/init.luau`
- Requires `state` and exposes it as `core.state` (the entrypoint and
  `components/*` consume it via `require(...core)`). The generic
  registry/loader pair that used to sit beside it had no readers and was
  removed.

### `core/state.luau`
Shared runtime singletons:
- Roblox service fields: `localPlayer`, `coreGui`, `workspace`,
  `runService`, `userInputService`, `guiService`, `tweenService`,
  `httpService`, `textService`, `replicatedStorage`,
  `localizationService`, `guiContainer` (secure-mode aware).
- `secureMode` — platform detection; `fallbackFont` (default
  `Enum.Font.BuilderSans`) + `setFallbackFont(font)`; `fontChoice`
  (`"default"`/`"brand"`, initial value `constants.defaultFontChoice`, set
  via `setFontChoice`); `brandFont(weight)` / `brandFontPair()` — font
  resolvers honoring the selection (and the platform's brand font
  override): `"default"` resolves everything to the fallback family (the
  original Roblox look), `"brand"` to `constants.fontAsset` — through
  `fontManager`'s one-time download in secure mode.
- Manager singletons: `fileSystemManager`, `assetResolver`, `fontManager`.

---

## components/

### `components/window/` (class `Window`, minified as `a17`)

Split by responsibility across one folder. `class.luau` holds the bare class
table so every part can attach methods without a require cycle; `init.luau`
requires the parts and returns the finished class, so `require(components.window)`
is unchanged for callers. `constants.luau` holds the values shared by more than
one part. Parts: `startup`, `theme`, `tabs`, `elements`, `overlays`, `layout`,
`visibility`, `input`, `settings`, `config`, `teardown`.
Constructor/`new` locals:
- `a2..a5` — `core.state`, `functions.colors`, `functions.textMetrics`, `utilities.layouts`.
- `a6..a14` — zIndex/display-order constants, default window props, layout-mode resolution.
- `a15` — `core.state` runtime table (services, localPlayer, tweenService…).
- `a4.toColorSequence` — gradient coercion helper for theme values.

Notable instance fields set in `new`: `screenGui`, `main`, `elements`,
`tabList`, `sidebar`, `settings` (plain table: `toggleKeybind`, `theme`,
`mouseOverride`, `keepOnScreen`, `haptics`,
`dragMinimisedBar`,
`antiWindowDuplicate`, `layoutMode`, `motionSpeed`, `fontChoice`), `rfSettings` (the
built-in "Overview" settings tab), `_settingsTabs` (settings-tab list),
`_settingsMode` / `_previousTab` (settings-mode bookkeeping),
`settingsAction` / `minimiseAction` (topbar actions), `drag`,
`collapsedInteract`, `connections` / `instances` / `themeProperties` /
`localeProperties` / `controls` / `tabs` (lifecycle registries),
`Flags` (metatable view over `controls`).

Method map (names preserved through minification). Settings-related:
- `_buildSettingsUI` — creates four built-in settings tab shells: Overview
  (`rfSettings`, order 1001), Controls (1002), Appearance (1003) and Persistence
  (1004), all `isSettingsTab` and `forgetState`. The gear opens the first row.
  Each stores a `_settingsContentBuilder`; `_buildSettingsContent(tab)` runs it
  on first selection after construction. Controls owns keyboard, cursor and
  window behavior. Appearance owns the font selection, layout and Motion &
  Feedback.
  Persistence always hosts saved-config Save/Load/Delete (independent of
  the `configuration` prop), plus default-on Auto Save Config and Auto Load
  Config toggles. Storage defaults are internal; the named-preset dropdown
  does not expose the default config filename. Auto-save writes are coalesced.
- `settingsAction` (topbar gear, `linkedTab = rfSettings`) — toggles
  settings mode via `_toggleSettingsMode`: entering shows only settings
  tabs and remembers the previous tab; a second click restores it. The topbar
  action is the single settings entry point.
- `_applySettingsLayout(active)` — reflows rail/elements for settings mode.
- `SaveSettings` / `LoadSettings` — per-window settings persistence via
  `utilities.persistence` (settings JSON).
Public surface:
- `Create(className, props, themeBindings?)` — instance factory: theme-bound
  property recording (`themeProperties`), locale-token binding
  (`_bindLocale`), image-guessed property assignment; tracks every instance
  for `Unload`. On an already-unloaded window it builds detached instead:
  the instance is parented under a throwaway per-window graveyard container
  (never into the destroyed tree) and left out of `instances`, so a
  superseded script's constructors finish harmlessly; `Unload` destroys the
  container.
  `_railGroup(tab)` / `_activeRail()` — the main/settings rail filters every visibility site shares.
- `ChangeTheme`, `CreateTab`/`CreateSection` (on an already-unloaded window
  they build detached like `Create` above instead of asserting — the tab or
  section is real and usable, and only the live-tree bookkeeping is skipped:
  rail insert, first-tab selection, chrome visibility, the settings reflow),
  `Notify`
  (constructs its card on the entrance queue's turn, see
  `components/overlayQueue.luau`)/`Popup`, `Show`/`Hide`/`ToggleHide`/`ToggleMinimise`, `Close` (animated
  close → `Unload`), `Save`/`Load`/`ListConfigs`/`DeleteConfig`/`GetPath`,
  `Get`/`Set`, `Navigate`, `SetLocale`/`SetTranslator`/
  `RegisterTranslations`, `ResolveIcon`, `Unload`.
- Lifecycle/extension helpers: `Connect`/`ConnectFor`/`Disconnect`/
  `DisconnectMany`, `DestroySubtree`/`DestroySubtrees`, `CreateGlow`,
  `CreateHoverOverlay`, `StyleElementBody`/`StyleElementPanel` (element
  gradient/corner/stroke styling), `_buildCompactRow` (settings-mode tab row).
Internal: `_reveal*`/`_fadeSurfaces`/`_firstShow`/`_quickRestore` (reveal
engine — both entrances animate the shell first and hand the page to
`_stageContentReveal`, which waits `contentRevealBeat`, runs `_revealElements`
one control per beat, and then opens the overlay gate; `_contentEntranceId` is
the generation that keeps a superseded entrance from touching the page, and
`_revealElements` owns clearing `_elementsPending` for the tab it walks), `_bindTopbarDrag`/`_bindKeybind`/`_bindMouseOverride`,
`_applyWindowSize`/`_applyRailWidth`/`_clampToScreen`/`_watchViewport`,
`_clampedPosition` (keep-on-screen clamp on the window's own half-extents),
`_restingCenterPosition`/`_recenterWindow` (screen-centre recentering;
re-derived by `_firstShow` and `_quickRestore` while the window is still at
its anchored resting spot, and by `ToggleMinimise`'s expand),
`_setLayoutMode`, `_toggleSettingsMode`
(topbar gear), `_registerControl`/`_unregisterControl`/`_persist`,
`_runGuarded`, `_setElementLocked`/`_buildLockScrim`, `_updateWindowTitle`.

### `components/settings.luau`
Dedicated settings component providing lazy UI generation for Overview, Controls, Appearance and Persistence, in that order:
- `buildUI(window)` — reuses `rfSettings` as the first Overview shell and adds the other three. Overview renders the About Card, copyable resource Links and Footer.
- Controls uses `elements/keybind` for the menu letter (callback converts the uppercase string to a KeyCode), an unlock-cursor Toggle and Window Behavior. There is no typed-key parser or mouse/unbound menu option.
- Appearance owns the standalone Font and layout Dropdowns and a related Motion & Feedback group. Persistence owns configuration toggles and save/load/delete controls. No built-in Collapsible Group contains only one element.
- `buildContent(window, tab)` — lazily constructs controls within a given settings tab upon first selection.
- `toggleSettingsMode(window)` — toggles between user tabs and settings tabs.
- `setSettingsMode(window, active)` — applies visibility and layout for settings mode.
- `applySettingsLayout(window, isSettings)` — manages tablist and layout visibility between modes.

### `components/changelogPanel.luau`
Deleted. Release history now renders as a regular `elements/changelog` element; no window-scoped store, badge, or dedicated mode remains. `utilities/persistenceChangelog.luau` was deleted with it.

### `components/sidebar.luau`
Tab-rail reflow:
- `maskUsername(name)` — shared masking helper (first 3 chars + `****`).
- `buildTabRail` — rail ScrollingFrame + UIPadding + UIListLayout (the layout implementations build their own rails).
- `applyRailRows(window, width, layout)` — rows collapse only at the icon-only width (the responsive rail is often narrower than the old 219px fixed rail); ends with `tabSelector.relayoutSidebarRows`.

### `components/drag.luau` (the detached drag handle)
- `Drag.new(window)` — builds the handle under the window: an 80x16 invisible
  hitbox (`self.drag`) holding the visible pill (`self.dragCosmetic`, 48x3 at
  rest) and the `dragInteract` TextButton, all parented to `window.screenGui`
  so the handle rides screen coordinates. `handleGap` (22) is how far the
  pill's centre sits below the window's bottom edge; `Window:_syncDragBar` and
  the window's own `dragHandleGap` place it with the same number.
- The pill's look is four named specs — `handleHover` (64x3, 0.5), `handleGrab`
  (56x3, 0), `handleIdle` (48x3, 0.7) and `handleParked` (0x3, 1.0) — so every
  state writes the same values, all four sharing `handleThickness` (3). The
  pill is actually round: `handleRadius` is half that thickness, so the ends
  stay domed through every width the specs tween. Hovering the hitbox reveals the hover look;
  dragging from it shows the grab look and moves the window with the pointer
  (positions lerped per frame, `constrainPosition` clamps through
  `settings.keepOnScreen`); letting go settles the pill through
  `restingLook(self)` — the hover look while the pointer is still on the
  handle, the idle hint otherwise.
- Lifecycle, driven by the window: `Drag:enable()` (the hitbox becomes
  reachable, the pill is left where its own states put it), `Drag:disable()`
  (off at once, pill parked), `Drag:fadeOut(spec)` (pill shrinks away first,
  hitbox follows when the fade has read — a token makes a pending hide stand
  down if an entrance claims the handle first) and `Drag:setMoving(active)`
  (the window is being moved by its topbar: pill brightened for the move,
  settled back when it ends). `Window:Show`/`Hide`/`Close`/`ToggleMinimise`
  and both settle paths (`_firstShow`, `_quickRestore`) call these; nothing
  pokes `self.drag.drag.Visible` any more.
- State fields a test can read: `dragging`, `moving`, `hovering` and
  `_handleToken`; the observable handle is `window.drag.drag.Visible` plus the
  pill's `Size`/`BackgroundTransparency`.

### `components/action.luau`, `chrome.luau`, `tabSelector.luau`
Small window-furniture classes; top-level `utility` require + constructor locals for created frames/buttons.

`tabSelector.railContentWidth(window, layout)` — natural rail width for the
responsive sidebar: the widest row in the current rail group (tabs or
settings tabs per `_settingsMode`), measured with `functions.textWidth`
(title + icon/spacing/paddings) plus row insets; 0 when the group is empty.
`Window:_railWidth` uses it to size the rail itself
(`min(content, floor(windowWidth / 2))` for the expanded responsive rail;
fixed widths elsewhere), and `tabSelector.relayoutSidebarRows` constrains an
overlong title to the row's remaining slot so its existing `TextWrapped`
wraps it in place. Re-derived from `sidebar.applyRailRows` (rail width
changes), `Window:_applyContentRailWidth` (layout/settings/locale/theme
changes, tab removal, lock flips), `Tab:Remove`, `Window:SetLocale` and
`Window:ChangeTheme`. No-op for the collapsed-sidebar layout.
`applyRailRows` treats the rail as collapsed only at the icon-only width
(`railCollapsedWidth`), so a content-sized rail narrower than the old fixed
219px still shows titles.

Lock UI is temporarily paused via `tabSelector.lockUIEnabled = false`.
Badge instances remain hidden (also after `SetLocked` and row rebuilds), and
both natural-width measurement and wrapped-title slots omit the badge reserve.
Flip the flag and regenerate the bundle to re-enable the retained UI below.
Host-side lock state, selection guards and search filtering remain active.

`tabSelector.buildContent` also creates the lock badge (`tab.topbarItemLock`,
13px, trailing-centred in the row — inset by the row padding, riding the row
itself rather than the content container): `Visible` only while `tab.locked`,
so an unlocked row draws no icon at all and `SetLocked` flips a flag instead
of rebuilding; `applyVisual` dims it with the row's content transparency. The
badge is part of the row's measured width (`lockReserve`: glyph + one content
gap), so `railContentWidth` fits the rail around it, `relayoutSidebarRows`
wraps a long locked title clear of it, and `SetLocked` re-derives the rail.
`setRowCollapsed` moves the badge to a corner seat on the icon-only tile
(where a trailing glyph would cover the centred icon) and restores each
expanding row's own title state (selected 0, locked 0.7, unselected 0.5) so a
rail re-apply never brightens rows it did not mean to.

`tabSelector.railCollapsed(window, layout)` answers whether the rail is at that
icon-only width right now (the rail's own `Size`, written by the layout's
`Build`/`ApplyWidth`; `forceCollapsed` is always collapsed). `tabSelector.build`
reads it, so a row rebuilt *after* the rail was sized — a layout switch
(`Window:_setLayoutMode` rebuilds every row), or `Window:CreateTab` while the
rail is icon-only — is born in the rail's current state: icon-only rows hide
their title, drop the expanded row padding and size themselves as a square
`rowHeight` tile (a full-rail row was 34x38 in a 64px rail, which left the icon
7px from the tile's sides but 9px from its top and bottom), instead of leaking
the start of the tab name past the icon inside a 64px rail. `Window:_setLayoutMode` also
re-applies the rail width after its rebuild loop, which is what re-constrains a
capped title's wrapping slot on the new rows.

### `components/overlayQueue.luau`
The entrance queue shared by every window-level overlay: `pending` (requests
waiting for a turn), `running` (one pump per window), `paused` (the gate held
closed while the window's own entrance is up), `closed` (the window is gone).
`Window.new` pre-seeds `_overlayQueue` with a placeholder that has none of those
fields, so `queueFor` completes the shape on first use — carrying `paused`/
`running`/`closed` across — and every entry point reads the queue through it;
that is what lets the rest of the module take `#queue.pending` unconditionally.
`OverlayQueue.request(window, build)` enqueues, `OverlayQueue.pause`/
`OverlayQueue.resume` open and close the gate (`Window.new` closes it,
`_firstShow`'s settle and `Window:_stageContentReveal` open it; `Window:Hide`
re-opens it when the entrance was cancelled before it ran), and
`OverlayQueue.close` is called from `Window:Unload` (and leaves the queue at its
placeholder values, since `Unload` clears the table whole afterwards). A card takes its turn with
`build(release)` and calls `release()` when its entrance is committed — the
constructor does that through `_entranceDone`, which the dismiss path also
reaches so a retired card cannot wedge the queue. Locals: `entranceGap` /
`backlogGap` / `backlogSize` (the cooldown between two cards, shortened while a
backlog waits), `entranceBudget` / `gateBudget` (bounded waits, so neither a
card that never reports back nor a gate nobody opens can park the pump),
`maxQueued` (six waiting requests, oldest dropped past that). Every wait is
accumulated from `task.wait()` deltas and the gaps go through `motion.step`,
so the queue answers the "Animation speed" setting instead of the wall clock.

### `components/notification.luau`, `popup.luau`, `tooltip.luau`, `keySystem.luau`
Overlay queues: `a1..a4` — container frame, TweenInfo presets, queue table, active-instance guard.
`Notification.new(window, props, release)` takes the entrance slot from `components/overlayQueue.luau` and hands it
back from `_entranceDone` when its staged fades are committed (icon, then
description); `Window:Notify` builds the layer
immediately but constructs the card only on its turn, so a burst at load time
costs one card per frame instead of all of them at once. `Popup` is modal and
stays outside the queue.
Exact notification title/content pairs are keyed per window. A matching live
card is dismissed through its exit motion before a replacement is queued, so the
new card runs a fresh entrance; pending keys coalesce to the newest snapshot
before the queue cap is enforced. Matching is case/whitespace-sensitive,
honours aliases/defaults, and does not include icon or duration. Dismissed/expired
cards do not block future requests.

`tooltip.luau` retains the independent `Window:ShowTooltip` / `HideTooltip` API:
one locale-aware floating panel per window, positioned over the supplied anchor.
The functional `(!)` badges and their hover/tap/hold wiring have been deleted.
Window transitions and teardown still close programmatic descriptions.

`keySystem.luau` is the standalone key gate behind `Astra:CreateKeySystem` —
meaningful locals throughout (popup-style, nothing minified). It owns no
window: `_create` is plain `Instance.new` plus immediate locale-token
resolution (no live rebinding — the gate has no `SetLocale`), with every
other prop routed through the shared image pipeline (`image.assign`, like
`Window:Create`) so the header, close and link-button glyphs render, the
theme is `themes.resolve` baked once at creation, and `Close` tracks every
connection itself. `new` normalises `keys` (string or list, blanks dropped), optionally
fetches remote keys up front (`grabKeyFromSite`, dead links fail closed),
passes through on an empty key list (with a warning) or a matching
`Astra/keys/<fileName>.txt` file, and otherwise builds the 400px card
(viewport-clamped, never under 280px) with the forced Sirius header
(`props.icon` is ignored; `custom_asset/sirius.png` still wins as the
source), field-plus-Continue row, plain note line and — from `links` plus
the promoted `getKeyUrl` — a row of up to three copy buttons (`_buildLinkRow`,
LayoutOrder 4): each face shows icon + name only, and `_copyLink` copies the
hidden URL then reveals it through a real `Notification` built against
`_notificationHost`, a window-shaped shim (Create/ResolveIcon/CreateGlow +
Connect/Disconnect/DestroySubtree + the baked theme and a notifications lane
in the gate's own ScreenGui) so the notification component runs before any
window exists; connections route back through the gate's sweep so `Close`
still retires a live card. `_submit` is the one submit path (button, Enter, tests);
`_shake` chains three lateral tweens plus the field-stroke error flash;
`_lock` freezes the gate at `maxAttempts`; module-level `activeGate` retires
a previous gate instead of stacking. Handle fields: `passed`, `closed`,
`attempts`, `Close()`; underscore fields (`_card`, `_input`, `_expected`,
`_links`, `_linkButtons`, `_linkInteracts`, `_notifyHost`, …) are
construction internals the runtime suite drives.

### `components/search.luau`
Fuzzy search overlay: locals for candidate list, scoring weights, debounce connection.

---

## layouts/

One module per bar-layout mode, each with `Build(window, layout)` (creates the
tab strip and rail chrome) and `ApplyWidth(window)` (reflow):

- `Sidebar.luau` — mode `sidebar` (responsive): vertical tab rail.
- `SidebarCollapsed.luau` — mode `collapsedSidebar`: compact rail.

`utilities/layouts.luau` holds the per-mode metric tables and dispatches
(`layouts.get(mode)`, `layouts.implementation(mode)`,
`layouts.railWidthFor(layout, viewportWidth)`); `utilities/windowSizing.luau`
uses the same builders for responsive sizing. The window selects the
implementation in `_setLayoutMode`.

---

## elements/

All element classes share the pattern:
- First local — `require(...core.state)` alias.
- `new(tab, props)` — locals for normalized props, created frame, and connections.
- `_setShown`, `_refreshTheme`, `Set`/`Set_`-style setters keep their public names.

Per-element specifics:
- `toggle.luau` — track/knob frames, accent tween locals.
- `slider.luau` — fill frame, handle, drag math locals (`a1..a12`: range min/max, step, value normalization).
- `dropdown.luau` — button, list frame, option rows (built on first open, `_materialiseOptions`/`_buildOptionAt`), highlight, search filter, and the multi-select action row. Row corners come from `rowTiers(window)`: the rows sit `rowInset` (6px) inside the panel that clips them and the panel wears `ElementCornerRadius`, so the outer tier *is* that radius (a row's arc then lands inside the clip instead of being cut by it) and the seam where two rows meet sits `rowSeam` (4px) below it; `_updateCorners` re-reads both on every pass. The search field rounds at `searchFieldRadius` (6px) and the checkbox at a quarter of its 12px box: a checkbox in the rows' own 16px glyph slot (a drawn 12px outline when off, the rows' check glyph when on) with Select all, which toggles the visible options, and Clear with its pack bin, which removes only those. The box is re-synced by every path that can move the selection or the visible set (`_syncActions`), and only a multi-select dropdown builds any of it.
- `input.luau` — TextBox, placeholder/focus locals, validation callback.
- `collapsibleGroup.luau` — optional declarative container for all tab element
  types and ordinary Groups. Validates definitions, rejects nested collapsibles,
  marks descendants as visually nested (transparent cards/no child outlines),
  animates measured content height through the motion service, and keeps child
  controls alive while hidden. Search and tab removal traverse its descendants.
  Surfaces: the container carries the element surface (`ElementGradient` over a
  white base) so its own rounded top corners read as the header band, the band
  rounds *its* top corners with the same `ElementCornerRadius` (Roblox rounds a
  GuiObject's own surface but never clips descendants to the arcs — a square
  band squared off the stroke's silhouette), and `bodyClip` paints the darker
  window surface under the divider with the container's bottom arcs. Because the
  band *is* the card's bottom edge while the group is closed, `_fitHeaderCorners`
  (through `Window:_setRoundedCorners`, the state-flipping companion of
  `_roundCorners`) moves the container's bottom arcs onto the band and squares
  them off again the moment the body is revealed, so both states keep one even
  silhouette on the same radius token.
- `description.luau` — the in-card muted helper line: an element built with a
  `description` prop grows its own card by the measured, wrapped line height and
  keeps its controls centred in the base region, so nothing renders below the
  card. Functional `info` badges have been removed; `description` is unchanged.
- `tab.luau` — tab class: `tabPage` (ScrollingFrame), `_register(element)` pipeline into `window.controls[flag]`, selector button visuals. `CreateChangelog` builds a regular changelog element wherever declared. Locked tabs (`locked` prop / `SetLocked(bool)`): the flag gates `Select` (no-op), the row tap (short "This tab is locked" notification instead), and hover; `_applyVisual` raises the row's content transparency while locked (copy of the shared state table, never a mutation of it); `SetLocked(true)` on the open tab clears `window.selectedTab` and selects the first unlocked non-neglect tab with same-rail preference (the `Remove` fallback rule), hiding the tab's elements and marking `_elementsPending` when no fallback exists.
- `group.luau`, `section.luau`, `tabSection.luau` — container classes with UIListLayout locals.
- `changelog.luau` — release-history element (`__type = "Changelog"`): normalizes `ChangelogEntry`/`ChangelogChange` props, maps symbols (`+`/`-`/`~`, or words like "added"/"removed"/"changed") to green/red/amber, fades entries in, supports `Set`/`Refresh`/`Add(entry, prepend?)`/`Clear`. Renders as a regular standalone element; supports `Set`/`Refresh`/`Add`/`Clear` and move/lock API.
- `isolated.luau` — the Isolated changelog container (`__type = "Isolated"`): a
  CollapsibleGroup-style expandable card whose header carries a changeable left
  icon, a title/subtitle stack and the built-in, never-changeable right chevron.
  Strict container: child definitions must be Changelogs — anything else errors
  at construction with
  `Astra:CreateIsolated — only Changelog elements can be placed inside Isolated`
  (level 0, exact message). Public `Expand`/`Collapse`/`Toggle` drive the shared
  expansion tween beside the header tap; `SetTitle`/`SetSubtitle`/`SetIcon`
  rewrite the changeable slots at runtime (`SetSubtitle(nil)` returns the header
  to the single-line band, `SetIcon(nil)` releases the icon gutter; none of them
  reach the chevron). Reuses the collapsible surface recipe: element-gradient
  header band with state-flipping corner ownership, 1px divider, window-surface
  body clipper. Search indexes its children, tab removal traverses them, and
  moveable/lockable apply to the container.
- `link.luau` — a card that carries a URL: icon, title, subtitle and a fixed
  trailing copy control. The link is a hidden value (stored on the element, never
  rendered), and the control copies it, swaps in the confirmation glyph for two
  seconds and reverts — one token per card, so a container that hides the card
  (`_setShown(false)`, or a Collapsible Group collapsing) ends the hold instead of
  carrying a stale check mark into the next reveal. The copy reaches the host for a
  clipboard each tap (`setclipboard` / `toclipboard` / `setrbxclipboard` / a
  `Clipboard` object / `StudioService:CopyToClipboard`), and glyph swaps go through
  `images/image.luau`'s `assign` so remote icons get the same cache rewrite the
  window's `Create` applies. Full card for a tab or a column Group, compact row for
  a horizontal one.
- `aboutCard.luau` — the About card (`__type = "AboutCard"`): one container with
  four blocks — a header (leading icon plus a title/subtitle stack), a row of one
  to three data tiles (each a badge icon with a label above its value), a wrapped
  description paragraph and an optional action band (icon, label, subtitle, the
  built-in trailing chevron and one full-band tap target). Surfaces reuse the
  shared nesting recipe: the card is the standard element body, a tile and the
  band use the regular `ElementSurface` fill with the element corner and stroke
  (`insetSurface`) instead of the darker window gradient, and a badge stays in
  the same control-surface family. `_layoutRows` keeps all one to three tiles on
  one compact 48px line and gives each an equal scale-based slice after its 8px
  gaps, so the Version / Build / Author recipe remains three-across rather than
  leaving Author alone on a second line. The scale geometry follows window
  resizing directly and `SetRow` refreshes it after an icon reservation changes;
  unusually long copy truncates inside its tile instead of changing the card's
  structure. A fourth row errors at construction with
  `Astra:CreateAboutCard — at most 3 data rows are supported, got N` because the
  action band is the card's trailing row. A row without an icon drops its badge
  and hands the tile to its text (`_applyRowIcon`), and a card without rows,
  description or action leaves those blocks out of the list layout. Reveal and
  theme passes run over one tracked part list (`parts`, each `{ instance,
  property, rest kind }` with the rest values in `restValue`), so a hidden card
  takes every label, glyph and stroke out together and a theme change re-reads
  them all. Setters: `SetTitle`/`SetSubtitle` (which reopens or closes the header
  band), `SetIcon`, `SetRow(index, row)` and `SetDescription`; moveable/lockable
  apply, locking disables the action band. The Settings → About tab is the
  reference instance, built from `components/settings.luau`'s `aboutVersion`,
  `aboutBuild` and `aboutAuthor`.
- `modePicker.luau` — the Mode Picker (`__type = "ModePicker"`): a multi-stop
  slider card with a display-only left icon, a centred title/subtitle stack and
  a reset button. Modes normalize from a map or array into a dot_position-sorted
  list of 3..5 (`min_modes`/`max_modes` clamp to that window; construction
  outside it errors `Astra:CreateModePicker — modes must be between N and M,
  got K`). The track borrows the toggle's switch height, the toggle's knob
  (26x18 pill) and the toggle's 2px clearance: stops inset by the knob's half
  width plus that gap, so the track's 11px cap and the knob's 9px cap are
  concentric at both ends and the knob never jams flush against the track's
  silhouette, with one 4px dot per stop at the knob's centre. The fill wears the
  knob's own pill (same height, same radius, same inset) and runs from the first
  stop to the knob's *trailing* edge through the same scale/offset pair the dots
  use, so no resize handler is needed, no accent bleeds around the knob's corners
  and the last stop fills the track end to end. `left_icon_color` (Color3 or
  `{r,g,b,a}`) paints the icon and, with `title_color_same_as_left_icon`, the
  title; per-mode `icon_color` overrides drift in on the delayed accent beat when
  a mode enables. While that link holds the title carries no `TextColor3` theme
  binding and answers `_titleRestColor()` for `Window:_wireElementHover`, so
  neither a theme pass nor a hover cycle settles it back onto a theme token; with
  the link off it binds to `ContentColor` like every other control title.
  `accent = "left_icon"` also retints fill and fill glow, otherwise both stay
  theme-bound like every other element. Drag and tap snap live through
  `HapticEngine.click()` per crossed stop; each mode's `onEnable` and the
  picker's `callback` fire through `_runGuarded`. The right icon resets to
  Mode 1, rolls runtime `AddMode`/`RemoveMode` back to the configured set and
  hands the config its `onReset`. `AddMode`/`RemoveMode` enforce the 3..5
  window and the `optional` flag; `allow_mode_add_remove = false` closes both.
  The description line is static when `description` is passed and otherwise
  rewraps to the selected mode's line. Tab, column Group and declarative
  Collapsible Groups all construct it; row Groups warn and skip it like every
  non-compact element.
- `divider.luau`, `stat.luau`, `text.luau` — display and interaction elements.
- `footer.luau` — the centred inline text-and-icon strip ("Built with ⚡ Astra ♡"):
  an ordered run of `{ text }` / `{ icon }` segments under one centring list
  layout; icons resolve through the catalog, scale with `textSize`, and
  unresolvable names drop instead of leaving gaps. `Set` rebuilds the run,
  destroying the old segments through `Window:DestroySubtree`. The container
  frame is an untinted transparent host and deliberately carries no theme
  binding (unlike the element cards, nothing gradients it, so a theme pass
  must never paint it opaque); visibility lives on the runs alone.
- `button.luau` — action card with no trailing glyph in full or compact mode. Optional leading icon and title retain explicit LayoutOrder; the card and stroke animate on press. Legacy tap-icon props are ignored.
- `keybind.luau` — required A–Z editable TextBox with a one-letter themed keycap, shared base-card layout, flags, guarded callbacks and move/lock methods. `value` is an uppercase string. `_canCapture` checks visibility, selected tab and ancestors; `Capture`/`CancelCapture` own `window._keybindCapture`; the TextBox sanitises direct edits while `_captureInput` accepts letters and Escape; `Set` validates without clearing. Keybinds intentionally have no description row. Tab and column Group expose `CreateKeybind`; declarative Collapsible Groups accept `Keybind`.
- `utilities/keybind.luau` — shared `letter(value)` validation for strings and KeyCode EnumItems; settings defaults, live validation and saved-setting migration use the same rule. Settings schema 2 migrates unsupported bindings to K.
- `components/window/input.luau` — routes input to the capture owner before the menu toggle; ignores game-processed input and focused *other* TextBoxes while allowing the editable keybind field to keep its capture. Tab changes, hide, minimise, group collapse, lock, removal and unload cancel capture.
- `components/chrome.luau` / `window/visibility.luau` — capsule icon/text use explicit Visible gates; only the Hide completion reveals them. Expanded, folding, restoring and topbar-minimised states never show the restore face.
- `baseCard.luau` — shared card container and header layout helper for element modules.
- Functional info badges: `infoHelper.luau` and badge gesture bindings were
  deleted. Legacy `info`/`infoIcon` props are ignored and `SetInfo` methods are
  no-ops for compatibility; reveal/hide paths no longer reference badge fields.

---

## settings/

- `init.luau` — module wiring: exports the `manager`, `registry`, `defaults`,
  `persistence` modules plus `settings.newManager(overrides)` and
  `settings.readPersisted(key, default)` (used by the entrypoint for the
  anti-duplicate guard).
- `registry.luau` — `definitions`: one `{ key, kind, domain, description }`
  entry per setting. Keys: `toggleKeybind` (keybind/behavior),
  `mouseOverride` (boolean/behavior), `keepOnScreen` (boolean/appearance),
  `haptics` (boolean/performance),
  `antiWindowDuplicate` (boolean/behavior), `layoutMode` (enum/appearance),
  `motionSpeed` (enum/performance), `fontChoice` (enum/appearance).
  Lookup: `registry.definition(key)`, `registry.keys()`.
- `defaults.luau` — `values`: flat defaults (`toggleKeybind = Enum.KeyCode.K`,
  `layoutMode = "sidebar"`, …); `defaults.clone(overrides)`.
- `manager.luau` — `SettingsManager.new(overrides)` → `{ defaults =
  defaults.clone(overrides), persistence = {} }`; methods `get`, `set`
  (routes through `registry.definition` + the domain validator, returns false
  for unknown keys), `reset`, `onChange(listener)`, `save`, `load`.
- `persistence.luau` — save/load/read of the per-window settings JSON over
  `utilities.persistenceSettings`.
- `appearance.luau`, `behavior.luau`, `performance.luau` — per-domain
  `validate(key, value) -> (ok, normalized)`. Appearance additionally
  whitelists `layoutMode ∈ { sidebar, collapsedSidebar }` and
  `fontChoice ∈ { default, brand }`.

---

## functions/

- `init.luau` — re-export table: `textWidth`, `textHeight`,
  `deriveFlagFromName`, `contrastColor`, `toColorSequence`, `contrastText`.
- `colors.luau` — `toColorSequence` (Color3/ColorSequence pass-through),
  `contrastColor` (black/white by luminance), `contrastText` (dark/white for
  text overlays).
- `textMetrics.luau` — text width/height estimation via `TextService`.
- `flagNames.luau` — control-flag (config key) sanitizer/uniquer.

---

## images/ & cache/

- `init.luau` — folder module: re-exports the image helpers
  (`resolve`, `assign`, `preload`, `avatar`, `rewrites`) alongside
  `windowIcons`.
- `image.luau` — `assign` (guarded property write), `resolve` (value →
  loadable image URL), `avatar(userId, callback)` — returns cached URI or
  `""`, fires callback after fetch; empty final URI → caller uses plate
  fallback; `preload(callback)` — batch preload reporting
  `(failedCount, failedRoles)`; `rewrites`/`onBlock`/`pending` — URL
  rewrites, blocklist hook, in-flight tracking.
- `windowIcons.luau` — asset-id registry for built-in chrome icons (settings,
  close, minimize, …).
- `cache/imageCache.luau` — disk/memory cache; `pcall(callback, uri or "")` at the end of the retry chain.
- `cache/moduleCache.luau`, `persistenceCache.luau`, `init.luau` — generic memoization layers.

---

## icons/

- `init.luau` — public surface (`get`, `resolve`, `getByPack`, `list`,
  `packs`, `count`, `isPack`, `priority`, `loaded`, `refreshCustom`) with lazy
  metatables per pack: a pack's data module is required on first lookup, then
  cached (`packLoaders` / `loadedPacks`). Name-only lookup walks the packs in
  `PACK_ORDER` (lucide, material, tabler, phosphor, heroicons, feather, remix) and
  stops at the first hit, so the search is lazy as well as deterministic;
  `"pack:name"` (and the `pack` argument) address one pack exactly, and a
  mis-cased or unknown pack resolves to nothing rather than to a neighbouring
  pack. Names and pack names are case-sensitive, never normalised. Resolution
  pipeline: pack values are repo-relative PNG paths under
  `assets/icons/<pack>-pack/<first-letter>/`; `resolve` maps them onto the
  repo's raw-GitHub base URL (`assetBase`), checks the executor's
  `custom_asset` folder first (indexed once with `listfiles`, subfolder keys,
  extension preference png/jpg/jpeg/webp/none, one `getcustomasset` per used
  path, misses memoised), passes numeric asset ids and `rbx*://` /
  `http(s)://` values through unchanged, and memoises each (request, pack)
  answer; `namedAssets` covers a few named chrome assets.
- `lucide/feather/material/phosphor/heroicons/tabler.luau` — pure data tables
  `{ [name] = "assets/icons/..." }`. Names are public lookup keys; never
  renamed. Entry counts: lucide 1776, material 1133, tabler 5130,
  phosphor 1512, heroicons 648, feather 287.

---

## themes/

- `init.luau` — resolution engine: module table, ColorSequence-key
  whitelist, `coerceValue`, `firstColor`, `deriveStrokes`
  (luminance-based stroke deriver), `resolve` (clones `default`, overlays
  chosen theme, so custom tables inherit missing keys).
- `default.luau` — the only built-in palette, a table of ~65 keys
  (surfaces, strokes, text colors, gradients, fonts, corner radii,
  slider/toggle/picker styling). Keys a custom table omits are inherited from
  this clone. A saved theme name other than `default` is ignored by
  `utilities/persistenceSettings.luau`.
  The corner scale is three nested tiers, each one step inside the tier above so
  the arcs stay concentric: `CornerRoundness` (12px) is the shell — the window
  silhouette plus the bands that mirror its corners, the bottom fade,
  notifications and popups; `ElementCornerRadius` (8px) is everything inside it
  (cards, field boxes, hover overlays, tab rows, dropdown panels, tooltips, the
  search bar, popup buttons); `PillCornerRadius` (32px) is the folded states —
  half the 64px chrome height, so the minimised bar is a full pill and the 50px
  capsule clamps to a pill of its own. All three are pixel radii on purpose:
  `input_field_test` pins the field box to `Scale` 0, and the tiers have to stay
  comparable for nested surfaces to line up. Controls that are round by nature
  ignore the tokens and take half their own height (`toggle.luau`,
  `slider.luau`, `drag.luau`, the unread dot in `action.luau`), so no theme can
  square them off.
  The three window sections are painted from dedicated surface tokens with a
  strict luminance hierarchy — `TopbarSurface` (darkest band),
  `SidebarSurface` (the tab rail, one step lighter) and `ElementSurface`
  (the elements area, lightest) — and the default palette keeps that order
  (`surface_hierarchy_test` pins it, including a minimum visible step
  between the shades). `ElementSurface` also paints the selected tab row,
  so the active tab reads as a continuation of the content it opens;
  unselected rows stay transparent and fall back to the rail's
  `SidebarSurface`. `CardSurface` (Color3, from the `2ecd628`
  settings-card fix) mirrors `ElementSurface` but is defined only for
  compatibility — no code reads it.

---

## utilities/ (selected)

- `constants.luau` — static constants incl. the `icons` map re-exported from `images/windowIcons.luau`.
- `motion.luau` — the library's animation service: named `TweenInfo` specs
  created once (`instant`, `fast`, `snappy`, `normal`, `smooth`, `emphasized`,
  `pop`, `glide`, `exit`, `spring`, `settle`, `spin`, `drift` — entrances
  decelerate, exits accelerate on `exit`'s In curve, lateral state moves ride
  `glide`'s InOut, `pop`/`settle`/`spring` carry the Back-overshoot family),
  `motion.tween(instance, props, spec, onCompleted)` which drops
  already-satisfied properties and cancels an in-flight tween that would fight
  over the same property, `motion.spec(info)` for rescaling a bespoke
  TweenInfo (delayed glow beats, the odometer reel) with the active profile,
  `motion.step(base)` for cascade pacing, and the speed profiles (`relaxed`
  1.35x, `normal` 1x, `snappy` 0.7x, `instant` = no animation) behind the
  window's "Animation speed" setting. Public as `Astra.Motion`.
- `persistenceSettings.luau` — settings JSON encode/decode.
- `persistenceWrite.luau` — atomic write helper.
- `persistenceConfig.luau`, `persistencePaths.luau` — window-config serialization and key paths.
- `persistence.luau` — facade re-exporting the config + settings persistence
  surface (`getPath`, `save`, `load`, `applyTo`, `list`, `delete`,
  `getSettingsPath`, `saveSettings`, `loadSettings`); required by the window
  and by `settings/persistence`.
- `layouts.luau` — per-mode metric tables (`chromeHeight`, `fadeSize`,
  `cardCorners`, …) and dispatch into the `layouts/` builders
  (`get`, `implementation`, `railWidthFor`).
- `HapticEngine.luau` — vibration wrappers guarded by service availability.
- `moveable.luau`, `lockable.luau` — drag/lock mixins.
- `log.luau` — warn/error/log with Astra prefix.
- `locale.luau` — translation table + `SetTranslator` support.
- `filesystem.luau`, `filesystemManager.luau` — RobloxFS abstraction (isFolder/WriteFile wrappers, secure-mode aware).
- `assetResolver.luau`, `network.luau`, `services.luau` — platform layer (HTTP fetch with retries, service singletons).
- `windowSizing.luau` — responsive size computation (desktop tiers around the
  600x420 default, min/max protected) plus the fixed mobile profile returned
  for touch-only phone-sized viewports (`isMobileViewport`).
- `enums.luau`, `ordering.luau`, `odometer.luau`, `fontManager.luau`, `functions.luau` (legacy shim), `path.luau` — small helpers.

---

## scripts/ (verification + previews)

| Script | What it does |
|---|---|
| `generate_bundle.js` | Rebuilds `version-1.luau` from the modular tree. |
| `check_requires.py` | Static require graph: every module resolves, no cycles. |
| `check_instance_fields.py` | Fails on custom-field writes on instances (the crash class that came from writing bookkeeping fields onto Instances). Scans the modular tree only — skips the generated bundle and hidden/vendored dirs, where flat scanning would collide same-name locals across module scopes. |
| `check_dangling_refs.py` | Fails when a `.luau`/`.md` file names a slash-anchored repo path that does not exist (stale comments/docs after a delete or move). Skips URLs, tree diagrams, historical records and deleted/removed history lines; resolves relative links and extensionless module references. |
| `check_syntax.sh` | Compiles every published file (modular tree, `example.client.luau`, `version-1.luau`). A syntax error in a loadstring'd bundle is invisible to the user — it only shows up as `attempt to call a nil value` at line 1 of the executor's chunk — so this is the gate that catches it here. |
| `sidebar_tab_sizing_test.sh`, `smoke_test_bundle.sh` | Rail sizing (name-driven width, cap, restore) and a bundle smoke run; also the collapsed rail: rows are icon-only (title hidden, content centred, no expanded padding) whether they were collapsed in place, rebuilt by a layout switch, or created while the rail was already icon-only, and a capped title re-constrains after that rebuild. |
| `collapsible_group_test.sh` | Collapsible groups: every declarative element type, state/callbacks, the connected-card geometry and surface recipe, and the corner treatment (band's top arcs matching the container, body clipper's bottom arcs). |
| `isolated_test.sh` | Isolated changelog container: two-line header recipe with repo-pack icon and built-in chevron, the Changelog-only guard (exact message), runtime `SetTitle`/`SetSubtitle`/`SetIcon` reflow, and the CollapsibleGroup-style expansion/lock/instant-motion behaviour. |
| `instance_budget_test.sh` | Per-element instance ceilings plus a realistic-page budget — the frame-time proxy guard. |
| `odometer_test.sh` | Odometer readout: lazy row materialisation, and the resting row still showing the value's digit through plain/wrap/roll-down transitions. |
| `dropdown_rows_test.sh` | Dropdown option rows: none (and no search bar) while closed whatever the list length, one per option in order on open plus the bar once, the rendered selected/unselected state and corner tiers, reopening reusing the rows, edits and picks made while closed, and the search filter. |
| `dropdown_actions_test.sh` | The multi-select action row: only a multi-select dropdown builds it, the checkbox's two states (the drawn outline against the rows' check glyph), Select all filling the visible set and toggling it back off, Clear sparing what the filter hides, the box following picks and filters, the 32px row in the open height, and the bin resolving to the pack's trash icon. |
| `tab_elements_test.sh` | Tab elements: only the selected tab is walked on a show/hide, a tab opened later shows its elements in the same frame and state, the search shows every tab it renders, and a late element shows with its tab. |
| `tab_lock_test.sh` | Locked tabs: the preserved flag + badge (always hidden during the UI pause) and auto-select skipping a locked first tab; tap → notification with no selection; hover leaves the locked row dimmed; `Navigate`/`Select` guards; `SetLocked(false)` re-enables; locking the open tab moves the selection to a same-rail fallback; search excludes locked tabs' elements; locking every remaining tab clears the selection and hides content, and unlocking restores it; retained badge geometry with no layout reserve, full title slots, and hidden badges after collapse/rebuild. |
| `toggle_switch_test.sh` | Switch geometry: one set of metrics, mirrored resting states, equal clearance, the sheen under the knob, and the animated positions matching the built ones. |
| `mode_picker_test.sh` | Mode Picker: the 3..5 mode window, snap/Set/callback order and clamping, dot rebuilds on add/remove, the knob's stop scales, reset semantics, the description following the selected mode, the title wearing the icon's RGB — and keeping it through a hover cycle and a per-mode `icon_color` — plus the track geometry: the knob's clearance inside the track's pill at both end stops, the fill wearing the knob's own pill and reaching its trailing edge, the last stop leaving no unpainted tail, and the end dots still at the knob's centres. |
| `input_field_test.sh` | Field-box corners: the Input field rounds with the theme's `ElementCornerRadius` as a theme binding (pixel radius, never a capsule scale), re-stated on a theme switch, and shared with its element card. |
| `corner_scale_test.sh` | The corner scale: the three nested tiers (12px shell, 8px elements, 32px folds) and which surface wears which, the round-by-nature controls deriving a half-height pill from their own metrics (switch track/knob/sheen, slider track/fill/handle, drag pill), the dropdown's row tiers read from the panel that clips them, a `ChangeTheme` reaching every bound surface, the corners that stay square on purpose (the elements band's top edge), and a sweep that fails if any painted surface in the tree is left with an all-zero corner. |
| `keybind_input_test.sh` | Dedicated A–Z capture: required value, validation, focus handling, cancellation, current-key suppression, groups, flags, lock/removal/unload and settings validation. |
| `keybind_persistence_test.sh` | Config and settings round trips; unsupported legacy bindings migrate to required K. |
| `capsule_visibility_test.sh` | Held-tween assertions before/after Hide completion, both styles, restore, topbar minimisation, instant motion and stale completion after unload. |
| `example_test.sh` | Runs the real local demo; covers every element, information-first tabs and no single-child Collapsible Groups in the demo/settings. |
| `slider_travel_test.sh` | Slider knob travel: the capsule's centre stays half a knob inside each track end (resting, held and after release), so it never overlaps the track end or card edge at max/min, and the fill ends at the knob's centre. |
| `icons_test.sh` | Icon resolver: name-only lookup across the packs in priority order (and how lazily they load), qualified `pack:name`, case sensitivity, unknown-pack warnings, custom assets (one import per path, memoised misses, the `listfiles` index), cache-key separation, and `window:ResolveIcon`. |
| `motion_test.sh` | Motion service: shared specs, time scale + its cache, profiles, tween ownership (cancel-on-overlap vs. unrelated properties), the no-op and animation-off paths, the window's "Animation speed" setting, and hover going through the service. |
| `anti_duplicate_window_test.sh` | Anti Duplicate Window: sequential CreateWindow replaces the previous shell, per-window opt-out still allows a second window, overlapping constructions from rapid re-entry collapse to exactly one live window, and replacement never interrupts active construction — a window whose host thread is suspended at a pacing checkpoint is marked unloaded at once and torn down only once that construction goes quiet, and a construction overtaken mid-`Window.new` hands its host a window that keeps accepting constructors before it is torn down unshown. |

All of them assemble `scripts/sidebar_sizing_stubs.luau` + `version-1.luau`
(so regenerate the bundle after a source edit) and run under the Luau CLI.

## Naming conventions after minification

| Pattern | Meaning |
|---|---|
| `a1`–`aN` (file-scope) | top-level requires, in require order |
| `a1`–`aN` (in-function) | per-function locals, in declaration order |
| `self`, method names | untouched (public/private API surface) |
| Roblox property string keys | untouched |
| Icon-name strings, config flags | untouched (data) |

When touching a minified file, re-minify only that file, then
`luau-compile` it and run `scripts/check_requires.py`,
`scripts/check_instance_fields.py`, `scripts/check_dangling_refs.py`, and
`node scripts/generate_bundle.js` — or just `sh scripts/check_all.sh`, which
runs every gate including the runtime tests.
(Validate against the full tree with `scripts/smoke_test_bundle.sh`.)
h`.)
`, which
runs every gate including the runtime tests.
(Validate against the full tree with `scripts/smoke_test_bundle.sh`.)
h`.)
