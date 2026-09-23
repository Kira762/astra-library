local fontManager = require(script.Parent.services)
local a2 = fontManager.getService("HttpService")
local a3 = fontManager.getService("RunService")
local a4 = require(script.Parent.filesystem)
local a5 = require(script.Parent.assetResolver)
local a6 = require(script.Parent.log)
local a7 = require(script.Parent.path)

local function a8(a9: unknown): string?
    local a10, a11 = pcall(function()
        return a2:JSONEncode(a9)
    end)
    if a10 and type(a11) == "string" then
        return a11
    else
        a6.warn("Failed to encode JSON:", a11)
        return nil
    end
end

local function a12(a13: string): unknown?
    local a14, a15 = pcall(function()
        return a2:JSONDecode(a13)
    end)
    if a14 then
        return a15
    else
        a6.warn("Failed to decode JSON:", a15)
        return nil
    end
end

local a16 = {}
a16.__type = "fontManager"

export type FontFace = {
    name: string,
    family: string,
    weight: number,
    style: string,
    assetId: string,
}

export type FontManifest = {
    name: string,
    faces: { FontFace },
}

export type CachedFont = {
    customId: number | string,
    manifest: FontManifest,
    loadedFromDisk: boolean,
    variants: { [string]: Font },
}

export type FontCache = { [number]: CachedFont }

export type FontResolverOptions = {
    fallbackFont: Font?,
    saveToDisk: boolean?,
    skipCache: boolean?,
}

type FontManagerState = {
    _debug: boolean,
    _pendingLoads: { [string]: { thread } },
    rootFolder: string,
    assetResolver: assetResolver.AssetResolver,
    defaultOptions: FontResolverOptions,
    fontCache: FontCache?,
}

export type FontManager = FontManagerState & {
    resolve: (self: FontManager, id: number | string) -> Font?,
    loadFont: (
        self: FontManager,
        id: (number | string)?,
        fontWeight: Enum.FontWeight?,
        fontStyle: Enum.FontStyle?,
        saveToDisk: boolean?,
        skipCache: boolean?
    ) -> Font?,
    getFontFromId: (self: FontManager, id: number | string) -> Font?,
}

export type fontManager = FontManager

local function a17(a18: unknown): FontManifest?
    local a19 = a18 :: any
    if type(a19) ~= "table" or type(a19.name) ~= "string" or type(a19.faces) ~= "table" then
        return nil
    end
    a19.name = a7.sanitizeFile(a19.name)
    if #a19.name == 0 or #a19.faces == 0 then
        return nil
    end
    for _, a20 in a19.faces do
        if type(a20) ~= "table" or type(a20.name) ~= "string" or type(a20.assetId) ~= "string" then
            return nil
        end
        a20.name = a7.sanitizeFile(a20.name)
        if #a20.name == 0 then
            return nil
        end
    end
    return a19 :: FontManifest
end

local a21 = { "\0\1\0\0", "OTTO", "true", "ttcf", "wOFF", "wOF2" }

