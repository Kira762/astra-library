# Astra v1 — Usage Guide

Load Astra and build your first window in a few lines.

---

## Load the library

One loader, one line — this is what `example.client.luau` does:

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()
```

Three things have to be right for that line to return a table:

- **The URL is the raw file of a public repo**, pointing at the published bundle
  `version-1.luau`. It is a generated artifact — load the single bundle, never the
  modular tree. `game:HttpGet` also needs `HttpService` requests enabled.
- **The runtime has `loadstring`.** Executors provide it; plain Studio does not, so in
  Studio / Rojo the library is a ModuleScript and you `require` it instead
  (`require(game:GetService("ReplicatedStorage").Astra)`). That is a load path, not a
  second loader — nothing that fetches the bundle does anything else.
- **The trailing `()` is there.** `loadstring(text)` only *compiles*; it returns the
  chunk, and calling it is what runs Astra and hands back the module table. `local
  Astra = loadstring(...)` without the call gives you a function, and every later
  `Astra:CreateWindow` fails with `attempt to index a function value`.

**What a failed load looks like.** `loadstring` does not throw when the text will not
compile — it returns `nil` plus the error, so the one-liner reports nothing more useful
than

```
rAnDoMcHuNkNaMe:1: attempt to call a nil value
Stack Begin
Script 'LocalScript', Line 1
Stack End
```

That message is about the *loader*, not about a bug inside Astra: the random name is the
executor's chunk, `Line 1` is the line holding the call, and "attempt to call a nil
value" only means the compiled chunk was `nil`. Read it as "the text I fetched never
compiled" and check, in order:

1. **The fetch returned something that is not Luau.** A private repository, a wrong
   branch/file name, or a rate limit all hand back an HTML error page (`404: Not
   Found`, `<html>…`) which never compiles. `print(game:HttpGet(url):sub(1, 120))`
   settles it in one line.
2. **The source really does have a syntax error.** Published files are compile-checked
   with `scripts/check_syntax.sh`; run it after editing anything here, then regenerate
   with `node scripts/generate_bundle.js`.

Once the line returns a table the compile is fine, and any later
`attempt to call a nil value` names the Astra line that called it — a missing
element method, a `Create…` on the wrong parent (Collapsible Groups live on a
Tab, not on a Group), or props passed positionally instead of as one table.

---

## Build a window

A window is the entry point. Create one, add a tab, and fill it with elements.

```lua
local window = Astra:CreateWindow({
    name = "Example Hub",
    subtitle = "Astra",
})

local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateButton({
    name = "Say hello",
    callback = function()
        window:Notify({ title = "Hello", content = "Your first element works." })
    end,
})

tab:CreateToggle({
    name = "Auto Sprint",
    callback = function(value)
        print("Auto Sprint:", value)
    end,
})
```

The first visible tab opens on its own, so there is nothing else to wire up. Layout is built-in — switch it anytime in **Settings → Appearance → Bar Layout**.

---

## Built-in saving preferences

Saving no longer needs a `configuration` table in normal window usage. Open
**Settings → Persistence** to change **Auto Save Config** and **Auto Load Config**.
Both default to on for a new installation. Your choices are stored separately
from control values, even while Auto Save Config is off.

- Auto Save Config saves supported control values after a short coalescing delay.
- Auto Load Config restores the default configuration on the next startup.
  Turning it on does not replace values in the current session.
- Turning either off does not delete saved configurations.
- Stable, unique flags are recommended for controls that should be restored.
- Ordinary controls and controls inside Collapsible Groups use the same system.
- File persistence requires a runtime with writable storage.

Default storage identifiers are internal and are not displayed in Settings.
The default configuration is shared by windows using the defaults; unrelated hubs
should use separate named presets or legacy configuration overrides to avoid
sharing values. Existing scripts with a `configuration` table remain accepted for
compatibility, but saved built-in save/load preferences take precedence.

### How saving works

Flags, multiple configurations, and reading values back out.

```lua
-- any element with a flag participates in Save/Load
tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true })

window:Set("autoSprint", false)
print(window:Get("autoSprint"))
print(window.Flags.autoSprint)

