local state = {}
state.__index = state
state.__type = "Statistic"

local constants = script.Parent.Parent.utilities

local Stat = require(constants.Parent.core.state)
local motion = require(constants.motion)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.odometer)
local name = require(constants.moveable)
local value = require(constants.constants)
local description = require(script.Parent.description)
local prefix = require(constants.locale)
local suffix = require(constants.log)

local element = value.statAccents

local frame = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.85),
    NumberSequenceKeypoint.new(1, 0),
})

local valueLabel = 38

-- [[The stat's accent gradient drifts to its new angle on the shared hero
-- spec — the same surface language as the window's own gradient.]]
local baseline = "emphasized"

-- [[Letter presentation: a stat whose value is not a number drops its numeric
-- readouts and carries the value's first letter as a glyph badge instead. The
-- glyph answer order is the value itself, then the stat's name, then "A", so
-- a badge always has exactly one letter — never an icon, digit or symbol.
-- Byte iteration keeps this free of any utf8 dependency.]]
local function firstGlyphChar(candidate)
    if candidate == nil then
        return nil
    end
    local plain = (tostring(candidate):gsub("%s+", ""))
    for index = 1, #plain do
        local char = plain:sub(index, index)
        if char:match("%a") then
            return string.upper(char)
        end
    end
    return nil
end

local function glyphText(value, fallbackName)
    return firstGlyphChar(value) or firstGlyphChar(fallbackName) or "A"
end

local function a14(a15)
    return a15.fill.Keypoints[1].Value
end

local function a16(a17)
    if a17 > 0 then
        return string.format("+%.1f%%", a17)
    elseif a17 < 0 then
        return string.format("%.1f%%", a17)
    else
        return "0%"
    end
end

local function a18(a19)
    if typeof(a19) ~= "number" then
        return tostring(a19)
    end
            local a20 = math.round(math.abs(a19))
    local s = string.format("%.0f", a20)
    local a21 = s:reverse():gsub("%d%d%d", "%0,"):reverse()
    if a21:sub(1, 1) == "," then
        a21 = a21:sub(2)
    end
        return if a19 < 0 and a20 ~= 0 then "-" .. a21 else a21
end

local function a22(a23)
        local a24 = math.round(a23)
    if a24 > 0 then
        return "+" .. a18(a24)
    elseif a24 < 0 then
        return a18(a24)
    else
        return "0"
    end
end

function state.new(tab, a25)
    a25 = if typeof(a25) == "table" then a25 else {}

    -- [[Non-numeric values switch the card to letter mode: the numeric
    -- readouts are skipped and the first letter of the value (or of the stat's
    -- own name) renders as a glyph badge instead. String values adopted the
    -- same passthrough the description already has, so "Default" reads as the
    -- letter D rather than a number roll.]]
    local desiredValue = if (a25.value or a25.Value) ~= nil then (a25.value or a25.Value) else 0
    local numeric = type(desiredValue) == "number"

    local resolvedIcon = tab.window:ResolveIcon(a25.icon or a25.Icon)

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = a25.name or a25.Name or "Statistic",
        icon = resolvedIcon,
        description = a25.description or a25.Description,

        value = desiredValue,
                        _hasValue = (a25.value or a25.Value) ~= nil,

        numberEasing = if (a25.numberEasing ~= nil)
            then a25.numberEasing
            elseif a25.NumberEasing ~= nil then a25.NumberEasing
            else true,

        changeMode = a25.changeMode or a25.ChangeMode or "percentage",         changeBaseline = a25.changeBaseline or a25.ChangeBaseline or "previous",

        prefix = a25.prefix or a25.Prefix or "",
        suffix = a25.suffix or a25.Suffix or "",

                        compact = a25.compact or a25.Compact or tab.compact or false,
        display = (a25.display or a25.Display or "value"),
        -- [[The glyph badge replaces the numeric readouts for text values and
        -- whenever the caller asks for a letter explicitly (a placeholder slot
        -- now that the settings Theme card uses it for the active-theme
        -- letter). A provided icon keeps the normal leading icon.]]
        letter = if (a25.letter ~= nil or a25.Letter ~= nil)
            then (a25.letter or a25.Letter) == true
            else not numeric,
        _initialValue = if (a25.value or a25.Value) ~= nil
            then (a25.value or a25.Value)
            else nil,
        _lastChange = 0,
    }, state)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end


    return self
end

