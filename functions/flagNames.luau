local flagNames = {}

local offsetBasis = 2166136261
local prime = 16777619

local function fnv1a(str: string): number
    local hash = offsetBasis
    for i = 1, #str do
        hash = bit32.bxor(hash, string.byte(str, i))
                local low = hash % 65536
        local high = (hash - low) / 65536
        hash = (((high * prime) % 65536) * 65536 + low * prime) % 4294967296
    end
    return hash
end

function flagNames.deriveFlagFromName(name: string): string
    local camelCase = name:gsub("(%S+)", function(w: string): string
        return w:sub(1, 1):upper() .. w:sub(2, -1)
    end):gsub("[^%w]", "")

            if camelCase == "" and name ~= "" then
        return string.format("Flag%08x", fnv1a(name))
    end

    return camelCase
end

return flagNames
