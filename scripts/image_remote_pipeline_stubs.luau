-- Partial executor layer for the remote-image pipeline regression.
-- Deliberately stores globals only in getgenv() and omits readfile,
-- listfiles, delfile and delfolder: image caching needs a usable subset, not
-- the entire optional executor filesystem API.
local genv = getgenv()
local files = {}
local folders = {}
local imported = {}
local fetched = {}
local png = "\137PNG\r\n\26\n" .. "image-test-body"

genv.writefile = function(path, body)
    files[path] = body
end

genv.isfile = function(path)
    return files[path] ~= nil
end

genv.isfolder = function(path)
    return folders[path] == true
end

genv.makefolder = function(path)
    folders[path] = true
end

genv.getsynasset = function(path)
    if files[path] == nil then
        error("missing local image: " .. path)
    end
    imported[path] = true
    return "rbxasset://partial-filesystem/" .. path
end

-- The request API is intentionally absent. The library should use the same
-- guarded game:HttpGet fallback that can load its bundle in this executor.
genv.request = nil
genv.http_request = nil
genv.http = nil
genv.syn = nil
genv.fluxus = nil

genv.readfile = nil
genv.listfiles = nil
genv.delfile = nil
genv.delfolder = nil

function game:HttpGet(url)
    fetched[url] = (fetched[url] or 0) + 1
    return png
end

genv.__ImageRemotePipeline = {
    files = files,
    folders = folders,
    imported = imported,
    fetched = fetched,
    png = png,
}
