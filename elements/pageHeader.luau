--[[
CreatePageHeader: the flat header a page opens with — a title, an optional
muted metadata line and an optional prose paragraph.

It is deliberately not a card. The surface rule is one surface per view: the
page already sits on the elements band, so the header adds no fill, no stroke
and no padding box of its own — sections below it separate with whitespace or
a hairline (see `CreateDivider`) rather than with another nested box.
Everything here is text:

  * title — the page's single heading, tokens.text.pageTitle at the strong
            weight, the only 20px line on the page,
  * meta  — one muted caption line (tokens.text.caption at tokens.alpha.meta).
            A table is joined with " · ", so a host can hand over
            `{ "1.4.0", "13 tabs", "Astra Team" }` and get the single quiet
            line the old stat tiles spelled out as three boxes,
  * body  — an optional paragraph at tokens.text.body, wrapped at
            tokens.measure.prose (about 65 characters), so the reading column
            stops widening when the window does.

There is no icon slot and no setter for one: the window header already carries
the brand, and repeating it on the page is the duplication this element exists
to remove. Title, meta and body are all live (`SetTitle`, `SetMeta`,
`SetBody`) and locale-bound like every other line in the library.
]]

local state = {}
state.__index = state
state.__type = "PageHeader"

local utilities = script.Parent.Parent.utilities

local locale = require(utilities.locale)
local moveable = require(utilities.moveable)
local tokens = require(utilities.tokens)

--[[
Page inset: the same `1, -20` width recipe every element keeps, so the
header's title starts on the same left edge as the cards below it even though
the header itself has no card to sit in.
]]
local pageInset = tokens.pageInset

--[[
Line spacing, on the grid's small steps. The list runs on a half step (4) so
the title and its metadata line read as one block; the paragraph rides its own
block whose 8px top padding the list's 4 completes to a full 12 — one clear
step between the metadata line and the prose, and the same 12 the library uses
between any two sections that are separated by whitespace instead of a rule.
]]
local lineGap = tokens.space.half
local paragraphPad = tokens.space.sm

local function read(properties, lower, upper)
    local value = properties[lower]
    if value == nil then
        value = properties[upper]
    end
    return value
end

local function textOrNil(value)
    if value == nil then
        return nil
    end
    local text = tostring(value)
    if text == "" then
        return nil
    end
    return text
end

--[[
The metadata line. A string is used as given; an array is joined with the
middot the old three-tile row implied. Nil — or an array with nothing in it —
means the page has no metadata, and the line drops out of the layout entirely
instead of leaving an empty band behind.
]]
local function metaText(value)
    if type(value) == "table" then
        local parts = {}
        for _, part in ipairs(value) do
            local text = textOrNil(part)
            if text then
                table.insert(parts, text)
            end
        end
        if #parts == 0 then
            return nil
        end
        return table.concat(parts, " · ")
    end
    return textOrNil(value)
end

function state.new(tab, props)
    assert(tab, "Missing argument #1 (Tab expected)")
    props = if type(props) == "table" then props else {}

    local self = setmetatable({
        tab = tab,
        window = tab.window,
        name = textOrNil(read(props, "name", "Name")) or textOrNil(read(props, "title", "Title")) or "",
        meta = metaText(read(props, "meta", "Meta")),
        body = textOrNil(read(props, "body", "Body")) or textOrNil(read(props, "text", "Text")),
        deriveFlagFromName = tab.deriveFlagFromName,
        forgetState = props.forgetState or tab.forgetState,
    }, state)

    self:_build()
    return self
end

function state:_build()
    local window = self.window

    self.main = window:Create("Frame", {
        Name = if self.name ~= "" then self.name else "PageHeader",
        Size = UDim2.new(1, -(pageInset * 2), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.tab.tabPage,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, lineGap),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })

    --[[
    Both text lines grow with their wrapped content: a long title or a long
    metadata line re-measures instead of clipping, which is the truncation
    ("Astra…") the carded header used to produce when its boxes were sized
    for one line of copy.
    ]]
    self.title = window:Create("TextLabel", {
        Name = "Title",
        Text = locale.t(self.name),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = tokens.text.pageTitle,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        LayoutOrder = 1,
        Parent = self.main,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })
    window:_bindLocale(self.title, "Text", self.name)

    self.metaLabel = window:Create("TextLabel", {
        Name = "Meta",
        Text = locale.t(self.meta or ""),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = tokens.text.caption,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Visible = self.meta ~= nil,
        LayoutOrder = 2,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    if self.meta then
        window:_bindLocale(self.metaLabel, "Text", self.meta)
    end

    --[[
    The paragraph's own block. It exists only to carry the 12px step above the
    prose: a UIListLayout has one padding for the whole list, so a single item
    that wants a larger gap brings its own.
    ]]
    self.bodyBlock = window:Create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = self.body ~= nil,
        LayoutOrder = 3,
        Parent = self.main,
    })
    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, paragraphPad),
        Parent = self.bodyBlock,
    })

    self.bodyLabel = window:Create("TextLabel", {
        Name = "Text",
        Text = locale.t(self.body or ""),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = tokens.text.body,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = self.bodyBlock,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    --[[
    The prose measure. AutomaticSize grows the line count; the constraint caps
    the line length, so a wider window adds words to a line and never
    characters to it.
    ]]
    window:Create("UISizeConstraint", {
        MaxSize = Vector2.new(tokens.measure.prose, 1e6),
        Parent = self.bodyLabel,
    })
    if self.body then
        window:_bindLocale(self.bodyLabel, "Text", self.body)
    end
end

--[[
A plain header owns no surface, so a reveal touches text only: the title lands
at full strength and the metadata line and paragraph settle at their own muted
resting alphas — the two tiers every other muted line in the library uses.
]]
function state:_setShown(shown, animate)
    local window = self.window
    window:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    window:_reveal(self.metaLabel, { TextTransparency = if shown then tokens.alpha.meta else 1 }, animate)
    window:_reveal(self.bodyLabel, { TextTransparency = if shown then tokens.alpha.muted else 1 }, animate)
end

--[[
Public setters. Each re-binds the locale, so a language change still retypes
the line, and each keeps its line in step with the copy instead of leaving a
blank band behind.
]]
function state:SetTitle(title)
    self.name = textOrNil(title) or ""
    self.window:_bindLocale(self.title, "Text", self.name)
end

function state:SetMeta(meta)
    self.meta = metaText(meta)
    if self.meta then
        self.window:_bindLocale(self.metaLabel, "Text", self.meta)
    else
        self.metaLabel.Text = ""
    end
    self.metaLabel.Visible = self.meta ~= nil
end

function state:SetBody(body)
    self.body = textOrNil(body)
    if self.body then
        self.window:_bindLocale(self.bodyLabel, "Text", self.body)
    else
        self.bodyLabel.Text = ""
    end
    self.bodyBlock.Visible = self.body ~= nil
end

moveable(state)

return state
