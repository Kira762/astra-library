local state = {}
state.__index = state
state.__type = "Text"

local constants = require(script.Parent.Parent.utilities.moveable)
local Text = require(script.Parent.Parent.utilities.locale)
local tokens = require(script.Parent.Parent.utilities.tokens)

-- Resting transparency of body text shown by this control.
local restingTextTransparency = tokens.alpha.muted

--[[
Card geometry. A carded Text block keeps the library's gutter and a 12px
inner padding (the 8pt grid's middle step); a plain block keeps the gutter
but no padding box and no surface at all — its heading and prose simply sit
on the page band, which is what makes a section read as content rather than
as another nested card.
]]
local cardPad = tokens.space.md

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = tostring(element.name or element.Name or ""),
        text = tostring(element.text or element.Text or ""),
        --[[
        `plain = true` drops the card: no fill, no stroke, no padding box.
        The prose measure still applies, so a plain paragraph keeps a
        readable line length on a wide window.
        ]]
        plain = element.plain == true or element.Plain == true,
        _plain = element.plain == true or element.Plain == true,
    }, state)

            self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -(tokens.pageInset * 2), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = if self.name ~= "" then self.name else "Text",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

                BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    if not self.plain then
        self.stroke = self.window:StyleElementBody(self.main)
    end

    if not self.plain then
        self.window:Create("UIPadding", {
            PaddingTop = UDim.new(0, cardPad),
            PaddingBottom = UDim.new(0, cardPad),
            PaddingLeft = UDim.new(0, cardPad),
            PaddingRight = UDim.new(0, cardPad),

            Parent = self.main,
        })
    end

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.main,
    })

        self.titleRow = self.window:Create("Frame", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,

        Parent = self.titleRow,
    })

    self.title = self.window:Create("TextLabel", {
        Text = Text.t(self.name),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = tokens.text.title,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,

                TextTransparency = 1,
        Parent = self.titleRow,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })

    self.body = self.window:Create("TextLabel", {
        Text = Text.t(self.text),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = tokens.text.body,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,

                TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    --[[
    The reading measure. AutomaticSize grows the line count; the constraint
    caps the line length, so prose stops widening at about 65 characters
    however wide the window gets.
    ]]
    self.window:Create("UISizeConstraint", {
        MaxSize = Vector2.new(tokens.measure.prose, 1e6),
        Parent = self.body,
    })

    self:_applyPresence()

    return self
end

function state:_applyPresence()
    self.titleRow.Visible = self.name ~= ""
    self.body.Visible = self.text ~= ""
end

function state:Set(body)
    self.text = tostring(body)
    self.window:_bindLocale(self.body, "Text", self.text)
    self:_applyPresence()
end

function state:SetTitle(element)
    self.name = tostring(element)
    self.window:_bindLocale(self.title, "Text", self.name)
    self:_applyPresence()
end

function state:_setShown(frame, a11)
        if frame then
        self.window:_revealCommon(self, a11)
    else
        self.window:_hideCommon(self, a11)
    end

    self.window:_reveal(self.body, { TextTransparency = if frame then restingTextTransparency else 1 }, a11)
end

constants(state)

return state
