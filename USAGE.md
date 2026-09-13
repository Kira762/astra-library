# Astra v1 — Usage Guide

Load Astra and build your first window in a few lines.

---

## Load the library

Two ways in, depending on where you run:

```lua
-- Studio / Rojo (recommended): Astra is a ModuleScript in ReplicatedStorage
local Astra = require(game:GetService("ReplicatedStorage").Astra)
```

```lua
-- Executor: the example loads the bundle from the repo and compiles it.
-- This is what example.client.luau does:
local bundleSource = game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau")
local compile = loadstring or load
local bundleLoader = compile(bundleSource)
local Astra = bundleLoader()
```

The bundle (`version-1.luau`) is a generated artifact — require/load the single
bundle, never the modular tree, when running outside Rojo.

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

## Turn on saving

Pass a configuration table and the window remembers every value between sessions. Nothing else is required, and each value restores as its original type.

```lua
local window = Astra:CreateWindow({
    name = "Example Hub",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "ExampleHub",
    },
})
```

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

Elements with `forgetState = true` are excluded. Elements without a flag are visual-only.

---

## Next steps

Windows, tabs and groups, elements, secure mode — full reference below. See `example.client.luau` for a complete end-to-end example.

### Windows

Titles, tags, themes, and every window method.

| Method | Description |
|---|---|
| `window:CreateTab({ name, icon })` | Create a tab. Returns a `Tab`. |
| `window:CreateSection({ name, icon })` | Top-level section — a `TabSection`. |
| `window:CreateTag({ text, title, icon, color, order })` | Small tag in the window footer. |
| `window:Notify({ title, content, icon, duration })` | Classic notification. |
| `window:Toast({ title, subtitle, icon, duration, position, ... })` | Compact toast. |
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
`window:LoadSettings()`, `window:SetProfile(profile)` — fills the profile card from real data with nothing invented: pass a string (or `nil`) to set/replace just the subtitle line (legacy behaviour: `nil` falls back to the `@username` line and leaves the host's key/whitelist rows alone), or a table for the whole payload:

```lua
window:SetProfile({
    subtitle = "Beta tester",              -- optional, replaces the @username line
    key = "ASTRA-XXXX-XXXX",               -- optional, masked until "Reveal profile details"
    tier = "PREMIUM",                      -- optional, the header pill's word (else PREMIUM / FREEMIUM from membership)
    whitelist = { status = "Active", daysLeft = 14 },  -- or expiresAt = os.time() + n
})
```

Fields you leave out read `—` on the card, and the whole row set stays masked until the window's **Reveal profile details** setting is on (the panel's own values always come from the player and the running server — never from this table).

Popup options: `options = { { text = "Cancel" }, { text = "Confirm", style = "primary" | "danger" | "neutral", callback = fn } }`.
Popup props: `title`, `subtitle`, `icon`, `content`, `boxes`, `options`, `dismissable`.

### Tabs and groups

```lua
local tab = window:CreateTab({ name = "Home", icon = "house" })
tab:Select()      -- switch to it
tab:Deselect()    -- switch away
tab:Remove()      -- destroy it

local row = window:CreateGroup()                       -- horizontal row
local col = row:CreateGroup({ direction = "column" }) -- nested column
col:CreateToggle({ name = "Left 1" })
```