window:Save("Slot2")
window:Load("Slot2")
window:ListConfigs()
window:DeleteConfig("Slot2")
```

Elements with `forgetState = true` are excluded. Controls may derive flags from their names; explicit unique flags make restores stable when labels change.

---

## Next steps

Windows, tabs and groups, elements, secure mode — full reference below. See `example.client.luau` for a complete end-to-end example.

### Windows

Titles, themes, and every window method.

| Method | Description |
|---|---|
| `window:CreateTab({ name, icon, locked })` | Create a tab. `locked = true` builds it gated (see [Locked tabs](#locked-tabs)). Returns a `Tab`. |
| `window:CreateSection({ name, icon })` | Top-level section — a `TabSection`. |
| `window:Notify({ title, content, icon, duration })` | Classic notification; opens on the entrance queue (see [Startup performance](#startup-performance)). |
| `window:Popup({ title, content, boxes, options, ... })` | Modal popup. Returns `Popup:Close()`. |
| `window:Navigate(tab)` | Select a tab by name or Tab object. |
| `window:Show()` / `window:Hide()` / `window:ToggleHide()` | Visibility. |
| `window:ToggleMinimise()` | Collapse/expand the rail. |
| `window:Close()` | Animated close (confirm popup is added by the topbar action); unloads the window when the transition finishes. |
| `window:Save(name?)` / `window:Load(name?)` | Save/load flags. |
| `window:ListConfigs()` | Array of saved config names. |
| `window:DeleteConfig(name)` | Delete a saved config. |
| `window:Get(flag)` / `window:Set(flag, value)` | Read/write by flag. |
| `window:ChangeTheme(theme)` | Swap theme at runtime. |
| `window:SetLocale(id)` / `window:SetTranslator(fn)` / `window:RegisterTranslations(t)` | Localisation. |
| `window:ResolveIcon(value, pack?)` | Icon name → asset id. |
| `window:ShowTooltip(anchor, text)` / `window:HideTooltip()` | Open/close a pinned floating description over any instance (programmatic API; functional info badges have been removed). |
| `window:GetPath()` | Returns the (folder, file) persistence path. |
| `window:Unload()` | Destroy the window. |
| `window.Flags` | Table of every registered flag's current value. |

Additional runtime helpers (used by the library internals, safe for extensions):
`window:Create(className, props, themeBindings?)` (instance factory with theme
and locale binding), `window:Connect(signal, fn)` /
`window:ConnectFor(element, signal, fn)` / `window:Disconnect(connection)` /
`window:DisconnectMany(list)`, `window:DestroySubtree(instance)` /
`window:DestroySubtrees(list)`, `window:CreateGlow(parent, color, blurRadius, transparency)`,
`window:CreateHoverOverlay(parent)`, `window:StyleElementBody(frame)` /
`window:StyleElementPanel(frame)`, `window:SaveSettings()` /
`window:LoadSettings()`.

Popup options: `options = { { text = "Cancel" }, { text = "Confirm", style = "primary" | "danger" | "neutral", callback = fn } }`.
Popup props: `title`, `subtitle`, `icon`, `content`, `boxes`, `options`, `dismissable`.

### Tabs and groups

```lua
local tab = window:CreateTab({ name = "Home", icon = "house" })
tab:Select()      -- switch to it
tab:Deselect()    -- switch away
tab:Remove()      -- destroy it

local row = tab:CreateGroup()                       -- horizontal row
local col = row:CreateGroup({ direction = "column" }) -- nested column
col:CreateToggle({ name = "Left 1" })
```

Tab methods: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateLink`, `CreateStat`, `CreateSection`, `CreateText`, `CreateFooter`, `CreateDivider`, `CreateGroup`, and optional `CreateCollapsibleGroup` and `CreateIsolated`.

Groups support: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`, `CreateStat`, `CreateSection`, `CreateText`, `CreateFooter`, `CreateDivider`, `CreateLink`, `CreateGroup`. Collapsible Groups can only be created directly on a tab.

Selected tabs retain their outline and highlight. Unselected tabs retain an
outline but have no fill/shadow highlight, including on hover.

`window:Notify` replaces exact **title + content** pairs per window (including the
`Title` / `Content` aliases and default text). An active match exits first, then
the new card takes the normal entrance queue and plays its reveal animation
again. A matching request that has not been built yet uses the newest props
without taking another queue slot. Case, whitespace, or a different title/body
remain separate messages; expired or dismissed text may be notified again.

### Locked tabs

**Lock UI is temporarily paused.** Badges remain hidden in both expanded and
collapsed rails, take no layout space, and the example's lock/unlock demo is
commented out. To restore the badge design later, set
`tabSelector.lockUIEnabled = true` in `components/tabSelector.luau` and rebuild
the bundle. The badge instances and positioning code are retained.

`CreateTab({ locked = true })` still creates a gated tab: host-side locking,
selection fallback, dimming, and search filtering are unchanged. This is a UI
gate, not an authorization/security boundary.

```lua
local premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })
premium:CreateButton({ name = "Enable ESP", callback = function() end })

