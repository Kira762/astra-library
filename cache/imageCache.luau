local filesystem = require(script.Parent.Parent.utilities.filesystem)
local path = require(script.Parent.Parent.utilities.path)
local variables = require(script.Parent.Parent.core.state)
local constants = require(script.Parent.Parent.utilities.constants)
local windowIcons = require(script.Parent.Parent.images.windowIcons)

export type RewriteMap = { [number]: string }
export type CacheSettledCallback = (failed: number, failedRoles: { string }) -> ()
export type PreloadCallback = CacheSettledCallback
export type AvatarCallback = (uri: string) -> ()
export type OnCachedCallback = (id: number) -> ()
export type ThumbnailEntry = {
    state: string?,
    imageUrl: string?,
}
export type ThumbnailResponse = {
    data: { ThumbnailEntry }?,
}
local imageCache = {}

type RemoteCallback = (uri: string?) -> ()

local cacheRoot = variables.fileSystemManager:getRootFolder()
local cacheFolder = variables.fileSystemManager:getAssetsFolder("images-icon")
local assetResolver = variables.assetResolver

local assetBase = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/assets/window-icons/"
local headshotPx = 48
local thumbEndpoint =
    "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=%dx%d&format=Png&isCircular=false"

local manifest: { [number]: string } = {}
for name, iconId in windowIcons.ids do
    local file = windowIcons.files[name]
    if file then
        manifest[iconId] = assetBase .. file
    end
end
local manifestSize = 0
for _ in manifest do
    manifestSize += 1
end

imageCache.rewrites = {} :: RewriteMap
	imageCache.onCached = nil :: OnCachedCallback?
local pngMagic = "\137PNG\r\n\26\n"
local remoteRewrites: { [string]: string } = {}
local remotePending: { [string]: { RemoteCallback } } = {}

local function cacheFile(filePath: string, url: string): string?
        if type(getfenv().getcustomasset) ~= "function" or typeof(filesystem.isfile) ~= "function" then
        return nil
    end
    if not filesystem.isfile(filePath) then
        pcall(filesystem.ensureFolder, cacheRoot)
        pcall(filesystem.ensureFolder, cacheFolder)
        local body = assetResolver:getAssetContentFromUrl(url, filePath, false)
                        if not body or string.sub(body, 1, 8) ~= pngMagic then
            return nil
        end
        if not pcall(filesystem.writefile, filePath, body) then
            return nil
        end
    end
    local ok, uri = pcall(getfenv().getcustomasset, filePath)
    return if ok and type(uri) == "string" then uri else nil
end

local function remoteFilePath(url: string): string
    local hash = 0
    for index = 1, #url do
        hash = (hash * 33 + string.byte(url, index)) % 2147483647
    end
    return path.join(cacheFolder, "icon_" .. tostring(hash) .. ".png")
end

function imageCache.remote(url: string, onReady: RemoteCallback?): string
    local env = getfenv()
    if type(env.getcustomasset) ~= "function" or typeof(filesystem.isfile) ~= "function" then
        if onReady then
            task.defer(onReady, nil)
        end
        return ""
    end

    local rewritten = remoteRewrites[url]
    if rewritten then
        if onReady then
            task.defer(onReady, rewritten)
        end
        return rewritten
    end

    local filePath = remoteFilePath(url)
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(env.getcustomasset, filePath)
        if ok and type(uri) == "string" then
            remoteRewrites[url] = uri
            if onReady then
                task.defer(onReady, uri)
            end
            return uri
        end
    end

    local pending = remotePending[url]
    if not pending then
        pending = {}
        remotePending[url] = pending
        task.spawn(function()
            local uri = cacheFile(filePath, url)
            if uri then
                remoteRewrites[url] = uri
            end
            local callbacks = remotePending[url]
            remotePending[url] = nil
            if callbacks then
                for _, callback in callbacks do
                    pcall(callback, uri)
                end
            end
        end)
    end
    if onReady then
        table.insert(pending, onReady)
    end
    return ""
end

local function avatarPath(userId: number): string
    return path.join(cacheFolder, "avatar_" .. tostring(userId) .. ".png")
