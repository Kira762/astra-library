local state = {}
state.__index = state
state.__type = "Toggle"

local constants = script.Parent.Parent.utilities

local Toggle = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.lockable)
local flag = require(constants.locale)
local value = require(constants.HapticEngine)
local callback = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- [[Switch metrics, in one place. The track and the knob are both pills and
-- [[the knob keeps the same clearance on every side it can see (`switchInset`
-- [[at the parked end, the same above and below), so the two resting states
-- [[are exact mirrors of each other.
--
-- [[The track is also deliberately only as wide as the knob plus its travel.
-- [[With the old 50px track around a 25px knob, "on" parked the knob 3px from
-- [[the right edge and left 22px of empty track on the left: a ratio of
-- [[roughly 7:1 at the same moment the knob looked like it floated. Dropping
-- [[the track to 44px keeps the knob's travel readable while the empty side
-- [[drops to 14px, so neither state reads as lopsided.
--
-- [[Positions are expressed from the track's right edge (scale 1), which is
-- [[how the knob's AnchorPoint (0, 0.5) resolves against its parent.]]
local switchTrackWidth = 44
local switchTrackHeight = 22
local switchKnobWidth = 26
local switchKnobHeight = 18
local switchInset = 2

local switchKnobActive = UDim2.new(1, -(switchKnobWidth + switchInset), 0.5, 0)
local switchKnobRest = UDim2.new(1, -(switchTrackWidth - switchInset), 0.5, 0)

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = element.name or element.Name or "Switch",
        icon = tab.window:ResolveIcon(element.icon or element.Icon),
        description = element.description or element.Description,
        forgetState = element.forgetState or element.ForgetState or tab.forgetState,         compact = tab.compact or false,
        flag = element.flag
            or element.Flag
            or (
                not (element.forgetState or element.ForgetState or tab.forgetState)
                    and tab.deriveFlagFromName(element.name or element.Name or "Switch")
                or nil
            ),

        callback = element.callback or element.Callback or function() end,

        value = if (element.value or element.Value) ~= nil then (element.value or element.Value) else false,
    }, state)

        self.window:_registerControl(self)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    if self.description and not self.compact then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

function state:_buildSwitch(frame)
    local window = self.window

    self.functionContainer = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(switchTrackWidth, switchTrackHeight),

        BackgroundTransparency = 1,
        Parent = frame,
    }, { BackgroundColor3 = "ToggleTrack" })

    window:Create("UICorner", {
        -- [[A true pill at any height, instead of a radius that happened to
        -- [[match the old 21px track.]]
        CornerRadius = UDim.new(1, 0),
        Parent = self.functionContainer,
    })

    self.containerStroke = window:Create("UIStroke", {
        Transparency = 1,         Parent = self.functionContainer,
    }, { Color = "SurfaceStroke" })

    self.indicator = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(switchKnobWidth, switchKnobHeight),
        Position = if self.value then switchKnobActive else switchKnobRest,
        AnchorPoint = Vector2.new(0, 0.5),
        -- [[Above the track's sheen overlay (ZIndex 1): the sheen belongs to
        -- [[the track, and at equal ZIndex the later sibling drew it straight
        -- [[over the knob, washing the knob's lower half and leaving it with
        -- [[an uneven rim.]]
        ZIndex = 2,
        BackgroundColor3 = self.value and self.window.theme.AccentColor or self.window.theme.ToggleKnobOff,

        BackgroundTransparency = 1,
        Parent = self.functionContainer,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.indicator,
    })

    self.indicatorStroke = window:Create("UIStroke", {
        Color = self.value and self.window.theme.AccentStroke or Color3.fromRGB(255, 255, 255),
        Transparency = 1,         Parent = self.indicator,
    })

        -- [[The glow is only ever visible while the switch is on, so it is
        -- [[built by _indicatorGlow() the first time that matters: an off
        -- [[switch carries no shadow instance at all.]]

        self.overlay = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        -- [[Under the knob (ZIndex 2) and over the track: the theme's sheen
        -- [[tints the track, not whatever is parked on it.]]
        ZIndex = 1,

        BackgroundTransparency = 1,
        Parent = self.functionContainer,
    }, { Visible = "DarkToggleOverlay" })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.overlay,
    })

    self.overlayGradient = window:Create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.35),
        }),

        Parent = self.overlay,
    })

    return self.functionContainer
end

function state:_performToggle()
    value.click()
    self.value = not self.value
    self:_animateIndicator()

    self.window:_runGuarded(self, self.callback, self.value)
    self.window:_persist(self)
end

function state:_buildFull()
    local window = self.window

    self.main = window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = window:StyleElementBody(self.main)
    self.hoverOverlay = window:CreateHoverOverlay(self.main)

    self.container = window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
    })

    self.containerLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = flag.t(self.name),
        Size = UDim2.fromOffset(250, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.interact = window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        AnchorPoint = Vector2.new(1, 0.5),
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.main,
    })

        self:_buildSwitch(self.main)
    self.functionContainer.Position = UDim2.new(1, -15, 0, 20)
    self.functionContainer.AnchorPoint = Vector2.new(1, 0.5)

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        Toggle.tweenService
            :Create(
                self.stroke,
                callback,
                { Transparency = 1 }
            )
            :Play()
        Toggle.tweenService
            :Create(
                self.main,
                TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, -26, 0, 41) }
            )
            :Play()

        self:_performToggle()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        Toggle.tweenService
            :Create(
                self.main,
                TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, -20, 0, 41) }
            )
            :Play()
        Toggle.tweenService
            :Create(
                self.stroke,
                callback,
                { Transparency = self.window.theme.ElementStrokeTransparency }
            )
            :Play()
    end)
end

function state:_buildCompact()
    local window = self.window

        self.main, self.stroke, self.interact = window:_buildCompactRow(self.tab, self.name, 10)
    self.hoverOverlay = self.interact

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),

        Parent = self.interact,
    })

        window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
        Padding = UDim.new(0, 10),

        Parent = self.interact,
    })

    self.container = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,

        Parent = self.interact,
    })

        window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.container,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,

            ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = flag.t(self.name),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

        window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

        self:_buildSwitch(self.interact)
    self.functionContainer.LayoutOrder = 1

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        Toggle.tweenService
            :Create(
                self.stroke,
                callback,
                { Transparency = 1 }
            )
            :Play()

        self:_performToggle()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        Toggle.tweenService
            :Create(
                self.stroke,
                callback,
                { Transparency = self.window.theme.ElementStrokeTransparency }
            )
            :Play()
    end)
end

function state:_indicatorGlow()
    if not self.indicatorGlow then
        self.indicatorGlow = self.window:CreateGlow(self.indicator, "AccentColor", 20, 1)
    end
    return self.indicatorGlow
end

function state:_animateIndicator()
    local track = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local glow = if self.value then self:_indicatorGlow() else self.indicatorGlow
    if glow then
        Toggle.tweenService
            :Create(glow, track, { Transparency = self.value and self.window.theme.AccentGlow or 1 })
            :Play()
    end
    if self.value then
        Toggle.tweenService
            :Create(self.indicator, track, {
                Position = switchKnobActive,
                BackgroundColor3 = self.window.theme.AccentColor,
                BackgroundTransparency = 0,
            })
            :Play()
        Toggle.tweenService
            :Create(self.indicatorStroke, track, { Color = self.window.theme.AccentStroke, Transparency = 0 })
            :Play()
    else
        Toggle.tweenService
            :Create(self.indicator, track, {
                Position = switchKnobRest,
                BackgroundColor3 = self.window.theme.ToggleKnobOff,
                BackgroundTransparency = self.window.theme.ToggleKnobOffTransparency,
            })
            :Play()
        Toggle.tweenService
            :Create(self.indicatorStroke, track, { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7 })
            :Play()
    end
end

local knob = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local accentTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)

function state:_setShown(flag, a16)
    local w = self.window
    if flag then
        w:_revealCommon(self, a16)
                w:_reveal(self.indicator, {
            BackgroundColor3 = self.value and w.theme.AccentColor or w.theme.ToggleKnobOff,
            BackgroundTransparency = self.value and 0 or w.theme.ToggleKnobOffTransparency,
        }, a16, knob)
        w:_reveal(self.indicatorStroke, {
            Color = self.value and w.theme.AccentStroke or Color3.fromRGB(255, 255, 255),
            Transparency = self.value and 0 or 0.7,
        }, a16, knob)
        local shownGlow = if self.value then self:_indicatorGlow() else self.indicatorGlow
        if shownGlow then
            w:_reveal(
                shownGlow,
                { Transparency = self.value and w.theme.AccentGlow or 1 },
                a16,
                accentTween
            )
        end
        w:_reveal(self.overlay, { BackgroundTransparency = 0 }, a16, knob)
        w:_reveal(self.containerStroke, { Transparency = 0.85 }, a16, knob)
        w:_reveal(
            self.functionContainer,
            { BackgroundTransparency = w.theme.ToggleTrackTransparency },
            a16,
            knob
        )
    else
        w:_hideCommon(self, a16)
        w:_reveal(self.indicator, { BackgroundTransparency = 1 }, a16, knob)
        w:_reveal(self.indicatorStroke, { Transparency = 1 }, a16, knob)
        if self.indicatorGlow then
            w:_reveal(self.indicatorGlow, { Transparency = 1 }, a16, accentTween)
        end
        w:_reveal(self.overlay, { BackgroundTransparency = 1 }, a16, knob)
        w:_reveal(self.containerStroke, { Transparency = 1 }, a16, knob)
        w:_reveal(self.functionContainer, { BackgroundTransparency = 1 }, a16, knob)
    end
end

function state:_refreshTheme()
    local t = self.window.theme
    local a17 = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local ts = Toggle.tweenService
    ts:Create(self.functionContainer, a17, { BackgroundTransparency = t.ToggleTrackTransparency }):Play()
    ts:Create(self.indicator, a17, {
        BackgroundColor3 = self.value and t.AccentColor or t.ToggleKnobOff,
        BackgroundTransparency = self.value and 0 or t.ToggleKnobOffTransparency,
    }):Play()
    ts:Create(self.indicatorStroke, a17, {
        Color = self.value and t.AccentStroke or Color3.fromRGB(255, 255, 255),
    }):Play()
    local glow = if self.value then self:_indicatorGlow() else self.indicatorGlow
    if glow then
        ts:Create(glow, a17, { Transparency = self.value and t.AccentGlow or 1 }):Play()
    end
end

function state:_minWidth()
    -- [[The switch column is the track's own width: the compact row sizes its
    -- [[label column against this, so it has to follow the metrics above.]]
    local w = 30 + 10 + switchTrackWidth     if self.icon then
        w += 21     end
        w += tab.textWidth(self.window.theme.Font, 16, flag.resolve(self.name))
    return w
end

props(state)
name(state)

function state:Set(a18, a19)
    local a20 = self.value ~= a18
    self.value = a18

    if a20 then
        self:_animateIndicator()
    end

        if not a19 then
        self.window:_runGuarded(self, self.callback, self.value)
        self.window:_persist(self)     end
end

return state