-- later, from host code only — e.g. after a login or premium check:
premium:SetLocked(false)
```

- **The lock is host-controlled.** There is no UI control that changes it; the
  only switch is `tab:SetLocked(bool)`. The state is per-session — it is not a
  flag and is never written to settings or configs.
- **While locked**, tapping the row raises a short notification ("This tab is
  locked", lock icon) instead of selecting it; the row has no hover state and
  is dimmed further than an unselected pill. Lock badges are hidden during
  the UI pause, even after `SetLocked` or a layout rebuild.
- **Locked tabs keep their contents private.** Their elements are never built
  visible, and search never indexes them, so their names cannot be found
  through the search box. `tab:Select()`, `window:Navigate(tab)` and the
  auto-select of a new window all skip locked tabs.
- **Locking a tab that is open** moves the selection to another unlocked tab
  (same-rail preference); if every other tab is locked or neglected, the
  selection clears and the tab's content is hidden until it is unlocked and
  opened again.
- It is a UI gate, not security: it hides content from the player, not from an
  executor reading the client.

### Elements

Every element supports `Moveable` (`:MoveTo`, `:MoveToTop`, `:MoveToBottom`, `:MoveUp`, `:MoveDown`) and most support `Lockable` (`:Lock`, `:Unlock`, `:IsLocked`). Most element props also accept `icon`.

Functional info (`circle-alert`) badges have been permanently removed from
`Button`, `Toggle`, `Slider`, `Dropdown`, and `Input`. Legacy `info` / `infoIcon`
props are ignored and `SetInfo` is a compatibility no-op, so old hosts do not
throw or recreate the badges. Use `description` for an inline helper line, or
`window:ShowTooltip(anchor, text)` for an explicitly host-managed tooltip.

### Button
```lua
tab:CreateButton({
    name = "Click Me", icon = "play",
    callback = function() print("clicked") end,
})
```

Buttons have no trailing cursor/tap icon in either full cards or compact groups.
The optional `icon` is a **leading** icon; card/stroke motion provides click feedback.
Legacy `tapIcon` / `TapIcon` props are ignored and cannot restore the removed glyph.

### Toggle
```lua
local t = tab:CreateToggle({
    name = "Auto Sprint", flag = "autoSprint", value = true,
    callback = function(on) print(on) end,
})
t:Set(false)          -- fires callback unless skipCallback
t:Set(false, true)    -- silent
```

### Slider
```lua
tab:CreateSlider({
    name = "Sensitivity", flag = "sens",
    range = { 1, 10 }, value = 5, increment = 1, suffix = "x",
    minimal = true,
    callback = function(value, dragging) end,
})
```

### Dropdown
```lua
local d = tab:CreateDropdown({
    name = "Preset", options = { "Low", "Medium", "High" }, value = "Medium",
    multiSelect = true, placeholder = "Pick items",
    callback = function(selected) end,
})
d:Refresh({ "A", "B" })
d:Add("C")
d:Remove("A")
```

### Keybind

```lua
local shortcut = tab:CreateKeybind({
    name = "Shortcut", value = "K", flag = "shortcut",
    description = "Click the keycap, then press one letter.",
    callback = function(letter) print(letter) end, -- uppercase string
})
shortcut:Set("p")                 -- stores P and calls back on a change
shortcut:Set(Enum.KeyCode.T, true) -- silent update
shortcut:Capture()                -- only when visible and interactive
shortcut:CancelCapture()          -- keep the previous letter
```

This is a key-capture button, **not a text input**. Click its keycap and press one
letter **A–Z**. Escape, clicking again, changing tabs, closing a group, hiding the
window or losing window focus cancels capture without clearing the old value.
Numbers, punctuation, mouse buttons, special keys, blank values and multi-letter
strings are rejected. A binding is always required: invalid initial values default
to **K**, while invalid `Set` calls return `false` and retain the previous letter.
`Set` returns `true` for valid values and invokes the callback only on a change
(unless silent). Capture consumes the key before the menu-toggle handler, so
rebinding the menu's current letter does not accidentally hide the window.

Available on tabs, column Groups, and declarative Collapsible Groups using
`type = "Keybind"` (not compact rows). Supports flags, `forgetState`, move/lock
methods, a leading `icon`, and descriptions. Values and callbacks use uppercase
strings for config persistence. The control records a shortcut; hosts decide what
to do with it. Built-in Settings → Controls uses it to set the menu-toggle KeyCode.

### Input
```lua
tab:CreateInput({
    name = "Name", placeholder = "Type here",
    value = "Initial", numeric = true, clearOnFocus = true,
    callback = function(text) end,
})
```

### Stat
```lua
local s = tab:CreateStat({ name = "Kills", value = 128, prefix = "", suffix = " kills" })
s:Set(200)
s:ResetBaseline(0)
```
Extra props: `display` (`"value"` | `"change"`), `compact`, `changeMode` (`"percentage"` | `"delta"`), `changeBaseline` (`"previous"` (default) | `"initial"` — which value a change is measured against; any other value, a number included, is read as `"previous"`, so `stat:ResetBaseline(number)` is the way to set a numeric baseline), `numberEasing`, `letter`.

A stat's `value` may be a string. Text values render as a single-letter badge by default (`letter = true` is the same thing explicitly); `letter = false` reads the whole value out as text instead — one label, no digit roll and no change readout — and `Set` / `SetText` / `ResetBaseline` all write to it:

```lua
local theme = tab:CreateStat({ name = "Current theme", value = "Default", letter = false })
theme:SetText("Studio")  -- the card reads "Studio", not "S"
```

### Link
```lua
tab:CreateLink({
    name = "Discord",                       -- title
    subtitle = "Join our community",        -- muted second line
    link = "https://discord.gg/example",    -- hidden value: copied, never shown
    icon = "message-circle",
    callback = function(link) end,          -- optional, after a successful copy
})
```

A card that carries a URL. The link is stored on the element and never rendered
as text: the trailing control copies it, swaps the copy mark for a check mark for
two seconds, then puts the copy mark back. Every card owns that cycle, whether it
stands alone, sits in a Group, or sits in a Collapsible Group — a card hidden
while it is confirming (a group that closes) is back on the copy mark the next
time it is revealed.

```lua
local link = tab:CreateLink({ name = "Discord", subtitle = "Join us", link = "https://discord.gg/example" })
link:Set("https://discord.gg/new")   -- or SetLink: rewrite the hidden value
link:SetTitle("Discord server")      -- title
link:SetSubtitle("Now with a stage") -- second line (empty drops the card to one line)
link:SetIcon("messages-square")      -- leading icon (nil removes it)
link:Copy()                          -- run the cycle from code; true when the copy landed
link:IsConfirming()                  -- true while the check mark is showing
```

`Set`, `SetLink`, `SetTitle`, `SetSubtitle`, `SetIcon` take effect immediately and
the copy always follows the link currently stored. The card asks its host for a
clipboard (`setclipboard`, `toclipboard`, `setrbxclipboard`, a `Clipboard` object,
or Studio's `StudioService:CopyToClipboard`); where none exists the control keeps
the copy mark and logs the reason, because the check mark means the link is on the
clipboard and nothing else may show it. A card built without a `link` behaves the
same way: it copies nothing, keeps the copy mark, and says why. The element
supports the move and lock API like the other interactive elements.

Holding the copy control never scrolls the page: a press on it is pinned to the
tab page's canvas for as long as it is held, so the card stays exactly where it
is instead of dragging down and springing back. The page scrolls normally
everywhere else, and a scroll made between taps is left alone.

### About card
```lua
local changelogPanel -- assign below with tab:CreateIsolated(...)
local card = tab:CreateAboutCard({
    name = "Astra",                                  -- header title
    subtitle = "UI Library for a better experience.", -- muted line under it
    icon = 80387863064905,                           -- leading mark (name or asset id)
    rows = {                                         -- 1 to 3 data rows
        { icon = "code",    label = "Version", value = "1.4.0" },
        { icon = "package", label = "Build",   value = "2026.09.12" },
        { icon = "user",    label = "Author",  value = "Astra Team" },
    },
    description = "Astra is a modern and flexible UI library designed to make "
        .. "your experience smoother, cleaner, and more customizable.",
    action = {                                       -- optional trailing band
        icon = "file-text",
        name = "View Changelog",
        subtitle = "See what's new in this version",
        callback = function()
            if changelogPanel then changelogPanel:Expand() end
        end,
    },
})
```

One card with four blocks: a header (icon, title, subtitle), a row of data
tiles (each a leading icon, a label and a value), a description paragraph, and
an optional action band that is the card's only tappable surface.

All data tiles share one compact 48px line, split evenly from left to right. The
standard Version / Build / Author recipe therefore stays three-across instead
of placing Author alone on a second line; on an unusually narrow window a long
value truncates inside its own tile rather than changing the card's structure.
Tiles and the action band use the regular `ElementSurface` fill, not the darker
window gradient, so they remain consistent with the rest of the controls. A
fourth row errors at construction
(`Astra:CreateAboutCard — at most 3 data rows are supported, got 4`) because the
action band is the card's trailing row. A row without `icon`, or a card without
`rows`/`description`/`action`, simply leaves those parts out of the layout.

```lua
card:SetTitle("Release notes")        -- header title
card:SetSubtitle(nil)                 -- drop the second line (header closes to one band)
card:SetIcon("sparkles")              -- leading mark (nil removes it)
card:SetRow(1, { icon = "box", label = "Version", value = "1.5.0" })  -- rewrite one row in place
card:SetDescription("Shorter copy.")  -- paragraph (nil/"" removes it)
```

`SetRow` addresses a row the card already has and only touches the fields it is
given. The card supports the move and lock API; locking it disables the action
band.

### Text / Divider / Group
```lua
local x = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })
x:Set("New body") x:SetTitle("New title")

