local state = {}
state.__index = state
state.__type = "Input"

local constants = script.Parent.Parent.utilities

local Input = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.lockable)
local placeholder = require(constants.locale)
local description = require(script.Parent.description)
local infoHelper = require(script.Parent.infoHelper)
local numeric = require(constants.constants)
local clearOnFocus = require(constants.HapticEngine)

-- [[Field feedback rides the shared motion service: the box follows typing
-- on the hover spec (quick, but never jumpy), focus fades the caret text on
-- the press spec, and theme refreshes cross-fade on the surface spec.]]
local motion = require(constants.motion)
local callback = "snappy"
local element = "fast"

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

    local rawDesc = placeholderLabel.description or placeholderLabel.Description or placeholderLabel.info or placeholderLabel.Info or placeholderLabel.tooltip or placeholderLabel.Tooltip
    local desc = if typeof(rawDesc) == "string" and rawDesc ~= "" then rawDesc else nil

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = placeholderLabel.name or placeholderLabel.Name or "Input",
        icon = tab.window:ResolveIcon(placeholderLabel.icon or placeholderLabel.Icon),
        description = desc,
        info = desc,
        infoIcon = placeholderLabel.infoIcon or placeholderLabel.InfoIcon,
        inlineDescription = placeholderLabel.inlineDescription or placeholderLabel.InlineDescription,
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

    -- [[The card grows for a description before the title row and the field
    -- [[box are built, so both centre in the base region instead of riding
    -- [[down onto the line.]]
    if self.inlineDescription or self.inline then
        description.attach(self)
    end

    self.container = self.window:Create("Frame", {
        Size = UDim2.new(1, -115, 0, 16),
        Position = UDim2.new(0, 20, description.center(self, 41)),
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
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Name = "Icon",
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,
            ZIndex = 5,

            ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    local hasInfo = self.description ~= nil and self.description ~= ""

    self.title = self.window:Create("TextLabel", {
        Name = "Title",
        Text = placeholder.t(self.name),
        Size = if hasInfo
            then UDim2.fromOffset(0, 16)
            else UDim2.new(1, if self.icon then -21 else 0, 0, 16),
        AutomaticSize = if hasInfo then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
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

    if hasInfo then
        self.window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = self.title,
        })
        infoHelper.attach(self, self.container, 2)
    end

    self.box = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, description.center(self, 41)),
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
        motion.tween(self.input, { TextTransparency = 0 }, element)
    end)

    self.window:ConnectFor(self, self.input.FocusLost, function()
        motion.tween(self.input, { TextTransparency = 0.6 }, element)
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
        motion.tween(self.box, { Size = UDim2.fromOffset(a18, 30) }, callback)
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
    motion.tween(
        self.box,
        { BackgroundTransparency = self.window.theme.FieldTransparency },
        "smooth"
    )
end

props(state)
name(state)

function state:SetDescription(descText)
    local cleaned = if typeof(descText) == "string" and descText ~= "" then descText else nil
    self.description = cleaned
    self.info = cleaned
    if cleaned then
        if self.infoButton then
            self.infoButton.Visible = true
            self.infoButton.ImageTransparency = 0.45
        elseif self.container then
            if self.title.AutomaticSize == Enum.AutomaticSize.None then
                self.title.AutomaticSize = Enum.AutomaticSize.X
                self.title.Size = UDim2.fromOffset(0, 16)
                self.window:Create("UIFlexItem", {
                    FlexMode = Enum.UIFlexMode.Shrink,
                    Parent = self.title,
                })
            end
            infoHelper.attach(self, self.container, 2)
            if self.infoButton then
                self.infoButton.ImageTransparency = 0.45
            end
        end
    elseif self.infoButton then
        self.infoButton.Visible = false
        if self.window and self.window._tooltipActiveAnchor == self.infoButton then
            local tooltip = require(script.Parent.Parent.components.tooltip)
            tooltip.hide(self.window, true)
        end
    end
end

function state:SetInfo(infoText)
    self:SetDescription(infoText)
end

return state
