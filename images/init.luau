--[[
Remote image pipeline — the folder module.

`images` is where a value becomes something Roblox can load: `assign` writes
an image property through the cache layer, `preload` warms the window's own
art, `avatar` builds a headshot URI. It has nothing to do with Astra's
built-in glyphs — those live in `windowIcons/`.
]]

local image = require(script.image)

local images = {
    resolve = image.resolve,
    assign = image.assign,
    preload = image.preload,
    avatar = image.avatar,
    rewrites = image.rewrites,
}

return images
