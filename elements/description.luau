--[[
The in-card description line. An element created with a `description` prop
grows its own card by the measured height of this line instead of spawning
a standalone row beneath the card, so the description can never sit on top
of the element's own UI and nothing renders below the card:

  * the line is a muted 14px `ContentColor` label,
  * the card grows by the measured, wrapped line count, so a host copy
    that wraps reserves exactly the room it renders in — the element's
    bottom-anchored rows ride up by `_descriptionExtra`,
  * the line stays locale-bound (`Window:SetLocale` retypes it and the card
    re-measures) and doubles as the lock-message surface
    (`Window:_setElementLocked` swaps its text, restoring the description
    on unlock) exactly as the old below-card descriptor row did.

The Stat is the element that attaches the line; the Collapsible Group
header carries its own variant of the recipe inline. Call `attach`
straight after the element's main frame is stroked and before its
children are built.
]]
local description = {}

local insetX = 20
local lineSize = 14
local lineHeight = 17
local bottomPad = 3
local topGap = 4
local fallbackWidth = 260
--[[
The engine's wrapped height lands a hair under a whole number of lines
(17.0 per line at this size), so the count rounds down over the slack and
up over everything else.
]]
local wrapSlack = 0.05

local functions = require(script.Parent.Parent.functions)
local locale = require(script.Parent.Parent.utilities.locale)

-- RichText hosts: measure the words, not the markup.
local function plain(text: string): string
    return (text:gsub("<[^>]+>", ""))
end

--[[
Fallback wrap count, for hosts whose text metrics cannot answer
(`functions.textHeight` returns the raw point size there): greedy
word-by-word, using the shared width metrics.
]]
local function greedyLines(text: string, width: number, font: Font): number
    local count = 1
    local current = 0
    for word in text:gmatch("%S+") do
        local wordWidth = functions.textWidth(font, lineSize, word)
        local grown = if current == 0 then wordWidth else current + functions.textWidth(font, lineSize, " " .. word)
        if current > 0 and grown > width then
            count += 1
            current = wordWidth
        else
            current = grown
        end
    end
    return count
end

local function availableWidth(self): number
    local width = self.main.AbsoluteSize.X - insetX * 2
    --[[
    Pre-layout guess; the width watcher below re-measures once the card
    has a real width.
    ]]
    return if width > 0 then width else fallbackWidth
end

local function lineCount(self): number
    local text = plain(tostring(self.descriptionLabel.Text))
    if text == "" then
        return 1
    end
    local width = availableWidth(self)
    local font = self.window.theme.Font
    local measured = functions.textHeight(font, lineSize, text, width)
    --[[
    The engine's own wrap when it answers (the popup, notification and
    toast reserve their room the same way); the hand count covers hosts
    with no text metrics, where the measurer reports the raw point size.
    ]]
    local counted = if measured > lineSize
        then math.ceil(measured / lineHeight - wrapSlack)
        else greedyLines(text, width, font)
    return math.max(1, counted)
end

--[[
Card heights ride `_descriptionExtra`: an element's bottom-anchored rows
subtract it from their Y so nothing drifts down into the line.
]]
local function apply(self, count: number)
    self._descriptionLines = count
    local extra = count * lineHeight + bottomPad
    local delta = extra - (self._descriptionExtra or 0)
    self._descriptionExtra = extra
    self.descriptionLabel.Size = UDim2.new(1, -insetX * 2, 0, count * lineHeight)
    local size = self.main.Size
    self.main.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + delta)
end

--[[
Re-measure after a rewrap: the card's width changed (layout mode, window
resize, the search page) or the text did (a locale switch, the lock
message).
]]
local function rewrap(self)
    local count = lineCount(self)
    if count ~= self._descriptionLines then
        apply(self, count)
    end
end

function description.attach(self)
    if self.descriptionLabel or not self.description or self.description == "" then
        return
    end

    local base = self.main.Size.Y.Offset
    self._descriptionExtra = 0

    self.descriptionLabel = self.window:Create("TextLabel", {
        Name = "Description",
        Text = locale.t(self.description),
        Position = UDim2.fromOffset(insetX, base - topGap),
        Size = UDim2.new(1, -insetX * 2, 0, lineHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        TextSize = lineSize,
        TextWrapped = true,
        RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    apply(self, lineCount(self))

    self.window:ConnectFor(self, self.main:GetPropertyChangedSignal("AbsoluteSize"), function()
        rewrap(self)
    end)
    self.window:ConnectFor(self, self.descriptionLabel:GetPropertyChangedSignal("Text"), function()
        rewrap(self)
    end)
end

return description
