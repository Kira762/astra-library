-- [[Astra multi-tab supported-usage example.]]
-- [[This example loads the current bundle with remote icon asset resolution.]]

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
    name = "Astra",
    subtitle = "Multi-tab supported API example",
})

-- [[Window tags are rendered beside the window title and remain available in the chrome.]]
window:CreateTag({
    icon = "tag",
    text = "0.0.35",
    color = Color3.fromRGB(88, 70, 170),
})
window:CreateTag({
    icon = "badge-check",
    text = "Beta",
    color = Color3.fromRGB(190, 55, 125),
})

-- [[Home: use a tab for overview content and simple state controls.]]
local home = window:CreateTab({ name = "Home", icon = "house" })
home:CreateSection({ name = "Overview" })
home:CreateText({
    name = "Welcome",
    text = "Create tabs from the Window, then create elements from each Tab.",
})
home:CreateButton({
    name = "Say hello",
    callback = function()
        window:Notify({ title = "Hello", content = "The Home tab is working." })
    end,
})
home:CreateToggle({
    name = "Enable feature",
    value = true,
    callback = function(value)
        window:Notify({
            title = "Feature",
            content = if value then "Feature enabled." else "Feature disabled.",
        })
    end,
})

-- [[Controls: use input elements for values, choices, and user text.]]
local controls = window:CreateTab({ name = "Controls", icon = "sliders-horizontal" })
controls:CreateSection({ name = "Input elements" })
controls:CreateSlider({
    name = "Volume",
    range = { 0, 100 },
    value = 50,
    increment = 1,
    callback = function(value)
        window:Toast({ title = "Volume", subtitle = tostring(value) })
    end,
})
controls:CreateDropdown({
    name = "Mode",
    options = { "Default", "Performance", "Visual" },
    value = "Default",
    callback = function(value)
        window:Notify({ title = "Mode changed", content = tostring(value) })
    end,
})
controls:CreateInput({
    name = "Display name",
    placeholder = "Enter a name",
    callback = function(value)
        window:Toast({ title = "Name updated", subtitle = tostring(value) })
    end,
})

-- [[Appearance: use visual elements for colors, dividers, and explanatory text.]]
local appearance = window:CreateTab({ name = "Appearance", icon = "palette" })
appearance:CreateSection({ name = "Visual elements" })
appearance:CreateSlider({
    name = "Opacity",
    range = { 0, 100 },
    value = 80,
    suffix = "%",
    callback = function(value)
        window:Toast({ title = "Opacity updated", subtitle = tostring(value) })
    end,
})
appearance:CreateDivider()
appearance:CreateText({
    name = "Layout",
    text = "Use this tab for visual and theme-related controls.",
})

-- [[Information: document the Window, Tab, and element creation pattern.]]
local information = window:CreateTab({ name = "Information", icon = "info" })
information:CreateSection({ name = "Usage" })
information:CreateText({
    name = "Create a tab",
    text = 'local tab = window:CreateTab({ name = "Settings", icon = "settings" })',
})
information:CreateText({
    name = "Create an element",
    text = 'tab:CreateButton({ name = "Action", callback = function() end })',
})
information:CreateText({
    name = "Select a tab",
    text = "Call tab:Select() to display a tab. This example selects Home on startup.",
})
information:CreateButton({
    name = "Show notification",
    callback = function()
        window:Toast({ title = "Astra", subtitle = "All example tabs are available." })
    end,
})
information:CreateSection({ name = "Additional elements" })
information:CreateProgress({
    name = "Progress",
    range = { 0, 100 },
    value = 68,
    steps = 10,
    suffix = "%",
})
information:CreateStat({
    name = "Active tests",
    value = 20,
    suffix = " tabs",
})
information:CreateKeybind({
    name = "Test shortcut",
    value = Enum.KeyCode.RightShift,
    callback = function()
        window:Toast({ title = "Shortcut", subtitle = "Test shortcut activated" })
    end,
})
local console = information:CreateConsole({
    name = "Test console",
    text = "A console element for displaying diagnostic lines.",
    height = 90,
})
console:Append("Changelog and element tests are ready.")
local elementGroup = information:CreateGroup({ direction = "column" })
elementGroup:CreateButton({
    name = "Group action",
    callback = function()
        window:Toast({ title = "Group", subtitle = "Grouped element action completed" })
    end,
})
elementGroup:CreateToggle({
    name = "Grouped toggle",
    value = true,
    callback = function(value)
        window:Toast({ title = "Grouped toggle", subtitle = if value then "Enabled" else "Disabled" })
    end,
})

