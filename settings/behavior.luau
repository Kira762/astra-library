local keybind = require(script.Parent.Parent.utilities.keybind)

local behavior = {}

function behavior.validate(key: string, value: any): (boolean, any)
    if key == "toggleKeybind" then
        local letter = keybind.letter(value)
        return letter ~= nil, if letter then Enum.KeyCode[letter] else nil
    end
    if key == "mouseOverride" or key == "antiWindowDuplicate" or key == "autoSaveConfig" or key == "autoLoadConfig" then
        return type(value) == "boolean", value == true
    end
    return false, nil
end

return behavior
