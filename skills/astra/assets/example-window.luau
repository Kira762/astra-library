-- [[Executor entry point. In Studio/Rojo, require ReplicatedStorage.Astra instead.]]
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

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

-- [[Information comes first. The remaining tabs group controls by what they do,
-- not by constructor name. Every supported element has a useful place here.]]
local overview = window:CreateTab({ name = "Overview", icon = "house" })
local actions = window:CreateTab({ name = "Actions", icon = "play" })
local preferences = window:CreateTab({ name = "Preferences", icon = "sliders-horizontal" })
local releaseHistory

overview:CreateAboutCard({
    name = "Astra",
    subtitle = "A small studio for every element.",
    icon = 80387863064905,
    rows = {
        { icon = "code", label = "Version", value = "1.4.0" },
        { icon = "package", label = "Build", value = "2026.09.21" },
        { icon = "user", label = "Author", value = "Astra Team" },
    },
    description = "Explore the library in three focused spaces. Read the essentials here, try feedback and actions next, then tune a sample profile in Preferences.",
    action = {
        icon = "file-text",
        name = "Release history",
        subtitle = "Explore the changes behind this studio",
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
    },
})
overview:CreateSection({ name = "Start here" })
overview:CreateText({
    name = "Your quick tour",
    text = "Actions demonstrates buttons, compact groups, statistics and feedback. Preferences covers switches, ranges, choices, text and letter-only key capture. The gear opens library settings; its Overview always comes first.",
})
overview:CreateDivider({ text = "Resources" })
overview:CreateLink({
    name = "Source & releases", subtitle = "Copy the repository link", icon = "code",
    link = "https://github.com/Kira762/astra-version-1",
})
overview:CreateLink({
    name = "Build with Astra", subtitle = "Copy the element and API guide", icon = "book-open",
    link = "https://github.com/Kira762/astra-version-1/blob/main/USAGE.md",
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
releaseHistory = overview:CreateIsolated({
    name = "Release history", subtitle = "Earlier library milestones", icon = "history",
    elements = {
        { type = "Changelog", name = "Earlier releases", entries = {
            { version = "1.4.0", date = "2026.09.12", changes = {
                { symbol = "+", text = "About cards, links and richer grouped controls." },
            } },
            { version = "1.2.0", title = "Structured content", changes = {
                { symbol = "+", text = "Isolated changelog containers and collapsible groups." },
            } },
        } },
    },
})
overview:CreateDivider()
overview:CreateFooter({ parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" }, { icon = "heart" } } })

-- [[Actions: an immediate result, a compact action pair and a related advanced
-- group. No collapsible wrapper is used for a lone control.]]
actions:CreateSection({ name = "Activity" })
local runs = actions:CreateStat({ name = "Completed runs", value = 0, suffix = " runs", changeMode = "delta", changeBaseline = "initial" })
actions:CreateButton({
    name = "Run a check", icon = "play", description = "Increment the counter and show a success notification.",
    callback = function()
        runs:Set(runs.value + 1)
        window:Notify({ title = "Check complete", content = "The button callback ran successfully." })
    end,
})
local shortcuts = actions:CreateGroup({ direction = "row" })
shortcuts:CreateButton({ name = "Reset counter", icon = "rotate-ccw", callback = function() runs:Set(0) end })
shortcuts:CreateButton({ name = "Notify", icon = "bell", callback = function()
    window:Notify({ title = "Hello from Astra", content = "Compact buttons share the same clean, icon-optional style." })
end })
actions:CreateDivider({ text = "Window preview" })
actions:CreateButton({ name = "Hide to capsule", icon = "minus", description = "Restore by tapping the capsule or pressing your menu letter.", callback = function() window:Hide() end })
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

-- [[Preferences: text stays an Input; shortcuts get their own Keybind.]]
preferences:CreateSection({ name = "Sample profile" })
preferences:CreateInput({ name = "Profile name", placeholder = "e.g. Evening session", clearOnFocus = false, flag = "demo.profileName" })
preferences:CreateToggle({ name = "Enable profile", value = true, flag = "demo.enabled" })
preferences:CreateSlider({ name = "Preview intensity", range = { 0, 100 }, value = 50, increment = 5, suffix = "%", flag = "demo.intensity" })
preferences:CreateDropdown({ name = "Quality preset", options = { "Low", "Balanced", "High" }, value = "Balanced", flag = "demo.quality" })
preferences:CreateDropdown({ name = "Active modules", options = { "Visuals", "Audio", "Notifications" }, value = { "Visuals" }, multiSelect = true, placeholder = "Choose modules", flag = "demo.modules" })
preferences:CreateDivider({ text = "Keyboard" })
preferences:CreateKeybind({
    name = "Sample shortcut", value = "P", flag = "demo.shortcut",
    description = "Click to capture one letter. This sample stores a key; it does not toggle the window. Change the menu key in Settings → Controls.",
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

overview:Select()
