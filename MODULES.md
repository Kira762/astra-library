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
Usage example (not minified). Loads the bundle with `game:HttpGet` + `loadstring`, then builds a 20-tab window: Home, Controls, Appearance, Information, Changelog, Updates, plus 15 labelled test tabs. Demonstrates window tags, every element type, groups, and the `CreateChangelog` element (including a runtime `changelog:Add`), and ends with an explicit `home:Select()`.

---

## core/

### `core/init.luau`
- Requires `state`, `registry`, `loader` and exposes them as one table:
  `core.state`, `core.registry`, `core.loader` (the entrypoint and
  `components/*` consume it via `require(...core)`).

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

### `core/registry.luau`
- `a1..a3` — name→module map, lazy getter, registration list. `registerFactory` lets components override element factories.

### `core/loader.luau`
- `knownModules` — allow-list (`state`, `registry`); `loader.load(name)` requires a known core module exactly once (re-entrant guard + pcall re-throw).
- `loader.service(name, factory)` — registers an element factory override through the registry and returns it.

---

## components/

### `components/window.luau` (the largest module; class `Window`, minified as `a17`)
Constructor/`new` locals:
- `a2..a5` — `core.state`, `functions.colors`, `functions.textMetrics`, `utilities.layouts`.
- `a6..a14` — zIndex/display-order constants, default window props, layout-mode resolution.
- `a15` — `core.state` runtime table (services, localPlayer, tweenService…).
- `a4.toColorSequence` — gradient coercion helper for theme values.

Notable instance fields set in `new`: `screenGui`, `main`, `elements`,
`tabList`, `sidebar`, `settings` (plain table: `toggleKeybind`, `theme`,
`mouseOverride`, `keepOnScreen`, `welcomeToast`, `haptics`,
`dragMinimisedBar`, `showProfile`, `showFullUsername`,
`antiWindowDuplicate`, `layoutMode`, `activeSubTab`), `rfSettings` (the
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
  Appearance hosts theme picker + Bar Layout picker (both
  popup-confirmed), the profile toggles (Show profile, Profile side
  Right/Left, Reveal profile details — refused with a "Show profile is
  required" notification while Show profile is off, and switched off with
  the card when Show profile goes off) and window toggles, Reset Window
  Position (recentres the window + card pair) and Reset Capsule Position;
  Persistence always hosts saved-config Save/Load/Delete (independent of
  the `configuration` prop), plus default-on Auto Save Config and Auto Load
  Config toggles. Storage defaults are internal; the named-preset dropdown
  does not expose the default config filename. Auto-save writes are coalesced.
- `settingsAction` (topbar gear, `linkedTab = rfSettings`) — toggles
  settings mode via `_toggleSettingsMode`: entering shows only settings
  tabs and remembers the previous tab; a second click restores it. The
  profile card no longer carries its own gear, so the topbar action is the
  single settings entry point.
- `_applySettingsLayout(active)` — reflows rail/elements for settings mode.
- `SaveSettings` / `LoadSettings` — per-window settings persistence via
  `utilities.persistence` (settings JSON, includes `activeSubTab` round-trip).
Public surface:
- `Create(className, props, themeBindings?)` — instance factory: theme-bound
  property recording (`themeProperties`), locale-token binding
  (`_bindLocale`), image-guessed property assignment; tracks every instance
  for `Unload`.
- `ChangeTheme`, `CreateTab`/`CreateSection`, `Notify`/`Toast`
  (both construct their card on the entrance queue's turn, see
  `components/overlayQueue.luau`)/`Popup`, `Show`/`Hide`/`ToggleHide`/`ToggleMinimise`, `Close` (animated
  close → `Unload`), `Save`/`Load`/`ListConfigs`/`DeleteConfig`/`GetPath`,
  `Get`/`Set`, `Navigate`, `SetLocale`/`SetTranslator`/
  `RegisterTranslations`, `ResolveIcon`, `SetProfile`, `Unload`.
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
`_clampedPosition` (keep-on-screen clamp — measures the window + profile-card
pair through `profilePanel.pairHalfSize`, so neither half can be dragged off
the edge), `_profileCenterPosition`/`_recenterForProfile` (window + profile-panel
recentering; re-derived by `_firstShow` and `_quickRestore` while the window is
still at its anchored resting spot, and by `ToggleMinimise`'s expand, which
re-clamps for the card that comes back), `_setLayoutMode`, `_toggleSettingsMode`
(topbar gear), `_registerControl`/`_unregisterControl`/`_persist`,
`_runGuarded`, `_setElementLocked`/`_buildLockScrim`, `_updateWindowTitle`.

### `components/settings.luau`
Dedicated settings component providing UI generation and management for Astra's built-in settings tabs (Appearance, Persistence, About, and General controls):
- `buildUI(window)` — instantiates the settings tab shells on demand.
- `buildContent(window, tab)` — lazily constructs controls within a given settings tab upon first selection.
- `toggleSettingsMode(window)` — toggles between user tabs and settings tabs.
- `setSettingsMode(window, active)` — applies visibility and layout for settings mode.
- `applySettingsLayout(window, isSettings)` — manages tablist and layout visibility between modes.

### `components/sidebar.luau`
Tab-rail reflow (the profile system moved to `components/profilePanel.luau`):
- `maskUsername(name)` — shared masking helper (first 3 chars + `****`), used by the profile panel.
- `buildTabRail` — rail ScrollingFrame + UIPadding + UIListLayout (the layout implementations build their own rails).
- `applyRailRows(window, width, layout)` — rows collapse only at the icon-only width (the responsive rail is often narrower than the old 219px fixed rail); ends with `tabSelector.relayoutSidebarRows`.

### `components/profilePanel.luau`
The profile panel — a compact 260x420 companion card floating beside the
window frame (a sibling in the same ScreenGui), exactly the default window's
height, replacing the in-window profile. Its surface is built by
`Window:StyleWindowSurface` — the same call that builds the window frame's own
background — so the plate takes the window's base colour, `WindowColor`
gradient (same rotation/offset), `CornerRoundness` corners, SurfaceStroke and
ShadowColor glow, shows at the window's own opacity (and fades with it on
show/hide), and follows the window's live gradient animation when the theme
turns it on. It reads as part of the shell rather than a separate card, and it
matches the design mock's structure:

