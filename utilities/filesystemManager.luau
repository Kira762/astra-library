local fs = require(script.Parent.filesystem)
local pathUtil = require(script.Parent.path)

local defaultRoot = "Mova"
local legacyRoot = "Astra"
local maxMigrationDepth = 32

local filesystemManager = {}
filesystemManager.__index = filesystemManager

local function isFolder(path: string): boolean
    if type(fs.isfolder) ~= "function" then
        return false
    end
    local ok, result = pcall(fs.isfolder, path)
    return ok and result == true
end

local function isFile(path: string): boolean
    if type(fs.isfile) ~= "function" then
        return false
    end
    local ok, result = pcall(fs.isfile, path)
    return ok and result == true
end

-- Copy legacy user data without overwriting anything already in Mova/.
-- The old tree is intentionally left in place so a failed/partial migration
-- can never destroy a user's only copy.
local function migrateLegacyTree(source: string, destination: string, depth: number?)
    depth = depth or 0
    if depth >= maxMigrationDepth or type(fs.listfiles) ~= "function" then
        return
    end
    local migrationMarker = pathUtil.join(destination, ".legacy-data-migrated")
    if depth == 0 and isFile(migrationMarker) then
        return
    end
    pcall(fs.ensureFolder, destination)

    local ok, entries = pcall(fs.listfiles, source)
    if not ok or type(entries) ~= "table" then
        return
    end

    local sourcePrefix = source:gsub("\\", "/"):gsub("/+$", "") .. "/"
    for _, listedPath in ipairs(entries) do
        if type(listedPath) == "string" then
            local normalizedPath = listedPath:gsub("\\", "/")
            local sourcePath = if normalizedPath:sub(1, #sourcePrefix) == sourcePrefix
                then normalizedPath
                else pathUtil.join(source, normalizedPath)
            local name = pathUtil.basename(sourcePath)
            if name ~= "" and name ~= "." and name ~= ".." and sourcePath ~= source then
                local destinationPath = pathUtil.join(destination, name)
                if isFolder(sourcePath) then
                    migrateLegacyTree(sourcePath, destinationPath, depth + 1)
                elseif isFile(sourcePath) and not isFile(destinationPath) then
                    local readOk, contents = pcall(fs.readfile, sourcePath)
                    if readOk and type(contents) == "string" then
                        pcall(fs.writefile, destinationPath, contents)
                    end
                end
            end
        end
    end
    if depth == 0 and type(fs.writefile) == "function" then
        pcall(fs.writefile, migrationMarker, "1")
    end
end

export type FileSystemManager = {
    root: string,
    assets: string,
    getPath: (self: FileSystemManager, subpath: string?) -> string,
    getAssetsFolder: (self: FileSystemManager, subfolder: string?) -> string,
    getRootFolder: (self: FileSystemManager) -> string,
}

function filesystemManager.new(rootOverride: string?): FileSystemManager
    local root = rootOverride or defaultRoot
    local self = setmetatable({
        root = root,
        assets = root .. "/assets",
    }, filesystemManager) :: any
    pcall(fs.ensureFolder, self.root)
    if root == defaultRoot then
        migrateLegacyTree(legacyRoot, root)
    end
    pcall(fs.ensureFolder, self.assets)

    return self
end

function filesystemManager:getPath(subpath: string?): string
    return pathUtil.join(self.root, subpath)
end

function filesystemManager:getAssetsFolder(subfolder: string?): string
    if subfolder then
        local folderPath = pathUtil.join(self.assets, subfolder)
        pcall(fs.ensureFolder, folderPath)
        return folderPath
    end
    return self.assets
end

function filesystemManager:getRootFolder(): string
    return self.root
end

return filesystemManager
