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
| `window:ShowTooltip(anchor, text)` / `window:HideTooltip()` | Open/close a pinned floating description over any instance (the `(!)` badges open theirs through this). |
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

Tab methods: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateStat`, `CreateSection`, `CreateText`, `CreateDivider`, `CreateGroup`, and optional `CreateCollapsibleGroup`.

Groups support: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`, `CreateStat`, `CreateSection`, `CreateText`, `CreateDivider`, `CreateGroup`. Collapsible Groups can only be created directly on a tab.

### Locked tabs

`CreateTab({ locked = true })` builds a tab that is visible in the sidebar but
gated: the row draws a small lock badge on its trailing edge — vertically
centred, inset by the row padding, with room reserved in the rail's width —
stays dimmed, and cannot be opened by the user. It is the library's answer to
"this section exists, but not for this user yet".

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
  is dimmed further than an unselected pill. In the collapsed icon-only rail
  the badge still shows on the icon tile. When unlocked, no icon is drawn at
  all — the row is identical to a tab that never had the prop.
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

Functional elements (`Button`, `Toggle`, `Slider`, `Dropdown`, `Input`) also accept an optional `info` string. When it has text, a circular `(!)` alert badge is drawn in the row **immediately after the element's name**, and:

- hovering the badge (desktop) reveals the floating description, and leaving it hides the description again;
- tapping it opens the description and keeps it open (a hover preview is pinned, not thrown away) — tapping it once more closes it;
- press-and-holding it for a moment reveals the description while your finger is still down, which is how touch devices reach it (no hover there);
- the description closes when the window hides, closes, switches tab or unloads, when the badge scrolls away, and when the text is cleared.

Only one description is open at a time, and the description never changes the card's compact height. An element with no `info` — or with `""` / whitespace — draws no badge and is laid out exactly like one that never had the prop. `infoIcon` replaces the badge glyph, and `:SetInfo(text)` adds, retargets or removes the description at runtime (`:SetInfo(nil)` / `:SetInfo("")` removes it).

Do not confuse the two text props: `description` is the in-card muted helper line that grows the card, `info` is the `(!)` badge and its floating description.

```lua
tab:CreateButton({ name = "Click Me", icon = "play", info = "Runs action immediately", callback = function() end })
tab:CreateToggle({ name = "Auto Sprint", info = "Toggles continuous sprinting", value = true })
tab:CreateSlider({ name = "Sensitivity", info = "Input sensitivity factor", range = { 1, 10 }, value = 5, suffix = "x", minimal = true, callback = function(v, dragging) end })
tab:CreateDropdown({ name = "Preset", info = "Target preset level", options = { "Low", "Medium", "High" }, value = "Medium", multiSelect = true, placeholder = "Pick items", callback = function(s) end })
tab:CreateInput({ name = "Name", info = "User display name", placeholder = "Type here", numeric = true, clearOnFocus = true, callback = function(t) end })

-- The badge glyph and the runtime text:
local button = tab:CreateButton({ name = "Export", info = "Downloads the log file", infoIcon = "download", callback = function() end })
button:SetInfo("Downloads the log file to your device") -- retarget the description
button:SetInfo("")                                      -- remove the badge again
```

### Button
```lua
tab:CreateButton({
    name = "Click Me", icon = "play",
    callback = function() print("clicked") end,
})
```

Every Button carries a built-in tap glyph on its right edge (phosphor `hand-tap`,
resolved through the icon catalog). Tapping the card fires `callback` and pulses
that glyph; the glyph itself is part of the card, so tapping it taps the button.
`tapIcon = false` hides it, and `tapIcon = "name" | <assetId>` replaces it.

```lua
tab:CreateButton({
    name = "Silent", icon = "bell-off",
    tapIcon = false,
    callback = function() end,
})
tab:CreateButton({
    name = "Refresh", tapIcon = "refresh-cw",
    callback = function() end,
})
```

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
theme:SetText("Emerald")  -- the card reads "Emerald", not "E"
```

### Text / Divider / Group
```lua
local x = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })
x:Set("New body") x:SetTitle("New title")

tab:CreateDivider()  tab:CreateDivider({ text = "or" })  tab:CreateDivider({ line = false, spacing = 8 })

local row = tab:CreateGroup()
local col = row:CreateGroup({ direction = "column" })
col:CreateToggle({ name = "Left 1" })
```

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
| **General** | Menu Toggle keybind field — type a key name (`K`, `Space`, `MB2`) and click away to bind it, `none` or an empty field to unbind — plus the unlock-cursor toggle, welcome toast toggle, Window Behavior (prevent duplicate windows, keep window on screen, draggable capsule, reset window & capsule positions), and Performance & Motion (haptics, animation speed). |
| **Appearance** | Theme dropdown + Apply (popup confirm) and the Bar Layout dropdown (Sidebar / Collapsed Sidebar). |
| **Persistence** | Auto Save Config / Auto Load Config toggles; Saved-configurations dropdown + name input + Save/Load/Delete. |
| **About** | Library info and links. |

The window rests dead centre of the screen. That resting centre is re-derived
on the first show and on every hide/show restore, and "Keep window on screen"
clamps the window inside the viewport so a drag cannot push it off the edge. A
position you dragged to is respected — auto-centring never overrides it;
**Reset Window Position** recentres the window.

There is no sub-tab API: these tabs are built by the window itself
(`Window:_buildSettingsUI`), not by user code.

### Themes

Built-ins: `"default"`, `"amethyst"`, `"cobalt"`, `"ember"`, `"frost"`, `"rose"`.

```lua
window:ChangeTheme("amethyst")
window:ChangeTheme({
    ElementGradient = ColorSequence.new(Color3.fromRGB(20,20,30), Color3.fromRGB(30,30,45)),
    AccentColor = Color3.fromRGB(120, 90, 220),
})
```

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

See `example.client.luau` — a single-tab example that loads the bundle with the one-line loader above and builds every element type (including ordinary and Collapsible Groups and Changelog) end to end.

---

## CreateWindow — all props

```lua
local window = Astra:CreateWindow({
    name = "My UI",              -- title (left side of topbar)
    subtitle = "v1.0",           -- small text next to title
    icon = "house",              -- topbar icon (pack name or asset id)
    theme = "default",           -- built-in name (10 built-ins, see Themes below) or custom table
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
toggle control), `Slider`, `Dropdown`, `Input`, `Stat`,
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
- Controls are built in startup batches even while collapsed, so saved flags
  are usable before the first expansion. The optional feature adds
  no container instances unless you explicitly create one.
ly create one.