function state:_buildFull()
    local window = self.window

    self.main = window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 70),
        BorderSizePixel = 0,
        Name = self.name,
        ZIndex = 5,

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundColor3 = "StatBackground", BackgroundTransparency = "ElementTransparency" })

    window:Create("UICorner", {
        Parent = self.main,
    }, { CornerRadius = "ElementCornerRadius" })

    self.stroke = window:Create("UIStroke", {
        Transparency = 1,
        Color = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    }, { Transparency = "ElementStrokeTransparency" })

    self.strokeGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = element.neutral.stroke,
        Transparency = frame,

        Parent = self.stroke,
    })

    -- [[A description grows the card before the readouts are built, so the
    -- [[bottom-anchored value and change hosts ride up above the line while
    -- [[the title keeps its own top-left corner.]]
    description.attach(self)

    self.titleContainer = window:Create("Frame", {
        Size = UDim2.new(1, -30, 0, 22),
        Position = UDim2.fromOffset(15, 12),
        BorderSizePixel = 0,
        LayoutOrder = -1,
        BackgroundTransparency = 1,
        ZIndex = 5,

        Parent = self.main,
    })

    self.gradientContainer = window:Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 5,

        Parent = self.main,
    })

    self.glow = window:CreateGlow(self.main, a14(element.neutral), 10, 1)

    self.title = window:Create("TextLabel", {
        Text = prefix.t(self.name),

        Size = UDim2.new(1, if self.icon then -30 else 0, 0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = 10,

        TextTransparency = 1,
        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "TitleFont" })

    self.mainGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = element.neutral.fill,
        Transparency = frame,

        Parent = self.gradientContainer,
    })

    window:Create("UICorner", {
        Parent = self.gradientContainer,
    }, { CornerRadius = "ElementCornerRadius" })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(22, 22),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 10,

            ImageTransparency = 1,
            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
    end

    self.containerLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    -- [[Letter mode: a single glyph badge replaces the bottom-anchored value
    -- and change readouts, so a text-named value still reads as one character
    -- (never an icon, digit or symbol — just the letter the value starts
    -- with). Everything above the line keeps the normal stat recipe.]]
    if self.letter then
        self.letterHost = window:Create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 15, 1, -12 - (self._descriptionExtra or 0)),
            Size = UDim2.new(1, -30, 0, 22),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 10,

            Parent = self.main,
        })

        self.letterGlyph = window:Create("TextLabel", {
            Text = glyphText(self.value, self.name),
            Size = UDim2.new(1, 0, 0, 22),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTransparency = 1,
            ZIndex = 11,

            Parent = self.letterHost,
        }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })

        return
    end

    self.valueHost = window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 15, 1, -12 - (self._descriptionExtra or 0)),
        Size = UDim2.new(0.5, -20, 0, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,

        Parent = self.main,
    })

    self.changeHost = window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -15, 1, -12 - (self._descriptionExtra or 0)),
        Size = UDim2.new(0.5, -20, 0, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,

        Parent = self.main,
    })

    self.valueOdo = props.new(window, self.valueHost, {
        textSize = 17,
        alignment = Enum.HorizontalAlignment.Left,
        transparency = 1,
    })
    self.valueOdo:snap(self:_formatValue(self.value))

    self.changeOdo = props.new(window, self.changeHost, {
        textSize = 13,
        alignment = Enum.HorizontalAlignment.Right,
        transparency = 1,
    })
    self.changeOdo:snap(self:_formatChange(0))

    self._accentGradients = { self.strokeGradient, self.mainGradient }
end

function state:_buildCompact()
    local window = self.window

    local a26 = self.tab.compact or false

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = if a26 then UDim2.fromOffset(0, valueLabel) else UDim2.new(1, -20, 0, valueLabel),
        AutomaticSize = if a26 then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
        ClipsDescendants = true,
        BorderSizePixel = 0,
        ZIndex = 5,

        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundColor3 = "StatBackground", BackgroundTransparency = "ElementTransparency" })

    window:Create("UICorner", {
        Parent = self.main,
    }, { CornerRadius = "ElementCornerRadius" })

    self.stroke = window:Create("UIStroke", {
        Transparency = 1,
        Color = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    }, { Transparency = "ElementStrokeTransparency" })

    self.strokeGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = element.neutral.stroke,
        Transparency = frame,

        Parent = self.stroke,
    })

    if a26 then
        window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Fill,
            Parent = self.main,
        })
    end

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = self.main,
    })

    self.card = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, valueLabel),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 5,

        BackgroundTransparency = 1,
        Parent = self.main,
    })

    window:Create("UICorner", {
        Parent = self.card,
    }, { CornerRadius = "ElementCornerRadius" })

    self.mainGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = element.neutral.fill,
        Transparency = frame,

        Parent = self.card,
    })

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),

        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
        Padding = UDim.new(0, 8),

        Parent = self.card,
    })

    self.titleContainer = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        ZIndex = 6,

        Parent = self.card,
    })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.titleContainer,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(18, 18),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,
            ZIndex = 6,

            ImageTransparency = 1,
            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = prefix.t(self.name),
        Size = UDim2.fromOffset(0, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = 6,

        TextTransparency = 1,
        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    self.readoutHost = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 6,

        Parent = self.card,
    })

    self.readoutOdo = props.new(window, self.readoutHost, {
        textSize = 15,
        alignment = Enum.HorizontalAlignment.Right,
        transparency = 1,
    })
    self.readoutOdo:snap(self.display == "change" and self:_formatChange(0) or self:_formatValue(self.value))

    self._accentGradients = { self.strokeGradient, self.mainGradient }
