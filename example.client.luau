-- [[Astra element-coverage example.]]
-- [[Everything lives in one tab so startup pacing and every element type can be
-- [[tested without navigating through a collection of duplicate demo tabs —
-- [[plus one locked tab demonstrating the lock badge and SetLocked.]]

-- [[The one and only bundle loader: fetch the published bundle and call the
-- [[chunk it compiles to. `loadstring` needs an executor — plain Studio does
-- [[not provide it — and the URL must be the raw file of a public repo.]]
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

local window = Astra:CreateWindow({
    name = "Astra Element Test",
    subtitle = "All elements in one paced tab",
    configuration = {
        fileName = "Astra-Example",
        customFolder = "AstraExamples",
        autoSave = true,
        autoLoad = true,
    },
})

-- [[One tab intentionally contains every supported element type.]]
local elements = window:CreateTab({ name = "Element Test", icon = "flask-conical" })

elements:CreateSection({ name = "Basic elements" })
elements:CreateText({
    name = "Text",
    text = "This single tab builds every Astra element so startup batching and layout pacing are easy to observe.",
})

local stat = elements:CreateStat({
    name = "Stat",
    value = 128,
    suffix = " requests",
    compact = true,
    changeMode = "delta",
    changeBaseline = "initial",
})

elements:CreateDivider({ text = "Interactive elements" })

-- [[Every functional element below carries an `info` description: the (!) badge
-- [[sits right after the element's name, and hovering it (or tapping it, or
-- [[holding it down on touch) reveals the floating description. Tap the badge
-- [[again to close it. Elements without `info` draw no badge at all.]] 

elements:CreateButton({
    name = "Button",
    icon = "hand-tap",
    info = "Triggers an action and updates telemetry stats.",
    callback = function()
        stat:Set(stat.value + 1)
        window:Notify({ title = "Button", content = "Stat was updated." })
    end,
})

elements:CreateToggle({
    name = "Toggle",
    info = "Enables or disables this feature with automatic state persistence.",
    infoIcon = "shield-check", -- the badge glyph; defaults to circle-alert
    value = true,
    callback = function(value)
        window:Notify({ title = "Toggle", content = if value then "Enabled" else "Disabled" })
    end,
})

elements:CreateSlider({
    name = "Slider",
    info = "Adjusts the numeric target value in calibrated steps.",
    range = { 0, 100 },
    value = 50,
    increment = 5,
    suffix = "%",
    callback = function(value)
        stat:Set(value)
    end,
})

elements:CreateDropdown({
    name = "Dropdown",
    info = "Selects one option from the available configuration list.",
    options = { "Low", "Medium", "High" },
    value = "Medium",
    callback = function(value)
        window:Notify({ title = "Dropdown", content = tostring(value) })
    end,
})

elements:CreateDropdown({
    name = "Multi-select dropdown",
    info = "Selects multiple tags simultaneously.",
    options = { "Combat", "Movement", "Visual" },
    value = { "Combat" },
    multiSelect = true,
    placeholder = "Choose tags",
})

-- [[Keep the example to the original Input element: one useful text field,
-- [[not extra one-off input rows.]]
elements:CreateInput({
    name = "Input",
    info = "Accepts custom text strings or evaluated numeric formulas.",
    placeholder = "Type something",
    callback = function(value)
        window:Notify({ title = "Input", content = tostring(value) })
    end,
})

-- [[`:SetInfo(text)` retargets the badge at runtime; an empty text removes it
-- [[(and the badge never existed for an element built without `info`).]] 
local runtimeInfo = elements:CreateButton({
    name = "Runtime info",
    callback = function()
        runtimeInfo:SetInfo(runtimeInfo.info and "" or "Added at runtime - tap the (!) badge again to close it.")
    end,
})

-- [[Locked tab: built gated, with a lock badge in the row's top-right corner.
-- [[Tapping it raises a notification instead of opening it; only host code
-- [[unlocks it, through tab:SetLocked(false).]]
local premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })
premium:CreateSection({ name = "Premium only" })
premium:CreateText({
    name = "Gated content",
    text = "This tab was built locked. The badge in its row's corner stays until host code unlocks it, and its contents are never built visible or indexed by search.",
})
premium:CreateButton({
    name = "Re-lock this tab",
    icon = "lock",
    info = "SetLocked(true) on the open tab moves the selection away.",
    callback = function()
        premium:SetLocked(true)
        elements:Select()
    end,
})

elements:CreateButton({
    name = "Unlock the Premium tab",
    icon = "lock-open",
    info = "Host-only: SetLocked(false) re-enables the row and its badge disappears.",
    callback = function()
        premium:SetLocked(false)
        premium:Select()
    end,
})

elements:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "Element Test",
            date = "Live",
            title = "All supported elements",
            changes = {
                { symbol = "+", category = "Added", text = "This changelog renders as a standalone element." },
            },
        },
    },
})

-- [[A normal Group is an element too. Its children use the compact row layout.]]
local group = elements:CreateGroup({ direction = "column" })
group:CreateSection({ name = "Group" })
group:CreateButton({
    name = "Grouped button",
    callback = function()
        window:Notify({ title = "Group", content = "The ordinary Group child is working." })
    end,
})
group:CreateToggle({ name = "Grouped toggle", value = false })

-- [[The declarative group exercises the CollapsibleGroup path with useful child
-- [[rows; the standalone Input above covers the original input element.]]
elements:CreateCollapsibleGroup({
    name = "Collapsible Group",
    icon = "panels-top-left",
    description = "Expand this card to inspect the useful declarative child rows.",
    elements = {
        { type = "Section", name = "Declarative children" },
        { type = "Text", name = "Text child", text = "All child controls are constructed while the group is collapsed." },
        { type = "Button", name = "Button child", callback = function() window:Notify({ title = "Child button", content = "Clicked" }) end },
        { type = "Toggle", name = "Toggle child", value = true },
        { type = "Switch", name = "Switch alias child", value = false },
        { type = "Slider", name = "Slider child", range = { 0, 100 }, value = 25 },
        { type = "Dropdown", name = "Dropdown child", options = { "One", "Two" }, value = "One" },
        { type = "Stat", name = "Stat child", value = 42, suffix = " checks" },
        { type = "Divider", text = "Nested diagnostics" },
        { type = "Changelog", name = "Nested changelog", entries = { { version = "1.0", date = "Live", changes = { { symbol = "+", text = "Changelog inside collapsible group" } } } } },
        {
            type = "Group",
            direction = "column",
            elements = {
                { type = "Text", name = "Nested Group", text = "Ordinary Groups may be nested." },
                { type = "Button", name = "Nested action", callback = function() window:Notify({ title = "Nested Group", content = "The nested action works." }) end },
            },
        },
    },
})

-- [[Select the only user tab explicitly so the example is deterministic.]]
elements:Select()
