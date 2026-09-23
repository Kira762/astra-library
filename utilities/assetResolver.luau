local networkUtil = require(script.Parent.network)
local logger = require(script.Parent.log)

export type AssetId = number | string
export type AssetDownloadUrl = string
export type CacheKey = AssetId
export type ResolvedAsset = AssetId
export type AssetRequestPayload = {
    Url: string,
    Method: string,
}
local assetResolver = {
    Enum = {
        AssetDownloadUrl = {
            RobloxDownloadUrl = "https://assetdelivery.roblox.com/v1/asset/?id=%d" :: AssetDownloadUrl,
            RoProxyDownloadUrl = "https://assetdelivery.roproxy.com/v1/asset?id=%d" :: AssetDownloadUrl,
        },
    },
}
assetResolver.__index = assetResolver
assetResolver.__type = "assetResolver"
type AssetResolverState = {
    contentCache: { [CacheKey]: string }?,
    contentCacheOrder: { CacheKey }?,
    contentDownloadUrl: AssetDownloadUrl,
    pendingRequests: { [CacheKey]: { thread } },
}
export type AssetResolver = AssetResolverState & {
    resolve: (self: AssetResolver, value: unknown) -> ResolvedAsset?,
    getAssetContentFromUrl: (self: AssetResolver, url: string, cacheKey: CacheKey?, forced: boolean?) -> string?,
    getAssetContentFromId: (self: AssetResolver, id: AssetId, forced: boolean?) -> string?,
}

local maxCacheEntries = 8

function assetResolver.new(cacheEnabled: boolean?, downloadUrl: AssetDownloadUrl?): AssetResolver
    local cacheTable: { [CacheKey]: string }? = if cacheEnabled then {} else nil
    local self = setmetatable(
        {
            contentCache = cacheTable,
            contentCacheOrder = if cacheEnabled then {} :: { CacheKey } else nil,
            contentDownloadUrl = downloadUrl or assetResolver.Enum.AssetDownloadUrl.RobloxDownloadUrl,
            pendingRequests = {},
        } :: AssetResolverState,
        assetResolver
    ) :: any
    return self
end

function assetResolver.resolve(resolver: AssetResolver, value: unknown): ResolvedAsset?
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "string" then
        return nil
    end

    if string.sub(value, 1, 11) == "rbxasset://" or string.sub(value, 1, 11) == "rbxthumb://" then
        return value
    end

    local id = tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    if id then
        return id
    end

    return nil
end

local function isSuccessResponse(response: unknown): boolean
    if type(response) ~= "table" then
        return false
    end
    local responsePayload = response :: { Body: unknown, StatusCode: unknown, Success: unknown }
    local body = responsePayload.Body
    if type(body) ~= "string" or #body == 0 then
        return false
    end
    if type(responsePayload.StatusCode) == "number" then
        local statusCode = responsePayload.StatusCode :: number
        return statusCode >= 200 and statusCode < 300
    end
    if type(responsePayload.Success) == "boolean" then
        return responsePayload.Success :: boolean
    end
        return false
end

function assetResolver.getAssetContentFromUrl(
    self: AssetResolver,
    url: string,
    cacheKey: CacheKey?,
    forced: boolean?
): string?
        local cache = self.contentCache
    if cacheKey ~= nil and cache and not forced then
        local cachedContent = cache[cacheKey]
        if cachedContent then
            return cachedContent
        end
    end

            local pending = self.pendingRequests
    if cacheKey ~= nil then
        local waiters = pending[cacheKey]
        if waiters then
            if not coroutine.isyieldable() then
                return nil
            end
            local caller = coroutine.running()
            if not caller then
                return nil
            end
            table.insert(waiters, caller)
            return coroutine.yield()
        end
        pending[cacheKey] = {}
    end

    local content: string? = nil
    local requestFn = networkUtil.getRequestFn()
    if not requestFn then
        logger.warn("No request function available to download asset content.")
    else
        local requestOk, requestResult = pcall(
            requestFn,
            {
                Url = url,
                Method = "GET",
            } :: AssetRequestPayload
        )
        if requestOk and isSuccessResponse(requestResult) then
            local responseBody = (requestResult :: { Body: string }).Body
            content = responseBody
            if cacheKey ~= nil and cache then
                local order = self.contentCacheOrder
                if order and cache[cacheKey] == nil then
                    table.insert(order, cacheKey)
                    local evictedKey = if #order > maxCacheEntries then table.remove(order, 1) else nil
                    if evictedKey ~= nil then
                        cache[evictedKey] = nil
                    end
                end
                cache[cacheKey] = responseBody
            end
        elseif not forced then
            logger.warn("Failed to download asset content for url: " .. tostring(url))
        end
    end

            if cacheKey ~= nil then
        local queued = pending[cacheKey]
        pending[cacheKey] = nil
        if queued then
            for _, waiter in queued do
                pcall(coroutine.resume, waiter, content)
            end
        end
    end
    return content
end

function assetResolver.getAssetContentFromId(self: AssetResolver, id: AssetId, forcedRefresh: boolean?): string?
    local resolvedId = self:resolve(id)
        if not resolvedId or type(resolvedId) ~= "number" then
        logger.warn("Invalid asset id: " .. tostring(resolvedId))
        return nil
    end

    local assetUrl = string.format(self.contentDownloadUrl, resolvedId)
    return self:getAssetContentFromUrl(assetUrl, resolvedId, forcedRefresh)
end

return assetResolver