end

function state:_setAccent(a27, a28)
    local a29 = element[a27]
    self.strokeGradient.Color = a29.stroke
    self.mainGradient.Color = a29.fill
    if self.glow then
        self.glow.Color = a14(a29)
    end

        local a30 = if a28 == 1 then 14 elseif a28 == -1 then -10 else 2
    local a31 = if a28 == 1
        then Vector2.new(0.04, 0.5)
        elseif a28 == -1 then Vector2.new(-0.04, 0.5)
        else Vector2.new(0, 0.5)
    for _, a32 in self._accentGradients do
        motion.tween(a32, { Rotation = a30, Offset = a31 }, baseline)
    end
end

function state:_formatValue(a33)
    return self.prefix .. a18(a33) .. self.suffix
end

function state:_formatChange(a34)
    if self.changeMode == "absolute" then
        return a22(a34)
    else
        return a16(a34)
    end
end

function state:_showValue(a35, a36, a37, a38)
    if self.numberEasing and not a38 then
        a35:to(self:_formatValue(a36), a36 >= a37)
    else
        a35:snap(self:_formatValue(a36))
    end
end

function state:_updateFullReadouts(a39, a40, a41, a42, a43, a44)
    self:_showValue(self.valueOdo, a39, a40, a44)

    if a43 then
        self.changeOdo:snap(a43)
        self._lastChange = 0
    elseif self.numberEasing and not a42 then
        self.changeOdo:to(self:_formatChange(a41), a41 >= self._lastChange)
        self._lastChange = a41
    else
        self.changeOdo:snap(self:_formatChange(a41 or 0))
        self._lastChange = a41 or 0
    end
end

function state:_updateCompactReadout(a45, a46, a47, a48, a49, a50)
    if self.display == "change" then
        if a49 then
            self.readoutOdo:snap(a49)
            self._lastChange = 0
        elseif self.numberEasing and not a48 then
            self.readoutOdo:to(self:_formatChange(a47), a47 >= self._lastChange)
            self._lastChange = a47
        else
            self.readoutOdo:snap(self:_formatChange(a47 or 0))
            self._lastChange = a47 or 0
        end
    else         self:_showValue(self.readoutOdo, a45, a46, a50)
    end
end

function state:Set(a51)
    -- [[Letter mode never builds the numeric readouts, so a Set() there keeps
    -- the glyph badge in step instead of driving odometers that do not exist.]]
    if self.letter then
        self.value = a51
        self._hasValue = a51 ~= nil
        if self.letterGlyph then
            self.letterGlyph.Text = glyphText(a51, self.name)
        end
        return
    end

    assert(typeof(a51) == "number", "Statistic:Set() - value must be a number, got " .. typeof(a51))

    local a52 = self.value
    local a53 = not self._hasValue
    self.value = a51
    self._hasValue = true

    if a53 then
        self._initialValue = a51
    end

    local a54 = if self.changeBaseline == "initial" then self._initialValue else a52
    local a55 = a53 or a54 == a51

        local a56, a57, a58, a59
    if a55 then
        a56 = 0
        a58 = "neutral"
        a59 = 0
    elseif a54 == 0 then
        local a60 = if a51 > 0 then "+" else "-"
        local a61 = if self.changeMode == "percentage" then "∞%" else "∞"
        a57 = a60 .. a61
        a58 = if a51 > 0 then "positive" else "negative"
        a59 = if a51 > 0 then 1 else -1
    elseif self.changeMode == "percentage" then
        a56 = ((a51 - a54) / math.abs(a54)) * 100
        a59 = if a56 > 0 then 1 elseif a56 < 0 then -1 else 0
        a58 = if a59 == 1 then "positive" elseif a59 == -1 then "negative" else "neutral"
    else
        a56 = a51 - a54
        a59 = if a56 > 0 then 1 elseif a56 < 0 then -1 else 0
        a58 = if a59 == 1 then "positive" elseif a59 == -1 then "negative" else "neutral"
    end

    self:_setAccent(a58, a59)

    if self.compact then
        self:_updateCompactReadout(a51, a52, a56, a55, a57, a53)
    else
        self:_updateFullReadouts(a51, a52, a56, a55, a57, a53)
    end
