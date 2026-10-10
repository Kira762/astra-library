-- Executor entry point. In Studio/Rojo, require ReplicatedStorage.Astra instead.
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-library/main/version-1.luau"))()

local window = Astra:CreateWindow({
    name = "Astra Element Studio",
    subtitle = "Explore • interact • customise",
    icon = "sirius",
    configuration = {
        fileName = "Astra-Example",
        customFolder = "AstraExamples",
        autoSave = true,
        autoLoad = true,
    },
})

--[[
Information comes first. The remaining tabs group controls by what they do,
not by constructor name. Every supported element has a useful place here.
]]
local overview = window:CreateTab({ name = "Overview", icon = "house" })
local actions = window:CreateTab({ name = "Actions", icon = "play" })
local preferences = window:CreateTab({ name = "Preferences", icon = "sliders-horizontal" })
local releaseHistory

overview:CreateSection({ name = "Astra", icon = 80387863064905 })
overview:CreateText({
    name = "A small studio for every element.",
    text = "Version 1.4.0 · build 2026.09.21 · by Astra Team.",
})
overview:CreateButton({
    name = "Release history",
    icon = "file-text",
    callback = function()
        if not releaseHistory then return end
        overview:Select()
        releaseHistory:Expand()
        task.defer(function()
            if not releaseHistory.main.Parent then return end
            local page = overview.tabPage
            local top = page.CanvasPosition.Y + releaseHistory.main.AbsolutePosition.Y - page.AbsolutePosition.Y
            page.CanvasPosition = Vector2.new(0, math.max(0, top - 10))
        end)
    end,
})
overview:CreateSection({ name = "Start here" })
overview:CreateText({
    name = "Your quick tour",
    text = "Actions demonstrates buttons, compact groups, statistics and feedback. Preferences covers switches, ranges, choices, text and letter-only key capture. The gear opens library settings; its Overview always comes first.",
})
overview:CreateDivider({ text = "Resources" })
overview:CreateLink({
    name = "Source & releases", subtitle = "Copy the repository link", icon = "code",
    link = "https://github.com/Kira762/astra-library",
})
overview:CreateLink({
    name = "Build with Astra", subtitle = "Copy the element and API guide", icon = "book-open",
    link = "https://github.com/Kira762/astra-library/blob/main/USAGE.md",
})
overview:CreateChangelog({
    name = "Studio highlights",
    entries = {
        { version = "Current", date = "2026.09.21", title = "Focused controls, quieter chrome", changes = {
            { symbol = "+", text = "Dedicated A–Z key capture, with a required letter and Escape to cancel." },
            { symbol = "~", text = "Buttons no longer carry a trailing cursor. The restore capsule appears only after hiding." },
            { symbol = "~", text = "Information comes first; controls are organised by purpose." },
        } },
    },
})
releaseHistory = overview:CreateCollapsibleGroup({
    name = "Release history", description = "Earlier library milestones", icon = "history",
    elements = {
        { type = "Changelog", name = "Recent releases", entries = {
            { version = "1.4.0", date = "2026.09.12", changes = {
                { symbol = "+", text = "Links, changelogs and richer grouped controls." },
            } },
        } },
        { type = "Changelog", name = "Earlier releases", entries = {
            { version = "1.2.0", title = "Structured content", changes = {
                { symbol = "+", text = "Collapsible groups and structured content blocks." },
            } },
        } },
    },
})
overview:CreateDivider()
overview:CreateFooter({ parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" }, { icon = "heart" } } })

--[[
Actions: an immediate result, a compact action pair and a related advanced
group. No collapsible wrapper is used for a lone control.
]]
actions:CreateSection({ name = "Activity" })
local runs = actions:CreateStat({ name = "Completed runs", value = 0, suffix = " runs", changeMode = "delta", changeBaseline = "initial" })
actions:CreateButton({
    name = "Run a check", icon = "play",
    callback = function()
        runs:Set(runs.value + 1)
        window:Notify({ title = "Check complete", content = "The button callback ran successfully." })
    end,
})
local shortcuts = actions:CreateGroup({ direction = "row" })
shortcuts:CreateButton({ name = "Reset counter", icon = "rotate-ccw", callback = function() runs:Set(0) end })
shortcuts:CreateButton({ name = "Notify", icon = "bell", callback = function()
    window:Notify({ title = "Hello from Astra", content = "Click again to replace this exact notification with a fresh animated card." })
end })
actions:CreateDivider({ text = "Window preview" })
actions:CreateButton({ name = "Hide to capsule", icon = "minus", callback = function() window:Hide() end })
actions:CreateCollapsibleGroup({
    name = "Feedback lab", icon = "flask-conical", description = "Two ways to test the overlay system.",
    elements = {
        { type = "Button", name = "Show confirmation", icon = "message-square", callback = function()
            window:Popup({ title = "Preview complete?", content = "This is a sample confirmation; it does not change your settings.", options = {
                { text = "Cancel" }, { text = "Confirm", style = "primary", callback = function()
                    window:Notify({ title = "Confirmed", content = "The popup action ran." })
                end },
            } })
        end },
        { type = "Button", name = "Show notification", icon = "bell", callback = function()
            window:Notify({ title = "Feedback lab", content = "Notifications are queued, not stacked all at once." })
        end },
    },
})

-- Preferences: text stays an Input; shortcuts get their own Keybind.
preferences:CreateSection({ name = "Sample profile" })
preferences:CreateInput({ name = "Profile name", placeholder = "e.g. Evening session", clearOnFocus = false, flag = "demo.profileName" })
preferences:CreateToggle({ name = "Enable profile", value = true, flag = "demo.enabled" })
preferences:CreateSlider({ name = "Preview intensity", range = { 0, 100 }, value = 50, increment = 5, suffix = "%", flag = "demo.intensity" })
preferences:CreateDropdown({ name = "Quality preset", options = { "Low", "Balanced", "High" }, value = "Balanced", flag = "demo.quality" })
preferences:CreateDropdown({ name = "Active modules", options = { "Visuals", "Audio", "Notifications" }, value = { "Visuals" }, multiSelect = true, placeholder = "Choose modules", flag = "demo.modules" })
preferences:CreateDivider({ text = "Keyboard" })
preferences:CreateKeybind({
    name = "Sample shortcut", value = "P", flag = "demo.shortcut",
    callback = function(letter)
        window:Notify({ title = "Shortcut saved", content = "Sample shortcut: " .. letter })
    end,
})
preferences:CreateCollapsibleGroup({
    name = "Delivery options", icon = "bell", description = "Related switches belong together.",
    elements = {
        { type = "Toggle", name = "Desktop notifications", value = true, flag = "demo.desktop" },
        { type = "Switch", name = "Quiet mode", value = false, flag = "demo.quiet" },
    },
})

-- One compact tab exposes every public element by its constructor name.
local allElements = window:CreateTab({ name = "All Elements", icon = "layout-grid" })
allElements:CreateSection({ name = "Section", icon = "list" })
allElements:CreateText({ name = "Text", text = "Text" })
allElements:CreateButton({ name = "Button", icon = "mouse-pointer-click" })
allElements:CreateToggle({ name = "Toggle", icon = "toggle-right", value = true })
allElements:CreateSlider({ name = "Slider", icon = "sliders-horizontal", range = { 0, 100 }, value = 50 })
allElements:CreateDropdown({ name = "Dropdown", icon = "list-filter", options = { "One", "Two" }, value = "One" })
allElements:CreateInput({ name = "Input", icon = "text-cursor-input", value = "Input" })
allElements:CreateKeybind({ name = "Keybind", icon = "keyboard", value = "K" })
allElements:CreateStat({ name = "Stat", value = 42 })
allElements:CreateLink({ name = "Link", subtitle = "Copy this URL", icon = "link", link = "https://github.com/Kira762/astra-library" })
allElements:CreateFooter({ parts = { { text = "Footer" }, { icon = "zap" } } })
allElements:CreateChangelog({ name = "Changelog", entries = { { version = "Demo", title = "Changelog", changes = { { symbol = "+", text = "Changelog" } } } } })
allElements:CreateDivider({ text = "Divider" })
local allGroup = allElements:CreateGroup({ direction = "column" })
allGroup:CreateText({ name = "Group", text = "Group" })
allElements:CreateCollapsibleGroup({
    name = "CollapsibleGroup", icon = "chevrons-up-down", description = "CollapsibleGroup",
    elements = {
        { type = "Text", name = "Text", text = "CollapsibleGroup contents" },
        { type = "Button", name = "Button" },
    },
})

overview:Select()
