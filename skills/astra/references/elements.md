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
```

Tab constructors: `CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`,
`CreateInput`, `CreateStat`, `CreateSection`, `CreateText`, `CreateChangelog`,
`CreateDivider`, `CreateGroup`, and `CreateCollapsibleGroup`.

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
  `Dropdown`, `Input`, `Stat`, `Section`, `Text`, `Changelog`, `Divider`, `Group`.
  Each entry uses exactly the same props as its `Create…` method.
- `elements` may be omitted for an empty header. Every group starts **collapsed**;
  there is no `expanded` prop.
- Collapsible groups cannot contain collapsible groups, directly or via a Group.
  Invalid types, sparse lists and cyclic definitions are rejected *before* any UI
  is created.
- Controls are built (and saved flags applied) while collapsed, so values survive
  open/close; closing cancels an uncommitted input edit and closes open dropdowns.
- Child handles are exposed in the container's `elements` array, in definition order.
- `:MoveTo`, `:MoveToTop`, `:MoveToBottom`, `:MoveUp`, `:MoveDown`, `:Lock`,
  `:Unlock` work on the container.

## Button

```lua
local b = tab:CreateButton({
    name = "Refresh", icon = "refresh-cw",
    tapIcon = false,                 -- hide the built-in tap glyph
    callback = function() end,
})
```

Every button carries a built-in tap glyph on its right edge, resolved through the
icon catalog; the glyph is part of the card, so tapping it taps the button.
`tapIcon = false` hides it, and `tapIcon = "name"` or an asset id replaces it.

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
`stat:ResetBaseline(number)` for a numeric baseline), `numberEasing`.

## Text, Section, Divider

```lua
local x = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })
x:Set("New body")
x:SetTitle("New title")

tab:CreateSection({ name = "Basic elements", icon = "list" })
tab:CreateDivider()                          -- plain rule
tab:CreateDivider({ text = "or" })           -- labelled rule
tab:CreateDivider({ line = false, spacing = 8 })
```

## Changelog

Scrollable release history with `+` (added, green), `-` (removed, red) and `~`
(changed, amber) symbols; symbol words such as `"added"`, `"removed"`, `"changed"`
map to the same colours.

```lua
local log = tab:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            game = "Game Name",              -- optional; gameId = number also accepted
            title = "Settings highlight",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
                { symbol = "+", text = "Added the Changelog element." },
                { symbol = "-", text = "Removed the old sub-tab API." },
            },
        },
    },
})

log:Add({ version = "Live", date = "Today", changes = { { symbol = "+", text = "Runtime entry." } } })  -- prepends
log:Add(entry, false)   -- append instead
log:Set({ ... })        -- replace all entries (`:Refresh` is an alias)
log:Clear()
```

## Moveable & Lockable

| Capability | Methods | Applies to |
|---|---|---|
| Moveable | `:MoveTo(index)`, `:MoveToTop()`, `:MoveToBottom()`, `:MoveUp()`, `:MoveDown()` | every element, including Groups and Collapsible Groups |
| Lockable | `:Lock()`, `:Unlock()`, `:IsLocked()` | most interactive elements |

Locked elements ignore user input while keeping their value; `MoveTo` indices are
tab-relative and re-clamped after sibling removal.