end

function state:ResetBaseline(a62)
    -- [[Letter mode has no numeric readouts or baselines; clearing the badge
    -- is the closest equivalent.]]
    if self.letter then
        self._initialValue = a62
        self.value = a62
        self._hasValue = a62 ~= nil
        if self.letterGlyph then
            self.letterGlyph.Text = glyphText(a62, self.name)
        end
        return
    end

    local a63 = self.value
    local a64 = not self._hasValue
    local a65 = if typeof(a62) == "number" then a62 else self.value
    self._initialValue = a65
    self.value = a65
    self._hasValue = true
    self._lastChange = 0

        if self.compact then
        if self.display == "change" then
            self.readoutOdo:snap(self:_formatChange(0))
        else
            self:_showValue(self.readoutOdo, a65, a63, a64)
        end
    else
        self.changeOdo:snap(self:_formatChange(0))
        self:_showValue(self.valueOdo, a65, a63, a64)
    end

    self:_setAccent("neutral", 0)
end

-- [[Letter readout update: swaps the glyph badge to the value's first letter.
-- Only meaningful on a stat built in letter mode (text value or letter=true);
-- numeric stats keep their own Set() path.]]
function state:SetText(text)
    if type(text) == "number" then
        self:Set(text)
        return
    end
    self.value = text
    self._hasValue = text ~= nil
    if self.letterGlyph then
        self.letterGlyph.Text = glyphText(text, self.name)
    end
end

function state:_setShown(a66, a67)
    local w = self.window

    if self.letter then
        if a66 then
            w:_revealCommon(self, a67)
            w:_reveal(self.gradientContainer, { BackgroundTransparency = 0 }, a67)
            w:_reveal(self.glow, { Transparency = 0.82 }, a67)
            w:_reveal(self.letterGlyph, { TextTransparency = 0 }, a67)
        else
            w:_hideCommon(self, a67)
            w:_reveal(self.gradientContainer, { BackgroundTransparency = 1 }, a67)
            w:_reveal(self.glow, { Transparency = 1 }, a67)
            w:_reveal(self.letterGlyph, { TextTransparency = 1 }, a67)
        end
        return
    end

    if self.compact then
        w:_reveal(
            self.main,
            { BackgroundTransparency = if a66 then (self.window:_elementBackgroundTransparency(self)) else 1 },
            a67
        )
        w:_reveal(
            self.stroke,
            { Transparency = if a66 then self.window:_elementStrokeTransparency(self, false) else 1 },
            a67
        )
        w:_reveal(self.card, { BackgroundTransparency = if a66 then 0 else 1 }, a67)
        w:_reveal(self.title, { TextTransparency = if a66 then 0 else 1 }, a67)
        if self.iconLabel then
            w:_reveal(self.iconLabel, { ImageTransparency = if a66 then 0 else 1 }, a67)
        end
        self.readoutOdo:reveal(if a66 then 0 else 1, a67)
        return
    end

    if a66 then
        w:_revealCommon(self, a67)
        w:_reveal(self.gradientContainer, { BackgroundTransparency = 0 }, a67)
        w:_reveal(self.glow, { Transparency = 0.82 }, a67)
        self.valueOdo:reveal(0, a67)
        self.changeOdo:reveal(0, a67)
    else
        w:_hideCommon(self, a67)
        w:_reveal(self.gradientContainer, { BackgroundTransparency = 1 }, a67)
        w:_reveal(self.glow, { Transparency = 1 }, a67)
        self.valueOdo:reveal(1, a67)
        self.changeOdo:reveal(1, a67)
    end
end

function state:_minWidth()
    local w = 24 + 8
    if self.icon then
        w += 24
    end
    w += tab.textWidth(self.window.theme.Font, 15, prefix.resolve(self.name))
    local a68 = if self.display == "change" then self:_formatChange(0) else self:_formatValue(self.value)
    w += tab.textWidth(self.window.theme.Font, 15, a68)
    return w
end

name(state)

return state
