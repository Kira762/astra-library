local state = {}
state.__index = state
state.__type = "Slider"

local constants = script.Parent.Parent.utilities

local Slider = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.odometer)
local name = require(constants.moveable)
local flag = require(constants.lockable)
local range = require(constants.locale)
local value = require(constants.HapticEngine)

local function increment(suffix)
    local minimal = 0
    while minimal < 6 do
        local callback = suffix * 10 ^ minimal
        if math.abs(callback - math.round(callback)) < 1e-9 then
            break
        end
        minimal += 1
    end
    return minimal
end

local function element(frame, fill, handle)
    local min = frame[1] + math.round((handle - frame[1]) / fill) * fill
    return math.clamp(min, frame[1], frame[2])
end

--[[
The slider's fill and handle always move through the shared service:
`normal` carries value changes, `fast` follows a drag (the handle chases
the pointer, so it must be quick and never fight the next frame's target),
`snappy` carries hover. Glow reveals trail on the delayed accent beat.
]]
local motion = require(constants.motion)
local max = "normal"
local isDragging = "fast"
local connection = "snappy"

local a22 = 300

local a23 = Vector2.new(35, 20)
local a24 = Vector2.new(41, 22)

--[[
The track, its fill and the handle are pills: each radius is half the
surface's own height, so the fill's ends stay concentric inside the
track's arc and the handle reads as a grabber rather than as a block.
Derived from the metrics beside them, not from a theme token — a slider
that squared off with a theme would look broken, not themed.
]]
local trackSize = Vector2.new(222, 14)
local trackRadius = UDim.new(0, trackSize.Y / 2)
local handleRadius = UDim.new(0, a23.Y / 2)

local function a28(x: number, a29: number, a30: number): number
    return math.clamp((x - a29) / a30, 0, 1)
end

function state.new(ownerTab, a31)
    a31 = if typeof(a31) == "table" then a31 else {}

    local self = setmetatable({
        tab = assert(ownerTab, "Missing argument #1 (Tab expected)"),
        window = ownerTab.window,
        name = a31.name or a31.Name or "Slider",
        icon = ownerTab.window:ResolveIcon(a31.icon or a31.Icon),
        forgetState = a31.forgetState or a31.ForgetState or ownerTab.forgetState,

        range = a31.range or a31.Range or { 0, 100 },
        increment = a31.increment or a31.Increment or 1,
        suffix = a31.suffix or a31.Suffix or "",

        callback = a31.callback or a31.Callback or function() end,

        dragging = false,
        minimal = a31.minimal or a31.Minimal or false,
        _handleWidth = a23.X,
    }, state)

    assert(
        typeof(self.range) == "table" and typeof(self.range[1]) == "number" and typeof(self.range[2]) == "number",
        "A slider range needs two numbers, like { 0, 100 }."
    )

    if self.range[1] > self.range[2] then
        self.range = { self.range[2], self.range[1] }
    end
    if self.increment <= 0 then
        self.increment = 1
    end

    self.value = if (a31.value or a31.Value) ~= nil
        then (a31.value or a31.Value)
        elseif (a31.currentValue or a31.CurrentValue) ~= nil then (
            a31.currentValue or a31.CurrentValue
        )
        else self.range[1]

    self.value = element(self.range, self.increment, self.value)

    self._decimals = increment(self.increment)

    self.flag = a31.flag
        or a31.Flag
        or (not self.forgetState and ownerTab.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 65),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)
    self._lastValue = self.value

    if not self.minimal then
        self:_buildLabel()
    end

    self.track = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -15, 0.5, 0),
        Size = UDim2.fromOffset(trackSize.X, trackSize.Y),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "SliderBackground" })

    self.window:Create("UICorner", {
        CornerRadius = trackRadius,

        Parent = self.track,
    })

    self.progress = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
        BackgroundTransparency = 1,
        Parent = self.track,
    })

    self.window:Create("UICorner", {
        CornerRadius = trackRadius,

        Parent = self.progress,
    })

    self.window:Create("UIGradient", {
        Offset = Vector2.new(0, 0.5),
        Rotation = 2,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
        }),

        Parent = self.progress,
    }, { Color = { "SliderProgress", tab.toColorSequence } })

    self.progressGlow = self.window:CreateGlow(self.progress, "AccentColor", 20, 1)

    self.handle = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(a23.X, a23.Y),
        BorderSizePixel = 0,
        ZIndex = 50,
        BackgroundTransparency = 1,
        Parent = self.track,
    }, { BackgroundColor3 = "SliderHandle" })

    self.window:Create("UICorner", {
        CornerRadius = handleRadius,

        Parent = self.handle,
    })

    self.handleGlow = self.window:CreateGlow(self.handle, Color3.fromRGB(255, 255, 255), 10, 1)

    self.handleStroke = self.window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.handle,
    }, { Color = "SliderStroke" })

    self.window:ConnectFor(self, self.track:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_renderProgress()
    end)

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.track,
    })

    self.window:ConnectFor(self, self.main.MouseEnter, function()
        if not self.window:_interactive() then
            return
        end
        motion.tween(self.track, { BackgroundColor3 = self.window.theme.SliderBackgroundHover }, max)
    end)

    self.window:ConnectFor(self, self.main.MouseLeave, function()
        motion.tween(self.track, { BackgroundColor3 = self.window.theme.SliderBackground }, max)
    end)

    self.window:ConnectFor(self, self.interact.InputBegan, function(a32)
        if
            a32.UserInputType == Enum.UserInputType.MouseButton1
            or a32.UserInputType == Enum.UserInputType.Touch
        then
            value.click()
            self.dragging = true
            self:_setHeld(true)
            self:_updateFromMouse()

            if self._dragConnection then
                self._dragConnection:Disconnect()
                self._dragConnection = nil
            end

            self._dragConnection = Slider.runService.RenderStepped:Connect(function()
                if self.window.unloaded or not self.dragging then
                    if self._dragConnection then
                        self._dragConnection:Disconnect()
                        self._dragConnection = nil
                    end
                    return
                end
                self:_updateFromMouse()
            end)
        end
    end)

    self.window:ConnectFor(self, Slider.userInputService.InputEnded, function(a33)
        if
            a33.UserInputType == Enum.UserInputType.MouseButton1
            or a33.UserInputType == Enum.UserInputType.Touch
        then
            self:_endDrag()
        end
    end)

    self.window:ConnectFor(self, Slider.userInputService.WindowFocusReleased, function()
        self:_endDrag()
    end)

    self.window:ConnectFor(self, self.main:GetPropertyChangedSignal("AbsoluteSize"), function()
        if self.window.animating or (self.window.hidden and self.window.hasShownOnce) then
            return
        end
        self:_applyLayout()
    end)
    self:_applyLayout()

    if self.minimal then
        self.main.Size = UDim2.new(1, -20, 0, 41)
        self.track.AnchorPoint = Vector2.new(0.5, 0.5)
        self.track.Position = UDim2.new(0.5, 0, 0.5, 0)
        self.track.Size = UDim2.new(1, -30, 0, 14)
    end

    self:_renderProgress()

    return self
