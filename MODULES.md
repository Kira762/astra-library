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
- Singleton bookkeeping: existing-window guard backed by a module-local `activeWindow` **and** a `getgenv()`-backed global store (key `__ASTRA_ACTIVE_WINDOW_V1`) so the anti-duplicate guard survives across `loadstring`ed instances; the `CreateWindow` dispatcher (pcall around `components.window.new`, re-throws on failure); the export table.
Exported names (typed surface is `Types.luau`'s `Astra`): `CreateWindow`, `Icons`; `Core` and `Settings` are also assigned on the table at runtime. There is no top-level `ChangeTheme`/`SetLocale`/`SetTranslator`/`RegisterTranslations`/`Unload` — those are window methods.
`CreateWindow` side effects: enforces the anti-duplicate guard (persisted `antiWindowDuplicate` setting, per-window opt-out via `settings.antiWindowDuplicate`), in secure mode preloads window images (`Image.preload` → failure `Notify`) and swaps in the brand fonts via `ChangeTheme({ Font, TitleFont })` once the entrance has landed (a theme pass over every instance the window owns is not something to spend while the window is still arriving; `FONT_SETTLE_BUDGET` bounds the wait so a window that never shows still gets its font), then auto-`Show()`s the window on the next frame (a `task.defer` plus one heartbeat, so a script's first synchronous `CreateTab` calls land before the shell appears; remaining constructors stream in behind it in small budget-limited batches until the build goes quiet, and an explicit `Hide()` before that tick cancels it via `_autoShowCancelled`). The two secure-mode branches (optional-icon preload, brand-font swap) run as sibling threads under one guard.

### `example.client.luau`
Usage example (not minified). Loads the bundle with the single-line loader — `local Astra = loadstring(game:HttpGet(url))()` — then builds one tab holding every supported element type: Section, Text, Stat, Divider, Button, Toggle, Slider, a single-select and a multi-select Dropdown, Input, an ordinary Group, a Collapsible Group of declarative children and an Isolated changelog container; release history renders via `tab:CreateChangelog` (see `changelog.example.luau`). It ends with an explicit `elements:Select()` so the run is deterministic.

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
  `Enum.Font.BuilderSans`) + `setFallbackFont(font)`; `brandFont(weight)` —
  font resolver honoring the platform's brand font override.
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
`antiWindowDuplicate`, `layoutMode`), `rfSettings` (the
built-in "General" settings tab), `_settingsTabs` (settings-tab list),
`_settingsMode` / `_previousTab` (settings-mode bookkeeping),
`settingsAction` / `minimiseAction` (topbar actions), `drag`,
`collapsedInteract`, `connections` / `instances` / `themeProperties` /
`localeProperties` / `controls` / `tabs` (lifecycle registries),
`Flags` (metatable view over `controls`).

Method map (names preserved through minification). Settings-related:
- `_buildSettingsUI` — creates the six built-in settings tab shells
  (General via `rfSettings`, plus Appearance, Behavior, Performance,
  Persistence, About; all `isSettingsTab`, `forgetState`). Rail/page order
  follows `customOrder` (General 1001 first, About 1006 last) so opening
  settings highlights the first rail row. Element content is built lazily:
  each tab stores a `_settingsContentBuilder` closure and
  `Window:_buildSettingsContent(tab)` runs it on the tab's first open
  (`Tab:Select`, after construction), so `CreateWindow` stays fast.
  Appearance hosts the theme picker and the Bar Layout picker (both
  popup-confirmed), plus window toggles, Reset Window Position (recentres
  the window) and Reset Capsule Position;
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
  for `Unload`.
  `_railGroup(tab)` / `_activeRail()` — the main/settings rail filters every visibility site shares.
- `ChangeTheme`, `CreateTab`/`CreateSection`, `Notify`
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
Dedicated settings component providing UI generation and management for Astra's built-in settings tabs (Appearance, Persistence, About, and General controls):
- `keyLabel(item)` / `parseKey(text)` — the menu binding's display and parse
  rules. The General → Toggle Keybind row is an ordinary `Input` field, so the
  label writes the bound key's name into it (`None` when unbound, `MB2`/`MB3`
  for mouse buttons) and the parse reads a typed name back into the `EnumItem`
  `window.settings.toggleKeybind` holds: canonical names for the keys people
  type (`k`, `space`, `left shift`, `f7`, `5`, `mb2`/`rmb`), separators dropped,
  an empty field or `none` clearing the binding, left click refused, and any
  unlisted name left to an `Enum.KeyCode`/`Enum.UserInputType` lookup. Text
  that names no key is refused with the previous binding restored.
- `buildUI(window)` — instantiates the settings tab shells on demand. The About
  tab's builder renders one `elements/aboutCard` (brand header, the version /
  build / author rows and the description paragraph) from the module-local
  `aboutVersion`, `aboutBuild` and `aboutAuthor` strings, which a release bumps;
  the card's optional action band is left off there because the tab has no
  changelog to open.
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
  state writes the same values. Hovering the hitbox reveals the hover look;
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

