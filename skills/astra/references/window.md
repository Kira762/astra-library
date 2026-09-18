# Astra v1 — Window, theme and runtime reference

## Window methods

| Method | Behaviour |
|---|---|
| `window:CreateTab({ name, icon })` | Returns a `Tab`. |
| `window:CreateSection({ name, icon })` | Top-level section — a `TabSection`. |
| `window:Notify({ title, content, icon, duration })` | Classic notification card; queued (see Startup pacing). |
| `window:Popup({ title, subtitle, icon, content, boxes, options, dismissable })` | Modal; returns a handle with `:Close()`. |
| `window:Navigate(tab)` | Select a tab by name or Tab object. |
| `window:Show()` / `Hide()` / `ToggleHide()` | Visibility. |
| `window:ToggleMinimise()` | Fold/expand into the capsule. |
| `window:Close()` | Animated close; unloads the window when the transition ends. |
| `window:Save(name?)` / `window:Load(name?)` | Write/read a saved config of flagged values. |
| `window:ListConfigs()` / `DeleteConfig(name)` | Saved-config bookkeeping. |
| `window:Get(flag)` / `window:Set(flag, value)` | Read/write a registered flag. |
| `window.Flags` | Table of every registered flag's current value. |
| `window:ChangeTheme(theme)` | Built-in name or a partial theme table. |
| `window:SetLocale(id)` / `SetTranslator(fn)` / `RegisterTranslations(t)` | Localisation. |
| `window:ResolveIcon(value, pack?)` | Icon name → asset URL/id. |
| `window:GetPath()` | `(folder, file)` of the persistence path. |
| `window:SetProfile(profile)` | Fill the profile card from real data. |
| `window:Unload()` | Destroy the window and its instances. |

Extension helpers used by library internals and safe for custom elements:
`window:Create(className, props, themeBindings?)`, `window:Connect(signal, fn)`,
`window:ConnectFor(element, signal, fn)`, `window:Disconnect(connection)`,
`window:DisconnectMany(list)`, `window:DestroySubtree(instance)`,
`window:DestroySubtrees(list)`, `window:CreateGlow(parent, color, blurRadius, transparency)`,
`window:CreateHoverOverlay(parent)`, `window:StyleElementBody(frame)`,
`window:StyleElementPanel(frame)`, `window:SaveSettings()`, `window:LoadSettings()`.

### CreateWindow props

```lua
local window = Astra:CreateWindow({
    name = "My UI",                   -- topbar title
    subtitle = "v1.0",
    icon = "house",                   -- icon name or asset id
    theme = "default",                -- built-in name or custom table
    showName = "Astra",               -- capsule label when minimised
    showIconOnly = false,
    fallbackFont = Enum.Font.Gotham,  -- used when the brand font cannot load
    translator = function(source, localeId) end,
    locale = "en",
    translations = { ... },
    settings = { antiWindowDuplicate = false },   -- optional per-window opt-out
})
```

Layout is **not** a prop — it is the user's **Settings → Appearance → Bar Layout**
choice (Default Topbar / Sidebar / Collapsed Sidebar).

### Popup options

```lua
window:Popup({
    title = "Apply theme?",
    content = "This restyles the window.",
    options = {
        { text = "Cancel" },
        { text = "Confirm", style = "primary", callback = function() end },  -- primary | danger | neutral
    },
    dismissable = true,
})
```

### Profile card

```lua
window:SetProfile({
    subtitle = "Beta tester",                 -- replaces the @username line
    key = "ASTRA-XXXX-XXXX",                  -- masked until "Reveal profile details"
    tier = "PREMIUM",                         -- header pill word
    whitelist = { status = "Active", daysLeft = 14 },   -- or expiresAt = os.time() + n
})
window:SetProfile("Beta tester")              -- replace just the subtitle line
```

Omitted fields render as `—`; the card's own player/server values are never taken
from this table. Window and card are centred as one unit, and "Keep window on
screen" clamps the pair.

## Built-in Settings (window-scoped)

Reached through the gear action in the topbar; clicking it again returns to the
previous tab. User code does not build these tabs.

| Tab | Contents |
|---|---|
| **General** | Menu toggle keybind field, unlock cursor, Window Behavior (prevent duplicate windows, keep on screen, draggable capsule, reset positions), Performance & Motion (haptics, animation speed). |
| **Appearance** | Theme dropdown + Apply, Bar Layout dropdown, profile card controls (show / side / reveal details). |
| **Persistence** | Auto Save Config, Auto Load Config, saved-configurations dropdown with name input and Save/Load/Delete. |
| **About** | Library info and links. |

## Themes

Built-ins: `default`, `amethyst`, `cobalt`, `crimson`, `ember`, `emerald`, `frost`,
`gold`, `onyx`, `rose` (theme modules resolve by lowercased name, so pass `"frost"`).

```lua
window:ChangeTheme("amethyst")
window:ChangeTheme({
    ElementGradient = ColorSequence.new(Color3.fromRGB(20, 20, 30), Color3.fromRGB(30, 30, 45)),
    AccentColor = Color3.fromRGB(120, 90, 220),
})
```

Partial tables are merged over the default theme; a `Color3` given for a gradient
key (`WindowColor`, `ElementGradient`, `ElementStrokeGradient`, `TabBackground`,
`TabStroke`, `SliderProgress`) is coerced to a `ColorSequence`.

## Icons

