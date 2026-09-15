-- [[Astra element-coverage example.]]
-- [[Everything lives in one tab so startup pacing and every element type can be
-- [[tested without navigating through a collection of duplicate demo tabs.]]

local bundleSource = game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau")
local compile = loadstring or load
assert(type(compile) == "function", "[Astra] This executor does not provide loadstring/load.")
local bundleLoader, compileError = compile(bundleSource)
assert(type(bundleLoader) == "function", "[Astra] Bundle compilation failed: " .. tostring(compileError))
local Astra = bundleLoader()

assert(
    type(Astra) == "table" and type(Astra.CreateWindow) == "function",
    "[Astra] Failed to load Astra bundle."
)

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

local progress = elements:CreateProgress({
    name = "Progress",
    range = { 0, 100 },
    value = 42,
    steps = 10,
    suffix = "%",
    showValue = true,
})

local stat = elements:CreateStat({
    name = "Stat",
    value = 128,
    suffix = " requests",
    compact = true,
    changeMode = "delta",
    changeBaseline = 100,
})

elements:CreateDivider({ text = "Interactive elements" })

elements:CreateButton({
    name = "Button",
    icon = "hand-tap",
    callback = function()
        progress:Set(math.random(0, 100))
        stat:Set(stat.value + 1)
        window:Notify({ title = "Button", content = "Progress and stat were updated." })
    end,
})

elements:CreateToggle({
    name = "Toggle",
    value = true,
    callback = function(value)
        window:Toast({ title = "Toggle", subtitle = if value then "Enabled" else "Disabled" })
    end,
})

elements:CreateSlider({
    name = "Slider",
    range = { 0, 100 },
    value = 50,
    increment = 5,
    suffix = "%",
    callback = function(value)
        progress:Set(value)
    end,
})

elements:CreateDropdown({
    name = "Dropdown",
    options = { "Low", "Medium", "High" },
    value = "Medium",
    callback = function(value)
        window:Toast({ title = "Dropdown", subtitle = tostring(value) })
    end,
})

elements:CreateDropdown({
    name = "Multi-select dropdown",
    options = { "Combat", "Movement", "Visual" },
    value = { "Combat" },
    multiSelect = true,
    placeholder = "Choose tags",
})

elements:CreateInput({
    name = "Input",
    placeholder = "Type something",
    callback = function(value)
        window:Toast({ title = "Input", subtitle = tostring(value) })
    end,
})

elements:CreateInput({
    name = "Numeric input",
    placeholder = "Enter a number",
    numeric = true,
    clearOnFocus = true,
})

elements:CreateKeybind({
    name = "Keybind",
    value = Enum.KeyCode.RightShift,
    callback = function()
        window:Toast({ title = "Keybind", subtitle = "Shortcut activated" })
    end,
})

elements:CreateChangelog({
    name = "Changelog",
    entries = {
        {
            version = "Element Test",
            date = "Live",
            title = "All supported elements",
            changes = {
                { symbol = "+", category = "Added", text = "This changelog is part of the single-tab startup test." },
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

-- [[The declarative group exercises the CollapsibleGroup path and every child
-- [[constructor, including the Switch alias used by declarative definitions.]]
elements:CreateCollapsibleGroup({
    name = "Collapsible Group",
    icon = "panels-top-left",
    description = "Expand this card to inspect every declarative child type.",
    elements = {
        { type = "Section", name = "Declarative children" },
        { type = "Text", name = "Text child", text = "All child controls are constructed while the group is collapsed." },
        { type = "Button", name = "Button child", callback = function() window:Toast({ title = "Child button", subtitle = "Clicked" }) end },
        { type = "Toggle", name = "Toggle child", value = true },
        { type = "Switch", name = "Switch alias child", value = false },
        { type = "Slider", name = "Slider child", range = { 0, 100 }, value = 25 },
        { type = "Dropdown", name = "Dropdown child", options = { "One", "Two" }, value = "One" },
        { type = "Input", name = "Input child", placeholder = "Child input" },
        { type = "Keybind", name = "Keybind child", value = Enum.KeyCode.RightControl },
        { type = "Stat", name = "Stat child", value = 42, suffix = " checks" },
        { type = "Progress", name = "Progress child", range = { 0, 100 }, value = 62, steps = 10, suffix = "%" },
        { type = "Divider", text = "Nested diagnostics" },
        {
            type = "Changelog",
            name = "Changelog child",
            entries = {
                {
                    version = "Test",
                    date = "Live",
                    title = "Nested changelog",
                    changes = {
                        { symbol = "+", text = "Changelog works inside a Collapsible Group." },
                    },
                },
            },
        },
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