tab:CreateDivider()  tab:CreateDivider({ text = "or" })  tab:CreateDivider({ line = false, spacing = 8 })

local row = tab:CreateGroup()
local col = row:CreateGroup({ direction = "column" })
col:CreateToggle({ name = "Left 1" })
```

### Footer (centred inline text + icons)

A quiet, centred line of text runs and inline icons that stays centred as one
unit and re-centres itself whenever its content changes — the classic
"Built with ⚡ Astra ♡" credit row. `parts` is an ordered list; each entry is
`{ text = "..." }`, `{ icon = "..." }`, both in one entry (text then icon), or
a plain string shorthand for text. Icons resolve through the icon catalog and
scale with the text size automatically; unresolvable names drop instead of
leaving a gap.

```lua
local footer = tab:CreateFooter({
    parts = {
        { text = "Built with" },
        { icon = "zap" },
        { text = "Astra" },
        { icon = "heart" },
    },
})

footer:Set({ "Made", { icon = "heart" }, "with Astra" })  -- replace the whole run
```

Optional props: `textSize` (default 13), `spacing` (default 6). Text runs
accept RichText markup. The element supports the move API.

### Changelog (element)

Release history renders as a standalone element wherever it is declared:

```lua
local log = tab:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            title = "Settings highlight",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
                { symbol = "+", text = "Added the changelog element." },
            },
        },
    },
})