Tab methods: `CreateButton`, `CreateToggle`/`CreateSwitch`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateKeybind`, `CreateStat`, `CreateProgress`, `CreateConsole`, `CreateSection`, `CreateText`, `CreateChangelog`, `CreateDivider`, `CreateGroup`.

Groups support: `CreateButton`, `CreateToggle`/`CreateSwitch`, `CreateSlider`, `CreateDropdown`, `CreateStat`, `CreateSection`, `CreateText`, `CreateDivider`, `CreateGroup`.

### Elements

Every element supports `Moveable` (`:MoveTo`, `:MoveToTop`, `:MoveToBottom`, `:MoveUp`, `:MoveDown`) and most support `Lockable` (`:Lock`, `:Unlock`, `:IsLocked`). Most element props also accept `description` (helper text under the name) and `icon`.

```lua
tab:CreateButton({ name = "Click Me", icon = "play", callback = function() end })
tab:CreateSlider({ name = "Sensitivity", range = { 1, 10 }, value = 5, suffix = "x", minimal = true, callback = function(v, dragging) end })
tab:CreateDropdown({ name = "Preset", options = { "Low", "Medium", "High" }, value = "Medium", multiSelect = true, placeholder = "Pick items", callback = function(s) end })
tab:CreateInput({ name = "Name", placeholder = "Type here", numeric = true, clearOnFocus = true, callback = function(t) end })
tab:CreateKeybind({ name = "Toggle Panel", value = Enum.KeyCode.F3, isMenuToggle = true, callback = function(v) end })
```

### Button
```lua
tab:CreateButton({
    name = "Click Me", icon = "play",
    description = "Optional helper text",
    callback = function() print("clicked") end,
})
```

### Toggle / Switch
```lua
local t = tab:CreateToggle({
    name = "Auto Sprint", flag = "autoSprint", value = true,
    callback = function(on) print(on) end,
})
t:Set(false)          -- fires callback unless skipCallback
t:Set(false, true)    -- silent
```
`CreateSwitch` is an alias.

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

### Keybind
```lua
tab:CreateKeybind({
    name = "Toggle Panel", value = Enum.KeyCode.F3,
    isMenuToggle = true, hold = true, holdThreshold = 0.2,
    callback = function(value) end, onChanged = function(key) end,
})
```

### Stat
```lua
local s = tab:CreateStat({ name = "Kills", value = 128, prefix = "", suffix = " kills" })
s:Set(200)
s:ResetBaseline(0)
```
Extra props: `display`, `compact`, `changeMode`, `changeBaseline`, `numberEasing`.

### Progress
```lua
local p = tab:CreateProgress({ name = "Download", range = { 0, 100 }, value = 35 })
p:Set(80)
p:Get()                 -- current value
p:GetPercentage()       -- 0–100
p:SetRange(0, 500)
p:SetText("Downloading...")
p:SetIndeterminate(true)
p:Remove()
```
Extra props: `steps`, `text`, `format(value, min, max)`, `showValue`, `indeterminate`.

### Text / Divider / Console / Group
```lua
local x = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })
x:Set("New body") x:SetTitle("New title")

tab:CreateDivider()  tab:CreateDivider({ text = "or" })  tab:CreateDivider({ line = false, spacing = 8 })

local con = tab:CreateConsole({ name = "Log", text = "-- ready", height = 130, follow = true, maxLines = 50 })
con:Append("hello") con:Set("reset") con:Get() con:Clear() con:Copy() con:SetHeight(200)

local row = tab:CreateGroup()
local col = row:CreateGroup({ direction = "column" })
col:CreateToggle({ name = "Left 1" })
```

### Changelog

Scrollable release-history element with `+` (added), `-` (removed) and `~` (changed) change symbols, rendered in green/red/amber.

```lua
local log = tab:CreateChangelog({
    name = "Release history",
    description = "Recent changes and fixes.",
    emptyText = "No entries yet.",   -- optional
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            game = "Game Name",      -- optional, game = "..." or gameId = number
            title = "Settings highlight",
            description = "Improved the built-in Settings active state.",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
                { symbol = "+", text = "Added the Changelog element." },
                { symbol = "-", text = "Removed the old sub-tab API." },
            },
        },
    },
})

