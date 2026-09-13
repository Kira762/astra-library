
local defaults = {}

defaults.values = {
    toggleKeybind = Enum.KeyCode.K,
    mouseOverride = true,
    keepOnScreen = true,
    welcomeToast = true,
    haptics = false,
    showProfile = true,
    showFullUsername = false,
    antiWindowDuplicate = true,
    layoutMode = "top",
    activeSubTab = 1,
    motionSpeed = "normal",
    autoSaveConfig = true,
    autoLoadConfig = true,
}

function defaults.clone(overrides: { [string]: any }?): { [string]: any }
    local result = table.clone(defaults.values)
    if overrides then
        for key, value in overrides do
            result[key] = value
        end
    end
    return result
end

return defaults
