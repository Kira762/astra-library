local Toast = {}
Toast.__index = Toast
Toast.__type = "Toast"

local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local functions = require(script.Parent.Parent.functions)
local constants = require(utilities.constants)
local imageModule = require(script.Parent.Parent.images.image)
local haptic = require(utilities.HapticEngine)

local showTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local expandTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local fadeInTween = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local textFadeTween = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local dismissTween = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local avatarSize = 24
local largeIconSize = 32
local smallIconPad = 18
local largeIconPad = 18
local avatarLeftPad = 10
local avatarRightPad = 28
local contentSpacing = 12
local outerPadding = 8
local layoutPad = 19
local minContentWidth = 140
local maxContentWidth = 320

local maxVisible = 6

local topPosition = UDim2.new(0.5, 0, 0.5, -180)
local bottomPosition = UDim2.new(0.5, 0, 0.5, 180)
local centerPosition = UDim2.new(0.5, 0, 0.5, 0)

local function autoDuration(text)
    return math.clamp(#text * 0.06 + 3, 3, 9)
end

local function resolveAssetId(asset)
    if type(asset) == "number" then
        return "rbxassetid://" .. tostring(asset)
    end
    return asset
end

function Toast.new(window, props, parent, release)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = props.title or props.Title or "",
        subtitle = props.subtitle or props.Subtitle,
        icon = window:ResolveIcon(props.icon or props.Icon),
        avatar = props.avatar or props.Avatar,
        minWidth = props.minWidth or props.MinWidth,
        subtitleAbove = props.subtitleAbove or props.SubtitleAbove or false,
        position = props.position or "Top",
        _hovered = false,
        _dismissed = false,
        -- [[The entrance queue's slot: released when this toast's entrance is
        -- committed, which is what lets a burst of them cascade instead of all
        -- landing on one frame. See `components/overlayQueue.luau`.]]
        _release = release,
    }, Toast)

    self.duration = props.duration or props.Duration or autoDuration(self.title .. (self.subtitle or ""))

    local isAvatar = self.avatar ~= nil and self.avatar ~= 0
    local hasIcon = isAvatar or (self.icon ~= nil and self.icon ~= 0 and self.icon ~= "")
    self._iconImage = if isAvatar
        then imageModule.avatar(self.avatar, function(uri)
            if self.iconLabel and not self._dismissed and self.main.Parent then
                imageModule.assign(self.iconLabel, "Image", uri)
            end
        end)
        elseif hasIcon then resolveAssetId(self.icon)
        else nil
    self._iconSize = if isAvatar then largeIconSize else avatarSize
    self._leftPad = if isAvatar then avatarLeftPad else smallIconPad
    self._rightPad = if isAvatar then avatarRightPad else largeIconPad
    self._minWidth = math.clamp(self.minWidth or 0, minContentWidth, maxContentWidth)
    local hasSubtitle = self.subtitle ~= nil and self.subtitle ~= ""

    self.main = self.window:Create("Frame", {
        Name = "Toast",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.toast,
        Parent = parent or self.window.toasts,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, outerPadding),
        Parent = self.main,
    })

    self.body = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 1, 0),
        Position = if self.position == "Bottom" then bottomPosition else topPosition,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true,
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.toast,
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
        PaddingLeft = UDim.new(0, self._leftPad),
        PaddingRight = UDim.new(0, self._rightPad),
        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, layoutPad),
        Parent = self.body,
    })

    if hasIcon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self._iconImage,
            Size = UDim2.fromOffset(self._iconSize, self._iconSize),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = constants.zIndex.toastContent,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            Parent = self.body,
        }, if isAvatar then nil else { ImageColor3 = "ContentColor" })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = self.iconLabel,
        })
    end

    self.container = self.window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, hasSubtitle and 32 or 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.toastContent,
        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = self.container,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        Text = self.title,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = if self.subtitleAbove then 2 else 1,
        ZIndex = constants.zIndex.toastContent,
        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "TitleFont" })

    if hasSubtitle then
        self.subtitleLabel = self.window:Create("TextLabel", {
            Text = self.subtitle,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 14),
            BackgroundTransparency = 1,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = if self.subtitleAbove then 1 else 2,
            ZIndex = constants.zIndex.toastContent,
            TextTransparency = 1,
            Parent = self.container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })
    end

    self.window._toastCount = (self.window._toastCount or 0) + 1
    self.main.LayoutOrder = -self.window._toastCount

    local liveToasts = self.window._liveToasts
    if not liveToasts then
        liveToasts = {}
        self.window._liveToasts = liveToasts
    end
    local liveList = liveToasts[self.main.Parent]
    if not liveList then
        liveList = {}
        liveToasts[self.main.Parent] = liveList
    end
    self._live = liveList
    table.insert(liveList, self)
    while #liveList > maxVisible do
        local oldest = table.remove(liveList, 1)
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