- **Pinned header** — 48px avatar with a presence dot and hairline ring,
  left-aligned display name (`TitlingColor`, 15px) over the `@username`
  subtitle (12px, `TitlingColor` at the window's 0.7 secondary
  transparency) and the tier pill (PREMIUM / FREEMIUM from
  `MembershipType`, or the host's own word; it rides the handle row and
  drops below the name only when it does not fit). A 1px divider closes
  the header. The card carries no settings gear — the window's topbar gear
  is the only settings entry point.
- **Scrolling details** — `Account`, `Current Game`, `Server` and
  `User Session` headings styled exactly like the window's Section element
  (16px `ContentColor` icon at 0.65, 15px `ContentColor` title at 0.6)
  over plates styled exactly like the window's element bodies
  (`Window:StyleElementBody`: `ElementGradient` over a white body at
  `ElementTransparency`, `ElementCornerRadius`, `ElementStroke` at
  `ElementStrokeTransparency`): User ID (COPY), Join date, Account age,
  Key (COPY) and Whitelist; the game thumbnail, the official game name and
  Place ID (COPY); Players and Job ID (COPY); and the session timer.
  Row icons/labels/values reuse the element row colours (`ContentColor`,
  muted labels at 0.45). Only this region scrolls — the header never
  moves, the card never grows past the window's height, and the 6px themed
  scrollbar appears only once the content is taller than the region.

- `build(window)` — builds the surface, header, detail cards and tooltip;
  avatar with a generation guard via `images.image.avatar`; text truncated
  at end. Mirrors `main`'s Position through property-change signals, so it
  follows drags/restores/resizes without a per-frame loop.
