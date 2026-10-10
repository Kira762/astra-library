--[[
Resolve executor/host globals consistently across Luau environments.

Executors commonly place APIs in `getgenv()` while a module's `getfenv()`
contains a different table. Other hosts expose them through `getfenv(0)` or
`_G`. Keep all roots in a stable order and search every one, so file, HTTP and
asset-import capabilities are not missed just because they live in another
execution environment.
]]

local globals = {}

type Root = { [string]: any }

function globals.roots(): { Root }
    local result: { Root } = {}
    local seen: { [table]: boolean } = {}

    local function add(value: any)
        if type(value) == "table" and not seen[value] then
            seen[value] = true
            table.insert(result, value)
        end
    end

    local getgenvFn: any = nil
    pcall(function()
        getgenvFn = getgenv
    end)
    if type(getgenvFn) == "function" then
        local ok, value = pcall(getgenvFn)
        if ok then
            add(value)
        end
    end

    local getfenvFn: any = nil
    pcall(function()
        getfenvFn = getfenv
    end)
    if type(getfenvFn) == "function" then
        local ok, value = pcall(getfenvFn, 0)
        if ok then
            add(value)
        end
        ok, value = pcall(getfenvFn)
        if ok then
            add(value)
        end
    end

    local globalTable: any = nil
    pcall(function()
        globalTable = _G
    end)
    add(globalTable)

    return result
end

function globals.get(name: string): any
    for _, root in globals.roots() do
        local ok, value = pcall(function()
            return root[name]
        end)
        if ok and value ~= nil then
            return value
        end
    end
    return nil
end

function globals.getFunction(name: string): any
    local value = globals.get(name)
    return if type(value) == "function" then value else nil
end

function globals.getPath(path: { string }): any
    for _, root in globals.roots() do
        local current: any = root
        local found = true
        for _, key in path do
            local ok, nextValue = pcall(function()
                if type(current) ~= "table" then
                    return nil
                end
                return current[key]
            end)
            if not ok or nextValue == nil then
                found = false
                break
            end
            current = nextValue
        end
        if found then
            return current
        end
    end
    return nil
end

return globals
