-- [[Shared validation for required, single-letter key bindings.]]
local keybind = {}

function keybind.letter(value)
    if typeof(value) == "EnumItem" then
        if value.EnumType ~= Enum.KeyCode then
            return nil
        end
        value = value.Name
    end
    if type(value) ~= "string" or not value:match("^[A-Za-z]$") then
        return nil
    end
    return value:upper()
end

return keybind
