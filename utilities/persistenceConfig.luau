local coreState = require(script.Parent.Parent.core.state)
local fs = require(script.Parent.filesystem)
local logger = require(script.Parent.log)
local pathUtil = require(script.Parent.path)
local paths = require(script.Parent.persistencePaths)
local writer = require(script.Parent.persistenceWrite)

local persistenceConfig = {}

type PersistedControl = {
    value: unknown,
    flag: string?,
    _canBeNil: boolean?,
    _serialize: ((PersistedControl) -> unknown)?,
    _deserialize: ((PersistedControl, unknown) -> ())?,
    Set: (PersistedControl, unknown) -> (),
}

type ConfigWindow = {
    controls: { [string]: PersistedControl },
    configuration: {
        fileName: string?,
        customFolder: string?,
    },
    name: string,
    _loading: boolean?,
    _loadedConfig: { [string]: unknown }?,
    _loadedConfigPath: string?,
}

function persistenceConfig.getPath(window: ConfigWindow, requestedName: unknown?): (string?, string?)
    return paths.getConfigPath(window, requestedName)
end

function persistenceConfig.save(window: ConfigWindow, saveName: unknown?): boolean
    local saveFolder, savePath = persistenceConfig.getPath(window, saveName)
    if not saveFolder or not savePath then
        logger.warn("Astra: configuration name '" .. tostring(saveName) .. "' has no usable characters")
        return false
    end

        if typeof(fs.writefile) ~= "function" then
        return false
    end

    local payload: { [string]: unknown } = {}
    for controlFlag, control in window.controls do
        local ok, serialized = pcall(function()
            local serializer = control._serialize
            if serializer then
                return serializer(control)
            end
            return control.value
        end)
        if ok then
            payload[controlFlag] = serialized
        else
            logger.warn("Astra: Failed to serialize flag '" .. tostring(controlFlag) .. "' - " .. tostring(serialized))
        end
    end

                local loadedConfig = window._loadedConfig
    if loadedConfig and window._loadedConfigPath == savePath then
        for preservedKey, preservedValue in loadedConfig do
            if window.controls[preservedKey] == nil then
                payload[preservedKey] = preservedValue
            end
        end
    end

    local encodeOk, encoded = pcall(coreState.httpService.JSONEncode, coreState.httpService, payload)
    if not encodeOk then
        logger.warn("Astra: Failed to encode configuration - " .. tostring(encoded))
        return false
    end

    local ok, writeErr = pcall(function()
        writer.write(saveFolder, savePath, encoded)
    end)

    if not ok then
        logger.warn("Astra: Failed to save configuration - " .. tostring(writeErr))
        return false
    end

                if window._loadedConfigPath == nil or window._loadedConfigPath == savePath then
        window._loadedConfig = payload
        window._loadedConfigPath = savePath
    end

    return true
end

local function readFile(sourcePath: string): ({ [string]: unknown }?, string?)
    if not fs.isfile(sourcePath) then
        return nil, nil
    end

    local readOk, raw = pcall(fs.readfile, sourcePath)
    if not readOk or type(raw) ~= "string" then
        logger.warn("Astra: Failed to read configuration file")
        return nil, nil
    end

    local decodeOk, decoded = pcall(coreState.httpService.JSONDecode, coreState.httpService, raw)

        if not decodeOk or type(decoded) ~= "table" then
        return nil, raw
    end

    return decoded :: { [string]: unknown }, raw
end

local function backupPathFor(targetPath: string): string
        local stem = pathUtil.stripExtension(targetPath, ".rfld")
    local candidatePath = stem .. " (Incorrect Format).rfld"
    local counter = 2
    while counter <= 100 and fs.isfile(candidatePath) do
        candidatePath = stem .. " (Incorrect Format " .. counter .. ").rfld"
        counter += 1
    end
    return candidatePath
end

function persistenceConfig.load(window: ConfigWindow, loadName: unknown?): boolean
    local loadFolder, loadPath = persistenceConfig.getPath(window, loadName)
    if not loadFolder or not loadPath then
        logger.warn("Astra: configuration name '" .. tostring(loadName) .. "' has no usable characters")
        return false
    end

        if typeof(fs.isfile) ~= "function" then
        return false
    end

    local restored, rawFallback = readFile(loadPath)

            if not restored and fs.isfile(loadPath) then
        local tempDecoded, tempRaw = readFile(writer.tempPathFor(loadPath))
        if tempDecoded and tempRaw then
            restored = tempDecoded
                        pcall(writer.write, loadFolder, loadPath, tempRaw)
        end
    end

    if not restored then
        if rawFallback then
            logger.warn("Astra: Configuration file has an invalid format, backing up and resetting")
            local backupPath = backupPathFor(loadPath)
            pcall(function()
                fs.ensureDir(loadFolder)
                fs.writefile(backupPath, rawFallback)
                fs.delfile(loadPath)
            end)
        end
        return false
    end

    local values = restored :: { [string]: unknown }
    local wasLoading = window._loading
    window._loading = true
        local applyOk, applyErr = pcall(function()
        for loadedFlag, loadedControl in window.controls do
            persistenceConfig.applyTo(loadedControl, values[loadedFlag])
        end
    end)
            window._loading = wasLoading
    if not applyOk then
        logger.warn("Astra: Failed to apply configuration - " .. tostring(applyErr))
    end

                window._loadedConfig = values
    window._loadedConfigPath = loadPath

    return true
end

function persistenceConfig.applyTo(target: PersistedControl, controlValue: unknown)
    if controlValue == nil and not target._canBeNil then
        return
    end
    local ok, setErr = pcall(function()
        local deserializer = target._deserialize
        if deserializer then
            deserializer(target, controlValue)
        else
            target:Set(controlValue)
        end
    end)
    if not ok then
        logger.warn("Astra: Failed to restore flag '" .. tostring(target.flag) .. "' - " .. tostring(setErr))
    end
end

function persistenceConfig.list(window: ConfigWindow): { string }
    local listFolder = persistenceConfig.getPath(window)

    local names: { string } = {}
        if not listFolder then
        return names
    end
    local ok, files = pcall(fs.listfiles, listFolder)
    if not ok or type(files) ~= "table" then
        return names
    end

    for _, file in files do
        local baseName = pathUtil.basename(file)
        if baseName:sub(-5):lower() == ".rfld" then
            local configName = pathUtil.stripExtension(baseName, ".rfld")
            if configName and configName ~= "" and not configName:find(" %(Incorrect Format[^%)]*%)$") then
                table.insert(names, configName)
            end
        end
    end

    table.sort(names)
    return names
end

function persistenceConfig.delete(window: ConfigWindow, deleteName: unknown): boolean
    if type(deleteName) ~= "string" or deleteName == "" then
        return false
    end

    local _, deletePath = persistenceConfig.getPath(window, deleteName)
    if not deletePath then
        return false
    end
    if typeof(fs.isfile) ~= "function" or not fs.isfile(deletePath) then
        return false
    end

        pcall(fs.delfile, writer.tempPathFor(deletePath))

    return (pcall(fs.delfile, deletePath))
end

return persistenceConfig
