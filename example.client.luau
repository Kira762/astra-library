-- [[Astra element-coverage example.]]
-- [[Everything lives in one tab so startup pacing and every element type can be
-- [[tested without navigating through a collection of duplicate demo tabs.]]

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
