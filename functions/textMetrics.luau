local state = require(script.Parent.Parent.core.state)
local textService = state.textService

local textMetrics = {}

local widthCache: { [string]: number } = {}
local widthCount = 0
local widthMax = 1024
local heightCache: { [string]: number } = {}
local heightCount = 0
local heightMax = 1024

local function createParams(text: string, font: Font, size: number, width: number): GetTextBoundsParams
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = width
	return params
end

local function measureAsync(params: GetTextBoundsParams): unknown
    local ok, result = pcall(function()
        return textService:GetTextBoundsAsync(params)
    end)
    return if ok then result else nil
end

local function extractAxis(result: unknown, axis: "X" | "Y"): number?
    if typeof(result) == "Vector2" then
        return if axis == "X" then result.X else result.Y
    end
    if type(result) == "table" and type((result :: any)[axis]) == "number" then
        return (result :: any)[axis]
    end
    return nil
end

function textMetrics.textWidth(font: Font, size: number, text: any): number
    text = tostring(text)
    local cacheKey = tostring(font.Family)
        .. "|"
        .. tostring(font.Weight)
        .. "|"
        .. tostring(font.Style)
        .. "|"
        .. tostring(size)
        .. "|"
        .. text
    local cached = widthCache[cacheKey]
    if cached then
        return cached
    end

    local width = extractAxis(measureAsync(createParams(text, font, size, math.huge)), "X")
    if not width then
        local charCount = utf8.len(text) or #text
        return math.ceil(size * 0.55 * charCount)
    end

    local ceiled = math.ceil(width)
    if widthCount >= widthMax then
        widthCache = {}
        widthCount = 0
    end
    widthCache[cacheKey] = ceiled
    widthCount += 1
    return ceiled
end

function textMetrics.textHeight(font: Font, size: number, text: any, maxWidth: number): number
    text = tostring(text)
    local cacheKey = tostring(font.Family)
        .. "|"
        .. tostring(font.Weight)
        .. "|"
        .. tostring(font.Style)
        .. "|"
        .. tostring(size)
        .. "|"
        .. tostring(maxWidth)
        .. "|"
        .. text
    local cached = heightCache[cacheKey]
    if cached then
        return cached
    end

    local height = extractAxis(measureAsync(createParams(text, font, size, maxWidth)), "Y")
    if not height then
        return size
    end

    local ceiled = math.ceil(height)
    if heightCount >= heightMax then
        heightCache = {}
        heightCount = 0
    end
    heightCache[cacheKey] = ceiled
    heightCount += 1
    return ceiled
end

return textMetrics