```lua
Astra.Icons.get("house")              -- searched in pack priority order
Astra.Icons.get("material:home")      -- exactly this pack
Astra.Icons.get("home", "tabler")     -- same, pack as second argument
Astra.Icons.resolve("house")          -- URL / asset id ready for an Image
Astra.Icons.list("lucide")
Astra.Icons.packs() Astra.Icons.count() Astra.Icons.isPack("feather")
Astra.Icons.priority() Astra.Icons.loaded()
Astra.Icons.refreshCustom()           -- re-read custom_asset/
```

- Pack priority: **lucide → material → tabler → phosphor → heroicons → feather → remix**.
  The first pack containing a bare name wins; the search is lazy, so a lucide name
  reads one pack.
- Lookups are exact and case-sensitive: `Home`, `HOME` and `Lucide:house` do not
  match `house`. An unknown pack warns once and resolves to nothing instead of
  substituting a pack.
- Values already usable as-is (`number`, `rbxassetid://`, `rbxasset://`,
  `rbxthumb://`, `http(s)://`) pass through, and an unresolved value comes back
  unchanged — a typo therefore renders a broken image, not an error.
- Icon names ship as 48x48 PNGs under `assets/icons/<pack>-pack/` in this repo and
  are mapped to raw-GitHub URLs at resolve time; no `rbxassetid` lookups needed.
- A `custom_asset/` folder next to the script wins over packs; one file per icon
  name (`.png`, `.jpg`, `.jpeg`, `.webp`, or no extension), subfolders allowed
  (`custom_asset/brand/house.png` → `get("brand/house")`). Qualified names are
  never shadowed.

## Motion

```lua
Astra.Motion.tween(frame, { BackgroundTransparency = 0.5 }, "snappy")
Astra.Motion.tween(panel, { Position = target }, "smooth", function() panel.Visible = false end)
Astra.Motion.tween(stroke, { Color = Color3.new(1, 1, 1) }, TweenInfo.new(0.3))   -- TweenInfo allowed
Astra.Motion.setProfile("relaxed")   -- relaxed | normal | snappy | instant
Astra.Motion.setTimeScale(0.8)
Astra.Motion.setEnabled(false)       -- apply targets immediately, no tweens
Astra.Motion.step(0.035)             -- cascade pacing, scaled like the rest
Astra.Motion.cancel(frame)           -- stop the tweens the service owns here
```

Spec names: `instant`, `fast`, `snappy`, `normal`, `smooth`, `emphasized`, `pop`,
`glide`, `exit`, `spring`, `settle`, `spin`, `drift`. The system is deliberate:
entrances decelerate (Out), exits accelerate (`exit`), lateral state moves ease
InOut (`glide`), playful surfaces use small Back overshoots (`pop`, `settle`,
`spring`). A tween already at its target is skipped, and a conflicting in-flight
tween on the same property is cancelled, so repeated event handlers cannot stack.

## Localisation

```lua
window:RegisterTranslations({ en = { play = "Play" }, de = { play = "Spielen" } })
window:SetLocale("de")
window:SetTranslator(function(source, localeId) return source end)
```

`translator`, `locale` and `translations` can also be passed to `CreateWindow`.

## Persistence

Saving is built in — no `configuration` table is required for normal use. Users
manage it in **Settings → Persistence** (`Auto Save Config` and `Auto Load Config`
both default to on for a new installation; the choices are stored separately from
control values).

- Auto Save writes supported control values after a short coalescing delay; Auto
  Load restores the default configuration on the next startup (never mid-session).
- Turning either off does not delete saved data.
- Stable, unique `flag`s make restores robust when labels change; controls inside
  Collapsible Groups use the same system.
- `forgetState = true` excludes an element from save/load.
- Named configs: `window:Save("Slot2")`, `window:Load("Slot2")`,
  `window:ListConfigs()`, `window:DeleteConfig("Slot2")`.
- A legacy `configuration = { fileName, customFolder, autoSave, autoLoad }` table on
  `CreateWindow` is still accepted, but the built-in save/load preferences take
  precedence. Default storage identifiers are shared by windows using the defaults —
  unrelated hubs should use separate named presets.
- File persistence needs a runtime with writable storage; `window:GetPath()` returns
  the `(folder, file)` pair actually in use.

## Startup pacing

Window construction is staged across frames: large batches of `CreateTab` /
`Create…` calls yield after roughly 4 ms of work or 120 instances (cooperative
budget — a single expensive control can exceed it). Calls still return fully built
objects, but may yield.

Auto-show happens one deferred tick plus one heartbeat later so the caller's first
synchronous calls land before the shell appears; remaining constructors stream in
behind the visible window. `window:Hide()` before that first reveal cancels
auto-show; `window:Show()` still works. The arrival itself cascades: shell first,
then page controls one beat apart, then overlays.

`window:Notify` overlays are **queued** — cards are built on their own
turn, one entrance at a time, with a cooldown between two of them. Past six waiting
requests the oldest not-yet-built request is dropped. With the speed profile set to
**Instant** the order is kept but the pauses disappear.

Search controls are created on first search; built-in settings tabs and their
controls are lazy until selected. Controls added to an inactive tab wait for that
tab to be shown before revealing.

## Window lifecycle notes

- With `antiWindowDuplicate` enabled (default), creating a new window unloads the
  previous live one first instead of leaving two shells fighting for input. Opt out
  per window with `settings = { antiWindowDuplicate = false }`.
- `window:Close()` animates out and unloads; `window:Unload()` destroys immediately.
- A window owns every instance it creates; `window:DestroySubtree` /
  `DestroySubtrees` are the supported way for custom elements to clean up.