- `layout(window)` — places the fixed-size card on the selected side
  (`settings.profileSide`, default `"right"`) flush with the window edge
  (12px gap), vertically centred on the window's centre; re-flows the
  scroll region (and its scrollbar thickness) whenever the window height
  or the content changes, so the card never has to be taller than the
  window.
- `setShown(window, shown, info)` — effective = requested AND enabled AND
  window visible (not hidden/minimised); fades every registered target
  (panel pieces, text, tier pill); idempotent (skips instances already at
  target).
- `applyLive(window)` — the 1s Heartbeat tick while the card is shown:
  player count (`#Players:GetPlayers()` / `MaxPlayers`), session time
  (`os.clock()` since the panel loaded) and the whitelist countdown. The
  connection is stored once in `window.profileRefreshConnection`.
- `isEnabled` / `isShown` / `shiftFor` — content-enabled check
  (`showProfile` on, player known, and the screen has horizontal room for
  window + gap + panel plus vertical room for the card's height — a space
  check, so landscape phones count), the same plus the window's own
  visibility (what the on-screen clamp asks: a minimised capsule is not
  shoved around by a card that is not there), and the off-centre shift
  `((260 + 12) / 2 = 136px)`, 0 while the panel is off.
- `pairHalfSize(window, width?, height?)` — how far the window + card pair
  reaches left, right and up/down from the window's centre: the card adds
  `width + gap` to its own side and, at 420px, can out-tall a short window.
  Plain window halves while the card is not shown. `Window:_clampedPosition`
  and the topbar drag both clamp with it, so "Keep window on screen" keeps
  the card on screen too.
- `setEnabled`, `setSide` — settings drivers (both recenter the window).
  `setEnabled` also raises a notification when the card is switched on but
  `hasRoom` fails, so an active toggle on a cramped viewport explains
  itself instead of showing nothing; switching the card *off* clears the
  reveal toggle with it (and says so), returning `revealCleared` so the
  settings UI can roll its switch back.
- `revealEnabled(window)` — the "Reveal profile details" toggle, still
  persisted under the legacy `showFullUsername` key.
- `revealAllowed` / `setReveal` / `syncReveal` — that toggle's dependency on
  `showProfile`: it unmasks values that live on the card, so `setReveal`
  refuses the on state while the card is off (setting stays off, card stays
  masked, "Show profile is required" notification, `false` returned so the
  caller rolls its switch back), and `syncReveal` normalises settings that
  arrive from disk with reveal = on and the card off (`Window:LoadSettings`).
- `applyIdentity(window)` — writes every identifying value on the card
  from the local player and that toggle: display name (headline) and
  @username (subtitle) through `sidebar.maskUsername`, user ID, place ID
  and job ID as a fixed `••••••` block, and drives the COPY buttons
  (registered in `window.profileCopyButtons`, each hidden while its value
  is masked, and each refuses to copy a masked value). A successful copy
  swaps the glyph for the success check for ~1.2s, states "Copied" on the
  button's own label (the glyph-only button's accessible name; no hover
  surface rides on the press), and then restores it; a
  repeat press cancels the pending timer and restarts the window, so two
  restores never race for one icon. An explicit
  `Window:SetProfile` subtitle is developer copy, so the toggle leaves it
  alone. Nil-safe on both the instances and the player; runs at the end of
  `build`, so the card never shows an unmasked value first.
