local fs = require(script.Parent.filesystem)
local pathUtil = require(script.Parent.path)

local defaultRoot = "Astra"

local filesystemManager = {}
filesystemManager.__index = filesystemManager

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