function Toast:_measure()
    local titleWidth = functions.textWidth(self.window.theme.TitleFont, 16, self.title)
    local subtitleWidth = if self.subtitleLabel
        then functions.textWidth(self.window.theme.Font, 14, self.subtitle)
        else 0
    local textWidth = math.max(titleWidth, subtitleWidth)

    local iconOffset = if self.iconLabel then self._leftPad + self._iconSize + layoutPad else self._leftPad
    local totalWidth = math.clamp(iconOffset + textWidth + self._rightPad, self._minWidth, maxContentWidth)

    if iconOffset + textWidth + self._rightPad > maxContentWidth then
        local availableWidth = maxContentWidth - iconOffset - self._rightPad
        for _, label in { self.titleLabel, self.subtitleLabel } do
            if label then
                label.AutomaticSize = Enum.AutomaticSize.None
                label.TextTruncate = Enum.TextTruncate.AtEnd
                label.Size = UDim2.fromOffset(availableWidth, label.Size.Y.Offset)
            end
        end
    end

    local textHeight = if self.subtitleLabel then 16 + 1 + 14 else 16
    local totalHeight = math.max(textHeight, if self.iconLabel then self._iconSize else 0) + 18

    return totalWidth, totalHeight
end

-- [[Hands the entrance slot back to the queue once the toast's entrance is
-- committed (or once it is dismissed, whichever comes first) so the next
-- queued overlay can start. Idempotent by design: both paths reach it.]]
function Toast:_entranceDone()
    local release = self._release
    if not release then
        return
    end
    self._release = nil
    release()
end

function Toast:_show()
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end

    haptic.notify()

    local width, height = self:_measure()
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end
    self.main.Size = UDim2.new(0, width, 0, 0)

    state.tweenService:Create(self.main, expandTween, { Size = UDim2.new(0, width, 0, height + outerPadding) }):Play()
    state.tweenService:Create(self.body, showTween, { Position = centerPosition }):Play()
    state.tweenService:Create(self.body, fadeInTween, { BackgroundTransparency = 0 }):Play()
    state.tweenService:Create(self.stroke, fadeInTween, { Transparency = 0.9 }):Play()
    state.tweenService:Create(self.shadow, textFadeTween, { Transparency = 0.6 }):Play()
    state.tweenService:Create(self.titleLabel, textFadeTween, { TextTransparency = 0 }):Play()

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end
    if self.iconLabel then
        state.tweenService:Create(self.iconLabel, textFadeTween, { BackgroundTransparency = 0.95 }):Play()
        state.tweenService:Create(self.iconLabel, textFadeTween, { ImageTransparency = 0 }):Play()
    end

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        self:_entranceDone()
        return
    end
    if self.subtitleLabel then
        state.tweenService:Create(self.subtitleLabel, textFadeTween, { TextTransparency = 0.5 }):Play()
    end

    -- [[Everything still running is the hold time now, not the entrance, so
    -- the next toast in the queue may take its turn.]]
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

function Toast:_dismiss()
    if self._dismissed then
        return
    end
    self._dismissed = true

    -- [[A toast retired before its entrance finished still owes the queue its
    -- slot; `_entranceDone` is a no-op once the show path handed it back.]]
    self:_entranceDone()

    local liveList = self._live
    local index = liveList and table.find(liveList, self)
    if liveList and index then
        table.remove(liveList, index)
    end

    if not self.main.Parent then
        return
    end

    state.tweenService:Create(self.body, fadeInTween, { BackgroundTransparency = 1 }):Play()
    state.tweenService:Create(self.stroke, fadeInTween, { Transparency = 1 }):Play()
    state.tweenService:Create(self.shadow, textFadeTween, { Transparency = 1 }):Play()
    state.tweenService:Create(self.titleLabel, textFadeTween, { TextTransparency = 1 }):Play()
    if self.subtitleLabel then
        state.tweenService:Create(self.subtitleLabel, textFadeTween, { TextTransparency = 1 }):Play()
    end
    if self.iconLabel then
        state.tweenService
            :Create(self.iconLabel, textFadeTween, { ImageTransparency = 1, BackgroundTransparency = 1 })
            :Play()
    end

    state.tweenService:Create(self.body, dismissTween, { Size = UDim2.new(1, -60, 1, 0) }):Play()
    local collapseTween =
        state.tweenService:Create(self.main, dismissTween, { Size = UDim2.new(0, self.main.Size.X.Offset, 0, 0) })
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

return Toast