local function a22(a23: string): boolean
    for _, a24 in a21 do
        if string.sub(a23, 1, #a24) == a24 then
            return true
        end
    end
    return false
end

local a25 = getfenv()

local function a26(a27: Enum.FontWeight, a28: Enum.FontStyle): string
    return tostring(a27) .. "|" .. tostring(a28)
end

local function a29(id: unknown): number?
    if type(id) == "number" then
        return id
    end

    if type(id) == "string" then
        return tonumber(id)
    end

    return nil
end

function a16.__index(self: FontManagerState, a30: unknown): unknown
    local a31 = (a16 :: any)[a30]
    if a31 ~= nil then
        return a31
    end

    local a32 = a29(a30)
    if not a32 then
        return nil
    end

    local a33 = self.fontCache
    if a33 then
        local a34 = a33[a32]
        if a34 then
            local a35 = a26(Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            local a36 = a34.variants and a34.variants[a35]
            if a36 then
                return a36
            end

            for _, a37 in pairs(a34.variants or {}) do
                return a37
            end
        end
    end

    return nil
end

function a16.new(
    a38: string,
    a39: boolean?,
    a40: boolean?,
    a41: assetResolver.AssetDownloadUrl?,
    a42: FontResolverOptions?
): FontManager
    local a43 = a42
        or {
            saveToDisk = true,
            skipCache = not a40 or false,
            fallbackFont = Font.fromEnum(Enum.Font.SourceSans),
        }
    local self = setmetatable(
        {
            rootFolder = a38,
            fontCache = if a40 then {} :: FontCache else nil,
            assetResolver = a5.new(a40, a41),
            defaultOptions = a43,
            _debug = a39 or a3:IsStudio() or false,
            _pendingLoads = {},
        } :: FontManagerState,
        a16
    ) :: any
        pcall(a4.ensureFolder, a38)
    return self
end

local function a44(
    self: FontManager,
    a45: number,
    a46: Enum.FontWeight,
    a47: Enum.FontStyle,
    a48: string
): Font?
    local a49 = self.rootFolder .. "/" .. a45 .. ".json"
        if typeof(a4.isfile) ~= "function" then
        return self.defaultOptions.fallbackFont
    end
    local a50: string? = nil
    local a51 = false
    if a3:IsStudio() and self._debug then
        a6.warn("Font manifest loading is not supported in Studio. Using default font manifest for testing.")
        a50 =
            '{"name":"Inter","faces":[{"name":"Thin","weight":100,"style":"normal","assetId":"rbxassetid://12187277209"},{"name":"Extra Light","weight":200,"style":"normal","assetId":"rbxassetid://12187293441"},{"name":"Light","weight":300,"style":"normal","assetId":"rbxassetid://12187268450"},{"name":"Regular","weight":400,"style":"normal","assetId":"rbxassetid://12187266066"},{"name":"Medium","weight":500,"style":"normal","assetId":"rbxassetid://12187336822"},{"name":"Semi Bold","weight":600,"style":"normal","assetId":"rbxassetid://12187254443"},{"name":"Bold","weight":700,"style":"normal","assetId":"rbxassetid://12187275575"},{"name":"Extra Bold","weight":800,"style":"normal","assetId":"rbxassetid://12187267750"},{"name":"Black","weight":900,"style":"normal","assetId":"rbxassetid://12187359223"}]}'
    elseif a4.isfile(a49) then
        local ok, a52 = pcall(a4.readfile, a49)
        a50 = ok and a52 or nil
    else
                a50 = self.assetResolver:getAssetContentFromId(a45, false)
        a51 = a50 ~= nil
    end
    local a53: FontManifest? = nil
    if a50 then
        local ok, a54 = pcall(a12, a50)
        if ok and a54 then
            a53 = a17(a54)
        else
            if self._debug then
                a6.warn(
                    "Failed to parse font manifest for font id: "
                        .. tostring(a45)
                        .. ". Error: "
                        .. tostring(a54)
                )
            end
        end
    else
        return self.defaultOptions.fallbackFont
    end
    if not a53 then
        if self._debug then
            a6.warn("Font manifest is nil for font id: " .. tostring(a45))
        end
                pcall(a4.delfile, a49)
        return self.defaultOptions.fallbackFont
    end
    if a51 and a50 then
        pcall(a4.writefile, a49, a50)
    end
    local a55 = self.rootFolder .. "/" .. a53.name
    local a56 = true
        if not pcall(a4.ensureFolder, a55) then
        return self.defaultOptions.fallbackFont
    end

            for i, a57 in ipairs(a53.faces) do
        local a58 = a55 .. "/" .. a57.name:gsub(" ", "-") .. ".ttf"
                        if a4.isfile(a58) then
            local a59, a60 = pcall(a4.readfile, a58)
            if not a59 or type(a60) ~= "string" or not a22(a60) then
                pcall(a4.delfile, a58)
            end
        end
        if not a4.isfile(a58) then
            local a61 = self.assetResolver:resolve(a57.assetId)
            local a62 = if a61 ~= nil
                then self.assetResolver:getAssetContentFromId(a61, false)
                else nil
            if not a62 or not a22(a62) then
                a56 = false
                if self._debug then
                    a6.warn(
                        "Font face content is missing or not a font for font id: "
                            .. tostring(a45)
                            .. ", face: "
                            .. a57.name
                    )
                end
                continue
            end
            pcall(a4.writefile, a58, a62)
        end
        local ok, a63 = pcall(a25.getcustomasset, a58)
        if ok and type(a63) == "string" then
            a53.faces[i].assetId = a63
            if self._debug then
                a6.print("Loaded font face for id: " .. tostring(a45) .. ", face: " .. a57.name)
            end
        else
            a56 = false
            if self._debug then
                a6.warn("Failed to load font face for id: " .. tostring(a45) .. ", face: " .. a57.name)
            end
        end
    end
            if not a56 then
        return self.defaultOptions.fallbackFont
    end

    local a64 = a8(a53)
    if not a64 or not pcall(a4.writefile, a55 .. "/manifest.json", a64) then
        return self.defaultOptions.fallbackFont
    end
    local a65, a66 = pcall(a25.getcustomasset, a55 .. "/manifest.json")
    if not a65 or not a66 then
        if self._debug then
            a6.warn("Failed to load font manifest for id: " .. tostring(a45))
        end
        return self.defaultOptions.fallbackFont
    end
        local ok, a67 = pcall(Font.new, a66 :: any, a46, a47)
    if not ok or not a67 then
        if self._debug then
            a6.warn("Failed to load font for id: " .. tostring(a45))
        end
        return self.defaultOptions.fallbackFont
    end

        local a68 = self.fontCache
    if a68 then
        a68[a45] = {
            customId = a66,
            manifest = a53,
            loadedFromDisk = true,
            variants = {
                [a48] = a67,
            },
        }
        if self._debug then
            a6.print("Cached font for id: " .. tostring(a45))
        end
    end
    return a67
end

function a16.loadFont(
    self: FontManager,
    id: (number | string)?,
    a69: Enum.FontWeight?,
    a70: Enum.FontStyle?,
    a71: boolean?,
    a72: boolean?
): Font?
    if a71 == nil then
        a71 = self.defaultOptions.saveToDisk
    end
    if a72 == nil then
        a72 = self.defaultOptions.skipCache
    end
    local a73 = a69 or Enum.FontWeight.Regular
    local a74 = a70 or Enum.FontStyle.Normal
    local a75 = a26(a73, a74)
    local a76 = self.assetResolver:resolve(id)
    local a77 = a29(a76)
    if not a77 then
        a6.warn("Invalid font id: " .. tostring(id))
        return self.defaultOptions.fallbackFont
    end
        local a78 = self.fontCache
    if a78 and not a72 then
        local a79 = a78[a77]
        if a79 then
            local a80 = a79.variants and a79.variants[a75]
            if a80 then
                if self._debug then
                    a6.print("Loaded font from cache for id: " .. tostring(a77))
                end
                return a80
            end

            local ok, a81 = pcall(Font.new, a79.customId :: any, a73, a74)
            if ok and a81 then
                a79.variants = a79.variants or {}
                a79.variants[a75] = a81
                if self._debug then
                    a6.print("Loaded font variant from cache for id: " .. tostring(a77))
                end
                return a81
            else
                if self._debug then
                    a6.warn("Failed to load font from cache for id: " .. tostring(a77))
                end
                a78[a77] = nil
                return self.defaultOptions.fallbackFont
            end
        end
    end

        if not a71 then
        if self._debug then
            a6.warn("Font loading without saving to disk can be detected by Anti-cheats.")
        end

        return self.defaultOptions.fallbackFont
    end

        local a82 = self._pendingLoads
    local a83 = tostring(a77) .. "|" .. a75
    local a84 = a82[a83]
    if a84 then
        if not coroutine.isyieldable() then
            return self.defaultOptions.fallbackFont
        end
        local a85 = coroutine.running()
        if not a85 then
            return self.defaultOptions.fallbackFont
        end
        table.insert(a84, a85)
        return coroutine.yield()
    end
    a82[a83] = {}

    local ok, a86 = pcall(a44, self, a77, a73, a74, a75)
    local a87 = if ok then a86 else self.defaultOptions.fallbackFont

                a84 = a82[a83]
    a82[a83] = nil
    if a84 then
        for _, a88 in a84 do
            pcall(coroutine.resume, a88, a87)
        end
    end
    return a87
end

function a16.resolve(self: FontManager, id: number | string): Font?
    local a89 = a29(id)
    if not a89 then
        return nil
    end

    local a90 = self.fontCache
    if a90 then
        local a91 = a90[a89]
        if a91 then
            if self._debug then
                a6.print("Resolved font for id: " .. tostring(a89))
            end
            for _, a92 in pairs(a91.variants or {}) do
                return a92
            end
        end
    end

    return nil
end

function a16.getFontFromId(self: FontManager, id: number | string): Font?
    return self:resolve(id)
end

return a16
