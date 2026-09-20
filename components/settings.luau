local utilities = script.Parent.Parent.utilities
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local layouts = require(utilities.layouts)

local settingsComponent = {}

local function layoutKey(layout)
    if type(layout) == "table" and layout.mode == "sidebar" and layout.forceCollapsed then
        return "collapsedSidebar"
    end
    return if type(layout) == "table" and layout.mode then layout.mode else "sidebar"
end

-- [[The Settings toggle binding is an ordinary Input field: it shows the bound
-- key's name and reads one back, so the row uses the same typed-value input as
-- every other field in the library. Labels read "None" for a cleared binding
-- and MB2/MB3 for mouse buttons, so window.settings.toggleKeybind stays an
-- EnumItem — which is what Window:_bindKeybind compares against and what the
-- settings file stores.]]
local mouseLabels = {
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
}

-- [[The short mouse forms the field accepts. MouseButton1 is absent on purpose:
-- a menu toggle bound to left click would fire on every click in the game.]]
local mouseNames = {
    mb2 = Enum.UserInputType.MouseButton2,
    mousebutton2 = Enum.UserInputType.MouseButton2,
    rmb = Enum.UserInputType.MouseButton2,
    mb3 = Enum.UserInputType.MouseButton3,
    mousebutton3 = Enum.UserInputType.MouseButton3,
    mmb = Enum.UserInputType.MouseButton3,
}

local leftMouseNames = { mb1 = true, lmb = true, mousebutton1 = true, leftmouse = true }

-- [[Canonical KeyCode names, keyed by what people actually type. A mis-cased
-- Enum lookup is an error in the engine, so the field resolves the usual keys
-- itself ("k", "space", "left shift") and leaves the rest to the lookup below,
-- which keeps uncommon but real names ("KeypadPlus") working.]]
local keyNames = {
    esc = "Escape",
    enter = "Return",
    ctrl = "LeftControl",
    control = "LeftControl",
    shift = "LeftShift",
    alt = "LeftAlt",
    del = "Delete",
    spacebar = "Space",
    back = "Backspace",
}
for _, name in {
    "Space", "Escape", "Return", "Tab", "Backspace", "Delete", "Insert", "Home", "End",
    "PageUp", "PageDown", "Up", "Down", "Left", "Right",
    "LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "RightAlt",
    "CapsLock", "Minus", "Equals", "LeftBracket", "RightBracket", "Semicolon", "Quote",
    "Comma", "Period", "Slash", "BackSlash",
} do
    keyNames[name:lower()] = name
end
for letter = string.byte("A"), string.byte("Z") do
    keyNames[string.char(letter):lower()] = string.char(letter)
end
for index = 1, 12 do
    keyNames[("f%d"):format(index)] = ("F%d"):format(index)
end
for digit, name in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" } do
    keyNames[tostring(digit - 1)] = name
end

local function keyLabel(item)
    if typeof(item) ~= "EnumItem" or item == Enum.KeyCode.Unknown then
        return "None"
    end
    return mouseLabels[item] or item.Name
end