local changelogTab = window:CreateTab({ name = "Changelog", icon = "history" })
local changelog = changelogTab:CreateChangelog({
    name = "Release history",
    description = "Recent Astra changes and fixes.",
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            title = "Settings highlight",
            description = "Improved the built-in Settings active state.",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings now stays highlighted while its tab is active." },
            },
        },
        {
            version = "0.0.34",
            date = "2026-09-11",
            title = "Example tab coverage",
            description = "Expanded the example with named and icon-backed tabs.",
            changes = {
                { symbol = "+", category = "Added", text = "Added more tabs for layout and element testing." },
            },
        },
    },
})
changelogTab:CreateButton({
    name = "Add test entry",
    callback = function()
        changelog:Add({
            version = "Test",
            date = "Live",
            title = "Runtime update",
            changes = {
                { symbol = "+", text = "This changelog entry was added at runtime." },
            },
        })
        window:Toast({ title = "Changelog", subtitle = "New entry added" })
    end,
})

-- [[Updates: use standard elements so release information is always visible.]]
local updatesTab = window:CreateTab({ name = "Updates", icon = "megaphone" })
updatesTab:CreateSection({ name = "Recent changes" })
updatesTab:CreateText({
    name = "0.0.35",
    text = "Improved bundle-loader diagnostics and settings navigation feedback.",
})
updatesTab:CreateText({
    name = "0.0.34",
    text = "Added a safeguard that keeps example tabs available when optional test elements fail.",
})
updatesTab:CreateText({
    name = "Beta preview",
    text = "This example is a Beta preview of the multi-tab Astra API.",
})
updatesTab:CreateButton({
    name = "Show update notice",
    callback = function()
        window:Toast({ title = "Updates", subtitle = "The replacement Updates tab is working." })
    end,
})

-- [[Additional test tabs: twenty main-window tabs with varied elements.]]
local testTabs = {
    { name = "Dashboard", icon = "layout-dashboard" },
    { name = "Analytics", icon = "chart-no-axes-combined" },
    { name = "Profile", icon = "user-round" },
    { name = "Security", icon = "shield" },
    { name = "Network", icon = "wifi" },
    { name = "Audio", icon = "volume-2" },
    { name = "Display", icon = "monitor" },
    { name = "Shortcuts", icon = "keyboard" },
    { name = "Notifications", icon = "bell" },
    { name = "Storage", icon = "hard-drive" },
    { name = "Automation", icon = "bot" },
    { name = "Advanced", icon = "wrench" },
    { name = "Debug", icon = "bug" },
    { name = "Logs", icon = "scroll-text" },
    { name = "Experiments", icon = "flask-conical" },
}

for index, details in ipairs(testTabs) do
    assert(
        type(details.name) == "string"
            and details.name ~= ""
            and type(details.icon) == "string"
            and details.icon ~= "",
        "Each example tab must define both a name and an icon."
    )
    local tab = window:CreateTab({ name = details.name, icon = details.icon })
    -- [[Keep the tab selector registered even if an optional element has an]]
    -- [[environment-specific constructor issue; this lets the remaining tabs load.]]
    local ok = pcall(function()
        tab:CreateSection({ name = "Test elements" })
        tab:CreateText({
            name = "Test tab " .. tostring(index),
            text = "This tab is part of the twenty-tab loading and layout test.",
        })
        tab:CreateButton({
            name = "Run test action",
            callback = function()
                window:Toast({ title = details.name, subtitle = "Action completed" })
            end,
        })

        if index % 4 == 1 then
            tab:CreateToggle({
            name = "Enabled",
            value = index % 3 == 0,
            callback = function(value)
                window:Toast({ title = details.name, subtitle = if value then "Enabled" else "Disabled" })
            end,
            })
            tab:CreateSlider({
            name = "Intensity",
            range = { 0, 100 },
            value = index * 5,
            increment = 5,
            callback = function(value)
                window:Toast({ title = details.name, subtitle = "Intensity: " .. tostring(value) })
            end,
            })
        elseif index % 4 == 2 then
            tab:CreateDropdown({
            name = "Preset",
            options = { "Low", "Medium", "High" },
            value = "Medium",
            callback = function(value)
                window:Toast({ title = details.name, subtitle = "Preset: " .. tostring(value) })
            end,
            })
            tab:CreateInput({
            name = "Label",
            placeholder = "Test input",
            callback = function(value)
                window:Toast({ title = details.name, subtitle = "Label: " .. tostring(value) })
            end,
            })
        elseif index % 4 == 3 then
            tab:CreateSlider({
            name = "Level",
            range = { 0, 100 },
            value = 50,
            callback = function(value)
                window:Toast({ title = details.name, subtitle = "Level: " .. tostring(value) })
            end,
            })
            tab:CreateDivider()
        else
            tab:CreateText({ name = "Status", text = "Ready for testing." })
            tab:CreateToggle({
            name = "Experimental mode",
            value = false,
            callback = function(value)
                window:Toast({ title = details.name, subtitle = if value then "Experimental mode on" else "Experimental mode off" })
            end,
            })
        end
    end)
end

-- [[Select the first tab explicitly so the example is deterministic on startup.]]
home:Select()