log:Add({ version = "Live", date = "Today", changes = { { symbol = "+", text = "Runtime entry." } } })
log:Set({ ... })
log:Clear()
```

Symbols: `+` added (green), `-` removed (red), `~` changed (amber); words `"added"`/`"removed"`/`"changed"` map to the same colours. Keep the history in its own file (see `changelog.example.luau`) and require it into the element props. The element supports `MoveTo`, `Lock`, etc. like other elements.

### Built-in Settings (window only)

Every window ships a built-in Settings group (gear action in the topbar). Clicking the gear switches into settings mode — only the settings tabs are shown — and clicking it again returns to the previous tab. It's window-scoped: it edits this window's own behaviour, stored per-window — not global.

The settings tabs are:

| Tab | Contents |
|---|---|
| **Overview** | First tab: library About Card, copyable repository and guide Links, and a Footer. |
| **Controls** | Required A–Z menu Keybind, unlock-cursor toggle, and Window Behavior (duplicate protection, keep on screen, draggable capsule, reset positions). |
| **Appearance** | Standalone Bar Layout Dropdown; Motion & Feedback (haptics, animation speed). |
| **Persistence** | Auto Save / Auto Load toggles; saved-configurations Dropdown + name Input + Save/Load/Delete actions. |

The menu binding cannot be cleared. Saved legacy non-letter bindings (including
Space, mouse buttons and unbound values) migrate to **K**. The settings pages
remain lazy-built. Single controls are shown directly, never hidden in a
one-element Collapsible Group.

The restore capsule's icon, text and hit target stay invisible throughout the
fold and appear only after `Hide()` completes. They disappear immediately when
restoring. `ToggleMinimise()` keeps the normal topbar, not the restore capsule.


The window rests dead centre of the screen. That resting centre is re-derived
on the first show and on every hide/show restore, and "Keep window on screen"
clamps the window inside the viewport so a drag cannot push it off the edge. A
position you dragged to is respected — auto-centring never overrides it;
**Reset Window Position** recentres the window.

There is no sub-tab API: these tabs are built by the window itself
(`Window:_buildSettingsUI`), not by user code.

### Themes

The built-in palette is `"default"`. Pass a partial table to `ChangeTheme` (or
to `CreateWindow`'s `theme` prop) to overlay keys on that palette. An unknown
name warns and falls back to default.

```lua
window:ChangeTheme("default")
window:ChangeTheme({
    ElementGradient = ColorSequence.new(Color3.fromRGB(20,20,30), Color3.fromRGB(30,30,45)),
    AccentColor = Color3.fromRGB(120, 90, 220),
})
```

**Corner scale.** Three radius tokens carry every surface, nested one step
inside each other so the arcs stay concentric:

| Token | Default | What wears it |
|---|---|---|
| `CornerRoundness` | `UDim.new(0, 12)` | The shell: the window silhouette and the bands that mirror its corners (topbar top pair, tab rail bottom-left, elements area bottom-right), the bottom fade, notifications, popups. |
| `ElementCornerRadius` | `UDim.new(0, 8)` | Everything inside the shell: element cards, field boxes, hover overlays, tab rows, dropdown panels and rows, About-card tiles, tooltips, the search bar, popup buttons. |
| `PillCornerRadius` | `UDim.new(0, 32)` | The folded states: the minimised bar (half the 64px chrome height, so a full pill) and the collapsed capsule (Roblox clamps a corner to half the smaller side, so the 50px capsule comes out a pill and the icon-only size a circle). |

```lua
-- a sharper build: same tiers, tighter numbers
window:ChangeTheme({ CornerRoundness = UDim.new(0, 6), ElementCornerRadius = UDim.new(0, 4) })
```

Keep all three **pixel** radii (`Scale` 0). A scale-based radius turns the
Input's field box into a capsule, and the two tiers have to stay comparable for
the nested surfaces to line up.

Controls that are round by nature do not read a token — they take half their own
height, so no theme can square them off: the switch (11px track, 9px knob), the
slider (7px track and fill, 10px handle), the drag pill and the unread dot.

### Icons

```lua
Astra.Icons.get("house")                -- searched in every pack, priority order
Astra.Icons.get("material:home")        -- exactly this pack (`pack:name`)
Astra.Icons.get("home", "tabler")       -- the optional pack argument does the same
Astra.Icons.getByPack("tabler", "home")
Astra.Icons.resolve("house")            -- a URL / asset id, ready for an Image
Astra.Icons.list("lucide")
Astra.Icons.packs() Astra.Icons.count() Astra.Icons.isPack("feather")
Astra.Icons.priority() Astra.Icons.loaded()      -- the search order / packs read so far
Astra.Icons.refreshCustom()                      -- re-read custom_asset/
window:ResolveIcon("house")             -- searches all packs
window:ResolveIcon("feather:home")      -- selects one exact icon
```
No window-wide `iconPack` option is needed.

**Name-only lookup.** A bare name is searched in every pack, in a fixed order —
lucide, material, tabler, phosphor, heroicons, feather, remix (`Astra.Icons.priority()`) —
and the first pack that has it wins. Nothing to pick, nothing to configure: lucide
spells the home glyph `house`, material has no `house` but has `home`, so both
`get("house")` and `get("home")` work, the latter from material. A name that exists
in several packs always answers from the earlier pack. The search is lazy: a pack's
table is read on first lookup, and only the packs up to the hit are read, so a lucide
name costs one pack. `Astra.Icons.loaded()` tells you which packs a session has read.

**Qualified names.** When it has to be a specific pack, qualify it —
`get("tabler:home")`, `resolve("lucide:house")`, `window:ResolveIcon("material:home")`
— or pass the pack as the second argument. An explicit pack is never overruled by the
order: if that pack has no such icon the request resolves to nothing (and `resolve`
hands back the value it was given). Names, pack names and the `pack:` prefix are
matched exactly as written; `Home`, `HOME` and `Lucide:house` are not `home`, and no
lookup is lowercased, corrected or fuzzed. An unknown pack name warns once per pack
and answers nothing, rather than substituting a pack you did not ask for.

**All-pack window lookup.** `window:ResolveIcon(name)` searches every pack, just
like `Astra.Icons.resolve`. `ResolveIcon(name, pack)` and `pack:name` still select
one exact pack when desired. Window and element icons can mix packs freely.
The old window-wide `iconPack` property is no longer used.

Icon names resolve to 48x48 PNGs that ship in this repo under
`assets/icons/<pack>-pack/`; the resolver maps them onto the repo's raw-GitHub URL
(or your executor's `getcustomasset` override when one is provided), so no
`rbxassetid` lookups are needed. Values already usable as-is — numbers,
`rbxassetid://…`, `rbxasset://…`, `rbxthumb://…`, `http(s)://…` — pass through
untouched, and an unresolved value comes back unchanged. See
[the visual icon catalog](assets/icons/README.md) for previews and copyable names across all seven packs.

