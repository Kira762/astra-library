
local windowIcons = {}

windowIcons.ids = {
    window = 80387863064905,
    close = 83277910885129,
    minimise = 108115485663409,
    maximise = 88738500661569,
    settings = 129180860773723,
    search = 100604009889706,
    chevron = 88479147175134,
    check = 125626312718314,
    dot = 91452555903853,
    config = 125823673784681,
}

windowIcons.roles = {
    close = "close",
    minimise = "minimise",
    maximise = "maximise",
    settings = "settings",
    search = "search",
    chevron = "chevron",
    check = "check",
    dot = "dot",
    config = "config",
}

function windowIcons.manifest()
    local manifest: { [number]: { roles: { string } } } = {}
    for name, id in windowIcons.ids do
        local entry = manifest[id]
        if not entry then
            entry = { roles = {} }
            manifest[id] = entry
        end
        table.insert(entry.roles, windowIcons.roles[name] or name)
    end
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
    local list = {}
    for name in windowIcons.ids do
        table.insert(list, windowIcons.roles[name] or name)
    end
    table.sort(list)
    return list
end

return windowIcons
