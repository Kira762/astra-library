local coreState = require(script.Parent.Parent.core.state)
local fs = require(script.Parent.filesystem)
local pathUtil = require(script.Parent.path)
local writer = require(script.Parent.persistenceWrite)

local persistenceChangelog = {}

-- [[Seen-state lives in its own file next to settings, keyed by window. It is]]
-- [[window metadata, not control state, so config save/load/delete never touch]]
-- [[it and resetting settings cannot resurrect the dot.]]
function persistenceChangelog.getChangelogPath(): (string, string)
    local folder = coreState.fileSystemManager:getPath("settings")
    return folder, pathUtil.join(folder, "astra-changelog.rfld")
end

-- [[Same identity as the default config (custom folder + file name or window]]
-- [[name), so hubs sharing install defaults share "seen" exactly like they]]
-- [[share values.]]
function persistenceChangelog.windowKey(window): string
    local configuration = window.configuration or {}
    local base = pathUtil.sanitizeFile(configuration.fileName or window.name)
    if base == "" then
        base = pathUtil.sanitizeFile(window.name)
    end
    if base == "" then
        base = "Configuration"
    end
    local folder = ""
    if configuration.customFolder then
        folder = pathUtil.sanitizeFolder(configuration.customFolder)
    end
    if folder == "" then
        return base
    end
    return folder .. "/" .. base
end

local function readDecoded(path: string): ({ [string]: string }?, string?)
    local exists = false
    pcall(function()
        exists = fs.isfile(path)
    end)
    if not exists then
        return nil, nil
    end

    local readOk, raw = pcall(fs.readfile, path)
    if not readOk or type(raw) ~= "string" then
        return nil, nil
    end

    local decodeOk, decoded = pcall(coreState.httpService.JSONDecode, coreState.httpService, raw)
    if not decodeOk or type(decoded) ~= "table" then
        return nil, raw
    end

    return decoded, raw
end

function persistenceChangelog.loadSeen(): { [string]: string }
    local folder, filePath = persistenceChangelog.getChangelogPath()
    local decoded = readDecoded(filePath)
    if decoded then
        return decoded
    end

    local tempDecoded, tempRaw = readDecoded(writer.tempPathFor(filePath))
    if tempDecoded and tempRaw then
        pcall(writer.write, folder, filePath, tempRaw)
        return tempDecoded
    end

    return {}
end

function persistenceChangelog.saveSeen(seen: { [string]: string }): boolean
    local folder, filePath = persistenceChangelog.getChangelogPath()

    local ok, encoded = pcall(coreState.httpService.JSONEncode, coreState.httpService, seen)
    if not ok then
        return false
    end

    local writeOk = pcall(writer.write, folder, filePath, encoded)

    if not writeOk then
        return false
    end

    return true
end

return persistenceChangelog
