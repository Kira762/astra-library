--[[
Theme resolution engine (themes/init.luau).

Extracted verbatim from components/window.luau so the window no longer owns
theme logic. Responsibilities: named-theme lookup against the themes folder,
value coercion (Color3 -> ColorSequence for gradient keys), stroke
derivation for user-supplied theme tables, and brand-font fallbacks.
The only built-in palette is `default`; unknown names warn and fall back
to it. Custom theme tables overlay the default key set.
]]

--[[
This file IS the `themes` ModuleScript (init.luau semantics): the
`default` theme module is a child of `script`, and other folders
(core, utilities) are siblings reachable through script.Parent.
]]
local themesFolder = script
local variables = require(script.Parent.core.state)
local log = require(script.Parent.utilities.log)

local themes = {}

local gradientKeys = {
    WindowColor = true,
    ElementGradient = true,
    ElementStrokeGradient = true,
    TabBackground = true,
    TabStroke = true,
    SliderProgress = true,
}

function themes.coerceValue(key, value)
    if gradientKeys[key] and typeof(value) == "Color3" then
        return ColorSequence.new(value)
    end
    return value
end

function themes.firstColor(value)
    return if typeof(value) == "ColorSequence" then value.Keypoints[1].Value else value
end

local function edgeShade(color, amount)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    local target = if luminance > 0.5 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
    return color:Lerp(target, amount)
end

--[[
Stroke derivation for user-supplied theme tables. Exposed so ChangeTheme
can re-derive derived stroke colors after merging user overrides.
]]
function themes.deriveStrokes(resolved, overrides)
    if overrides.ElementGradient then
        local fill = themes.firstColor(resolved.ElementGradient)
        if overrides.ElementStroke == nil then
            resolved.ElementStroke = edgeShade(fill, 0.28)
        end
        if overrides.ElementStrokeGradient == nil then
            resolved.ElementStrokeGradient = ColorSequence.new(edgeShade(fill, 0.4))
        end
        if overrides.ElementStrokeHover == nil then
            resolved.ElementStrokeHover = edgeShade(fill, 0.52)
        end
    end
    if overrides.TabBackground and overrides.TabStroke == nil then
        resolved.TabStroke = ColorSequence.new(edgeShade(themes.firstColor(resolved.TabBackground), 0.4))
    end
end

local function themeOverrides(value)
    if typeof(value) == "table" then
        return value
    elseif typeof(value) == "string" then
        local named = themesFolder:FindFirstChild(string.lower(value))
        if named then
            return require(named)
        end
        log.warn("Astra: unknown theme '" .. value .. "', using default")
    elseif value ~= nil then
        log.warn("Astra: invalid theme (expected a built-in name or a theme table), using default")
    end
    return require(themesFolder["default"])
end

--[[
Resolve a theme value (nil, built-in name, or theme table) to a full theme
table. Public API: window code calls themes.resolve(value).
]]
function themes.resolve(value)
    local resolved = table.clone(require(themesFolder["default"]))
    local overrides = themeOverrides(value)
	for key, override in overrides do
		resolved[key] = themes.coerceValue(key, override)
	end
	if typeof(value) == "table" then
		themes.deriveStrokes(resolved, overrides)
	end

	local userTable = if typeof(value) == "table" then value else nil
    if not (userTable and (userTable.Font or userTable.font)) then
        resolved.Font = variables.brandFont(Enum.FontWeight.Medium)
    end
    if not (userTable and (userTable.TitleFont or userTable.titleFont)) then
        resolved.TitleFont = variables.brandFont(Enum.FontWeight.SemiBold)
    end

    return resolved
end

return themes