**Custom assets.** A `custom_asset/` folder next to your script takes precedence
over the packs at resolve time: one file per icon name, in `.png`, `.jpg`, `.jpeg`,
`.webp` (tried in that order) or with no extension, subfolders allowed —
`custom_asset/brand/house.png` is asked for as `get("brand/house")`. With an executor
that provides `listfiles` the folder is indexed once and looked up by name, so names
you have no file for cost nothing; without it the resolver keeps the historic
extension probe. Either way a file is imported at most once per runtime, misses are
remembered, and `Astra.Icons.refreshCustom()` re-reads the folder after you add or
remove files. Qualified names are never shadowed by the folder.

### Key System (key gate)

`Astra:CreateKeySystem` shows a Rayfield-style "enter your key" card *before*
any window exists — a 400px card in the window's own shell language (12px
shell corner, 8px field and button corners, accent Continue) under a forced
Sirius header. Build your window inside `onSuccess`:

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

Astra:CreateKeySystem({
    title = "Example Hub",
    subtitle = "Key System",
    note = "Get your key at example.com, then paste it below.",
    keys = { "KEY-1", "KEY-2" },
    links = {
        { name = "Get Key", icon = "key-round", link = "https://example.com/key" },
        { name = "Discord", icon = "message-circle", link = "https://discord.gg/example" },
        { name = "Docs", icon = "book-open", link = "https://example.com/docs" },
    },
    saveKey = true,
    fileName = "ExampleHub",
    onSuccess = function(key)
        local window = Astra:CreateWindow({ name = "Example Hub" })
        local tab = window:CreateTab({ name = "Home" })
        tab:Select()
    end,
})
```

| Prop | Default | Meaning |
|---|---|---|
| `keys` | (none) | One key or a list. Blank entries are dropped; with no keys left the gate warns and passes through so a misconfigured loader never bricks. |
| `grabKeyFromSite` | `false` | Treat each entry as a raw URL and fetch the expected key from its trimmed body, once, up front. A URL that fails to fetch warns and can never match. |
| `saveKey` | `true` | Persist a passing key to `Astra/keys/<fileName>.txt`. |
| `fileName` | `title` | Key file name (sanitised, `.txt` appended). |
| `note` | `"Enter your key to continue."` | Instruction line, up to two lines — longer notes truncate instead of growing the card, so keep it under ~110 characters. Always plain text: it is never a copy target. |
| `placeholder` | `"Enter key"` | Field placeholder. |
| `links` | (none) | 0–3 buttons in a row under the note. Each entry `{ name, icon?, link }` shows icon + name on its face — the URL itself never renders there. The `icon` accepts anything the [Icons](#icons) catalog accepts (a bare name, `pack:name`, an asset id, or a `custom_asset/` file) and renders through the same image pipeline as window icons, so the usage example's glyphs are yours to restyle. Pressing copies the link to the clipboard and confirms through a notification whose content *is* the copied link. An entry with no usable `link` is skipped with a warning; past three entries warn and drop from the tail. |
| `getKeyUrl` | (none) | Legacy sugar: prepends a leading **Get Key** link button carrying this URL (icon + name, copy on press, exactly like a `links` entry). The note itself stays plain. If three explicit `links` already fill the row, the last one makes room (warns). |
| `maxAttempts` | (none) | Wrong-submit budget. Exhausting it locks the gate permanently and fires `onMaxAttempts` — the host decides what that means (Rayfield kicks the player; Astra delegates). |
| `dismissable` | `true` | Show the close button and answer Escape. The backdrop never dismisses. `false` builds neither. |
| `theme` | default palette | The same value `CreateWindow` accepts (name or table), resolved once and baked in. |
| `icon` | — | **Ignored.** The header always wears the Sirius mark (`pack:name`, name or asset id are all overridden; an executor file at `custom_asset/sirius.png` still wins as the source). Accepted so older scripts keep running unchanged. |
| `onSuccess(key)` | (none) | Fires with the passing key. A matching saved key skips the UI entirely and fires it straight away (passthrough). |
| `onClose()` | (none) | The user dismissed the card (close button or Escape). |
| `onMaxAttempts()` | (none) | The attempt budget ran out. |

Submit from the Continue button or the Enter key — any other focus loss stays
silent, so one press can never submit twice. Comparison is strict after
trimming surrounding whitespace (mobile keyboards append spaces; keys with
significant whitespace do not exist). A wrong key shakes the card, flashes
the field stroke red and clears the field without closing. A link button
press copies even while locked (the lock is exactly when a user needs the
real-key link) and only a finished gate stops it. One gate at a
time: creating a second retires the first.

The handle carries `passed`, `closed`, `attempts` and `Close()`.

Callbacks run on their own thread. If the anti-duplicate guard replaces the
window while `onSuccess` is still building (a re-execution, or a second gated
hub), the interrupted build finishes detached instead of erroring: a late
`CreateTab`/`CreateSection` on the replaced window returns a detached
tab/section, and everything chained onto it lands in a throwaway container —
never the destroyed tree.

### Motion (animation)

Astra's window transitions — hover, element reveal, the window entrance, the
result flashes, every card's entrance and dismissal — run through one service,
so your own animations can use the same timing and answer the same
"Animation speed" setting the user picked in Performance → Motion. (The
entrance queue that spaces the notification and toast arrivals paces itself
through `Motion.step`, so it stretches and shortens with that setting too;
the only curves outside the vocabulary are two delayed glow beats, and those rescale with the
profile as well.)

```lua
-- Animate with the library's own specs.
Astra.Motion.tween(frame, { BackgroundTransparency = 0.5 }, "snappy")

