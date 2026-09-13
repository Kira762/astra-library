-- [[The in-card description line. An element with a `description` prop grows
-- [[its own card by the measured height of this line instead of spawning a
-- [[standalone row beneath the card: the same recipe the Collapsible Group
-- [[header uses (a muted 14px ContentColor line under the title, card 41 ->
-- [[61 for one line), measured with the shared text metrics so wrapped host
-- [[copy gets the room it needs, and re-measured whenever the card's width
-- [[changes (layout mode, window resize, the search page). Controls keep
-- [[centring in the base region the card had before it grew, so the title
-- [[line never drifts down into the description. The label doubles as the
-- [[lock-message surface (Window:_setLocked) exactly as the old standalone
-- [[descriptor did, and it is revealed with the element by _revealCommon.]]
local description = {}

local insetX = 20
local lineSize = 14
local lineHeight = 17
local bottomPad = 3
local topGap = 4

local functions = require(script.Parent.Parent.functions)
local locale = require(script.Parent.Parent.utilities.locale)

-- [[RichText hosts: measure the words, not the markup.]]
local function plain(text: string): string
	return (text:gsub("<[^>]+>", ""))
end

local function lineCount(self): number
	local width = self.main.AbsoluteSize.X - insetX * 2
	if width <= 0 then
		-- [[Pre-layout guess; the width watcher below re-measures once the
		-- [[card has a real width.]]
		width = 260
	end
	local font = self.window.theme.Font
	local count = 1
	local current = 0
	for word in plain(tostring(self.descriptionLabel.Text)):gmatch("%S+") do
		local piece = if current == 0 then word else " " .. word
		local grown = current + functions.textWidth(font, lineSize, piece)
		if current > 0 and grown > width then
			count += 1
			current = functions.textWidth(font, lineSize, word)
		else
			current = grown
		end
	end
	return count
end

-- [[Card heights everywhere go through here: writers state their base and
-- [[the description's measured extra rides along, so hover tweens, layout
-- [[switches and the dropdown's open height all keep the line's room.]]
function description.height(self, base: number): number
	return base + (self._descriptionExtra or 0)
end

-- [[Y placement for the rows and controls that centre in the card: with a
-- [[description they centre in the base region, not the grown card.]]
function description.center(self, base: number): (number, number)
	if self.descriptionLabel then
		return 0, base / 2
	end
	return 0.5, 0
end

local function apply(self, count: number)
	self._descriptionLines = count
	local extra = count * lineHeight + bottomPad
	local delta = extra - (self._descriptionExtra or 0)
	self._descriptionExtra = extra
	self.descriptionLabel.Size = UDim2.new(1, -insetX * 2, 0, count * lineHeight)
	local size = self.main.Size
	self.main.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + delta)
end

-- [[Call straight after the element's main frame exists (before its centred
-- [[children are built, so `center` already answers for the grown card).]]
function description.attach(self)
	if self.descriptionLabel or not self.description or self.description == "" then
		return
	end

	self._baseHeight = self.main.Size.Y.Offset
	self._descriptionExtra = 0

	self.descriptionLabel = self.window:Create("TextLabel", {
		Name = "Description",
		Text = locale.t(self.description),
		Position = UDim2.fromOffset(insetX, self._baseHeight - topGap),
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
		local count = lineCount(self)
		if count ~= self._descriptionLines then
			apply(self, count)
		end
	end)

	-- [[The label's text is locale-bound (SetLocale retypes it) and the lock
	-- [[message swaps through it; either can rewrap, so the card re-measures
	-- [[whenever the text changes.]]
	self.window:ConnectFor(self, self.descriptionLabel:GetPropertyChangedSignal("Text"), function()
		local count = lineCount(self)
		if count ~= self._descriptionLines then
			apply(self, count)
		end
	end)
end

return description
