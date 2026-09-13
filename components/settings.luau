local utilities = script.Parent.Parent.utilities
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local profilePanel = require(script.Parent.profilePanel)
local layouts = require(utilities.layouts)

local settingsComponent = {}

local function layoutKey(layout)
    return if type(layout) == "table" and layout.mode then layout.mode else "top" end
end

function settingsComponent.buildUI(window)
    if window._settingsUIBuilt then
        return
    end
    window._settingsUIBuilt = true
    local appearance = window:CreateTab({ name = "Appearance", icon = "palette", customOrder = 1002, forgetState = true, isSettingsTab = true })
    local persistence = window:CreateTab({ name = "Persistence", icon = "save", customOrder = 1003, forgetState = true, isSettingsTab = true })
    local about = window:CreateTab({ name = "About", icon = "info", customOrder = 1004, forgetState = true, isSettingsTab = true })
    for _, tab in { appearance, persistence, about } do
        tab._isSettingsTab = true
        table.insert(window._settingsTabs, tab)
    end

    -- [[The settings shells are created on first settings access.]]
    -- [[Each tab's elements are created the first time that tab is opened]]
    -- [[(see _buildSettingsContent), so opening the window stays fast. The]]
    -- [[builders run at most once, in the original creation order.]]
    window._settingsContentBuilt = window._settingsContentBuilt or {}

    local function buildAbout()
        about:CreateCollapsibleGroup({
            name = "Rayfield Gen2",
            icon = "info",
            elements = {
                {
                    type = "Text",
                    name = "About Rayfield Gen2",
                    text = "Rayfield Gen2 is a ground-up rebuild of the Rayfield Interface Suite, built entirely in code for a faster, more stable, and more consistent experience.",
                },
                {
                    type = "Text",
                    name = "Highlights",
                    text = "State can persist between sessions, themes can change at runtime, labels can be translated, and the interface is designed for both desktop and mobile.",
                },
            },
        })
        about:CreateCollapsibleGroup({
            name = "Astra",
            icon = "sparkles",
            elements = {
                {
                    type = "Text",
                    name = "Our Story",
                    text = "Astra began from Rayfield Gen2 and was reshaped into a distinct interface library with its own visual language, behavior, and features.",
                },
                {
                    type = "Text",
                    name = "What Astra Provides",
                    text = "A responsive, customizable interface with persistent settings, runtime themes, localization support, animated window transitions, and a growing set of reusable elements.",
                },
                {
                    type = "Text",
                    name = "Customized by Haijo",
                    text = "Originally from Rayfield, Astra is customized, refined, and maintained by Haijo.",
                },
            },
        })
        about:CreateCollapsibleGroup({
            name = "Links",
            icon = "link",
            elements = {
                {
                    type = "Text",
                    name = "Documentation",
                    text = "https://docs.sirius.menu/rayfield-gen2",
                },
            },
        })
    end
    about._settingsContentBuilder = buildAbout

    local function buildGeneral()
        window.rfSettings:CreateCollapsibleGroup({
            name = "General Controls",
            icon = constants.icons.settings,
            elements = {
                {
                    type = "Keybind",
                    name = "Toggle Keybind",
                    icon = constants.icons.search,
                    value = window.settings.toggleKeybind,
                    editable = true,
                    isMenuToggle = true,
                    onChanged = function(value)
                        window.settings.toggleKeybind = value
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Unlock cursor while open",
                    value = window.settings.mouseOverride,
                    callback = function(value)
                        window.settings.mouseOverride = value
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Welcome toast",
                    value = window.settings.welcomeToast,
                    callback = function(value)
                        window.settings.welcomeToast = value
                        window:SaveSettings()
                    end,
                },
            },
        })

        window.rfSettings:CreateCollapsibleGroup({
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
                        window:_recenterForProfile(true)
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

        local motionLabels = { relaxed = "Relaxed", normal = "Normal", snappy = "Snappy", instant = "Instant" }
        local motionOptions = { "Relaxed", "Normal", "Snappy", "Instant" }
        local motionProfiles = { Relaxed = "relaxed", Normal = "normal", Snappy = "snappy", Instant = "instant" }
        local currentMotion = motionLabels[window.settings.motionSpeed] or motionLabels.normal

        window.rfSettings:CreateCollapsibleGroup({
            name = "Performance & Motion",
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
    window.rfSettings._settingsContentBuilder = buildGeneral

    local function buildAppearance()
        local themes = {
            default = "Default",
            amethyst = "Amethyst",
            cobalt = "Cobalt",
            crimson = "Crimson",
            ember = "Ember",
            emerald = "Emerald",
            frost = "Frost",
            gold = "Gold",
            onyx = "Onyx",
            rose = "Rose",
        }
        local selectedTheme = window.settings.theme
        local function themeLabel(key)
            return themes[key] or themes.default
        end
        if not themes[selectedTheme] then
            selectedTheme = "default"
        end

        appearance:CreateCollapsibleGroup({
            name = "Theme",
            icon = "palette",
            elements = {
                {
                    type = "Dropdown",
                    name = "Theme",
                    options = { "Default", "Amethyst", "Cobalt", "Crimson", "Ember", "Emerald", "Frost", "Gold", "Onyx", "Rose" },
                    value = themeLabel(selectedTheme),
                    callback = function(value)
                        for key, label in themes do
                            if value == label then
                                selectedTheme = key
                                break
                            end
                        end
                    end,
                },
                {
                    type = "Button",
                    name = "Apply theme",
                    callback = function()
                        if selectedTheme == window.settings.theme then
                            window:Notify({ title = "Theme", content = "The " .. themeLabel(selectedTheme) .. " theme is already active." })
                            return
                        end
                        window:Popup({
                            title = "Apply theme?",
                            content = "Apply the " .. themeLabel(selectedTheme) .. " theme to this window?",
                            options = {
                                { text = "Cancel" },
                                {
                                    text = "Apply",
                                    style = "primary",
                                    callback = function()
                                        window.settings.theme = selectedTheme
                                        window:ChangeTheme(selectedTheme)
                                        window:SaveSettings()
                                        window:Notify({ title = "Theme applied", subtitle = themeLabel(selectedTheme) })
                                    end,
                                },
                            },
                        })
                    end,
                },
            },
        })

        local layoutMap = { top = "Default Topbar", sidebar = "Sidebar (Responsive)", collapsedSidebar = "Collapsed Sidebar" }
        local layoutDropdown
        local currentLayout = window.settings.layoutMode or window.layout.mode

        local layoutGroup = appearance:CreateCollapsibleGroup({
            name = "Layout",
            icon = "panel-left",
            elements = {
                {
                    type = "Dropdown",
                    name = "Bar Layout",
                    options = { layoutMap.top, layoutMap.sidebar, layoutMap.collapsedSidebar },
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
                },
            },
        })
        layoutDropdown = layoutGroup.elements[1]

        local revealToggle
        local profileGroup = appearance:CreateCollapsibleGroup({
            name = "Profile",
            icon = "user",
            elements = {
                {
                    type = "Toggle",
                    name = "Show profile",
                    value = window.settings.showProfile,
                    callback = function(value)
                        local revealCleared = profilePanel.setEnabled(window, value)
                        if revealCleared and revealToggle then
                            revealToggle:Set(false, true)
                        end
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Dropdown",
                    name = "Profile side",
                    options = { "Right", "Left" },
                    value = if (window.settings.profileSide or "right") == "left" then "Left" else "Right",
                    callback = function(choice)
                        local side = if choice == "Left" then "left" else "right"
                        if (window.settings.profileSide or "right") == side then
                            return
                        end
                        profilePanel.setSide(window, side)
                        window:SaveSettings()
                    end,
                },
                {
                    type = "Toggle",
                    name = "Reveal profile details",
                    value = window.settings.showFullUsername,
                    callback = function(value)
                        if not profilePanel.setReveal(window, value) and revealToggle then
                            revealToggle:Set(false, true)
                        end
                        window:SaveSettings()
                    end,
                },
            },
        })
        revealToggle = profileGroup.elements[3]
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
                                    window:Toast({
                                        title = locale.resolve("Saved configuration"),
                                        subtitle = name,
                                        icon = constants.icons.config,
                                    })
                                else
                                    window:Toast({
                                        title = locale.resolve("Couldn't save configuration"),
                                        subtitle = name,
                                    })
                                end
                            end,
                        },
                        {
                            type = "Button",
                            name = "Load",
                            callback = function()
                                if not selected or selected == "" then
                                    window:Toast({ title = locale.resolve("Pick a configuration to load") })
                                    return
                                end
                                if window:_applyNamedConfig(selected) then
                                    window:Toast({
                                        title = locale.resolve("Loaded configuration"),
                                        subtitle = selected,
                                    })
                                else
                                    window:Toast({
                                        title = locale.resolve("Couldn't load configuration"),
                                        subtitle = selected,
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
                                    window:Toast({ title = locale.resolve("Pick a configuration to delete") })
                                    return
                                end
                                if window:DeleteConfig(name) then
                                    selected = nil
                                    refresh()
                                    window:Toast({
                                        title = locale.resolve("Deleted configuration"),
                                        subtitle = name,
                                    })
                                else
                                    window:Toast({
                                        title = locale.resolve("Couldn't delete configuration"),
                                        subtitle = name,
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
    -- [[Lazy settings content: a tab's elements are created the first]]
    -- [[time it is opened, keeping window construction fast. The pcall]]
    -- [[keeps one bad element from taking the whole window down.]]
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
    window._settingsLayoutActive = isSettings == true
    if window.tabList then
        window.tabList.Visible = not window.hidden and not window.minimised
    end
    if window.sidebar then
        window.sidebar.Visible = not window.hidden and not window.minimised
    end
    for _, tab in window.tabs do
        if tab.topbarItem then
            tab.topbarItem.Visible = not window.hidden and not window.minimised
                and (window._settingsMode == (tab._isSettingsTab == true))
        end
    end
    if window.selectedTab and window.selectedTab.tabPage then
        window.selectedTab.tabPage.Size = if window.layout.mode == "sidebar" then UDim2.new(1, -35, 1, 0) else UDim2.new(1, -20, 1, 0)
        window.selectedTab.tabPage.Position = if window.layout.mode == "sidebar" then UDim2.new(0, 35, 0, 0) else UDim2.new(0, 0, 0, 0)
    end
    -- [[The visible rail group changed: re-derive the responsive rail's]]
    -- [[width from the tabs now shown (no-op for the other layouts).]]
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
                and (active == (tab._isSettingsTab == true))
        end
    end
    settingsComponent.applySettingsLayout(window, active)
end

return settingsComponent
