local imageCache = require(script.Parent.Parent.cache.imageCache)
local variables = require(script.Parent.Parent.core.state)

type AvatarCallback = imageCache.AvatarCallback
type PreloadCallback = imageCache.PreloadCallback

local image = {}

image.rewrites = imageCache.rewrites
image.onBlock = nil :: ((unknown) -> ())?

type PendingProperties = { [string]: boolean }

image.pending = {} :: { [number]: { [Instance]: PendingProperties } }

local settled = false

local imageProperties: { [string]: boolean } = {
    Image = true,
    HoverImage = true,
    PressedImage = true,
}

local function idOf(value: unknown): number?
    if type(value) == "number" then
        return value
    elseif type(value) == "string" then
        return tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    end
    return nil
end

local function blocked(value: unknown): string
    if image.onBlock then
        image.onBlock(value)
    end
    return ""
end

function image.preload(onSettled: PreloadCallback?): (boolean, number)
    settled = false
    return imageCache.preload(function(failed, failedRoles)
        settled = true
        table.clear(image.pending)
        if onSettled then
            onSettled(failed, failedRoles)
        end
    end)
end

function image.avatar(userId: number, onReady: AvatarCallback?): string
    local uri = `rbxthumb://type=AvatarHeadShot&id={userId}&w=48&h=48`
    if not variables.secureMode then
        --[[
        The URI is immediately usable; still deliver the callback so
        callers that only render on it do not stay blank.
        ]]
        if onReady then
            task.defer(onReady, uri)
        end
        return uri
    end

    return imageCache.avatar(userId, onReady)
end

function image.assign(instance: Instance, property: string, value: unknown)
    local target = instance :: any
    if not imageProperties[property] then
        target[property] = value
        return
    end

    local isRemoteUrl = type(value) == "string" and string.match(value, "^https?://") ~= nil
    if isRemoteUrl then
        target[property] = imageCache.remote(value :: string, function(uri)
            if instance.Parent then
                target[property] = uri or ""
            end
        end)
    else
        target[property] = image.resolve(value)
    end
    if variables.secureMode and not settled then
        local id = idOf(value)
        if id and not image.rewrites[id] then
            local waiting = image.pending[id]
            if not waiting then
                waiting = setmetatable({}, { __mode = "k" }) :: any
                image.pending[id] = waiting
            end
            local properties = waiting[instance]
            if not properties then
                properties = {}
                waiting[instance] = properties
            end
            properties[property] = true
        end
    end
end

imageCache.onCached = function(id: number)
    local waiting = image.pending[id]
    if not waiting then
        return
    end
    local uri = image.rewrites[id]
    if uri then
        for instance, properties in waiting do
            if instance.Parent then
                local target = instance :: any
                for property in properties do
                    target[property] = uri
                end
            end
        end
    end
    image.pending[id] = nil
end

function image.resolve(value: unknown): string
    if value == nil or value == 0 or value == "" then
        return ""
    end

    if type(value) == "string" then
        if string.match(value, "^https?://") then
            return imageCache.remote(value)
        end
        if string.sub(value, 1, 11) == "rbxasset://" then
            return value
        end
        if string.sub(value, 1, 11) == "rbxthumb://" then
            return if variables.secureMode then blocked(value) else value
        end
    end

    local id: number? = nil
    if type(value) == "number" then
        id = value
    elseif type(value) == "string" then
        id = tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    end

    local rewrite = if id then image.rewrites[id] else nil
    if rewrite then
        return rewrite
    end

    if variables.secureMode then
        return blocked(value)
    end

    if type(value) == "number" then
        return "rbxassetid://" .. value
    end
    if type(value) == "string" then
        return value
    end

    return blocked(value)
end

return image