log:Add({ version = "Test", date = "Live", changes = { { symbol = "+", text = "Runtime entry." } } })  -- prepends by default
log:Add(entry, false)  -- append at the end instead
log:Set({ ... })       -- replace all entries
log:Refresh({ ... })   -- alias of Set
log:Clear()
```

### Tag

```lua
local tag = window:CreateTag({ text = "0.0.35", icon = "tag", color = Color3.fromRGB(88, 70, 170), order = 1 })
tag:Set({ text = "0.0.36" })
tag:SetText("0.0.36")  tag:SetColor(Color3.new())  tag:SetIcon("badge-check")  tag:Remove()
```

### Built-in Settings (window only)

Every window ships a built-in Settings group (gear action in the topbar). Clicking the gear switches into settings mode — only the settings tabs are shown — and clicking it again returns to the previous tab. It's window-scoped: it edits this window's own behaviour, stored per-window — not global.

The settings tabs are:

| Tab | Contents |
|---|---|
| **General** | Toggle keybind (show/hide), unlock-cursor toggle, welcome toast toggle. |
| **Appearance** | Theme dropdown + Apply (popup confirm), Bar Layout dropdown (Default Topbar / Sidebar / Collapsed Sidebar), Show profile / Profile side / Reveal profile details (unmasks the display name, username, user ID, place ID, job ID and license key on the profile card, and only works while **Show profile** is on — flipping it on with the card off raises a "Show profile is required" notification and leaves it off, and hiding the card switches it off with it), Keep window on screen (keeps the window **and** its card in view), Draggable capsule, Reset Window Position. |
| **Behavior** | Prevent duplicate windows. |
| **Performance** | Haptics. |
| **Persistence** | Saved-configurations dropdown + name input + Save/Load/Delete. Only present when `configuration` was passed to `CreateWindow`. |
| **About** | Library info and links. |

The card's layout (masked and revealed) is checked into
`assets/profile-panel-preview.png` / `assets/profile-panel-preview-revealed.png`;
`sh scripts/profile_panel_preview.sh` re-renders them offline from the real
panel code whenever the card changes.

The window and its profile card (a compact 260x420 card — the default
window's height) are centred as one unit: with the card on, the window rests
half a card (136px) off the screen centre on the opposite side of it, so
window + 12px gap + card line up in the middle together. That resting
centre is re-derived on the first show, on every hide/show restore and whenever
the card's state changes (toggle, side, viewport, a player turning up late), and
"Keep window on screen" clamps the pair rather than the window alone, so a drag
can push neither of them off the edge. A position you dragged to is respected —
auto-centring never overrides it; **Reset Window Position** recentres the pair.

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
Astra.Icons.get("house")
Astra.Icons.get("play", "material")
Astra.Icons.getByPack("tabler", "home")
Astra.Icons.list("lucide")
Astra.Icons.packs() Astra.Icons.count()
Astra.Icons.isPack("feather")
window:ResolveIcon("house")
```
`iconPack`: `"lucide" | "material" | "tabler" | "phosphor" | "heroicons" | "feather"`.

Icon names resolve to 48x48 PNGs that ship in this repo under `assets/icons/<pack>/`; the resolver maps them to the repo's raw GitHub URL (or your executor's `getcustomasset` if provided), so no `rbxassetid` lookups are needed. See `assets/icons/feather-pack.md` and `assets/icons/tabler-pack.md` for pack details.

### Motion (animation)

Astra's window transitions — hover, element reveal, the window entrance, the
result flashes — run through one service, so your own animations can use the
same timing and answer the same "Animation speed" setting the user picked in
Performance → Motion. (Component-local flourishes such as the toast queue
still run on their own specs.)

```lua
-- Animate with the library's own specs.
Astra.Motion.tween(frame, { BackgroundTransparency = 0.5 }, "snappy")

-- Specs: instant, fast, snappy, normal, smooth, emphasized, pop, exit,
-- spring, spin, drift. A TweenInfo works anywhere a name does.
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

See `example.client.luau` — a 20-tab example (Home, Controls, Appearance, Information, Changelog, Updates, plus 15 labelled test tabs) that loads the bundle with the remote loader and exercises tags, every element type, groups, and the Changelog element end to end.

---

## CreateWindow — all props

```lua
local window = Astra:CreateWindow({
    name = "My UI",              -- title (left side of topbar)
    subtitle = "v1.0",           -- small text next to title
    icon = "house",              -- topbar icon (pack name or asset id)
    iconPack = "lucide",         -- "lucide" | "material" | "tabler" | "phosphor" | "heroicons" | "feather" (PascalCase alias: IconPack)
    theme = "default",           -- built-in name (10 built-ins, see Themes below) or custom table
    profile = "Display Name",    -- optional profile (avatar + name)
    showName = "Astra",          -- name shown when the window is minimised to the capsule (default "Astra")
    showIcon = "house",          -- capsule icon while minimised
    showIconOnly = false,        -- capsule shows only the icon, no name
    fallbackFont = Enum.Font.Gotham,  -- font used when the brand font cannot load
    translator = function(source, localeId) return ... end,  -- optional custom translator
    locale = "en",
    translations = { ... },
    configuration = {            -- persistence
        autoSave = true,
        autoLoad = true,
        fileName = "MyConfig",
        customFolder = nil,
    },
})
```
Layout is **not** a CreateWindow prop — switch it in **Settings → Appearance → Bar Layout**.
