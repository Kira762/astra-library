local state = {}
state.__index = state
state.__type = "Progress"

local constants = script.Parent.Parent.utilities

local Progress = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.locale)
local description = require(script.Parent.description)

local range = 60
local value = 8
local text = 20
local element = 6
local frame = 6

local fill = 16
local textLabel = 14
local a14 = 0.4

local a15 = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local a16 = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.85),
    NumberSequenceKeypoint.new(1, 0),
})

local a17 = 0.9
local a18 = TweenInfo.new(a17, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, -1, true)

local function a19(a20: unknown): number?
    local a21 = tonumber(a20)
    if a21 == nil or a21 ~= a21 or math.abs(a21) == math.huge then
        return nil
    end
    return a21
end

function state.new(tab, a22)
    a22 = if typeof(a22) == "table" then a22 else {}

            local a23 = a19(a22.steps or a22.Steps)
    a23 = if a23 and a23 >= 2 then math.floor(a23) else nil

    local a24 = a22.range or a22.Range
    local a25 = a19(a24 and a24[1]) or 0
    local a26 = a19(a24 and a24[2]) or a23 or 1
    if a25 > a26 then
        a25, a26 = a26, a25
    end

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = a22.name or a22.Name or "Progress",
        description = a22.description or a22.Description,
        icon = tab.window:ResolveIcon(a22.icon or a22.Icon),

        min = a25,
        max = a26,
        steps = a23,
        value = 0,
                text = a22.text or a22.Text,
        format = a22.format or a22.Format,
        showValue = if a22.showValue == nil then true else a22.showValue == true,
        indeterminate = a22.indeterminate or a22.Indeterminate or false,
    }, state)

    self.value = self:_clamp(a19(a22.value or a22.Value) or a25)

    self:_build()

    return self
end

function state:_clamp(a27: number): number
    return math.clamp(a19(a27) or self.min, self.min, self.max)
end

function state:_ratio(): number
    local a28 = self.max - self.min
    if a28 <= 0 then
        return 1
    end
    return (self.value - self.min) / a28
end

function state:_filledSteps(): number
    local a29 = self.steps :: number
    return math.clamp(math.round(self:_ratio() * a29), 0, a29)
end

function state:_readout(): string
    if self.text then
        return name.resolve(self.text)
    end
    if self.format then
        local ok, a30 = pcall(self.format, self.value, self.min, self.max)
        if ok and type(a30) == "string" then
            return a30
        end
    end
        if self.steps then
        return string.format("%d/%d", self:_filledSteps(), self.steps)
    end
    return string.format("%d%%", math.round(self:_ratio() * 100))
end

function state:_build()
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, range),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

                BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)

    -- [[A description grows the card before the track is built, so the
    -- [[bottom-anchored bar and steps ride up above the line instead of
    -- [[drawing over it.]]
    description.attach(self)

        self.container = self.window:Create("Frame", {
        Size = UDim2.new(1, -110, 0, fill),
        Position = UDim2.new(0, text, 0, 20),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

                        ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = name.t(self.name),

        Size = UDim2.new(1, if self.icon then -22 else 0, 0, fill),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = fill,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.readout = self.window:Create("TextLabel", {
        Text = self:_readout(),

        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -text, 0, 20),
        Size = UDim2.fromOffset(50, textLabel),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = textLabel,
        TextXAlignment = Enum.TextXAlignment.Right,
        Visible = self.showValue,

                TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    if self.steps then
        self:_buildSteps()
        return
    end

                self.track = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -16 - (self._descriptionExtra or 0)),
        Size = UDim2.new(1, -text * 2, 0, value),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "SliderBackground" })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.track,
    })

    self.fill = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromScale(if self.indeterminate then 0 else self:_ratio(), 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,

        BackgroundTransparency = 1,
        Parent = self.track,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.fill,
    })

    self.window:Create("UIGradient", {
        Offset = Vector2.new(0, 0.5),
        Rotation = 2,
        Transparency = a16,

        Parent = self.fill,
    }, { Color = { "SliderProgress", tab.toColorSequence } })

    self.fillGlow = self.window:CreateGlow(self.fill, "AccentColor", 20, 1)

    if self.indeterminate then
        self:_startSweep()
    end
end

function state:_buildSteps()
    local a31 = self.steps :: number

    self.track = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -17 - (self._descriptionExtra or 0)),
        Size = UDim2.new(1, -text * 2, 0, element),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, frame),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.track,
    })

    self.stepFrames = {}
    for a32 = 1, a31 do
                local a33 = self.window:Create("Frame", {
            Size = UDim2.new(1 / a31, -(frame * (a31 - 1)) / a31, 1, 0),
            BorderSizePixel = 0,
            LayoutOrder = a32,
                                                BackgroundTransparency = 1,
            Parent = self.track,
        }, { BackgroundColor3 = "SliderBackground" })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = a33,
        })

                local a34 = self.window:Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            ZIndex = 2,

            BackgroundTransparency = 1,
            Parent = a33,
        })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = a34,
        })

                        self.window:Create("UIGradient", {
            Rotation = 90,

            Parent = a34,
        }, { Color = { "SliderProgress", tab.toColorSequence } })

        table.insert(self.stepFrames, { segment = a33, fill = a34 })
    end
