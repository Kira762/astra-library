local coreState = require(script.Parent.Parent.core.state)
local pathUtil = require(script.Parent.path)

local persistencePaths = {}

type ConfigWindow = {
    configuration: {
        fileName: string?,
        customFolder: string?,
    },
    name: string,
}

function persistencePaths.getConfigPath(window: ConfigWindow, configName: unknown?): (string?, string?)
    local folder = coreState.fileSystemManager:getPath("config")
    if window.configuration.customFolder then
        folder = pathUtil.join(folder, pathUtil.sanitizeFolder(window.configuration.customFolder))
    end
    if configName ~= nil then
        local sanitizedName = pathUtil.sanitizeFile(configName)
        if sanitizedName == "" then
            return nil, nil
        end
        return folder, pathUtil.join(folder, sanitizedName .. ".txt")
    end
    local baseName = pathUtil.sanitizeFile(window.configuration.fileName or window.name)
    if baseName == "" then
        baseName = pathUtil.sanitizeFile(window.name)
    end
    if baseName == "" then
        baseName = "Configuration"
    end
    return folder, pathUtil.join(folder, baseName .. ".txt")
end

function persistencePaths.getSettingsPath(): (string, string)
    local settingsFolder = coreState.fileSystemManager:getPath("settings")
    return settingsFolder, pathUtil.join(settingsFolder, "astra.txt")
end

return persistencePaths
