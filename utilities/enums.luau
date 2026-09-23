local enums = {}

function enums.itemFromValue(enumType, value)
    local ok, directItem = pcall(function()
        return enumType:FromValue(value)
    end)
    if ok and directItem then
        return directItem
    end

    local listedOk, items = pcall(function()
        return enumType:GetEnumItems()
    end)
    if not listedOk then
        return nil
    end

    for _, candidate in items do
        if candidate.Value == value then
            return candidate
        end
    end

    return nil
end

return enums
