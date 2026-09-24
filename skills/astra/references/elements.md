# Astra v1 — Elements reference

Every element is created with **one props table** on a Tab or a Group:

```lua
local handle = tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = false })
```

Props may be written in camelCase or PascalCase (`name` / `Name`, `callback` /
`Callback`); camelCase is the convention. Element constructors live on the Tab and
Group classes — never on the window.

## Tab

```lua
local tab = window:CreateTab({ name = "Home", icon = "house" })
tab:Select()      -- switch to it
tab:Deselect()    -- switch away
tab:Remove()      -- destroy the tab
tab:SetLocked(locked)  -- gate the tab (host-only; see window.md, "Locked tabs")
```

`CreateTab` also accepts `locked = true`: the tab shows in the sidebar but
cannot be opened (the lock badge UI is temporarily hidden; tap raises a
notification, search skips its elements, `Select`/`Navigate` bail). Only
`tab:SetLocked(false)` unlocks it.

Tab constructors: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`,
`CreateInput`, `CreateLink`, `CreateStat`, `CreateSection`, `CreateText`,
`CreateFooter`, `CreateDivider`, `CreateGroup`, `CreateCollapsibleGroup`, and `CreateIsolated`.

## Group

A Group is an element that lays its own children out. Created on a tab or on
another group:

```lua
local row = tab:CreateGroup()                            -- horizontal row (default)
local col = row:CreateGroup({ direction = "column" })    -- stacked column
col:CreateToggle({ name = "Left 1" })
```

Group constructors are the Tab list **minus** `CreateCollapsibleGroup`. A row keeps
its compact layout when its children support it; the declarative builder inside a
Collapsible Group falls back to a column when a child is non-compact, so no element
is silently dropped.

## Collapsible Group (tab only)

```lua
tab:CreateCollapsibleGroup({
    name = "LocalPlayer",
    icon = "user-round",                              -- optional, any pack
    description = "Optional helper line under the header",
    elements = {
        { type = "Toggle", name = "Infinite Jump", flag = "infiniteJump", value = false, callback = function(on) end },
        { type = "Slider", name = "Walk Speed", flag = "walkSpeed", range = { 16, 100 }, value = 16 },
        { type = "Group", elements = {
            { type = "Button", name = "Reset Speed", icon = "feather:rotate-ccw", callback = function() window:Set("walkSpeed", 16) end },
        } },
    },
})
```

- Supported `type` values: `Button`, `Toggle`, `Switch` (alias of Toggle), `Slider`,
  `Dropdown`, `Input`, `Link`, `Stat`, `Section`, `Text`, `Footer`, `Divider`, `Group`, `Changelog`.
  Each entry uses exactly the same props as its `Create…` method and renders as a regular child.
- `elements` may be omitted for an empty header. Every group starts **collapsed**;
  there is no `expanded` prop.
- Collapsible groups cannot contain collapsible groups, directly or via a Group.
  Invalid types, sparse lists and cyclic definitions are rejected *before* any UI
  is created.
- Controls are built (and saved flags applied) while collapsed, so values survive
  open/close; closing cancels an uncommitted input edit and closes open dropdowns.
- Child handles are exposed in the container's `elements` array, in definition order.

## Isolated (tab only, Changelog-only container)

A CollapsibleGroup-style expandable card dedicated to release history: header
with a left icon, a title/subtitle stack and the built-in right chevron; the
revealed body only ever holds Changelog elements.

```lua
local panel = tab:CreateIsolated({
    name = "View Changelog",                     -- title line (changeable)
    subtitle = "See what's new in this version", -- muted line (changeable)
    icon = "file-text",                          -- left icon (changeable)
    elements = {                                 -- ONLY Changelog definitions
        { type = "Changelog", name = "Release history", entries = {
            { version = "1.2.0", date = "2025-06-14", changes = {
                { symbol = "+", text = "Added Isolated changelog container" },
            } },
        } },
    },
})

