local state = {}
state.__index = state
state.__type = "Divider"

local constants = require(script.Parent.Parent.utilities.moveable)
local Divider = require(script.Parent.Parent.utilities.locale)

local tab = 1
local props = 12
local text = 10
local line = 14
local element = 12

local frame = 0.88
local a10 = 0.55

function state.new(tab, a11)
    a11 = if typeof(a11) == "table" then a11 else {}

    local a12 = a11.spacing or a11.Spacing
    local a13 = a11.text or a11.Text

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        text = if a13 ~= nil then tostring(a13) else "",
        spacing = if type(a12) == "number" then math.max(a12, 0) else props,
                        line = a11.line ~= false and a11.Line ~= false,
    }, state)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 0),
        BorderSizePixel = 0,
        Name = "Divider",
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, text),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    if self.line then
        self.left = self:_buildHalf(1)
    end

    if self.text ~= "" then
        self:_buildLabel()
    end

    self:_applyHeight()

    return self
end

function state:_buildHalf(a14)
    local a15 = self.window:Create("Frame", {
        Size = UDim2.new(0, 0, 0, tab),
        BorderSizePixel = 0,
        LayoutOrder = a14,

                BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "ContentColor" })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,

        Parent = a15,
    })

    return a15
end

function state:_buildLabel()
    self.title = self.window:Create("TextLabel", {
        Text = Divider.t(self.text),
        Size = UDim2.fromOffset(0, line),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = element,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 2,

                TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    if self.line then
        self.right = self:_buildHalf(3)
    end
end

function state:_applyHeight()
    local a16 = if self.text ~= "" then line elseif self.line then tab else 0
    self.main.Size = UDim2.new(1, -40, 0, self.spacing * 2 + a16)
end

function state:Set(a17)
    self.text = if a17 ~= nil then tostring(a17) else ""

    if self.text ~= "" and not self.title then
        self:_buildLabel()

                        if not self.window.hidden then
            self:_setShown(true, true)
        end
    end

        if self.title then
        self.window:_bindLocale(self.title, "Text", self.text)

                                        local a18 = self.text ~= ""
        self.title.Visible = a18
        if self.right then
            self.right.Visible = a18
        end
    end

    self:_applyHeight()
end

function state:_setShown(a19, a20)
    local w = self.window
    local a21 = if a19 then frame else 1

    w:_reveal(self.left, { BackgroundTransparency = a21 }, a20)
    w:_reveal(self.right, { BackgroundTransparency = a21 }, a20)
    w:_reveal(self.title, { TextTransparency = if a19 then a10 else 1 }, a20)
end

constants(state)

return state
