local coreState = require(script.Parent.Parent.core.state)
local pathUtil = require(script.Parent.path)
local fs = require(script.Parent.filesystem)

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

    local currentPath = pathUtil.join(folder, baseName .. ".txt")
    -- The former default config lived under Astra/config/AstraConfigs with
    -- the name Astra-Hub. Copy it forward once, without replacing a Mova
    -- config, so upgrading the default paths does not make saved controls
    -- appear to disappear. The original remains untouched as a backup.
    if
        window.configuration.customFolder == "MovaConfigs"
        and window.configuration.fileName == "Mova-Hub"
        and type(fs.isfile) == "function"
        and type(fs.readfile) == "function"
        and type(fs.writefile) == "function"
    then
        local currentExists = false
        pcall(function()
            currentExists = fs.isfile(currentPath)
        end)
        if not currentExists then
            for _, legacyPath in {
                pathUtil.join("Mova/config/AstraConfigs", "Astra-Hub.txt"),
                pathUtil.join("Astra/config/AstraConfigs", "Astra-Hub.txt"),
            } do
                local legacyExists = false
                pcall(function()
                    legacyExists = fs.isfile(legacyPath)
                end)
                if legacyExists then
                    local readOk, contents = pcall(fs.readfile, legacyPath)
                    if readOk and type(contents) == "string" then
                        pcall(fs.ensureDir, folder)
                        local writeOk = pcall(fs.writefile, currentPath, contents)
                        if writeOk then
                            break
                        end
                    end
                end
            end
        end
    end

    return folder, currentPath
end

function persistencePaths.getSettingsPath(): (string, string)
    local settingsFolder = coreState.fileSystemManager:getPath("settings")
    local currentPath = pathUtil.join(settingsFolder, "mova.txt")
    if type(fs.isfile) == "function" and type(fs.readfile) == "function" and type(fs.writefile) == "function" then
        local currentExists = false
        pcall(function()
            currentExists = fs.isfile(currentPath)
        end)
        if not currentExists then
            pcall(fs.ensureFolder, settingsFolder)
            for _, legacyPath in {
                pathUtil.join(settingsFolder, "astra.txt"),
                pathUtil.join("Astra/settings", "astra.txt"),
            } do
                local legacyExists = false
                pcall(function()
                    legacyExists = fs.isfile(legacyPath)
                end)
                if legacyExists then
                    local readOk, contents = pcall(fs.readfile, legacyPath)
                    if readOk and type(contents) == "string" then
                        pcall(fs.writefile, currentPath, contents)
                    end
                    break
                end
            end
        end
    end
    return settingsFolder, currentPath
end

return persistencePaths
