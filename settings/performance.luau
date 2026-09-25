
local performance = {}

function performance.validate(key: string, value: any): (boolean, any)
    if key == "haptics" then
        return type(value) == "boolean", value == true
    end
    return false, nil
end

return performance