end

function state:_buildLabel()
    self.container = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 20, 0.5, 0),
        Size = UDim2.new(1, -255, 0, 33),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.main,
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.container,
    })

    self.titleContainer = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.container,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    self.titleFlex = self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.None,
        Parent = self.titleContainer,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            ImageTransparency = 1,
            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = range.t(self.name),
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        RichText = true,
        LayoutOrder = 1,
        ZIndex = 5,

        TextTransparency = 1,
        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    self.valueHost = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        LayoutOrder = 1,
        Parent = self.container,
    })

    self.valueOdo = props.new(self.window, self.valueHost, {
        textSize = 15,
        alignment = Enum.HorizontalAlignment.Left,
        transparency = 1,
        duration = 0.28,
    })
    self.valueOdo:snap(self:_format(self.value))
end

function state:_setMainHeight(a34)
    -- `a34` is the height every layout writes (65 wide, 70 narrow).
    local height = a34
    if self._widthManaged then
        self.main.Size = UDim2.new(self.main.Size.X.Scale, self.main.Size.X.Offset, 0, height)
    else
        self.main.Size = UDim2.new(1, -20, 0, height)
    end
end

function state:_applyLayout()
    if self.minimal then
        return
    end
    local a35 = self.main.AbsoluteSize.X
    local a36 = if a35 > 0 and a35 < a22 then "narrow" else "wide"
    if self._layoutMode == a36 then
        return
    end
    self._layoutMode = a36

    if a36 == "narrow" then
        self:_setMainHeight(70)

        self.container.AnchorPoint = Vector2.new(0, 0)
        self.container.Position = UDim2.new(0, 20, 0, 14)
        self.container.Size = UDim2.new(1, -40, 0, 16)
        self.containerLayout.FillDirection = Enum.FillDirection.Horizontal
        self.titleFlex.FlexMode = Enum.UIFlexMode.Fill
        self.valueHost.AutomaticSize = Enum.AutomaticSize.X
        self.valueHost.Size = UDim2.new(0, 0, 0, 16)

        self.track.AnchorPoint = Vector2.new(0.5, 1)
        self.track.Position = UDim2.new(0.5, 0, 1, -14)
        self.track.Size = UDim2.new(1, -30, 0, 14)
    else
        self:_setMainHeight(65)

        self.container.AnchorPoint = Vector2.new(0, 0.5)
        self.container.Position = UDim2.new(0, 20, 0.5, 0)
        self.container.Size = UDim2.new(1, -255, 0, 33)
        self.containerLayout.FillDirection = Enum.FillDirection.Vertical
        self.titleFlex.FlexMode = Enum.UIFlexMode.None
        self.valueHost.AutomaticSize = Enum.AutomaticSize.None
        self.valueHost.Size = UDim2.new(1, 0, 0, 16)

        self.track.AnchorPoint = Vector2.new(1, 0.5)
        self.track.Position = UDim2.new(1, -15, 0.5, 0)
        self.track.Size = UDim2.new(0, 222, 0, 14)
    end

    self:_renderProgress()
