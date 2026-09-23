
local persistenceCache = {}

local cache: { [string]: any } = {}

function persistenceCache.getSettings(key: string): any?
    return cache[key]
end

function persistenceCache.putSettings(key: string, value: any)
    cache[key] = value
end

function persistenceCache.invalidateSettings(key: string?)
    if key then
        cache[key] = nil
    else
        table.clear(cache)
    end
end

return persistenceCache
