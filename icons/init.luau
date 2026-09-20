-- [[Icon resolver service.]]
-- [[]]
-- [[Public API is compatible with the previous single-module catalog:]]
-- [[local Icons = require(path.to.icons)]]
-- [[Icons.get("arrow-down")            -- searches every pack in priority order]]
-- [[Icons.get("arrow-down", "lucide")  -- one pack only]]
-- [[Icons.get("material:home")         -- pack-qualified: that pack, exactly]]
-- [[Icons.getByPack("material", "add")]]
-- [[Icons.resolve(value, pack)]]
-- [[Icons.list(pack) / Icons.packs() / Icons.count(pack) / Icons.isPack(pack)]]
-- [[Icons.priority() / Icons.loaded() / Icons.refreshCustom()]]
-- [[Icons.Lucide == "lucide" (and the other pack name constants)]]
-- [[]]
-- [[Packs are lazy: each pack's data table lives in its own module and is]]
-- [[required on first lookup for that pack only, then kept cached. No HTTP]]
-- [[requests happen between internal modules; pack data is static.]]
-- [[]]
-- [[Lookups are exact. Icon names and pack names are case-sensitive: nothing]]
-- [[is lowercased, corrected or fuzzy-matched, so a miss is a miss. A name]]
-- [[that exists in several packs resolves to the first pack listed by]]
-- [[`Icons.priority()` (lucide, material, tabler, phosphor, heroicons, feather,]]
-- [[remix); an explicit pack - `get(name, pack)` or the `"pack:name"` form -]]
-- [[is never overridden by that order, and an unknown or mis-cased pack name]]
-- [[resolves to nothing rather than to some other pack.]]

local icons = {}

-- [[Pack priority for a bare name. Deterministic, and also the order packs]]
-- [[load in: the search stops at the first pack that has the name, so a lucide]]
-- [[icon never pulls in the other six tables.]]
local PACK_ORDER = { "lucide", "material", "tabler", "phosphor", "heroicons", "feather", "remix" }

-- [[Pack registry: pack name -> lazy loader. Each loader requires the pack]]
-- [[module on demand; require() itself caches the module table afterwards.]]
local packLoaders = {
    lucide = function()
        return require(script.lucide)
    end,
    material = function()
        return require(script.material)
    end,
    tabler = function()
        return require(script.tabler)
    end,
    phosphor = function()
        return require(script.phosphor)
    end,
    heroicons = function()
        return require(script.heroicons)
    end,
    feather = function()
        return require(script.feather)
    end,
    remix = function()
        return require(script.remix)
    end,
}

local loadedPacks: { [string]: { [string]: string } } = {}

-- [[Pack name constants (legacy surface: Icons.Lucide, Icons.Material, ...)]]
icons.Lucide = "lucide"
icons.Material = "material"
icons.Tabler = "tabler"
icons.Phosphor = "phosphor"
icons.Heroicons = "heroicons"
icons.Feather = "feather"
icons.Remix = "remix"

-- [[Lazily exposed pack tables (Icons.lucide, Icons.material, ...).]]
setmetatable(icons, {
    __index = function(self, pack: string)
        local loader = packLoaders[pack]
        if not loader then
            return nil
        end
        local data = loader()
        loadedPacks[pack] = data
        -- [[Cache the table so future reads skip the metatable entirely.]]
        rawset(self, pack, data)
        return data
    end,
})

local function packTable(pack: string?): { [string]: string }?
    pack = pack or "lucide"
    if type(pack) ~= "string" then
        return nil
    end
    local cached = loadedPacks[pack]
    if cached then
        return cached
    end
    local loader = packLoaders[pack]
    if not loader then
        return nil
    end
    local data = loader()
    loadedPacks[pack] = data
    rawset(icons, pack, data)
    return data
end

function icons.isPack(pack: string?): boolean
    return pack ~= nil and type(pack) == "string" and packLoaders[pack] ~= nil
end

-- [[The order a bare name is searched in (a copy: callers cannot reorder it).]]
function icons.priority(): { string }
    local order = table.create(#PACK_ORDER)
    for index, pack in ipairs(PACK_ORDER) do
        order[index] = pack
    end
    return order
end

-- [[Which packs have been loaded so far. Laziness is part of the contract]]
-- [[(startup must not read 13.7k lines of tables to show one icon), so it is]]
-- [[observable: a suite asserts that one lucide name loads one pack.]]
function icons.loaded(): { string }
    local names = {}
    for pack in loadedPacks do
        table.insert(names, pack)
    end
    table.sort(names)
    return names
end

local namedAssets = {
}

local function environment(): any
    return (getfenv and getfenv()) or _G
end

-- [[Warnings are once per unknown pack name: a typo in a hot path must not]]
-- [[spam the console every frame, but the first occurrence has to be findable.]]
local warnedPacks: { [string]: boolean } = {}

local function report(message: string)
    local env = environment()
    if type(env.warn) == "function" then
        pcall(env.warn, message)
    end
end

local function warnUnknownPack(pack: string, request: string)
    if warnedPacks[pack] then
        return
    end
    warnedPacks[pack] = true
    report(`[Icons] Unknown icon pack "{pack}" in "{request}": pack names are case-sensitive ({table.concat(PACK_ORDER, ", ")})`)
end

-- [[`"pack:name"` -> pack, name. Split on the first colon only, so an icon]]
-- [[name that itself contains a colon is still addressable. No pack prefix]]
-- [[means "search every pack".]]
local function splitRequest(value: string): (string?, string)
    local colon = string.find(value, ":", 1, true)
    if not colon then
        return nil, value
    end
    return string.sub(value, 1, colon - 1), string.sub(value, colon + 1)
end

local function findInPack(pack: string, name: string): string?
    local data = packTable(pack)
    if not data then
        return nil
    end
    return data[name]
end

local assetBase = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/"

local function prefixed(resolved: string?): string?
    if type(resolved) == "string" and string.sub(resolved, 1, 7) == "assets/" then
        return assetBase .. resolved
    end
    return resolved
end

-- =========================================================================
-- Custom assets
-- =========================================================================
-- [[User files under `custom_asset/` win over every pack. The folder is]]
-- [[indexed once with the executor's `listfiles` instead of being probed per]]
-- [[lookup: a name that has no file there costs nothing after the first]]
-- [[search (a 16-element page used to spend 195 getcustomasset calls on]]
-- [[misses alone), and a file that is used is imported once per path.]]
-- [[]]
-- [[Executors without `listfiles` keep the historic per-name probe, now]]
-- [[memoised - including the misses, which is what repeats do not re-run.]]
-- [[]]
-- [[Files may live in subfolders (`custom_asset/brand/house.png` is looked up]]
-- [[as `"brand/house"`). Extensions keep the historic set and preference]]
-- [[order: png, jpg, jpeg, webp, then a bare filename with no extension.]]

local customAssetFolder = "custom_asset"
local customExtensions = { ".png", ".jpg", ".jpeg", ".webp" }

local customIndex: { [string]: string }? = nil
local customIndexBuilt = false
local customProbed: { [string]: string? } = {}
local customUris: { [string]: string? } = {}
local resolved: { [string]: string? } = {}

-- [[A custom file's lookup key (its path inside the folder, without the]]
-- [[extension) and the rank of that extension. Files with an unknown]]
-- [[extension are not indexed; a bare filename ranks last, as it always did.]]
local function customKey(path: string): (string?, number?)
    local lower = string.lower(path)
    for rank, ext in ipairs(customExtensions) do
        if string.sub(lower, -#ext) == ext then
            return string.sub(path, 1, #path - #ext), rank
        end
    end
    local base = string.match(lower, "[^/]*$") or lower
    if not string.find(base, ".", 1, true) then
        return path, #customExtensions + 1
    end
    return nil, nil
end

local function buildCustomIndex(): { [string]: string }?
    local env = environment()
    if type(env.listfiles) ~= "function" then
        return nil
    end
    local ok, entries = pcall(env.listfiles, customAssetFolder)
    if not ok or type(entries) ~= "table" then
        -- [[No folder (or no listing support right now): an empty index, so]]
        -- [[every later lookup is a table miss instead of a filesystem probe.]]
        return {}
    end
    local index: { [string]: string } = {}
    local ranks: { [string]: number } = {}
    for _, entry in ipairs(entries) do
        if type(entry) == "string" and entry ~= "" then
            local key, rank = customKey(entry)
            if key then
                local prefix = customAssetFolder .. "/"
                if string.sub(key, 1, #prefix) == prefix then
                    key = string.sub(key, #prefix + 1)
                end
                local previous = ranks[key]
                if previous == nil or rank < previous then
                    index[key] = entry
                    ranks[key] = rank
                end
            end
        end
    end
    return index
end

local function customFile(value: string): string?
    if not customIndexBuilt then
        customIndex = buildCustomIndex()
        customIndexBuilt = true
    end
    local index = customIndex
    if index then
        return index[value]
    end
    local probed = customProbed[value]
    if probed ~= nil then
        return probed or nil
    end
    local env = environment()
    if type(env.getcustomasset) ~= "function" then
        customProbed[value] = false
        return nil
    end
    for _, ext in ipairs(customExtensions) do
        local path = customAssetFolder .. "/" .. value .. ext
        local ok, uri = pcall(env.getcustomasset, path)
        if ok and type(uri) == "string" and uri ~= "" then
            customProbed[value] = path
            customUris[path] = uri
            return path
        end
    end
    -- [[A file with no extension is the last accepted form (historic).]]
    local bare = customAssetFolder .. "/" .. value
    local ok, uri = pcall(env.getcustomasset, bare)
    if ok and type(uri) == "string" and uri ~= "" then
        customProbed[value] = bare
        customUris[bare] = uri
        return bare
    end
    customProbed[value] = false
    return nil
end

local function customUri(value: string): string?
    local path = customFile(value)
    if not path then
        return nil
    end
    local cached = customUris[path]
    if cached ~= nil then
        return cached or nil
    end
    local env = environment()
    local ok, uri = pcall(env.getcustomasset, path)
    if ok and type(uri) == "string" and uri ~= "" then
        customUris[path] = uri
        return uri
    end
    customUris[path] = false
    return nil
end

-- [[Re-read the custom asset folder and drop every memo that depended on it]]
-- [[(including resolved icons). Call it after adding or replacing files at]]
-- [[runtime. Returns how many files the listing found; 0 means the executor]]
-- [[has no listfiles and lookups fall back to the per-name probe.]]
function icons.refreshCustom(): number
    customIndex = buildCustomIndex()
    customIndexBuilt = true
    table.clear(customProbed)
    table.clear(customUris)
    table.clear(resolved)
    local count = 0
    for _ in customIndex or {} do
        count += 1
    end
    return count
end

-- =========================================================================
-- Lookup
-- =========================================================================

-- [[Get icon path by name. Without a pack, every pack is searched in]]
-- [[`icons.priority()` order and the first match wins.]]
function icons.get(name: string, pack: string?): string?
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if namedAssets[name] then
        return namedAssets[name]
    end
    local qualifiedPack, qualifiedName = splitRequest(name)
    if qualifiedPack ~= nil then
        if not packLoaders[qualifiedPack] then
            warnUnknownPack(qualifiedPack, name)
            return nil
        end
        if qualifiedName == "" then
            return nil
        end
        return findInPack(qualifiedPack, qualifiedName)
    end
    if pack ~= nil then
        if type(pack) ~= "string" or not packLoaders[pack] then
            warnUnknownPack(tostring(pack), name)
            return nil
        end
        return findInPack(pack, name)
    end
    for _, candidate in ipairs(PACK_ORDER) do
        local hit = findInPack(candidate, name)
        if hit then
            return hit
        end
    end
    return nil
end

-- [[Get icon URL by pack and name (a pack-qualified `get`).]]
function icons.getByPack(pack: string, name: string): string?
    return icons.get(name, pack)
end

-- [[The loadable form of one request, or nil when nothing matched.]]
local function lookup(value: string, pack: string?): string?
    if namedAssets[value] then
        return prefixed(namedAssets[value])
    end
    local qualifiedPack, qualifiedName = splitRequest(value)
    if qualifiedPack ~= nil then
        if not packLoaders[qualifiedPack] then
            warnUnknownPack(qualifiedPack, value)
            return nil
        end
        if qualifiedName == "" then
            return nil
        end
        return prefixed(findInPack(qualifiedPack, qualifiedName))
    end
    if pack ~= nil then
        -- [[An explicit pack is exactly that: `resolve(name, "material")` and
        -- [[`window:ResolveIcon` (which passes the window's pack) answer from
        -- [[that pack or not at all. Falling back here would quietly overrule
        -- [[the pack a host picked. A caller walking a list of candidate
        -- [[names also relies on it: a name the active pack does not have has
        -- [[to come back unresolved so the next candidate is tried.]]
        if type(pack) ~= "string" or not packLoaders[pack] then
            warnUnknownPack(tostring(pack), value)
            return nil
        end
        return prefixed(findInPack(pack, value))
    end
    for _, candidate in ipairs(PACK_ORDER) do
        local hit = prefixed(findInPack(candidate, value))
        if hit then
            return hit
        end
    end
    return nil
end

local function isLoadable(value: string): boolean
    return string.match(value, "^rbxassetid://") ~= nil
        or string.match(value, "^rbxasset://") ~= nil
        or string.match(value, "^rbxthumb://") ~= nil
        or string.match(value, "^https?://") ~= nil
end

-- [[Resolve a component icon.]]
-- [[]]
-- [[  1. values that are already loadable pass through untouched,]]
-- [[  2. a file in the custom asset folder wins over every pack,]]
-- [[  3. `"pack:name"` is exact - that pack or nothing,]]
-- [[  4. with no pack, a bare name is looked up in `icons.priority()` order]]
-- [[     and the first pack that has it wins; with a pack, that pack answers]]
-- [[     or the request stays unresolved (explicit packs are never overruled),]]
-- [[  5. nothing matches: the value comes back unchanged, which is the]]
-- [[     fallback the UI has always used.]]
-- [[]]
-- [[Results are memoised per (request, pack): repeated resolves of the same]]
-- [[icon - and every element that asks for it - reuse one answer, and a]]
-- [[custom file's imported URI is taken from the executor once.]]
function icons.resolve(value: (string | number)?, pack: string?): (string | number)?
    if value == nil or value == 0 or value == "" then
        return value
    end
    if type(value) ~= "string" then
        return value
    end
    if isLoadable(value) then
        return value
    end
    local key = (if type(pack) == "string" then pack else "") .. "\0" .. value
    local cached = resolved[key]
    if cached ~= nil then
        return if cached == false then value else cached
    end
    local hit = customUri(value) or lookup(value, pack)
    resolved[key] = hit or false
    return hit or value
end

-- [[List all available icon names in a pack]]
function icons.list(pack: string?): { string }
    pack = pack or "lucide"
    local data = packTable(pack)
    if not data then
        return {}
    end
    local result = {}
    for name in data do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

-- [[List all available packs]]
function icons.packs(): { string }
    local names = table.create(#PACK_ORDER)
    for index, pack in ipairs(PACK_ORDER) do
        names[index] = pack
    end
    return names
end

-- [[Count icons in a pack (loads that pack on demand)]]
function icons.count(pack: string?): number
    pack = pack or "lucide"
    local data = packTable(pack)
    if not data then
        return 0
    end
    local n = 0
    for _ in data do
        n += 1
    end
    return n
end

return icons
