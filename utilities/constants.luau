local iconRegistry = require(script.Parent.Parent.images.windowIcons)
local uiIcons = require(script.Parent.Parent.images.uiIcons)
local constants = {}

constants.fontAsset = "rbxassetid://12187375716"

constants.icons = iconRegistry.ids
constants.uiIcons = uiIcons

constants.accent = {
    on = Color3.fromRGB(23, 153, 110),
    onStroke = Color3.fromRGB(32, 201, 144),
}

constants.statAccents = {
    positive = {
        fill = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
        stroke = ColorSequence.new(Color3.fromRGB(0, 213, 156), Color3.fromRGB(0, 189, 135)),
    },
    negative = {
        fill = ColorSequence.new(Color3.fromRGB(172, 47, 47), Color3.fromRGB(135, 37, 37)),
        stroke = ColorSequence.new(Color3.fromRGB(255, 75, 75), Color3.fromRGB(244, 67, 67)),
    },
    neutral = {
        fill = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
        stroke = ColorSequence.new(Color3.fromRGB(0, 213, 156), Color3.fromRGB(0, 189, 135)),
    },
}

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
