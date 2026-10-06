local state = {}
state.__index = state
state.__type = "Section"

local constants = require(script.Parent.Parent.utilities.moveable)
local Section = require(script.Parent.Parent.utilities.locale)
local tokens = require(script.Parent.Parent.utilities.tokens)

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = element.name or element.Name or "Section",
        icon = tab.window:ResolveIcon(element.icon or element.Icon),
    }, state)

    --[[
    A section label is the quietest heading a page has: 13px, muted, inset a
    little deeper than the cards under it. Its top step is a full grid step
    (16) when something sits above it, so sections separate with whitespace
    instead of with a box.
    ]]
    local props = if #self.tab.elements == 0 then 0 else tokens.space.lg

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, tokens.lineHeight.label + props),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    })

    if props > 0 then
        self.window:Create("UIPadding", {
            PaddingTop = UDim.new(0, props),
            Parent = self.main,
        })
    end

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Parent = self.main,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(tokens.icon.inline, tokens.icon.inline),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            ImageTransparency = 1,
            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = Section.t(self.name),

        Size = UDim2.new(1, if self.icon then -22 else 0, 0, tokens.lineHeight.label),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = tokens.text.label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    return self
end

function state:_setShown(name, icon)
    local w = self.window
    w:_reveal(self.title, { TextTransparency = if name then tokens.alpha.meta else 1 }, icon)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if name then 0.65 else 1 }, icon)
    end
end

constants(state)

return state