-- Specs: instant, fast, snappy, normal, smooth, emphasized, pop, glide,
-- exit, spring, settle, spin, drift. A TweenInfo works anywhere a name does.
--
-- The vocabulary is a system: entrances decelerate (Out), exits accelerate
-- (`exit` is In — a dismissal is quicker than its entrance), lateral state
-- moves ease InOut (`glide` — the window folding into its capsule), and the
-- playful surfaces get a small Back overshoot (`pop` for the shell, `settle`
-- for small elements, `spring` for drag landings).
Astra.Motion.tween(stroke, { Color = Color3.new(1, 1, 1) }, TweenInfo.new(0.3))

-- Settle work after the animation, without racing a synchronous completion.
Astra.Motion.tween(panel, { Position = target }, "smooth", function()
    panel.Visible = false
end)

-- Steer the whole interface.
Astra.Motion.setProfile("relaxed")     -- relaxed | normal | snappy | instant
Astra.Motion.setTimeScale(0.8)         -- custom multiplier instead
Astra.Motion.setEnabled(false)         -- apply targets immediately, no tweens
Astra.Motion.step(0.035)               -- cascade pacing, scaled like the rest
Astra.Motion.cancel(frame)             -- stop what the service owns here
```

`motion.tween` never animates a property that is already at its target (a call
whose properties are all satisfied creates no tween at all) and cancels an
in-flight tween it would fight with, so repeated calls from an event handler
cannot stack competing animations on the same property.

### Localisation

```lua
window:RegisterTranslations({ en = { play = "Play" }, de = { play = "Spielen" } })
window:SetLocale("de")
window:SetTranslator(function(source, localeId) return ... end)
```

### Full example

See `example.client.luau` — a ten-tab studio that loads the bundle with the one-line loader above, opens behind `Astra:CreateKeySystem` (the demo key `ASTRA-STUDIO-2026` shows the full gate → `onSuccess` flow, saved and replayed on the next join), and builds every element type (including ordinary and Collapsible Groups, Isolated and Changelog) end to end, with each control wired to something real: character and lighting edits, teleporting, a Heartbeat-driven performance sampler, the persistence API, and the theme/motion/window methods.

---

## CreateWindow — all props

```lua
local window = Astra:CreateWindow({
    name = "My UI",              -- title (left side of topbar)
    subtitle = "v1.0",           -- small text next to title
    icon = "house",              -- topbar icon (pack name or asset id)
    theme = "default",           -- built-in name (`"default"`) or a custom table
    showName = "Astra",          -- name shown when the window is minimised to the capsule (default "Astra")
    showIconOnly = false,        -- capsule shows only the icon, no name
    fallbackFont = Enum.Font.Gotham,  -- font used when the brand font cannot load
    translator = function(source, localeId) return ... end,  -- optional custom translator
    locale = "en",
    translations = { ... },

})
```
Layout is **not** a CreateWindow prop — switch it in **Settings → Appearance → Bar Layout**.

### Startup performance

Window construction is staged across frames. Large initial batches of `CreateTab`
and `Create…` calls yield at completed-control boundaries after roughly 4 ms of
work or 120 new instances. These are cooperative limits, not a hard frame-time
cap: a single expensive control can exceed them. Calls still return fully built
objects, but may yield while creating the initial UI.

Automatic show happens on the next frame — one deferred tick plus one heartbeat,
so the caller's first synchronous `CreateTab` calls land before the shell
appears — and the remaining constructors keep streaming in behind the
already-visible window in small budget-limited batches until the build goes
quiet, so the opening tween keeps receiving frames. `window:Hide()` before the
first reveal cancels auto-show; `window:Show()` can still be called explicitly.

The arrival itself is staged rather than instant: the window's shell (frame, surface,
corner, topbar) animates in first, the page's controls cascade in one control per beat
a beat later, and overlays follow the content. `window:Notify` overlays are
therefore queued — the card is *built* on its own turn, one entrance at a time, with a
cooldown between two of them — instead of all landing on the frame the window opens
on. A backlog stays bounded: past six waiting requests the oldest one that has not
been built yet is dropped. Nothing else about the two calls changed (they still accept
the same props and their cards still dismiss on click, on timeout, and on the visible
cap), and with the speed profile set to **Instant** the queue keeps the order but drops
the pauses, so a host that fires a notification per loaded module gets a cascade
instead of a freeze either way.

Search controls are created the first time search opens. Additional built-in
settings tabs are created on first settings access, and their controls remain lazy
until each tab is selected. Controls added to inactive tabs wait until that tab is
shown before running their reveal animations.

### Collapsible Group (optional)

`tab:CreateCollapsibleGroup` groups controls under an animated header. Existing
standalone elements and ordinary Groups are unchanged; nothing is automatically
wrapped in a Collapsible Group.

```lua
local window = Astra:CreateWindow({
    name = "My Hub",
    subtitle = "Player tools",
    icon = "house",
})
local tab = window:CreateTab({ name = "Player", icon = "user-round" })

