
local functions = {}

local colors = require(script.Parent.Parent.functions.textMetrics)
local textMetrics = require(script.Parent.Parent.functions.colors)
local flagNames = require(script.Parent.Parent.functions.flagNames)

functions.textWidth = colors.textWidth
functions.textHeight = colors.textHeight
functions.deriveFlagFromName = flagNames.deriveFlagFromName
functions.contrastColor = textMetrics.contrastColor
functions.toColorSequence = textMetrics.toColorSequence
functions.contrastText = textMetrics.contrastText

return functions