- `applyLicense` — the host-owned key and whitelist rows. Astra ships no
  key store of its own, so the key and whitelist come from what the host
  handed to `Window:SetProfile` and read `—` when nothing was supplied.
  `applyLicense` takes `{ key, tier, whitelist = { status, daysLeft |
  expiresAt } }` (the host's table, copied, never mutated): the whitelist
  row shows `14 days left`, `1 day left`, `Expired`, a non-"Active" status
  spelled out, or the placeholder.
- `cardIcon(window, name)` — every icon the card draws, resolved against the
  window's active icon pack through a name-alias table (`iconAliases`) that
  starts with the lucide name and lists the other packs' equivalents
  (`badge-check` -> `check-badge` / `seal-check` / `verified_user` / `award`,
  `copy` -> `clipboard` / `content_copy`, ...). A window built with any pack
  therefore draws the card's icons instead of empty squares; the answer is
  cached per window, and the default pack resolves to exactly the icons it
  always used.
- `tierText` / `applyTier` — the header tier pill. A host `tier` (uppercased)
  wins; otherwise `MembershipType` decides PREMIUM vs FREEMIUM, so the pill
  always states a real tier. PREMIUM keeps the accent crown; any other tier
  reads in the muted placeholder colour with a badge icon, and the pill width
  is re-measured from its own label. Both icons go through `cardIcon`, so the
  pill states its tier with an icon on every pack.
- `flashCopied(window, name)` / `setCopyStatus` — copy feedback: the row's
  copy icon becomes a green (`Success`) check for ~1.2s and then returns to
  the copy icon, while the button's own label says what it
  copies ("Copy Job ID") and "Copied" while the check is up. A repeat click
  cancels the pending timer and restarts the window (so two restores never
  race for one icon) and a rebuilt card is ignored. The copy itself goes
  through the executor's clipboard entry point (`setclipboard` and the common
  aliases), so a missing/failing function means no feedback rather than a
  false success.
- `fetchUniverseId` / `resolveUniverseId` / `fetchGameName` — the official
  two-step game-name flow: `apis.roblox.com/universes/v1/places/{PlaceId}/
  universe` converts the place to its universe, then
  `games.roblox.com/v1/games?universeIds={UniverseId}` answers the game
  detail list whose matching entry's `name` is the game name. Cached per
  place and queued while in flight; `resolveUniverseId` prefers
  `DataModel.GameId` and also feeds the thumbnail fetch, and the label keeps
  `DataModel.Name` until the platform answers.