### `components/notification.luau`, `popup.luau`, `tooltip.luau`
Overlay queues: `a1..a4` — container frame, TweenInfo presets, queue table, active-instance guard.
`Notification.new(window, props, release)` takes the entrance slot from `components/overlayQueue.luau` and hands it
back from `_entranceDone` when its staged fades are committed (icon, then
description); `Window:Notify` builds the layer
immediately but constructs the card only on its turn, so a burst at load time
costs one card per frame instead of all of them at once. `Popup` is modal and
stays outside the queue.
Exact notification title/content pairs are keyed per window. `Notification.refresh`
reuses active cards and resets their shared hold counter/duration; the entrance
queue coalesces pending keys with the newest snapshot (before enforcing its cap).
Matching is case/whitespace-sensitive, honours aliases/defaults, and does not
include icon or duration. Dismissed/expired cards do not block future requests.

`tooltip.luau` retains the independent `Window:ShowTooltip` / `HideTooltip` API:
one locale-aware floating panel per window, positioned over the supplied anchor.
The functional `(!)` badges and their hover/tap/hold wiring have been deleted.
Window transitions and teardown still close programmatic descriptions.

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
- `dropdown.luau` — button, list frame, option rows (built on first open, `_materialiseOptions`/`_buildOptionAt`), highlight, search filter, and the multi-select action row: a checkbox in the rows' own 16px glyph slot (a drawn 12px outline when off, the rows' check glyph when on) with Select all, which toggles the visible options, and Clear with its pack bin, which removes only those. The box is re-synced by every path that can move the selection or the visible set (`_syncActions`), and only a multi-select dropdown builds any of it.
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
  band are the window surface with the element corner and stroke
  (`insetSurface`), and a badge is the content surface. The tiles are packed
  against the card's measured width (`_availableWidth` reads the card and falls
  back to the default window's content width before the first measure,
  `_rowMinWidth` measures each row's own copy with the fonts it renders in, and
  `_packRows` is a greedy fill where a line costs its widest tile times its tile
  count plus the gaps) so a line never squeezes a tile below its copy: the tiles
  that fit share the line evenly and the rest wrap under it (`_layoutRows`), and
  the packing re-runs from the card's `AbsoluteSize` watcher and after `SetRow`
  changes a row's copy. A fourth row errors at construction with
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
- `divider.luau`, `stat.luau`, `text.luau` — display and interaction elements.
- `footer.luau` — the centred inline text-and-icon strip ("Built with ⚡ Astra ♡"):
  an ordered run of `{ text }` / `{ icon }` segments under one centring list
  layout; icons resolve through the catalog, scale with `textSize`, and
  unresolvable names drop instead of leaving gaps. `Set` rebuilds the run.
- `button.luau` — action card with a built-in right-edge tap glyph (`tapIcon` opts out or replaces it), themed through `ContentColor`, revealed with the card, and pulsed on press. Compact/grouped buttons explicitly sort their horizontal layout by `LayoutOrder`: optional custom icon, title, then built-in tap glyph.
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
  `antiWindowDuplicate` (boolean/behavior), `layoutMode` (enum/appearance).
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
  whitelists `layoutMode ∈ { top, sidebar, collapsedSidebar }`.

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
- `default.luau` + 9 themes (`amethyst`, `cobalt`, `crimson`, `ember`,
  `emerald`, `frost`, `gold`, `onyx`, `rose`) — theme tables of ~65 keys
  (surfaces, strokes, text colors, gradients, fonts, corner radii,
  slider/toggle/picker styling). Keys a theme omits are inherited from the
  `default` clone. Registered in two places: the settings-UI theme table in
  `components/window/theme.luau` and the persisted-theme whitelist in
  `utilities/persistenceSettings.luau`.
  The three window sections are painted from dedicated surface tokens with a
  strict luminance hierarchy — `TopbarSurface` (darkest band),
  `SidebarSurface` (the tab rail, one step lighter) and `ElementSurface`
  (the elements area, lightest) — and every built-in theme keeps that order
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
| `check_instance_fields.py` | Fails on custom-field writes on instances (the crash class that came from writing bookkeeping fields onto Instances). |
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
| `input_field_test.sh` | Field-box corners: the Input field rounds with the theme's `ElementCornerRadius` as a theme binding (pixel radius, never a capsule scale), re-stated on a theme switch, and shared with its element card. |
| `keybind_input_test.sh` | Menu-toggle binding: the Settings menu binding is an `Input` field whose typed text commits an `EnumItem` (case/alias tolerant, `MB2`, `none`/empty clearing), refuses junk and left click without saving, keeps typing inside the field from toggling the window, and still toggles it afterwards. |
| `slider_travel_test.sh` | Slider knob travel: the capsule's centre stays half a knob inside each track end (resting, held and after release), so it never overlaps the track end or card edge at max/min, and the fill ends at the knob's centre. |
| `icons_test.sh` | Icon resolver: name-only lookup across the packs in priority order (and how lazily they load), qualified `pack:name`, case sensitivity, unknown-pack warnings, custom assets (one import per path, memoised misses, the `listfiles` index), cache-key separation, and `window:ResolveIcon`. |
| `motion_test.sh` | Motion service: shared specs, time scale + its cache, profiles, tween ownership (cancel-on-overlap vs. unrelated properties), the no-op and animation-off paths, the window's "Animation speed" setting, and hover going through the service. |

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
`scripts/check_instance_fields.py`, and `node scripts/generate_bundle.js`.
(Validate against the full tree with `scripts/smoke_test_bundle.sh`.)
h`.)