-- [[Returns the key the text names, or Enum.KeyCode.Unknown for an empty or
-- "none" field (an unbound menu key). Text that names no key returns nil, with
-- a reason when the refusal needs its own wording.]]
local function parseKey(text)
    if type(text) ~= "string" then
        return nil
    end
    local trimmed = (text:gsub("^%s+", ""):gsub("%s+$", ""))
    local typed = trimmed:lower()
    if typed == "" or typed == "none" then
        return Enum.KeyCode.Unknown
    end
    -- [[Separators are dropped so "left shift" and "MB-2" read like their enum
    -- names; whatever is left still has to be a plain word.]]
    local name = (typed:gsub("[%s_%-]", ""))
    if name == "" or not name:match("^%w+$") then
        return nil
    end
    if leftMouseNames[name] then
        return nil, "leftMouse"
    end
    local mouse = mouseNames[name]
    if mouse then
        return mouse
    end
    local canonical = keyNames[name]
    if canonical then
        local ok, key = pcall(function()
            return Enum.KeyCode[canonical]
        end)
        if ok and typeof(key) == "EnumItem" then
            return key
        end
    end
    for _, candidate in { trimmed, trimmed:sub(1, 1):upper() .. trimmed:sub(2), trimmed:upper() } do
        local keyOk, key = pcall(function()
            return Enum.KeyCode[candidate]
        end)
        if keyOk and typeof(key) == "EnumItem" then
            return key
        end
        local typeOk, inputType = pcall(function()
            return Enum.UserInputType[candidate]
        end)
        if typeOk and mouseLabels[inputType] then
            return inputType
        end
    end
    return nil
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
            name = "Astra",
            icon = "sparkles",
            elements = {
                {
                    type = "Text",
                    name = "About Astra",
                    text = "Astra is an interface library built entirely in code: one loader line, one window, and a set of reusable elements that stay fast to open and behave the same on desktop and mobile.",
                },
                {
                    type = "Text",
                    name = "Highlights",
                    text = "State can persist between sessions, themes can change at runtime, labels can be translated, and the interface is designed for both desktop and mobile.",
                },
                {
                    type = "Text",
                    name = "What Astra Provides",
                    text = "A responsive, customizable interface with persistent settings, runtime themes, localization support, animated window transitions, and a growing set of reusable elements.",
                },
            },
        })
        about:CreateCollapsibleGroup({
            name = "Links",
            icon = "link",
            elements = {
                {
                    type = "Text",
                    name = "Repository",
                    text = "https://github.com/Kira762/astra-version-1",
                },
                {
                    type = "Text",
                    name = "Usage guide",
                    text = "https://github.com/Kira762/astra-version-1/blob/main/USAGE.md",
                },
            },
        })
    end
    about._settingsContentBuilder = buildAbout

    local function buildGeneral()
        local keybindField

        -- [[A typed key becomes the menu toggle. The field is refused, with the
        -- previous binding restored, when the text is not a key.]]
        local function refuseKeybind(message, previous)
            window:Notify({ title = locale.resolve("Keybind unavailable"), content = message })
            keybindField:Set(previous, true)
            -- [[The field already flashed for the commit that reached here; the
            -- refusal flash replaces it so the row reads as rejected.]]
            window:_flashResult(keybindField, false)
        end

        local function commitKeybind(text)
            local previous = keyLabel(window.settings.toggleKeybind)
            local key, reason = parseKey(text)
            if not key then
                local message = if reason == "leftMouse"
                    then string.format(locale.resolve("Left click can't toggle the menu. Kept %s."), previous)
                    else string.format(locale.resolve("%s is not a key name. Kept %s."), tostring(text), previous)
                refuseKeybind(message, previous)
                return
            end
            if key == window.settings.toggleKeybind then
                -- [[Unchanged binding: normalise the field ("k" reads "K", an
                -- empty field reads "None") without writing settings again.]]
                keybindField:Set(previous, true)
                return
            end
            window.settings.toggleKeybind = key
            keybindField:Set(keyLabel(key), true)
            window:SaveSettings()
        end

        local generalControls = window.rfSettings:CreateCollapsibleGroup({
            name = "General Controls",
            icon = constants.icons.settings,
            elements = {
                {
                    type = "Input",
                    name = "Toggle Keybind",
                    icon = "keyboard",
                    value = keyLabel(window.settings.toggleKeybind),
                    placeholder = "e.g. K, Space, MB2",
                    callback = commitKeybind,
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
            },
        })
        keybindField = generalControls.elements[1]

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
        local themeOrder = { "default", "amethyst", "cobalt", "crimson", "ember", "emerald", "frost", "gold", "onyx", "rose" }
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
        local themeOptions = {}
        for _, key in ipairs(themeOrder) do
            table.insert(themeOptions, themes[key])
        end

        local function themeLabel(key)
            return themes[key] or themes.default
        end
        local function themeKey(label)
            for key, candidate in themes do
                if candidate == label then
                    return key
                end
            end
            return nil
        end

        -- [[The theme row follows a staged apply: the dropdown only *selects*
        -- a candidate (currentTheme stays untouched until the Apply button is
        -- confirmed), while the stat above shows the theme in effect — the
        -- full theme name, no icon, via the stat's text readout. Reset to
        -- Default is always on the row; only the Apply half is staged, and it
        -- appears beside Reset while a candidate differs from the active
        -- theme, then goes back to being absent once that candidate is
        -- applied (or dropped by picking the active theme again).]]
        local currentTheme = if themes[window.settings.theme] then window.settings.theme else "default"
        local pendingTheme

        -- Forward-declared so the element callbacks below can capture them;
        -- their bodies are assigned after the group is built.
        local themeStat, themeDropdown, themeButtonGroup, themeApplyButton
        local setPendingThemeButtons, syncThemeControls, confirmThemeReset

        local themeGroup = appearance:CreateCollapsibleGroup({
            name = "Theme",
            icon = "palette",
            elements = {
                {
                    type = "Stat",
                    name = "Current theme",
                    -- Reads the whole theme name out; letter = false opts this
                    -- text value out of the stat's single-letter badge.
                    value = themeLabel(currentTheme),
                    letter = false,
                },
                {
                    type = "Dropdown",
                    name = "Theme",
                    options = themeOptions,
                    value = themeLabel(currentTheme),
                    callback = function(value)
                        local candidate = themeKey(value)
                        if not candidate or candidate == currentTheme then
                            pendingTheme = nil
                            setPendingThemeButtons(false)
                            return
                        end
                        pendingTheme = candidate
                        setPendingThemeButtons(true)
                    end,
                },
                {
                    type = "Group",
                    elements = {
                        {
                            type = "Button",
                            name = "Reset to Default",
                            icon = "rotate-ccw",
                            callback = function()
                                window:Popup({
                                    title = "Reset theme?",
                                    content = "Set this window back to the " .. themeLabel("default") .. " theme?",
                                    options = {
                                        { text = "Cancel" },
                                        {
                                            text = "Reset",
                                            style = "primary",
                                            callback = confirmThemeReset,
                                        },
                                    },
                                })
                            end,
                        },
                        {
                            type = "Button",
                            name = "Apply Theme",
                            icon = "check",
                            callback = function()
                                if not pendingTheme then
                                    return
                                end
                                window:Popup({
                                    title = "Apply theme?",
                                    content = "Apply the " .. themeLabel(pendingTheme) .. " theme to this window?",
                                    options = {
                                        { text = "Cancel" },
                                        {
                                            text = "Apply",
                                            style = "primary",
                                            callback = function()
                                                currentTheme = pendingTheme
                                                pendingTheme = nil
                                                window.settings.theme = currentTheme
                                                window:ChangeTheme(currentTheme)
                                                window:SaveSettings()
                                                syncThemeControls()
                                                window:Notify({ title = "Theme applied", subtitle = themeLabel(currentTheme) })
                                            end,
                                        },
                                    },
                                })
                            end,
                        },
                    },
                },
            },
        })

        themeStat = themeGroup.elements[1]
        themeDropdown = themeGroup.elements[2]
        themeButtonGroup = themeGroup.elements[3]
        themeApplyButton = themeButtonGroup and themeButtonGroup.elements[2]
        function setPendingThemeButtons(show)
            if not themeApplyButton or not themeApplyButton.main then
                return
            end
            -- [[Only the Apply half of the row is staged: Reset to Default is
            -- permanent, so the row is never hidden and Reset never appears
            -- and disappears. Apply is absent until a candidate differs from
            -- the active theme, and returns to absent the moment that
            -- candidate is applied or dropped again.]]
            themeApplyButton.main.Visible = show == true
        end
        function syncThemeControls()
            if themeDropdown then
                themeDropdown:Set(themeLabel(currentTheme), true)
            end
            if themeStat then
                themeStat:SetText(themeLabel(currentTheme))
            end
            setPendingThemeButtons(pendingTheme ~= nil and pendingTheme ~= currentTheme)
        end
        function confirmThemeReset()
            pendingTheme = nil
            currentTheme = "default"
            window.settings.theme = "default"
            window:ChangeTheme("default")
            window:SaveSettings()
            syncThemeControls()
            window:Notify({ title = "Theme reset", subtitle = themeLabel("default") })
        end

        setPendingThemeButtons(false)

        local layoutMap = { sidebar = "Sidebar (Responsive)", collapsedSidebar = "Collapsed Sidebar" }
        local layoutDropdown
        local currentLayout = window.settings.layoutMode or window.layout.mode

        local layoutGroup = appearance:CreateCollapsibleGroup({
            name = "Layout",
            icon = "panel-left",
            elements = {
                {
                    type = "Dropdown",
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
                },
            },
        })
        layoutDropdown = layoutGroup.elements[1]

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
    -- [[isSettings is retained for callers; the flags derive from the live]]
    -- [[rail so settings modes share one layout switch.]]
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
                and (window:_railGroup(tab) == window:_activeRail())
        end
    end
    settingsComponent.applySettingsLayout(window, active)
end

return settingsComponent