- `setProfile` / `setSubtitle` / `refreshName` — `Window:SetProfile`
  accepts a string or `nil` (legacy: swaps only the subtitle line and
  leaves the host's key/tier/whitelist rows alone), or a table
  (`{ subtitle, key, tier, whitelist }`; omitted fields clear their rows).
  `refreshName` is kept as an alias for `applyIdentity`.
- `showTooltip` / `hideTooltip` — the card's own hover-help for values
  that do not fit their row (measured with `functions.textWidth`), for the
  display name and for the game name, shown on the card surface so the
  scroll region never clips it. The label stacks above the surface itself
  (`ZIndex` 11 over the surface's 10) because the window's ScreenGui stacks
  by global z-index; copy buttons deliberately raise no tooltip of their
  own — the glyph and the green check are the whole press feedback.

The window rests off-centre so window + gap + panel are centred as one unit
(`Window:_profileCenterPosition` / `Window:_recenterForProfile`): with the
panel on the right the window sits 136px left of screen centre, and
vice-versa. The resting centre is re-derived whenever the pair's state can
have changed while nothing was on screen to move — `_firstShow` (a player
turning up between the build and the first show), `_quickRestore` (a recenter
that ran while hidden only parks `_restorePosition`) and `_applyWindowSize`
(viewport changes) — but only while the window is still at its anchored
`0.5/0.5` spot, so a position the user dragged to is never overridden
(Reset Window Position recentres the pair on purpose). The panel hides when
the screen lacks room for the pair (portrait phones) and with
hide/minimise/close.

### `components/drag.luau`
- `utility` — `core.state` alias. Locals `a1..a8` — drag input state (start pos, delta thresholds, RenderStepped connection).

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
changes, tab removal), `Tab:Remove`, `Window:SetLocale` and
`Window:ChangeTheme`. No-op for the topbar and collapsed-sidebar layouts.
`applyRailRows` treats the rail as collapsed only at the icon-only width
(`railCollapsedWidth`), so a content-sized rail narrower than the old fixed
219px still shows titles.

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

### `components/notification.luau`, `toast.luau`, `popup.luau`
Overlay queues: `a1..a4` — container frame, TweenInfo presets, queue table, active-instance guard.
`Notification.new(window, props, release)` and `Toast.new(window, props, parent,
release)` take the entrance slot from `components/overlayQueue.luau` and hand it
back from `_entranceDone` when their staged fades are committed (icon, then
description/subtitle); `Window:Notify`/`Window:Toast` build the layer
immediately but construct the card only on its turn, so a burst at load time
costs one card per frame instead of all of them at once. `Popup` is modal and
stays outside the queue.

### `components/search.luau`
Fuzzy search overlay: locals for candidate list, scoring weights, debounce connection.

---

## layouts/

One module per bar-layout mode, each with `Build(window, layout)` (creates the
tab strip and rail chrome) and `ApplyWidth(window)` (reflow):

- `Topbar.luau` — mode `top`: horizontal tab strip in the topbar.
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
- `keybind.luau` — listening state flag, input connection. Editable fields keep the current key selected, accept exactly one letter (extras are truncated, non-letters dropped), unbind on backspace while staying focused for the next key, and restore the bound key's display on focus loss; capture mode is unchanged.
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
- `description.luau` — legacy in-card helper-line utility kept for bundle
  compatibility; public element constructors no longer read `description` props.
- `tab.luau` — tab class: `tabPage` (ScrollingFrame), `_register(element)` pipeline into `window.controls[flag]`, selector button visuals.
- `group.luau`, `section.luau`, `tabSection.luau` — container classes with UIListLayout locals.
- `changelog.luau` — release-history element (`__type = "Changelog"`): normalizes `ChangelogEntry`/`ChangelogChange` props, maps symbols (`+`/`-`/`~`, or words like "added"/"removed"/"changed") to green/red/amber, fades entries in, supports `Set`/`Refresh`/`Add(entry, prepend?)`/`Clear`.
- `divider.luau`, `stat.luau`, `text.luau` — display and interaction elements.
- `button.luau` — action card with a built-in right-edge tap glyph (`tapIcon` opts out or replaces it), themed through `ContentColor`, revealed with the card, and pulsed on press.
- `baseCard.luau` — shared card container and header layout helper for element modules.

---

## settings/

- `init.luau` — module wiring: exports the `manager`, `registry`, `defaults`,
  `persistence` modules plus `settings.newManager(overrides)` and
  `settings.readPersisted(key, default)` (used by the entrypoint for the
  anti-duplicate guard).
- `registry.luau` — `definitions`: one `{ key, kind, domain, description }`
  entry per setting. Keys: `toggleKeybind` (keybind/behavior),
  `mouseOverride` (boolean/behavior), `keepOnScreen` (boolean/appearance),
  `welcomeToast` (boolean/behavior), `haptics` (boolean/performance),
  `showProfile` (boolean/appearance), `showFullUsername` (boolean/appearance —
  documented as requiring `showProfile`, the rule `profilePanel.setReveal`
  enforces),
  `antiWindowDuplicate` (boolean/behavior), `layoutMode` (enum/appearance),
  `activeSubTab` (enum/appearance — persisted, retained for compatibility
  with the pre-rebuild sub-tab UI). Lookup: `registry.definition(key)`,
  `registry.keys()`.
- `defaults.luau` — `values`: flat defaults (`toggleKeybind = Enum.KeyCode.K`,
  `layoutMode = "top"`, `activeSubTab = 1`, …); `defaults.clone(overrides)`.
- `manager.luau` — `SettingsManager.new(overrides)` → `{ defaults =
  defaults.clone(overrides), persistence = {} }`; methods `get`, `set`
  (routes through `registry.definition` + the domain validator, returns false
  for unknown keys), `reset`, `onChange(listener)`, `save`, `load`.
- `persistence.luau` — save/load/read of the per-window settings JSON over
  `utilities.persistenceSettings` (round-trips `activeSubTab` and friends).
- `appearance.luau`, `behavior.luau`, `performance.luau` — per-domain
  `validate(key, value) -> (ok, normalized)`. Appearance additionally
  whitelists `layoutMode ∈ { top, sidebar, collapsedSidebar }` and floors
  `activeSubTab` to an integer ≥ 1.

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
  close, minimize, profile placeholder, …).