local playerControls = tab:CreateCollapsibleGroup({
    name = "LocalPlayer",
    icon = "user-round", -- optional; may be from any icon pack
    elements = {
        {
            type = "Toggle",
            name = "Infinite Jump",
            flag = "infiniteJump",
            value = false,
            callback = function(enabled)
                print("Infinite jump:", enabled)
            end,
        },
        {
            type = "Slider",
            name = "Walk Speed",
            flag = "walkSpeed",
            range = { 16, 100 },
            value = 16,
            callback = function(value)
                print("Walk speed:", value)
            end,
        },
        {
            type = "Group",
            elements = {
                {
                    type = "Button",
                    name = "Reset Speed",
                    icon = "feather:rotate-ccw",
                    callback = function() window:Set("walkSpeed", 16) end,
                },
                {
                    type = "Button",
                    name = "Show Speed",
                    callback = function() print(window:Get("walkSpeed")) end,
                },
            },
        },
    },
})
```

**Supported types:** `Button`, `Toggle`, `Switch` (declarative alias of the
toggle control), `Slider`, `Dropdown`, `Input`, `Link`, `Stat`,
`Section`, `Text`, `Divider`, and ordinary `Group`. Each uses the
same properties and implementation as its normal `Create…` method, including
the optional `description` helper line. `elements` can be omitted for an empty
header.

An ordinary Group retains its compact row layout when its children support it.
Use `direction = "column"` for a vertical Group; the declarative builder also
chooses a column automatically if the Group contains noncompact controls, so no
chosen element is silently discarded. Ordinary Groups may contain ordinary Groups.
**Collapsible Groups cannot contain Collapsible Groups**, directly or through a
Group. Invalid types, sparse lists, and cyclic/nested Collapsible Group definitions
are rejected before creating any UI.

- `{ type = "Changelog", ... }` renders as a regular Changelog element.
- Every Collapsible Group starts collapsed; there is no `expanded` usage property.
- Click the header to open/close. Multiple groups operate independently.
- Expansion uses Astra's motion service, including the instant-motion setting.
- Values, flags and running features remain active when collapsed. Closing and
  reopening do not recreate controls, reset them, or rerun their value callbacks.
- Closing cancels an uncommitted input edit and closes open dropdowns;
  already committed values remain unchanged.
- Search includes child names and temporarily expands matching groups. Closing
  search restores their previous expansion state.
- Children render at the same width as standalone elements, and the header
  matches the Text element's card metrics (gutters, title and body styling).
- The card silhouette stays even in both states: collapsed, the header band is the
  card's bottom edge and carries the container's rounded bottom corners; open, the
  band ends at the straight divider and the revealed body carries them. Both read
  the same `ElementCornerRadius`, so no corner ever changes radius.
- All three layouts are supported; the tab supplies scrolling for long contents.
- `MoveTo`, `MoveToTop`, `MoveToBottom`, `MoveUp`, `MoveDown`, `Lock`, and `Unlock`
  work on the container. Created child handles are also available in its
  `elements` array, in definition order, just like an ordinary Group.

### Isolated (changelog container)

`tab:CreateIsolated` is the Changelog's own container: a collapsed header card —
left icon, title/subtitle stack and the built-in expansion chevron — that
reveals a body of release-history entries with exactly the Collapsible Group
tween. It is a strict container: **only Changelog elements work inside it**.

```lua
local changelogPanel = tab:CreateIsolated({
    name = "View Changelog",                     -- title line (changeable)
    subtitle = "See what's new in this version", -- muted line (changeable)
    icon = "file-text",                          -- left icon (changeable)
    elements = {                                 -- ONLY Changelog definitions
        {
            type = "Changelog",
            name = "Release history",
            entries = {
                {
                    version = "1.2.0",
                    date = "2025-06-14",
                    changes = {
                        { symbol = "+", text = "Added Isolated changelog container" },
                        { symbol = "~", text = "Chevron now rotates when expanded" },
                    },
                },
            },
        },
    },
})

--[[ RUNTIME METHODS ]]
changelogPanel:Expand()                            -- open (CollapsibleGroup-style tween)
changelogPanel:Collapse()                          -- close
changelogPanel:Toggle()                            -- open / close
changelogPanel:SetTitle("Release Notes")           -- changeable
changelogPanel:SetSubtitle("v1.2.0 is live")       -- changeable; nil clears the line
changelogPanel:SetIcon("scroll-text")              -- changeable (left icon only)
-- No setter exists for the right-side chevron: it is built in and fixed.
```

- **Guard:** any non-Changelog child definition — another control type, a
  nested container, a built element or a non-table value — errors at
  construction with
  `Astra:CreateIsolated — only Changelog elements can be placed inside Isolated`,
  before any UI exists. Isolated containers cannot nest inside Collapsible
  Groups either, and, like Collapsible Groups, are created directly on a tab.
- **Built-in chevron:** the right-facing expansion glyph is always rendered,
  rotates with the expansion state, and is never changeable or removable —
  the container exposes no setter that reaches it. `SetIcon` only ever
  touches the left icon slot.
- **Header:** the title rides the standard 41px band; a subtitle adds the muted
  14px line under it (61px band), and clearing the subtitle at runtime returns
  the card to the single-line band. Icon and chevron stay vertically centred on
  whichever band the header is.
- Everything else behaves like a Collapsible Group: search indexes the child
  names and expands matching containers, `MoveTo`/`Lock`/`Unlock` work, child
  handles live in `elements` in definition order, and collapsed children keep
  their state without rerunning callbacks.
- Controls are built in startup batches even while collapsed, so saved flags
  are usable before the first expansion. The optional feature adds
  no container instances unless you explicitly create one.
ly create one.
