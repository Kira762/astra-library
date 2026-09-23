
local appearance = {}

function appearance.validate(key: string, value: any): (boolean, any)
    if key == "keepOnScreen" then
        return type(value) == "boolean", value == true
    end
    if key == "layoutMode" then
        if value == "sidebar" or value == "collapsedSidebar" then
            return true, value
        end
        return false, nil
    end
    if key == "fontChoice" then
        if value == "default" or value == "brand" then
            return true, value
        end
        return false, nil
    end
    return false, nil
end

return appearance
