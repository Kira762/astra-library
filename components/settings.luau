local utilities = script.Parent.Parent.utilities
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local layouts = require(utilities.layouts)

local settingsComponent = {}

--[[
The About card's copy. The card itself is a reusable element — these are
simply the values this build stamps into the Settings tab's card, so a
release updates them here and nowhere else.
]]
local aboutVersion = "1.4.0"
local aboutAuthor = "Astra Team"

local function layoutKey(layout)
    if type(layout) == "table" and layout.mode == "sidebar" and layout.forceCollapsed then
        return "collapsedSidebar"
    end
    return if type(layout) == "table" and layout.mode then layout.mode else "sidebar"
end

function settingsComponent.buildUI(window)
    if window._settingsUIBuilt then
        return
    end
    window._settingsUIBuilt = true
    local about = window.rfSettings
    local general = window:CreateTab({ name = "Controls", icon = "keyboard", customOrder = 1002, forgetState = true, isSettingsTab = true })
    local appearance = window:CreateTab({ name = "Appearance", icon = "palette", customOrder = 1003, forgetState = true, isSettingsTab = true })
    local persistence = window:CreateTab({ name = "Persistence", icon = "save", customOrder = 1004, forgetState = true, isSettingsTab = true })
    for _, tab in { general, appearance, persistence } do
        tab._isSettingsTab = true
        table.insert(window._settingsTabs, tab)
    end

    --[[
    The settings shells are created on first settings access.
    Each tab's elements are created the first time that tab is opened
    (see _buildSettingsContent), so opening the window stays fast. The
    builders run at most once, in the original creation order.
    ]]
    window._settingsContentBuilt = window._settingsContentBuilt or {}

    local function buildAbout()
        --[[
        The About page is kept deliberately short: one compact About card
        (brand header plus two data tiles) and a single repository link —
        the usage guide, releases and issues all live behind that link.
        The version and author strings live at the top of this module.
        ]]
        about:CreateAboutCard({
            name = "Astra",
            subtitle = "UI Library for a better experience.",
            icon = constants.icons.dot,
            rows = {
                { icon = "code", label = "Version", value = aboutVersion },
                { icon = "user", label = "Author", value = aboutAuthor },
            },
        })
        about:CreateLink({
            name = "Repository", subtitle = "Docs, releases and issues", icon = "code",
            link = "https://github.com/Kira762/astra-version-1",
        })
    end
    about._settingsContentBuilder = buildAbout

    local function buildGeneral()
        general:CreateKeybind({
            name = "Toggle Keybind",
            value = window.settings.toggleKeybind,
            callback = function(letter)
                window.settings.toggleKeybind = Enum.KeyCode[letter]
                window:SaveSettings()
            end,
        })
        general:CreateToggle({
            name = "Unlock cursor while open",
            value = window.settings.mouseOverride,
            callback = function(value)
                window.settings.mouseOverride = value
                window:SaveSettings()
            end,
        })
        general:CreateCollapsibleGroup({
            name = "Window Behavior",
            icon = "layout",
            elements = {
                {
                    type = "Toggle",
                    name = "Prevent duplicate windows",
                    value = window.settings.antiWindowDuplicate,
                    callback = function(value)
                        window.settings.antiWindowDuplicate = value
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Keep window on screen",
                    value = window.settings.keepOnScreen,
                    callback = function(value)
                        window.settings.keepOnScreen = value
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Draggable capsule",
                    value = window.settings.dragMinimisedBar,
                    callback = function(value)
                        window.settings.dragMinimisedBar = value == true
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Button",
                    name = "Reset Window Position",
                    callback = function()
                        window:_recenterWindow(true)
                    end,
                },
                {
                    type = "Button",
                    name = "Reset Capsule Position",
                    callback = function()
                        window:_resetCapsulePosition()
                    end,
                },
            },
        })
    end
    general._settingsContentBuilder = buildGeneral

    local function buildAppearance()
        --[[
        The only built-in palette is `default`; hosts overlay keys through
        `window:ChangeTheme({ ... })`. Appearance therefore has no colour
        to pick — the font selection, layout and motion stay here.
        ]]
        local fontLabels = { default = "Default", brand = "Astra" }
        local fontOptions = { "Default", "Astra" }
        local fontChoices = { Default = "default", Astra = "brand" }

        appearance:CreateDropdown({
            name = "Font",
            options = fontOptions,
            value = fontLabels[window.settings.fontChoice or "default"] or fontLabels.default,
            callback = function(choice)
                local requested = fontChoices[choice]
                if not requested or requested == (window.settings.fontChoice or "default") then
                    return
                end
                window.settings.fontChoice = requested
                window:_applyFontSetting()
                window:SaveSettings()
                window:Notify({
                    title = "Font changed",
                    content = "Switched to the " .. choice .. " font.",
                })
            end,
        })

        local layoutMap = { sidebar = "Sidebar (Responsive)", collapsedSidebar = "Collapsed Sidebar" }
        local layoutDropdown
        local currentLayout = window.settings.layoutMode or window.layout.mode

        layoutDropdown = appearance:CreateDropdown({
            name = "Bar Layout",
            options = { layoutMap.sidebar, layoutMap.collapsedSidebar },
            value = layoutMap[currentLayout],
            callback = function(choice)
                local requested
                for key, label in layoutMap do
                    if choice == label then
                        requested = key
                        break
                    end
                end
                if not requested then
                    return
                end
                local active = layoutKey(window.layout)
                if requested == active then
                    window:Notify({ title = "Bar layout", content = "The " .. choice .. " layout is already active." })
                    if layoutDropdown then
                        layoutDropdown:Set(layoutMap[active], true)
                    end
                    return
                end
                if layoutDropdown then
                    layoutDropdown:Set(layoutMap[active], true)
                end
                window:Popup({
                    title = "Apply bar layout?",
                    content = "Are you sure you want to change the layout to " .. choice .. "?",
                    options = {
                        { text = "Cancel" },
                        {
                            text = "Apply",
                            style = "primary",
                            callback = function()
                                if window:_setLayoutMode(requested) then
                                    currentLayout = requested
                                    window.settings.layoutMode = requested
                                    window:SaveSettings()
                                    if layoutDropdown then
                                        layoutDropdown:Set(layoutMap[requested], true)
                                    end
                                    window:Notify({ title = "Bar layout changed", content = "Switched to the " .. layoutMap[requested] .. " layout." })
                                else
                                    currentLayout = layoutKey(window.layout)
                                    if layoutDropdown then
                                        layoutDropdown:Set(layoutMap[currentLayout], true)
                                    end
                                    window:Notify({ title = "Bar layout", content = "The selected bar layout could not be applied right now." })
                                end
                            end,
                        },
                    },
                })
            end,
        })

        local motionLabels = { relaxed = "Relaxed", normal = "Normal", snappy = "Snappy", instant = "Instant" }
        local motionOptions = { "Relaxed", "Normal", "Snappy", "Instant" }
        local motionProfiles = { Relaxed = "relaxed", Normal = "normal", Snappy = "snappy", Instant = "instant" }
        local currentMotion = motionLabels[window.settings.motionSpeed] or motionLabels.normal

        appearance:CreateCollapsibleGroup({
            name = "Motion & Feedback",
            icon = "gauge",
            elements = {
                {
                    type = "Toggle",
                    name = "Haptics",
                    value = window.settings.haptics,
                    callback = function(value)
                        window.settings.haptics = value
                        haptic.setEnabled(value)
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Dropdown",
                    name = "Animation speed",
                    options = motionOptions,
                    value = currentMotion,
                    callback = function(value)
                        local profile = motionProfiles[value]
                        if not profile or profile == window.settings.motionSpeed then
                            return
                        end
                        window.settings.motionSpeed = profile
                        window:_applyMotionSetting()
                        window:SaveSettings()
                    end,
                },
            },
        })
    end
    appearance._settingsContentBuilder = buildAppearance

    local function buildPersistence()
        persistence:CreateCollapsibleGroup({
            name = "Auto Save & Load",
            icon = "save",
            elements = {
                {
                    type = "Toggle",
                    name = "Auto Save Config",
                    value = window.settings.autoSaveConfig,
                    callback = function(value)
                        window.settings.autoSaveConfig = value
                        window.configuration.autoSave = value
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Auto Load Config",
                    value = window.settings.autoLoadConfig,
                    callback = function(value)
                        window.settings.autoLoadConfig = value
                        window.configuration.autoLoad = value
                        window:SaveSettings()
                    end,
                },
            },
        })

        local function namedConfigs()
            return window:ListConfigs()
        end
        local selected = namedConfigs()[1]
        local configDropdown, configName
        local function refresh()
            local configs = namedConfigs()
            if configDropdown then
                configDropdown:Refresh(configs)
                if selected and not table.find(configs, selected) then
                    selected = configs[1]
                elseif not selected and #configs > 0 then
                    selected = configs[1]
                end
                if selected then
                    configDropdown:Set(selected, true)
                else
                    configDropdown:Set(nil, true)
                end
            end
        end

        local configGroup = persistence:CreateCollapsibleGroup({
            name = "Configurations",
            icon = constants.icons.config,
            elements = {
                {
                    type = "Dropdown",
                    name = "Saved Configurations",
                    icon = constants.icons.config,
                    options = namedConfigs(),
                    value = selected,
                    placeholder = "No saved configurations",
                    callback = function(value)
                        selected = value
                    end,
                },
                {
                    type = "Input",
                    name = "Configuration Name",
                    placeholder = "e.g. PvP Loadout",
                    clearOnFocus = false,
                },
                {
                    type = "Group",
                    elements = {
                        {
                            type = "Button",
                            name = "Save",
                            icon = constants.icons.config,
                            callback = function()
                                local name = if configName then configName.value else ""
                                if name == "" then
                                    name = selected
                                end
                                if not name or name == "" then
                                    name = window.configuration.fileName or "Configuration"
                                end
                                if window:Save(name) then
                                    if configName then
                                        configName:Set("")
                                    end
                                    selected = name
                                    refresh()
                                    window:Notify({
                                        title = locale.resolve("Saved configuration"),
                                        content = name,
                                        icon = constants.icons.config,
                                    })
                                else
                                    window:Notify({
                                        title = locale.resolve("Couldn't save configuration"),
                                        content = name,
                                    })
                                end
                            end,
                        },
                        {
                            type = "Button",
                            name = "Load",
                            callback = function()
                                if not selected or selected == "" then
                                    window:Notify({ title = locale.resolve("Pick a configuration to load") })
                                    return
                                end
                                if window:_applyNamedConfig(selected) then
                                    window:Notify({
                                        title = locale.resolve("Loaded configuration"),
                                        content = selected,
                                    })
                                else
                                    window:Notify({
                                        title = locale.resolve("Couldn't load configuration"),
                                        content = selected,
                                    })
                                end
                            end,
                        },
                        {
                            type = "Button",
                            name = "Delete",
                            callback = function()
                                local name = selected
                                if not name or name == "" then
                                    window:Notify({ title = locale.resolve("Pick a configuration to delete") })
                                    return
                                end
                                if window:DeleteConfig(name) then
                                    selected = nil
                                    refresh()
                                    window:Notify({
                                        title = locale.resolve("Deleted configuration"),
                                        content = name,
                                    })
                                else
                                    window:Notify({
                                        title = locale.resolve("Couldn't delete configuration"),
                                        content = name,
                                    })
                                end
                            end,
                        },
                    },
                },
            },
        })
        configDropdown = configGroup.elements[1]
        configName = configGroup.elements[2]
    end
    persistence._settingsContentBuilder = buildPersistence
