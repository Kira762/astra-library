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
-- [[The click choreography rides the motion service's specs: the tap glyph
-- dips on `fast` and springs back on `settle` (a small overshoot that reads
-- as a physical press), the card nudges in on `snappy` and lands back on
-- `settle`, and the stroke follows hover on `snappy`.]]
local element = "snappy"
local tapPress = "fast"
local tapRelease = "settle"

-- [[Built-in "tap" glyph for the card's right edge. Candidates are tried in
-- [[catalog order and the first hit wins: `icons.resolve` answers an
-- [[unresolved request with the request itself, so a changed string is the
-- [[signal that a name (or a `custom_asset/` file) actually loaded. `hand-tap`
-- [[is the phosphor hand-with-tap-lines glyph the affordance is named after;
-- [[the rest keep the icon present when a host strips a pack.]]
local tapCandidates = { "hand-tap", "touch_app", "tabler:hand-click", "mouse-pointer-click", "hand" }

local function resolveTapIcon(window, override)
    if override ~= nil and override ~= true then
        return window:ResolveIcon(override)
    end
    for _, candidate in ipairs(tapCandidates) do
        local resolved = window:ResolveIcon(candidate)
        if resolved ~= candidate then
            return resolved
        end
    end
    return nil
end

function state.new(tab, frame)
    frame = if typeof(frame) == "table" then frame else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = frame.name or frame.Name or "Button",
        icon = tab.window:ResolveIcon(frame.icon or frame.Icon),
        description = frame.description or frame.Description,
        compact = tab.compact or false,
        callback = frame.callback or frame.Callback or function() end,
    }, state)

    -- [[The trailing tap affordance is built-in: present unless the caller
    -- [[opts out with `tapIcon = false`, and any icon request (name, pack
    -- [[name, or asset id) replaces the glyph.]]
    local tapValue = frame.tapIcon
    if tapValue == nil then
        tapValue = frame.TapIcon
    end
    if tapValue ~= false then
        self.tapImage = resolveTapIcon(self.window, tapValue)
    end

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

    -- [[The tap glyph sits in the card's right gutter, centred in the base
    -- [[region exactly like the title row, and is created after `interact`
    -- [[so it paints above the (invisible) click surface.]]

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,

        Parent = self.main,
    })

    if self.tapImage then
        local centerScale, centerOffset = description.center(self, 43)
        self.tapIcon = self.window:Create("ImageLabel", {
            Image = self.tapImage,
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.new(1, -15, centerScale, centerOffset),
            AnchorPoint = Vector2.new(1, 0.5),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            ImageTransparency = 1,
            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })

        self.tapScale = self.window:Create("UIScale", {
            Scale = 1,

            Parent = self.tapIcon,
        })
    end

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        callback.click()
        if self.tapScale then
            Button.tweenService:Create(self.tapScale, motion.spec(tapPress), { Scale = 0.78 }):Play()
        end
        Button.tweenService
            :Create(
                self.stroke,
                motion.spec(element),
                { Transparency = 1 }
            )
            :Play()
        Button.tweenService
            :Create(
                self.main,
                motion.spec("snappy"),
                { Size = UDim2.new(1, -26, 0, description.height(self, 43)) }
            )
            :Play()

        self:_runCallback()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        if self.tapScale then
            Button.tweenService:Create(self.tapScale, motion.spec(tapRelease), { Scale = 1 }):Play()
        end
        Button.tweenService
            :Create(
                self.main,
                motion.spec(tapRelease),
                { Size = UDim2.new(1, -20, 0, description.height(self, 43)) }
            )
            :Play()
        Button.tweenService
            :Create(
                self.stroke,
                motion.spec(element),
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

    -- [[Trailing item of the row: the same tap glyph as the full card, at the
    -- [[row's right edge. `interact` owns the row, so the icon is inside the
    -- [[click surface and tapping it is tapping the button.]]
    if self.tapImage then
        self.tapIcon = window:Create("ImageLabel", {
            Image = self.tapImage,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 2,

            ImageTransparency = 1,
            Parent = self.interact,
        }, { ImageColor3 = "ContentColor" })

        self.tapScale = window:Create("UIScale", {
            Scale = 1,

            Parent = self.tapIcon,
        })
    end

    self.window:_wireElementHover(self)

    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        callback.click()
        if self.tapScale then
            Button.tweenService:Create(self.tapScale, motion.spec(tapPress), { Scale = 0.78 }):Play()
        end
        Button.tweenService
            :Create(
                self.stroke,
                motion.spec(element),
                { Transparency = 1 }
            )
            :Play()

        self:_runCallback()

        task.wait(0.11)

        if self.window.unloaded then
            return
        end

        if self.tapScale then
            Button.tweenService:Create(self.tapScale, motion.spec(tapRelease), { Scale = 1 }):Play()
        end
        Button.tweenService
            :Create(
                self.stroke,
                motion.spec(element),
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
    if self.tapIcon then
        w += 22
    end
    w += tab.textWidth(self.window.theme.Font, 16, icon.resolve(self.name))
    return w
end

props(state)
name(state)

return state