panel:Expand()  panel:Collapse()  panel:Toggle()   -- same tween as CollapsibleGroup
panel:SetTitle("Release Notes")
panel:SetSubtitle("v1.2.0 is live")  -- nil clears the line and shrinks the header
panel:SetIcon("scroll-text")         -- left icon only; nil releases the gutter
```

- Any non-Changelog child errors at construction, before any UI exists:
  `Astra:CreateIsolated — only Changelog elements can be placed inside Isolated`.
  Isolated containers also cannot nest inside Collapsible Groups.
- The right chevron is built in: always rendered, rotates with the expansion
  state, never changeable or removable — no setter reaches it.
- Starts collapsed; search indexes child names and expands matches; the
  move/lock API applies to the container; child handles live in `elements`.
- `:MoveTo`, `:MoveToTop`, `:MoveToBottom`, `:MoveUp`, `:MoveDown`, `:Lock`,
  `:Unlock` work on the container.

## Button

```lua
local b = tab:CreateButton({
    name = "Refresh", icon = "refresh-cw",
    callback = function() end,
})
```

Buttons never draw a trailing cursor glyph. `icon` is the optional leading icon;
legacy `tapIcon` / `TapIcon` props are ignored. Click feedback uses card/stroke motion.

## Toggle

```lua
local t = tab:CreateToggle({
    name = "Auto Sprint", flag = "autoSprint", value = true,
    callback = function(on) print(on) end,
})
t:Set(false)          -- fires callback
t:Set(false, true)    -- silent
```

`Switch` is a declarative alias for the same control (Collapsible Group `type`).

## Slider

```lua
local s = tab:CreateSlider({
    name = "Sensitivity", flag = "sens",
    range = { 1, 10 }, value = 5, increment = 1, suffix = "x",
    minimal = true,
    callback = function(value, dragging) end,
})
```

`range` is `{ min, max }`; `suffix` is appended to the readout; `minimal = true`
uses the compact card; `dragging` is true while the handle is being moved.

## Dropdown

```lua
local d = tab:CreateDropdown({
    name = "Preset", options = { "Low", "Medium", "High" }, value = "Medium",
    multiSelect = true, placeholder = "Pick items",
    callback = function(selected) end,     -- a table when multiSelect, a string otherwise
})
d:Refresh({ "A", "B" })   -- replace the option list
d:Add("C")
d:Remove("A")
```

Multi-select rows carry a checkbox and a Select all / Clear action row that only
touches the currently visible options. Long lists get a search filter inside the
open list.

## Keybind

```lua
local key = tab:CreateKeybind({
    name = "Shortcut", value = "K", flag = "shortcut",
    callback = function(letter) print(letter) end,
})
key:Set("p")                 -- normalises to P; false for invalid values
key:Set(Enum.KeyCode.T, true) -- silent
key:Capture()
key:CancelCapture()
```

- A dedicated one-letter TextBox is editable in place; click inside it and type
  or paste one A–Z letter.
- Required value; defaults to K. Cannot clear or bind numbers, punctuation,
  special keys or mouse buttons. Invalid edits and `Set` calls retain the prior
  letter.
- Values/callbacks are uppercase strings; callbacks run on changes only.
- Escape, focus loss, tab switches, folding the parent, hide or unload cancel
  capture. Capturing a key never triggers the window toggle.
- Supports `name`, `icon`, `value`, `flag`, `forgetState`, `callback`, move/lock
  methods, tabs, column Groups and declarative `type = "Keybind"`; it has no
  description row.
- Records the key; only the built-in Settings control assigns the menu shortcut.

## Input

```lua
local i = tab:CreateInput({
    name = "Name", value = "Initial", placeholder = "Type here",
    numeric = true, clearOnFocus = true,
    callback = function(text) end,
})
```

## Stat

```lua
local st = tab:CreateStat({ name = "Kills", value = 128, prefix = "", suffix = " kills" })
st:Set(200)
st:ResetBaseline(0)
print(st.value)
```

Extra props: `display` (`"value"` | `"change"`), `compact`, `changeMode`
(`"percentage"` | `"delta"`), `changeBaseline` (`"previous"` default | `"initial"`;
any other value, numbers included, is read as `"previous"` — use
`stat:ResetBaseline(number)` for a numeric baseline), `numberEasing`, `letter`.

`value` may be a string. A text value shows as a one-letter badge unless
`letter = false`, which reads the whole value out as text instead (no odometer,
no change readout): `tab:CreateStat({ name = "Current theme", value = "Default",
letter = false })` reads "Default". `Set`, `SetText` and `ResetBaseline` all
write that label.

## Link

```lua
local link = tab:CreateLink({
    name = "Discord",                       -- title
    subtitle = "Join our community",        -- muted second line
    link = "https://discord.gg/example",    -- hidden value: copied, never rendered
    icon = "message-circle",
    callback = function(copied) end,        -- optional, after a successful copy
})

link:Set("https://discord.gg/new")    -- or SetLink: rewrite the hidden value
link:SetTitle("Discord server")
link:SetSubtitle("Now with a stage")  -- "" drops the card to its single-line height
link:SetIcon("messages-square")       -- nil removes the leading icon
link:Copy()                           -- run the cycle from code; true when it landed
link:IsConfirming()                   -- true while the check mark is showing
```

- The link is a hidden value: it is stored on the element (`handle.link`) and never
  drawn as text, so a card can carry an invite without printing it on screen.
- The trailing control is fixed and non-configurable: it copies the link, swaps the
  copy mark for a check mark for two seconds, then reverts on its own.
- Each card owns its cycle. Two cards can be in different states, and a container
  never carries the feedback: a Collapsible Group that collapses while a card is
  confirming reveals that card on the copy mark.
- The copy asks the host for a clipboard (`setclipboard`, `toclipboard`,
  `setrbxclipboard`, a `Clipboard` object, or Studio's `StudioService`). With none
  available the card keeps the copy mark and logs the reason instead of claiming
  success.
- Works standalone, in a Group (row or column) and as a declarative
  `{ type = "Link", ... }` child.

## About card (tab only)

```lua
local changelogPanel -- assign below with tab:CreateIsolated(...)
local card = tab:CreateAboutCard({
    name = "Astra",                                   -- header title
    subtitle = "UI Library for a better experience.", -- muted line under it
    icon = 80387863064905,                            -- pack name or asset id
    rows = {                                          -- 1 to 3 rows
        { icon = "code",    label = "Version", value = "1.4.0" },
        { icon = "package", label = "Build",   value = "2026.09.12" },
        { icon = "user",    label = "Author",  value = "Astra Team" },
    },
    action = {                                        -- optional trailing band
        icon = "file-text",
        name = "View Changelog",
        subtitle = "See what's new in this version",
        callback = function()
            if changelogPanel then changelogPanel:Expand() end
        end,                                         -- fires on a tap of the band
    },
})

