local Notification = {}
Notification.__index = Notification
Notification.__type = "Notification"

local utilities = script.Parent.Parent.utilities

local state = require(utilities.Parent.core.state)
local functions = require(script.Parent.Parent.functions)
local constants = require(utilities.constants)
local haptic = require(utilities.HapticEngine)

local showTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local fadeInTween = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local textFadeTween = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local bodyFadeTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local dismissTween = TweenInfo.new(0.9, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local bodyHiddenPosition = UDim2.new(0.5, 360, 0.5, 0)
local bodyShownPosition = UDim2.new(0.5, 0, 0.5, 0)

local maxVisible = 6

local padding = 8

local function autoDuration(content)
    return math.clamp(#content * 0.06 + 3, 3, 9)
end

function Notification.new(window, props, release)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = props.title or props.Title or "Notification",
        content = props.content or props.Content or "",
        icon = window:ResolveIcon(props.icon or props.Icon),
        _hovered = false,
        _dismissed = false,
        -- [[Handed over by the entrance queue when this card was queued: the
        -- next overlay does not start until this one releases the slot, which
        -- is what turns the burst a host fires at load time into a cascade. Nil
        -- for a card built directly, which then owns its own timing.]]
        _release = release,
    }, Notification)

    self.duration = props.duration or props.Duration or autoDuration(self.content)

    local hasIcon = self.icon ~= nil and self.icon ~= 0 and self.icon ~= ""

    self.main = self.window:Create("Frame", {
        Name = "Notification",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.notification,
        Parent = self.window.notifications,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, padding),
        Parent = self.main,
    })

    self.body = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 1, 0),
        Position = bodyHiddenPosition,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true,
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.notification,
        BackgroundTransparency = 1,
        Parent = self.main,
    })

    self.window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),
        Parent = self.body,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    self.window:Create("UICorner", {
        Parent = self.body,
    }, { CornerRadius = "CornerRoundness" })

    self.stroke = self.window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.body,
    }, { Color = "SurfaceStroke" })

    self.shadow = self.window:CreateGlow(self.body, "ShadowColor", 20, 1)

    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 14),
        Parent = self.body,
    })

    if hasIcon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(24, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = constants.zIndex.notification,
            ImageTransparency = 1,
            Parent = self.body,
        }, { ImageColor3 = "ContentColor" })
    end

    self.container = self.window:Create("Frame", {
        Size = UDim2.fromOffset(hasIcon and 222 or 260, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.notification,
        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = self.container,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        Text = self.title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = constants.zIndex.notification,
        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "TitleFont" })

    if self.content ~= "" then
        self.descriptionLabel = self.window:Create("TextLabel", {
            Text = self.content,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            TextSize = 15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            ZIndex = constants.zIndex.notification,
            TextTransparency = 1,
            Parent = self.container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })
    end

    self.window._notificationCount = (self.window._notificationCount or 0) + 1
    self.main.LayoutOrder = self.window._notificationCount

    local liveNotifications = self.window._liveNotifications
    if not liveNotifications then
        liveNotifications = {}
        self.window._liveNotifications = liveNotifications
    end
    table.insert(liveNotifications, self)
    while #liveNotifications > maxVisible do
        local oldest = table.remove(liveNotifications, 1)
        if oldest and oldest ~= self then
            task.spawn(oldest._dismiss, oldest)
        end
    end

    self._connections = {
        self.window:Connect(self.body.MouseEnter, function()
            self._hovered = true
        end),
        self.window:Connect(self.body.MouseLeave, function()
            self._hovered = false
        end),
        self.window:Connect(self.body.InputBegan, function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                self:_dismiss()
            end
        end),
    }

    task.spawn(function()
        self:_show()
    end)

    return self
end

function Notification:_measure()
    local contentWidth = self.iconLabel and 222 or 260

    local textHeight = functions.textHeight(self.window.theme.TitleFont, 16, self.title, contentWidth)
    if self.descriptionLabel then
        textHeight = textHeight + 4 + functions.textHeight(self.window.theme.Font, 15, self.content, contentWidth)
    end

    return math.max(textHeight, self.iconLabel and 24 or 0) + 28
end

-- [[Hand the entrance slot back to the queue. Fires when the last piece of the
-- entrance has been committed, and also on any early exit: a card that is
-- dismissed before it opens (the visibility cap, a click, an unload) must not
-- leave the next one waiting for a tween that will never finish. Idempotent,
-- because the show path and the dismiss path can both reach it.]]
function Notification:_entranceDone()
    local release = self._release
    if not release then
        return
    end
    self._release = nil
    release()
end

function Notification:_show()
    local totalHeight = self:_measure() + padding
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end

    haptic.notify()

    state.tweenService:Create(self.main, showTween, { Size = UDim2.new(1, 0, 0, totalHeight) }):Play()
    state.tweenService:Create(self.body, bodyFadeTween, { Position = bodyShownPosition }):Play()
    state.tweenService:Create(self.body, fadeInTween, { BackgroundTransparency = 0 }):Play()
    state.tweenService:Create(self.titleLabel, textFadeTween, { TextTransparency = 0 }):Play()
    state.tweenService:Create(self.stroke, fadeInTween, { Transparency = 0.95 }):Play()
    state.tweenService:Create(self.shadow, textFadeTween, { Transparency = 0.6 }):Play()

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end
    if self.iconLabel then
        state.tweenService:Create(self.iconLabel, textFadeTween, { ImageTransparency = 0 }):Play()
    end

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end
    if self.descriptionLabel then
        state.tweenService:Create(self.descriptionLabel, textFadeTween, { TextTransparency = 0.35 }):Play()
    end

    -- [[The card is fully on screen from here: everything that is still
    -- running is its hold time, not its entrance, so the next one may start.]]
    self:_entranceDone()

    local elapsed = 0
    while elapsed < self.duration and not self._dismissed and self.main.Parent do
        local dt = task.wait()
        if not self._hovered then
            elapsed += dt
        end
    end

    self:_dismiss()
end

function Notification:_dismiss()
    if self._dismissed then
        return
    end
    self._dismissed = true

    -- [[A card retired before its entrance finished still owes the queue its
    -- slot; `_entranceDone` is a no-op once the show path has handed it back.]]
    self:_entranceDone()

    local liveNotifications = self.window._liveNotifications
    local index = liveNotifications and table.find(liveNotifications, self)
    if liveNotifications and index then
        table.remove(liveNotifications, index)
    end

    if not self.main.Parent then
        return
    end

    state.tweenService:Create(self.body, fadeInTween, { BackgroundTransparency = 1 }):Play()
    state.tweenService:Create(self.stroke, fadeInTween, { Transparency = 1 }):Play()
    state.tweenService:Create(self.shadow, textFadeTween, { Transparency = 1 }):Play()
    state.tweenService:Create(self.titleLabel, textFadeTween, { TextTransparency = 1 }):Play()
    if self.descriptionLabel then
        state.tweenService:Create(self.descriptionLabel, textFadeTween, { TextTransparency = 1 }):Play()
    end
    if self.iconLabel then
        state.tweenService:Create(self.iconLabel, textFadeTween, { ImageTransparency = 1 }):Play()
    end

    state.tweenService:Create(self.body, dismissTween, { Size = UDim2.new(1, -90, 1, 0) }):Play()
    local collapseTween = state.tweenService:Create(self.main, dismissTween, { Size = UDim2.new(1, 0, 0, 0) })
    local connection
    connection = collapseTween.Completed:Connect(function(playbackState)
        if connection then
            connection:Disconnect()
            connection = nil
        end
        if playbackState ~= Enum.PlaybackState.Completed or not self._dismissed or not self.main.Parent then
            return
        end

        for _, conn in self._connections do
            self.window:Disconnect(conn)
        end
        self.window:DestroySubtree(self.main)
    end)
    collapseTween:Play()
end

return Notification
