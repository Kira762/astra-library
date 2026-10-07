local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

-- Harness handles: the test drives the gate through these.
local keyGate
local window
local overview
local studioReady

local function buildStudio()
    window = Astra:CreateWindow({
        name = "Mova",
        subtitle = "Gen 1",
        icon = "sirius",
    })

    -- 1. Overview — information lives here and only here
    overview = window:CreateTab({ name = "Overview", icon = "house" })

    overview:CreateSection({ name = "Astra", icon = 80387863064905 })
    overview:CreateText({
        name = "A UI-only tour of the API.",
        text = "Every element, grouped. Nothing here touches the game.",
    })
    overview:CreateLink({
        name = "Repository",
        subtitle = "Copy the project link",
        icon = "code",
        link = "https://github.com/Kira762/astra-version-1",
    })
    overview:CreateChangelog({
        name = "What's new",
        entries = {
            { version = "1.4.0", date = "2026-09-12", changes = {
                { symbol = "+", text = "Links, changelogs and richer grouped controls." },
            } },
        },
    })
    overview:CreateDivider()
    overview:CreateFooter({ parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" } } })

    -- 2. Controls — every interactive element, side by side in row Groups
    local controls = window:CreateTab({ name = "Controls", icon = "sliders-horizontal" })

    controls:CreateSection({ name = "Grouped controls", icon = "mouse-pointer-click" })

    local actions = controls:CreateGroup({ direction = "row" })
    actions:CreateButton({ name = "Add", icon = "plus" })
    actions:CreateButton({ name = "Apply", icon = "check" })
    actions:CreateButton({ name = "Delete", icon = "trash-2" })

    local switches = controls:CreateGroup({ direction = "row" })
    switches:CreateToggle({ name = "Sound", value = true })
    switches:CreateToggle({ name = "Music" })

    local levels = controls:CreateGroup({ direction = "row" })
    levels:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 60, suffix = "%" })
    levels:CreateSlider({ name = "Bass", range = { 0, 100 }, value = 40, suffix = "%" })

    controls:CreateStepper({ name = "Party size", icon = "hash", value = 2, min = 1, max = 8, step = 1 })

    controls:CreateDivider({ text = "Fields" })

    controls:CreateDropdown({ name = "Mode", options = { "Casual", "Ranked", "Custom" }, value = "Casual" })
    controls:CreateInput({ name = "Nickname", placeholder = "Type a name" })
    controls:CreateKeybind({ name = "Toggle UI", value = "K" })

    -- 3. Layout — stats in a row, and a fold for the secondary controls
    local layout = window:CreateTab({ name = "Layout", icon = "layout-grid" })

    layout:CreateSection({ name = "Readouts", icon = "gauge" })

    local readouts = layout:CreateGroup({ direction = "row" })
    readouts:CreateStat({ name = "XP", value = 1280 })
    readouts:CreateStat({ name = "Level", value = 12 })
    readouts:CreateStat({ name = "Rank", value = "A", letter = true })

    layout:CreateDivider({ text = "Folded" })

    layout:CreateCollapsibleGroup({
        name = "More options",
        icon = "chevrons-up-down",
        description = "Secondary controls, folded away.",
        elements = {
            { type = "Toggle", name = "Option A", value = true },
            { type = "Slider", name = "Strength", range = { 0, 10 }, value = 4 },
            { type = "Group", elements = {
                { type = "Button", name = "Undo", icon = "rotate-ccw" },
                { type = "Button", name = "Redo", icon = "rotate-cw" },
            } },
        },
    })

    overview:Select()
    studioReady = true
end

keyGate = Astra:CreateKeySystem({
    title = "Astra",
    subtitle = "Key System",
    note = "Demo key: ASTRA-STUDIO-2026.",
    keys = { "ASTRA-STUDIO-2026" },
    getKeyUrl = "https://github.com/Kira762/astra-version-1/blob/main/example.client.luau",
    links = {
        { name = "Repository", icon = "external-link", link = "https://github.com/Kira762/astra-version-1" },
    },
    saveKey = true,
    fileName = "Astra-Example",
    maxAttempts = 5,
    onSuccess = buildStudio,
    onClose = function()
    end,
    onMaxAttempts = function()
    end,
})