- `cache/imageCache.luau` — disk/memory cache; `pcall(callback, uri or "")` at the end of the retry chain.
- `cache/moduleCache.luau`, `persistenceCache.luau`, `init.luau` — generic memoization layers.

---

## icons/

- `init.luau` — public surface (`get`, `resolve`, `getByPack`, `list`,
  `packs`, `count`, `isPack`, `priority`, `loaded`, `refreshCustom`) with lazy
  metatables per pack: a pack's data module is required on first lookup, then
  cached (`packLoaders` / `loadedPacks`). Name-only lookup walks the packs in
  `PACK_ORDER` (lucide, material, tabler, phosphor, heroicons, feather) and
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
  `components/window.luau` and the persisted-theme whitelist in
  `utilities/persistenceSettings.luau`.
  `CardSurface` (Color3, from the `2ecd628` settings-card fix) is still
  defined in every theme but no longer referenced by the rebuilt settings
  UI — kept for compatibility.

---

## utilities/ (selected)

- `constants.luau` — static constants incl. `icons` map (with `profileAvatarPlaceholder`).
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
- `persistenceSettings.luau` — settings JSON encode/decode; `activeSubTab` round-trips here.
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
| `check_instance_fields.py` | Fails on custom-field writes on instances (the `_profileGeneration` crash class). |
| `profile_{compact,centering,reveal,details}_test.sh` | Profile card suites: geometry/visibility, window-pair centring, the reveal toggle, and the redesigned card (tokens, pinned header + scrolling, live server/session values, license rows, tooltip, no-player case). |
| `sidebar_tab_sizing_test.sh`, `smoke_test_bundle.sh` | Rail sizing (name-driven width, cap, restore) and a bundle smoke run; also the collapsed rail: rows are icon-only (title hidden, content centred, no expanded padding) whether they were collapsed in place, rebuilt by a layout switch, or created while the rail was already icon-only, and a capped title re-constrains after that rebuild. |
| `collapsible_group_test.sh` | Collapsible groups: every declarative element type, state/callbacks, the connected-card geometry and surface recipe, and the corner treatment (band's top arcs matching the container, body clipper's bottom arcs). |
| `instance_budget_test.sh` | Per-element instance ceilings plus a realistic-page budget — the frame-time proxy guard. |
| `odometer_test.sh` | Odometer readout: lazy row materialisation, and the resting row still showing the value's digit through plain/wrap/roll-down transitions. |
| `dropdown_rows_test.sh` | Dropdown option rows: none (and no search bar) while closed whatever the list length, one per option in order on open plus the bar once, the rendered selected/unselected state and corner tiers, reopening reusing the rows, edits and picks made while closed, and the search filter. |
| `dropdown_actions_test.sh` | The multi-select action row: only a multi-select dropdown builds it, the checkbox's two states (the drawn outline against the rows' check glyph), Select all filling the visible set and toggling it back off, Clear sparing what the filter hides, the box following picks and filters, the 32px row in the open height, and the bin resolving to the pack's trash icon. |
| `tab_elements_test.sh` | Tab elements: only the selected tab is walked on a show/hide, a tab opened later shows its elements in the same frame and state, the search shows every tab it renders, and a late element shows with its tab. |
| `toggle_switch_test.sh` | Switch geometry: one set of metrics, mirrored resting states, equal clearance, the sheen under the knob, and the animated positions matching the built ones. |
| `input_field_test.sh` | Field-box corners: the Input field and the Keybind cap round with the theme's `ElementCornerRadius` as theme bindings (pixel radii, never capsule scales), re-stated on a theme switch, and shared with their element cards. |
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