end

function state:_format(a37)
    local a38 = string.format("%." .. self._decimals .. "f", a37)
    if self.suffix ~= "" then
        return a38 .. " " .. self.suffix
    end
    return a38
end

function state:_pillTravel()
    return math.max(self.track.AbsoluteSize.X, 0)
end

function state:_renderProgress(a39)
    local a40 = self.range[2] - self.range[1]
    local a41 = if a40 ~= 0 then math.clamp((self.value - self.range[1]) / a40, 0, 1) else 0

    local half = (self._handleWidth or a23.X) / 2
    local center = half + a41 * math.max(self:_pillTravel() - half * 2, 0)
    local fill = UDim2.new(0, center, 1, 0)
    local at = UDim2.new(0, center, 0.5, 0)
    if a39 then
        motion.tween(self.progress, { Size = fill }, a39)
        motion.tween(self.handle, { Position = at }, a39)
    else
        self.progress.Size = fill
        self.handle.Position = at
    end
end

function state:_updateFromMouse()
    local a43 = self:_pillTravel()
    if a43 <= 0 then
        return
    end

    local a44 =
        a28(Slider.userInputService:GetMouseLocation().X, self.track.AbsolutePosition.X, a43)
    local a45 = element(self.range, self.increment, self.range[1] + a44 * (self.range[2] - self.range[1]))

    if a45 ~= self.value then
        self.value = a45
        if self.valueOdo then
            self.valueOdo:snap(self:_format(a45))
        end
        self._lastValue = a45
        self:_renderProgress(connection)
        self:_fireCallback(a45)
    end
end

function state:_endDrag()
    if not self.dragging then
        return
    end
    self.dragging = false
    self:_setHeld(false)

    if self._dragConnection then
        self._dragConnection:Disconnect()
        self._dragConnection = nil
    end

    self.window:_persist(self)
end

function state:_setHeld(a46)
    if not a46 then
        self:_fireCallback(self.value)
    end

    local a47 = if a46 then a24 else a23
    self._handleWidth = a47.X

    motion.tween(self.handle, {
        Size = UDim2.fromOffset(a47.X, a47.Y),
        BackgroundTransparency = if a46 then 0.7 else 0,
    }, isDragging)
    motion.tween(self.handleStroke, { Transparency = if a46 then 0.6 else 1 }, isDragging)
    self:_renderProgress(isDragging)
end

function state:_fireCallback(a48)
    self.window:_runGuarded(self, self.callback, a48, self.dragging == true)
end

function state:Set(a49, a50)
    a49 = element(self.range, self.increment, a49)
    self.value = a49
    if self.valueOdo then
        self.valueOdo:to(self:_format(a49), a49 >= (self._lastValue or a49))
    end
    self._lastValue = a49
    self:_renderProgress(max)

    if not a50 then
        self:_fireCallback(a49)
        self.window:_persist(self)
    end
end

local glowBase = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)
local function a51()
    return motion.spec(glowBase)
end

function state:_setShown(a52, a53)
    local w = self.window
    if a52 then
        w:_revealCommon(self, a53)
        w:_reveal(self.track, { BackgroundTransparency = 0 }, a53)
        w:_reveal(self.progress, { BackgroundTransparency = 0 }, a53)
        w:_reveal(self.handle, { BackgroundTransparency = 0 }, a53)
        if self.valueOdo then
            self.valueOdo:reveal(0.3, a53)
        end
        w:_reveal(self.progressGlow, { Transparency = math.max(0.55, w.theme.AccentGlow) }, a53, a51())
        w:_reveal(self.handleGlow, { Transparency = 0.8 }, a53, a51())
    else
        w:_hideCommon(self, a53)
        w:_reveal(self.track, { BackgroundTransparency = 1 }, a53)
        w:_reveal(self.progress, { BackgroundTransparency = 1 }, a53)
        w:_reveal(self.handle, { BackgroundTransparency = 1 }, a53)
        if self.valueOdo then
            self.valueOdo:reveal(1, a53)
        end
        w:_reveal(self.progressGlow, { Transparency = 1 }, a53, a51())
        w:_reveal(self.handleGlow, { Transparency = 1 }, a53, a51())
    end
end

function state:_refreshTheme()
    motion.tween(
        self.progressGlow,
        { Transparency = math.max(0.55, self.window.theme.AccentGlow) },
        "smooth"
    )
end

function state:_minWidth()
    if self.minimal then
        return 100
    end
    local w = 40
    if self.icon then
        w += 22
    end
    w += tab.textWidth(self.window.theme.Font, 16, range.resolve(self.name))
    w += 12
    w += tab.textWidth(self.window.theme.Font, 15, self:_format(self.value))
    return math.max(w, 160)
end

name(state)
flag(state)

function state:SetInfo(infoText)
    -- Deprecated compatibility no-op: functional info badges were removed.
end

return state
