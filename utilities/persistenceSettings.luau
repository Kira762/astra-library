local coreState = require(script.Parent.Parent.core.state)
local fs = require(script.Parent.filesystem)
local paths = require(script.Parent.persistencePaths)
local writer = require(script.Parent.persistenceWrite)
local enumHelper = require(script.Parent.enums)

local persistenceSettings = {}

type SettingsWindow = {
    settings: {
        toggleKeybind: EnumItem,
        theme: string,
        mouseOverride: boolean,
        keepOnScreen: boolean,
        dragMinimisedBar: boolean,
        welcomeToast: boolean,
        haptics: boolean,
        showProfile: boolean,
        showFullUsername: boolean,
        profileSide: string,
        antiWindowDuplicate: boolean,
        layoutMode: string,
        activeSubTab: number,
        motionSpeed: string,
    },
}

type DecodedSettings = {
    toggleKeybind: { [number]: unknown }?,
    theme: unknown?,
    mouseOverride: unknown?,
    keepOnScreen: unknown?,
    dragMinimisedBar: unknown?,
    welcomeToast: unknown?,
        haptics: unknown?,
        showProfile: unknown?,
        showFullUsername: unknown?,    profileSide: unknown?,
    antiWindowDuplicate: unknown?,
    layoutMode: unknown?,
    activeSubTab: unknown?,
    motionSpeed: unknown?,
}

function persistenceSettings.getSettingsPath(): (string, string)
    return paths.getSettingsPath()
end

function persistenceSettings.saveSettings(window: SettingsWindow): boolean
    local folder, filePath = persistenceSettings.getSettingsPath()

    local payload: { [string]: unknown } = {
        toggleKeybind = {
            tostring(window.settings.toggleKeybind.EnumType),
            window.settings.toggleKeybind.Value,
        } :: { unknown },
        theme = window.settings.theme,
        mouseOverride = window.settings.mouseOverride,
        keepOnScreen = window.settings.keepOnScreen,
        dragMinimisedBar = window.settings.dragMinimisedBar,
        welcomeToast = window.settings.welcomeToast,
        haptics = window.settings.haptics,
        showProfile = window.settings.showProfile,
        showFullUsername = window.settings.showFullUsername,
        profileSide = window.settings.profileSide,
        antiWindowDuplicate = window.settings.antiWindowDuplicate,
        layoutMode = window.settings.layoutMode,
        activeSubTab = window.settings.activeSubTab,
        motionSpeed = window.settings.motionSpeed,
    }

    local ok, encoded = pcall(coreState.httpService.JSONEncode, coreState.httpService, payload)
    if not ok then
        return false
    end

    local writeOk = pcall(writer.write, folder, filePath, encoded)

    if not writeOk then
        return false
    end

    return true
end

local function readDecoded(path: string): (DecodedSettings?, string?)
    local exists = false
    pcall(function()
        exists = fs.isfile(path)
    end)
    if not exists then
        return nil, nil
    end

    local readOk, raw = pcall(fs.readfile, path)
    if not readOk or type(raw) ~= "string" then
        return nil, nil
    end

    local decodeOk, decoded = pcall(coreState.httpService.JSONDecode, coreState.httpService, raw)
        if not decodeOk or type(decoded) ~= "table" then
        return nil, raw
    end

        return decoded :: DecodedSettings, raw
end

local function readWithFallback(): DecodedSettings?
    local settingsFolder, settingsPath = persistenceSettings.getSettingsPath()
    local tempFolder = readDecoded(settingsPath)
    if tempFolder then
        return tempFolder
    end

    local tempPath, tempRaw = readDecoded(writer.tempPathFor(settingsPath))
    if tempPath and tempRaw then
        pcall(writer.write, settingsFolder, settingsPath, tempRaw)
        return tempPath
    end

    return nil
end

function persistenceSettings.loadSettings(window: SettingsWindow): boolean
    local decodedSettings = readWithFallback()

    if not decodedSettings then
        return false
    end

    if decodedSettings.toggleKeybind then
        pcall(function()
            local enumTypeName = tostring(decodedSettings.toggleKeybind[1]):gsub("^Enum%.", "")
            local enumType = (Enum :: any)[enumTypeName]
            if enumType then
                local keybindItem = enumHelper.itemFromValue(enumType, decodedSettings.toggleKeybind[2])
                if keybindItem then
                    window.settings.toggleKeybind = keybindItem
                end
            end
        end)
    end

    if type(decodedSettings.theme) == "string" then
        local theme = string.lower(decodedSettings.theme)
        if theme == "default" or theme == "amethyst" or theme == "cobalt"
            or theme == "crimson" or theme == "ember" or theme == "emerald"
            or theme == "frost" or theme == "gold" or theme == "onyx"
            or theme == "rose"
        then
            window.settings.theme = theme
        end
    end

    if type(decodedSettings.mouseOverride) == "boolean" then
        window.settings.mouseOverride = decodedSettings.mouseOverride
    end

    if type(decodedSettings.keepOnScreen) == "boolean" then
        window.settings.keepOnScreen = decodedSettings.keepOnScreen
    end

    if type(decodedSettings.dragMinimisedBar) == "boolean" then
        window.settings.dragMinimisedBar = decodedSettings.dragMinimisedBar
    end

    if type(decodedSettings.welcomeToast) == "boolean" then
        window.settings.welcomeToast = decodedSettings.welcomeToast
    end

    if type(decodedSettings.haptics) == "boolean" then
        window.settings.haptics = decodedSettings.haptics
    end

    if type(decodedSettings.showProfile) == "boolean" then
        window.settings.showProfile = decodedSettings.showProfile
    end
    if type(decodedSettings.showFullUsername) == "boolean" then
        window.settings.showFullUsername = decodedSettings.showFullUsername
    end
    if decodedSettings.profileSide == "left" or decodedSettings.profileSide == "right" then
        window.settings.profileSide = decodedSettings.profileSide
    end
    if type(decodedSettings.antiWindowDuplicate) == "boolean" then
        window.settings.antiWindowDuplicate = decodedSettings.antiWindowDuplicate
    end
    if decodedSettings.layoutMode == "top"
        or decodedSettings.layoutMode == "sidebar"
        or decodedSettings.layoutMode == "collapsedSidebar"
    then
        window.settings.layoutMode = decodedSettings.layoutMode
    end

    if type(decodedSettings.activeSubTab) == "number" and decodedSettings.activeSubTab >= 1 then
        window.settings.activeSubTab = math.floor(decodedSettings.activeSubTab)
    end

    -- [[Motion profiles are validated by the motion service, the same way the
    -- live setting is, so a hand-edited settings file cannot put the library
    -- on a profile that does not exist.]]
    if type(decodedSettings.motionSpeed) == "string" then
        local motion = require(script.Parent.motion)
        if motion.profiles[decodedSettings.motionSpeed] then
            window.settings.motionSpeed = decodedSettings.motionSpeed
        end
    end

    return true
end

return persistenceSettings
