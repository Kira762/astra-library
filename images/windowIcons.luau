
local windowIcons = {}

windowIcons.ids = {
    window = 91452555903853,
    close = 83277910885129,
    minimise = 108115485663409,
    maximise = 88738500661569,
    settings = 129180860773723,
    search = 100604009889706,
    chevron = 88479147175134,
    check = 125626312718314,
    dot = 80387863064905,
    config = 125823673784681,
}

-- Human-readable filenames for the fallback PNGs in assets/window-icons/.
-- Numeric rbxassetids stay in `ids` for Roblox loading; these names are what
-- `cache/imageCache` fetches from GitHub when secureMode rewrites assets.
windowIcons.files = {
    window = "sirius.png",
    close = "close.png",
    minimise = "minimise.png",
    maximise = "maximise.png",
    settings = "settings.png",
    search = "search.png",
    chevron = "chevron.png",
    check = "check.png",
    dot = "astra.png",
    config = "config.png",
}

windowIcons.roles = {
    close = "close",
    minimise = "minimise",
    maximise = "maximise",
    settings = "settings",
    search = "search",
    chevron = "chevron",
    check = "check",
    dot = "astra",
    config = "config",
}

-- [[The id/role tables are module constants, so the reverse manifest and the
-- [[sorted role list are built once on first use instead of on every call -
-- [[roleForId used to rebuild the whole manifest per failed icon.]]
local cachedManifest: { [number]: { roles: { string } } }? = nil
local cachedRoleList: { string }? = nil

function windowIcons.manifest()
    if cachedManifest then
        return cachedManifest
    end
    local manifest: { [number]: { roles: { string } } } = {}
    for name, id in windowIcons.ids do
        local entry = manifest[id]
        if not entry then
            entry = { roles = {} }
            manifest[id] = entry
        end
        table.insert(entry.roles, windowIcons.roles[name] or name)
    end
    cachedManifest = manifest
    return manifest
end

function windowIcons.roleForId(id: number): string
    local entry = windowIcons.manifest()[id]
    if not entry or #entry.roles == 0 then
        return "window icon"
    end
    return table.concat(entry.roles, "/")
end

function windowIcons.roleList(): { string }
    if cachedRoleList then
        return cachedRoleList
    end
    local list = {}
    for name in windowIcons.ids do
        table.insert(list, windowIcons.roles[name] or name)
    end
    table.sort(list)
    cachedRoleList = list
    return list
end

return windowIcons
