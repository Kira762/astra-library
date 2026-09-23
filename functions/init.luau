
local textMetrics = require(script.textMetrics)
local colors = require(script.colors)
local flagNames = require(script.flagNames)

local functions = {}

functions.textWidth = textMetrics.textWidth
functions.textHeight = textMetrics.textHeight
functions.deriveFlagFromName = flagNames.deriveFlagFromName
functions.contrastColor = colors.contrastColor
functions.toColorSequence = colors.toColorSequence
functions.contrastText = colors.contrastText

return functions