end

local function decodeThumbnailUrl(body: string): string?
    local decodeOk, parsed = pcall(function()
        return variables.httpService:JSONDecode(body)
    end)
    if not decodeOk or type(parsed) ~= "table" then
        return nil
    end

    local data = (parsed :: ThumbnailResponse).data
    if type(data) ~= "table" then
        return nil
    end

    local entry = data[1]
    if type(entry) ~= "table" then
        return nil
    end

    local thumbnail = entry :: ThumbnailEntry
    if thumbnail.state == "Completed" and type(thumbnail.imageUrl) == "string" then
        return thumbnail.imageUrl
    end

    return nil
end

local function fetchAvatar(userId: number): string?
    local cdnUrl: string? = nil
    for attempt = 1, 4 do
                local body = assetResolver:getAssetContentFromUrl(
            string.format(thumbEndpoint, userId, headshotPx, headshotPx),
            "avatar:" .. tostring(userId),
            attempt > 1
        )
        if body then
            local imageUrl = decodeThumbnailUrl(body)
            if imageUrl then
                cdnUrl = imageUrl
                break
            end
        end
        if attempt < 4 then
            task.wait(0.3)
        end
    end
    if not cdnUrl then
        return nil
    end

    return cacheFile(avatarPath(userId), cdnUrl)
end

local pendingAvatars: { [number]: { AvatarCallback } } = {}
local failedAvatars: { [number]: boolean } = {}

function imageCache.preload(onSettled: PreloadCallback?): (boolean, number)
    local env = getfenv()
    if type(env.getcustomasset) ~= "function" or typeof(filesystem.isfile) ~= "function" then
        if onSettled then
            task.defer(onSettled, manifestSize, windowIcons.roleList())
        end
        return false, manifestSize
    end

    local rewrites = imageCache.rewrites
	    table.clear(rewrites)
    local function settle()
        if not onSettled then
            return
        end
        local failed = 0
        local failedRoles = {}
        for id in manifest do
            if not rewrites[id] then
                failed += 1
                table.insert(failedRoles, windowIcons.roleForId(id))
            end
        end
        table.sort(failedRoles)
        onSettled(failed, failedRoles)
    end

    local pending, missing = 0, 0
    local spawning = true     for id, url in manifest do
        local filePath = path.join(cacheFolder, tostring(id) .. ".png")
        local uri: string? = nil
        if filesystem.isfile(filePath) then
            local ok, res = pcall(env.getcustomasset, filePath)
            uri = if ok and type(res) == "string" then res else nil
        end
        if uri then
                        rewrites[id] = uri
        else
                        missing += 1
            pending += 1
            task.spawn(function()
                local cached = cacheFile(filePath, url)
                if cached then
                    rewrites[id] = cached
                    if imageCache.onCached then
                                                pcall(imageCache.onCached, id)
                    end
                end
                pending -= 1
                if pending == 0 and not spawning then
                    settle()
                end
            end)
        end
    end

    spawning = false
    if pending == 0 then
        settle()
    end

    return missing == 0, missing
end

function imageCache.avatar(userId: unknown, onReady: AvatarCallback?): string
    if type(userId) ~= "number" then
        return ""
    end

        if typeof(filesystem.isfile) ~= "function" then
        return ""
    end

    local filePath = avatarPath(userId)
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(getfenv().getcustomasset, filePath)
        if ok and type(uri) == "string" then
            return uri
        end
    end

        if failedAvatars[userId] then
        return ""
    end

            local waiting = pendingAvatars[userId]
    if waiting then
        if onReady then
            table.insert(waiting, onReady)
        end
        return ""
    end

    if onReady then
        pendingAvatars[userId] = { onReady }
        task.spawn(function()
            local uri = fetchAvatar(userId)
            local callbacks = pendingAvatars[userId]
            pendingAvatars[userId] = nil
            if not uri then
                failedAvatars[userId] = true
            end
            if callbacks then
                for _, callback in callbacks do
                    pcall(callback, uri or "")
                end
            end
        end)
    end

    return ""
end

return imageCache
