
local moduleCache = {}

local cache: { [string]: any } = {}

function moduleCache.singleton(key: string, factory: () -> any): any
    local cached = cache[key]
    if cached ~= nil then
        return cached
    end
    local result = factory()
    cache[key] = result
    return result
end

function moduleCache.get(key: string): any?
    return cache[key]
end

function moduleCache.peek(key: string): boolean
    return cache[key] ~= nil
end

function moduleCache._forget(key: string)
    cache[key] = nil
end

return moduleCache
