-- [[Astra v1 starter hub - one window, two tabs, every element type.]]
-- [[Copy this file into an executor, or use it as the shape for a bigger hub.
-- [[Requires loadstring (an executor) and HttpService requests enabled.]]

-- [[The published bundle is the only thing to load: fetch it, then call the
-- [[chunk. The trailing `()` is what returns the Astra table.]]
local Astra =
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

local window = Astra:CreateWindow({
    name = "Starter Hub",
    subtitle = "Astra v1",
    icon = "sparkles",
    theme = "default",
})

-- [[Every control with a flag participates in the built-in Save/Load that the
-- [[Settings window exposes; keep flags stable and unique.]]

local home = window:CreateTab({ name = "Home", icon = "house" })

home:CreateSection({ name = "Quick actions" })

local stat = home:CreateStat({
    name = "Actions run",
    value = 0,
    suffix = " calls",
    compact = true,
})

home:CreateButton({
    name = "Say hello",
    icon = "play",
    callback = function()
        stat:Set(stat.value + 1)
        window:Notify({ title = "Hello", content = "The button callback works." })
    end,
})

home:CreateButton({
    name = "Confirm something",
    icon = "circle-help",
    callback = function()
        window:Popup({
            title = "Are you sure?",
            content = "Popups return options, each with its own callback.",
            options = {
                { text = "Cancel" },
                {
                    text = "Confirm",
                    style = "primary",
                    callback = function()
                        window:Notify({ title = "Confirmed", content = "The popup callback ran." })
                    end,
                },
            },
        })
    end,
})

home:CreateDivider({ text = "Saved settings" })

home:CreateToggle({
    name = "Auto Sprint",
    flag = "autoSprint",
    value = false,
    callback = function(on)
        window:Notify({ title = "Auto Sprint", content = if on then "Enabled" else "Disabled" })
    end,
})

home:CreateSlider({
    name = "Walk Speed",
    flag = "walkSpeed",
    range = { 16, 100 },
    value = 16,
    increment = 2,
    suffix = " studs",
    callback = function(value, dragging)
        if not dragging then
            window:Notify({ title = "Walk Speed", content = tostring(value) })
        end
    end,
})

home:CreateDropdown({
    name = "Visual preset",
    flag = "visualPreset",
    options = { "Low", "Medium", "High" },
    value = "Medium",
    callback = function(value)
        print("preset:", value)
    end,
})

home:CreateInput({
    name = "Display name",
    flag = "displayName",
    placeholder = "Type a name",
    callback = function(text)
        print("name:", text)
    end,
})

home:CreateDivider({ text = "Groups" })

-- [[A plain Group is an element too: a row by default, a column on request.]]
local row = home:CreateGroup()
local column = row:CreateGroup({ direction = "column" })
column:CreateText({ name = "Nested group", text = "Groups may contain groups and elements." })
column:CreateToggle({ name = "Grouped toggle", flag = "groupedToggle", value = true })

-- [[Collapsible groups exist only on tabs and take declarative children.]]
home:CreateCollapsibleGroup({
    name = "LocalPlayer",
    icon = "user-round",
    description = "Expand for the player controls.",
    elements = {
        { type = "Toggle", name = "Infinite Jump", flag = "infiniteJump", value = false },
        { type = "Slider", name = "Jump Power", flag = "jumpPower", range = { 50, 200 }, value = 50 },
        {
            type = "Group",
            elements = {
                {
                    type = "Button",
                    name = "Reset speed",
                    icon = "feather:rotate-ccw",
                    callback = function()
                        window:Set("walkSpeed", 16)
                    end,
                },
                {
                    type = "Button",
                    name = "Show speed",
                    callback = function()
                        print(window:Get("walkSpeed"))
                    end,
                },
            },
        },
    },
})

local about = window:CreateTab({ name = "About", icon = "info" })

about:CreateText({
    name = "Astra",
    text = "One loader, one window, tabs full of elements. Flags are saved automatically.",
    icon = "sparkles",
})

-- [[Release history renders as a standalone element.]]
about:CreateChangelog({
    name = "Release history",
    entries = {
        {
            version = "v1",
            date = "Live",
            title = "Starter hub",
            changes = {
                { symbol = "+", category = "Added", text = "Tabs, every element type and a Collapsible Group." },
                { symbol = "~", text = "Flags belong to the built-in Save/Load system." },
            },
        },
    },
})

about:CreateButton({
    name = "Switch theme",
    icon = "palette",
    callback = function()
        window:ChangeTheme("amethyst")
        window:Notify({ title = "Theme", content = "Amethyst applied." })
    end,
})

-- [[Switching tabs explicitly keeps the example deterministic.]]
home:Select()
