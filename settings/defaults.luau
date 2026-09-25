local keybind = require(script.Parent.Parent.utilities.keybind)

local defaults = {}

defaults.values = {
    toggleKeybind = Enum.KeyCode.K,
    mouseOverride = false,
    keepOnScreen = true,
    haptics = false,
    antiWindowDuplicate = true,
    layoutMode = "sidebar",
    fontChoice = "default",
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
    local letter = keybind.letter(result.toggleKeybind)
    result.toggleKeybind = if letter then Enum.KeyCode[letter] else Enum.KeyCode.K
    return result
end

return defaults
