
local motion = require(script.Parent.Parent.utilities.motion)

local performance = {}

function performance.validate(key: string, value: any): (boolean, any)
    if key == "haptics" then
        return type(value) == "boolean", value == true
    end
    if key == "motionSpeed" then
        --[[
        Validated against the motion service's own profile list, so the
        setting can never name a profile the library does not implement.
        ]]
        if type(value) == "string" and motion.profiles[value] then
            return true, value
        end
        return false, nil
    end
    return false, nil
end

return performance