end

function settingsComponent.buildContent(window, tab)
    settingsComponent.buildUI(window)
    --[[
    Lazy settings content: a tab's elements are created the first
    time it is opened, keeping window construction fast. The pcall
    keeps one bad element from taking the whole window down.
    ]]
    if window._settingsContentBuilt[tab] or not tab._settingsContentBuilder then
        return
    end
    window._settingsContentBuilt[tab] = true
    local ok, err = pcall(tab._settingsContentBuilder)
    if not ok then
        window:Notify({ title = "Settings", content = "Some settings content failed to load: " .. tostring(err) })
    end
end

function settingsComponent.applySettingsLayout(window, isSettings)
    --[[
    isSettings is retained for callers; the flags derive from the live
    rail so settings modes share one layout switch.
    ]]
    local rail = window:_activeRail()
    window._settingsLayoutActive = rail == "settings"
    if window.tabList then
        window.tabList.Visible = not window.hidden and not window.minimised
    end
    if window.sidebar then
        window.sidebar.Visible = not window.hidden and not window.minimised
    end
    for _, tab in window.tabs do
        if tab.topbarItem then
            tab.topbarItem.Visible = not window.hidden and not window.minimised
                and (window:_railGroup(tab) == window:_activeRail())
        end
    end
    if window.selectedTab and window.selectedTab.tabPage then
        window.selectedTab.tabPage.Size = UDim2.new(1, -35, 1, 0)
        window.selectedTab.tabPage.Position = UDim2.new(0, 35, 0, 0)
    end
    --[[
    The visible rail group changed: re-derive the responsive rail's
    width from the tabs now shown (no-op for the other layouts).
    ]]
    window:_applyContentRailWidth()
end

function settingsComponent.toggleSettingsMode(window)
    if window._settingsMode then
        local previousTab = window._previousTab
        window._previousTab = nil
        if previousTab and previousTab.window == window and previousTab.tabPage and not previousTab._isSettingsTab then
            previousTab:Select()
            return
        end
        for _, tab in window.tabs do
            if not tab._isSettingsTab and tab.window == window and tab.tabPage then
                tab:Select()
                return
            end
        end
        return
    end

    window._previousTab = window.selectedTab
    window.rfSettings:Select()
end

function settingsComponent.setSettingsMode(window, active)
    active = active == true
    if active and window._constructed then
        settingsComponent.buildUI(window)
    end
    window._settingsMode = active
    if active and window._previousTab == nil and window.selectedTab and not window.selectedTab._isSettingsTab then
        window._previousTab = window.selectedTab
    end
    for _, tab in window.tabs do
        if tab.topbarItem then
            tab.topbarItem.Visible = not window.hidden and not window.minimised
                and (window:_railGroup(tab) == window:_activeRail())
        end
    end
    settingsComponent.applySettingsLayout(window, active)
end

return settingsComponent
