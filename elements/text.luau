local state = {}
state.__index = state
state.__type = "Text"

local constants = require(script.Parent.Parent.utilities.moveable)
local Text = require(script.Parent.Parent.utilities.locale)

-- [[Resting transparency of body text shown by this control.]]
local restingTextTransparency = 0.45

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = tostring(element.name or element.Name or ""),
        text = tostring(element.text or element.Text or ""),
        icon = tab.window:ResolveIcon(element.icon or element.Icon),
    }, state)

            self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = if self.name ~= "" then self.name else "Text",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

                BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),

        Parent = self.main,
    })

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

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

                        ImageTransparency = 1,
            Parent = self.titleRow,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = Text.t(self.name),
        Size = UDim2.new(1, if self.icon then -22 else 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,

                TextTransparency = 1,
        Parent = self.titleRow,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    self.body = self.window:Create("TextLabel", {
        Text = Text.t(self.text),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,

                TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self:_applyPresence()

    return self
end

function state:_applyPresence()
    self.titleRow.Visible = self.name ~= "" or self.icon ~= nil
    self.body.Visible = self.text ~= ""
end

function state:Set(icon)
    self.text = tostring(icon)
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
