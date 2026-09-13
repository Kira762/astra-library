local state = {}
state.__index = state
state.__type = "Input"

local constants = script.Parent.Parent.utilities

local Input = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.lockable)
local placeholder = require(constants.locale)
local numeric = require(constants.constants)
local clearOnFocus = require(constants.HapticEngine)

local callback = numeric.pillResizeInfo
local element = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function frame(textBox)
    local a, b = textBox:match("^([%d%.%-]+)%^([%d%.%-]+)$")
    if a and b then
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then
            return na ^ nb
        end
    end
    return tonumber(textBox)
end

function state.new(tab, placeholderLabel)
    placeholderLabel = if typeof(placeholderLabel) == "table" then placeholderLabel else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = placeholderLabel.name or placeholderLabel.Name or "Input",
        icon = tab.window:ResolveIcon(placeholderLabel.icon or placeholderLabel.Icon),
        forgetState = placeholderLabel.forgetState or placeholderLabel.ForgetState or tab.forgetState,
        placeholder = placeholderLabel.placeholder or placeholderLabel.Placeholder or "",
        numeric = placeholderLabel.numeric or placeholderLabel.Numeric or false,
        clearOnFocus = placeholderLabel.clearOnFocus or placeholderLabel.ClearOnFocus or false,

        callback = placeholderLabel.callback or placeholderLabel.Callback or function() end,
    }, state)

    self.value =
        tostring(placeholderLabel.value or placeholderLabel.Value or placeholderLabel.currentValue or placeholderLabel.CurrentValue or "")

    self.flag = placeholderLabel.flag
        or placeholderLabel.Flag
        or (not self.forgetState and tab.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.main)

    self.container = self.window:Create("Frame", {
        Size = UDim2.new(1, -115, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = placeholder.t(self.name),
        Size = UDim2.new(1, if self.icon then -21 else 0, 0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = 5,

        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.box = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(85, 30),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "FieldBackground" })

    self.window:Create("UICorner", {
        Parent = self.box,
    }, { CornerRadius = "ElementCornerRadius" })

    self.boxStroke = self.window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.box,
    }, { Color = "SurfaceStroke" })

    self._glowIdle = 1
    self.input = self.window:Create("TextBox", {
        Text = self.value,
        PlaceholderText = placeholder.t(self.placeholder),
        Size = UDim2.new(1, -15, 0, 15),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = self.clearOnFocus,

        TextTransparency = 1,
        Parent = self.box,
    }, { TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })

    self.window:ConnectFor(self, self.input:GetPropertyChangedSignal("Text"), function()
        if self.numeric then
            local a15 = (self.input.Text:gsub("[^%d%.%-eE%^]", ""))
            if a15 ~= self.input.Text then
                self.input.Text = a15
                return
            end
        end
        self:_sizeBox(true)
    end)

    self.window:ConnectFor(self, self.input.Focused, function()
        Input.tweenService:Create(self.input, element, { TextTransparency = 0 }):Play()
    end)

    self.window:ConnectFor(self, self.input.FocusLost, function()
        Input.tweenService:Create(self.input, element, { TextTransparency = 0.6 }):Play()
        if self.clearOnFocus and self.input.Text == "" and self.value ~= "" then
            self.input.Text = self.value
            return
        end
        if self.input.Text == self.value then
            return
        end
        self:_commit(self.input.Text)
    end)

    self.window:_wireElementHover(self)

    self:_sizeBox(false)
    return self
end

function state:_sizeBox(a16)
    local a17 = self.input.Text ~= "" and self.input.Text or self.placeholder
    local a18 = math.clamp(tab.textWidth(self.window.theme.Font, 15, a17) + 30, 70, 220)
    self.container.Size = UDim2.new(1, -(a18 + 35), 0, 16)
    if a16 then
        Input.tweenService:Create(self.box, callback, { Size = UDim2.fromOffset(a18, 30) }):Play()
    else
        self.box.Size = UDim2.fromOffset(a18, 30)
    end
end

function state:_commit(a19, a20)
    a19 = tostring(a19)
    if self.numeric then
        local n = frame(a19)
        if not n or n ~= n or n == math.huge or n == -math.huge then
            if self.input.Text ~= self.value then
                self.input.Text = self.value
            end
            return
        end
        a19 = tostring(n)
    end

    local a21 = a19 ~= self.value
    self.value = a19
    if self.input.Text ~= a19 then
        self.input.Text = a19
    end

    if not a20 then
        self.window:_runGuarded(self, self.callback, a19)
        self.window:_persist(self)
        if a21 and not self.window._loading then
            clearOnFocus.click()
            self.window:_flashResult(self, true)
        end
    end
end

function state:Set(a22, a23)
    self:_commit(a22, a23)
end

function state:_fieldGlow()
    if not self.glow then
        self.glow = self.window:CreateGlow(self.box, "FieldGlow", 20, 1)
    end
    return self.glow
end

function state:_setShown(a24, a25)
    local w = self.window
    if a24 then
        w:_revealCommon(self, a25)
        w:_reveal(self.box, { BackgroundTransparency = w.theme.FieldTransparency }, a25)
        w:_reveal(self.boxStroke, { Transparency = 0.85 }, a25)
        w:_reveal(self.input, { TextTransparency = 0.6 }, a25)
    else
        w:_hideCommon(self, a25)
        w:_reveal(self.box, { BackgroundTransparency = 1 }, a25)
        w:_reveal(self.boxStroke, { Transparency = 1 }, a25)
        w:_reveal(self.input, { TextTransparency = 1 }, a25)
    end
end

function state:_refreshTheme()
    Input.tweenService
        :Create(
            self.box,
            TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = self.window.theme.FieldTransparency }
        )
        :Play()
end

props(state)
name(state)

return state
