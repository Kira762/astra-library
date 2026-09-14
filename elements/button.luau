local state = {}
state.__index = state
state.__type = "Button"

local constants = script.Parent.Parent.utilities

local Button = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.lockable)
local icon = require(constants.locale)
local callback = require(constants.HapticEngine)
local baseCard = require(script.Parent.baseCard)
local description = require(script.Parent.description)
local element = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function state.new(tab, frame)
    frame = if typeof(frame) == "table" then frame else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = frame.name or frame.Name or "Button",
        icon = tab.window:ResolveIcon(frame.icon or frame.Icon),
        compact = tab.compact or false,
        callback = frame.callback or frame.Callback or function() end,
    }, state)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    return self
end

function state:_runCallback()
    self.window:_runGuarded(self, self.callback)
end

function state:_buildFull()
    baseCard.buildFull(self, {
        height = 43,
        rightPadding = 40,
        titleText = icon.t(self.name),
    })

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,

        Parent = self.main,
    })

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        callback.click()
        Button.tweenService
            :Create(
                self.stroke,
                element,
                { Transparency = 1 }
            )
            :Play()
        Button.tweenService
            :Create(
                self.main,
                TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, -26, 0, description.height(self, 43)) }
            )
            :Play()

        self:_runCallback()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        Button.tweenService
            :Create(
                self.main,
                TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, -20, 0, description.height(self, 43)) }
            )
            :Play()
        Button.tweenService
            :Create(
                self.stroke,
                element,
                { Transparency = self.window:_elementStrokeTransparency(self, false) }
            )
            :Play()
    end)
end

function state:_buildCompact()
    local window = self.window

    self.main, self.stroke, self.interact = window:_buildCompactRow(self.tab, self.name)
    self.hoverOverlay = self.interact

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),

        Parent = self.interact,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6),

        Parent = self.interact,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,

            ImageTransparency = 1,
            Parent = self.interact,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = icon.t(self.name),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.interact,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        callback.click()
        Button.tweenService
            :Create(
                self.stroke,
                element,
                { Transparency = 1 }
            )
            :Play()

        self:_runCallback()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        Button.tweenService
            :Create(
                self.stroke,
                element,
                { Transparency = self.window:_elementStrokeTransparency(self, false) }
            )
            :Play()
    end)
end

function state:_setShown(stroke, hoverOverlay)
    if stroke then
        self.window:_revealCommon(self, hoverOverlay)
    else
        self.window:_hideCommon(self, hoverOverlay)
    end
end

function state:_minWidth()
    local w = 32
    if self.icon then
        w += 22
    end
    w += tab.textWidth(self.window.theme.Font, 16, icon.resolve(self.name))
    return w
end

props(state)
name(state)

return state