card:SetTitle("Release notes")
card:SetSubtitle(nil)                 -- "" / nil drops the header to one band
card:SetIcon("sparkles")              -- nil removes the leading mark
card:SetRow(1, { icon = "box", label = "Version", value = "1.5.0" })
```

- Three blocks in one card: header (icon, title, subtitle), the data rows and
  the optional action band. `description` is ignored — the paragraph block
  has been removed.
- `rows` takes **1 to 3** entries. All entries stay on one compact 48px line and
  split it evenly from left to right, so Version / Build / Author renders as
  three columns rather than two columns plus an orphan below. On an unusually
  narrow window, long copy truncates inside its tile instead of wrapping the
  tile. A fourth row errors at construction:
  `Astra:CreateAboutCard — at most 3 data rows are supported, got N` — the action
  band is the card's trailing row.
- Optional parts drop out of the layout instead of rendering blank: a row without
  `icon` loses its badge, and a card without `rows` or `action` simply has one
  block fewer.
- The action band is the card's only tappable surface: a tap (anywhere on the
  band, not only the chevron) fires `callback` once, with a haptic click. The
  trailing chevron itself is fixed and has no setter.
- `SetRow(index, row)` addresses a row the card already has, rewrites only the
  fields given, and errors for an index it does not have.
- Supports the move API and `Lock()`/`Unlock()`/`IsLocked()`; a locked card fires
  no action.

## Text, Section, Divider

```lua
local x = tab:CreateText({ name = "Title", text = "Body text" })
x:Set("New body")
x:SetTitle("New title")

tab:CreateSection({ name = "Basic elements", icon = "list" })
tab:CreateDivider()                          -- plain rule
tab:CreateDivider({ text = "or" })           -- labelled rule
tab:CreateDivider({ line = false, spacing = 8 })

-- Footer: a centred run of text and inline icons that re-centres as one unit.
local footer = tab:CreateFooter({
    parts = {
        { text = "Built with" },
        { icon = "zap" },
        { text = "Astra" },
        { icon = "heart" },
    },
})
footer:Set({ "Made", { icon = "heart" }, "with Astra" })  -- replace the run
```

`CreateFooter` takes `parts` (ordered; `{ text = ... }` / `{ icon = ... }` /
plain-string shorthand), optional `textSize` (13) and `spacing` (6). Icons
resolve through the icon catalog and scale to the text; unresolvable names
drop. Text runs accept RichText.

## Changelog

Release history renders as a standalone element wherever it is declared:

```lua
local log = tab:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = { { version = "0.0.35", date = "2026-09-11", changes = {
        { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
    } } },
})

log:Add({ version = "Live", date = "Today", changes = { { symbol = "+", text = "Runtime entry." } } })  -- prepends
log:Add(entry, false)   -- append instead
log:Set({ ... })        -- replace all entries (full { name, entries, ... } tables accepted)
log:Clear()
log:SetTitle("History")
log:Refresh()
```

Symbols: `+` added (green), `-` removed (red), `~` changed (amber); the words
`"added"`/`"removed"`/`"changed"` map to the same colours. The element supports the same move/lock API as other elements.

## Moveable & Lockable

| Capability | Methods | Applies to |
|---|---|---|
| Moveable | `:MoveTo(index)`, `:MoveToTop()`, `:MoveToBottom()`, `:MoveUp()`, `:MoveDown()` | every element, including Groups and Collapsible Groups |
| Lockable | `:Lock()`, `:Unlock()`, `:IsLocked()` | most interactive elements |

Locked elements ignore user input while keeping their values, selection, callback
and layout; `MoveTo` indices are tab-relative and re-clamped after sibling
removal. Functional controls publish `usage = "lockable:astra:<elementId>"`
(or a usage array that retains pre-existing entries). Static/decorative elements
and Buttons without callbacks are excluded. Supply `id`/`elementId` for a stable
ID and `lockLevel = 1..5` or `lockGroup` (`minor`, `standard`, `action`,
`sensitive`, `all`) to override the automatic tier.

Built-in Settings → Controls has a fixed, cumulative five-mode controller:
Mode 1 locks level 1, each higher mode adds its level, and Mode 5 locks every
registered control. Its own reset button remains usable; external code can use
`window:SetElementLockMode(1..5)` and `window:GetElementLockMode()`. Manual locks
compose with mode locks, and this client-side gate is not a security boundary.
