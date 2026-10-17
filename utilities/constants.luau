--[[
Mova's own glyphs (close, minimise, settings, ...). Not the icon-pack
catalog — that is `icons/`, and a host never resolves these by name.
]]
local windowIcons = require(script.Parent.Parent.windowIcons)
local constants = {}

--[[
Font selection. `default` renders every text surface with the stock
fallback font — the original Roblox look (state.fallbackFont,
Enum.Font.BuilderSans) — while `brand` uses the custom family below
(Finger Paint, rbxassetid://12187375716). This value is only the
initial choice: the live selection is the persisted `fontChoice`
window setting (Settings → Appearance → Font), switchable mid-session.
]]
constants.defaultFontChoice = "default" -- "default" | "brand"
constants.fontAsset = "rbxassetid://12187375716"

constants.icons = windowIcons.ids
constants.uiIcons = windowIcons.names

constants.zIndex = {
    elementLock = 60,
    elementLockContent = 65,
    bottomFade = 100,
    tabFade = 2,
    notification = 1500,
    drag = 100003,
    restoreContent = 100001,
    restoreInteract = 100002,
}

constants.displayOrder = {
    window = 99999,

    popup = 100001,
}

return constants