end

function state:_startSweep()
    if self._sweep or self.steps then
        return     end

    self.fill.AnchorPoint = Vector2.new(0, 0.5)
    self.fill.Position = UDim2.fromScale(0, 0.5)
    self.fill.Size = UDim2.fromScale(0, 1)

    self._sweep = Progress.tweenService:Create(self.fill, a18, { Size = UDim2.fromScale(1, 1) })
    self._sweep:Play()
end

function state:_stopSweep()
    if not self._sweep then
        return
    end
    self._sweep:Cancel()
    self._sweep = nil
    self.fill.AnchorPoint = Vector2.new(0, 0.5)
    self.fill.Position = UDim2.fromScale(0, 0.5)
end

function state:_render(a35: boolean?)
    self.readout.Text = self:_readout()

    if self.steps then
                if not self._shown then
            return
        end
        local a36 = self:_filledSteps()
        for a37, a38 in self.stepFrames do
            local a39 = if a37 <= a36 then 0 else 1
            if a35 == false then
                a38.fill.BackgroundTransparency = a39
            else
                Progress.tweenService:Create(a38.fill, a15, { BackgroundTransparency = a39 }):Play()
            end
        end
        return
    end

    local a40 = UDim2.fromScale(self:_ratio(), 1)
    if a35 == false then
        self.fill.Size = a40
    else
        Progress.tweenService:Create(self.fill, a15, { Size = a40 }):Play()
    end
end

function state:Set(a41)
    self.value = self:_clamp(a41)

    if self.indeterminate then
        self.indeterminate = false
        self:_stopSweep()
    end

    self:_render()
end

function state:Get(): number
    return self.value
end

function state:GetPercentage(): number
    return self:_ratio()
end

function state:SetRange(a42, a43)
    a42 = a19(a42) or self.min
    a43 = a19(a43) or self.max
    if a42 > a43 then
        a42, a43 = a43, a42
    end

    self.min, self.max = a42, a43
    self.value = self:_clamp(self.value)
    self:_render()
end

function state:SetText(a44)
    self.text = a44
    self.readout.Text = self:_readout()
end

function state:SetIndeterminate(a45)
    a45 = a45 == true
    if a45 == self.indeterminate then
        return
    end
    self.indeterminate = a45

    if a45 then
        self:_startSweep()
    else
        self:_stopSweep()
        self:_render(false)
    end
end

function state:_setShown(a46, a47)
    local w = self.window

    self._shown = a46
    w:_reveal(self.readout, { TextTransparency = if a46 then a14 else 1 }, a47)

    if a46 then
        w:_revealCommon(self, a47)
    else
        w:_hideCommon(self, a47)
    end

    if self.steps then
        local a48 = self:_filledSteps()
        for a49, a50 in self.stepFrames do
            w:_reveal(a50.segment, { BackgroundTransparency = if a46 then 0 else 1 }, a47)
            w:_reveal(a50.fill, { BackgroundTransparency = if a46 and a49 <= a48 then 0 else 1 }, a47)
        end
        return
    end

    w:_reveal(self.track, { BackgroundTransparency = if a46 then 0 else 1 }, a47)
    w:_reveal(self.fill, { BackgroundTransparency = if a46 then 0 else 1 }, a47)
    w:_reveal(self.fillGlow, { Transparency = if a46 then w.theme.AccentGlow else 1 }, a47)
end

function state:Remove()
    self:_stopSweep()
    self.main:Destroy()
end

props(state)

return state
