--[[
The Stepper ("Value Configuration") is the library's numeric counter row:
an integrated pill capsule with a `[−]` button, a highlighted editable
value field, and a `[+]` button — three controls that read as one
surface, not three.

Behaviour contract:
  * the value starts at `0` (or the `value` prop) and never leaves
    `[min, max]` — `min` defaults to `0` and `max` is optional, so the
    control has no upper limit unless one is specified;
  * (+) adds `step`, (−) subtracts `step`, each clamped, and the display
    rewrites in real time after every click;
  * the middle field is a real input: typed numbers are rounded to the
    step's precision and clamped into range on commit, and anything that
    does not parse restores the previous value.

The row carries an optional subtitle below the title (the `description`
prop, attached through the shared description engine — same recipe as
the Stat). The cluster on the right is one pill: the buttons flank the
focal value field with the same gap on both sides so the eye lands on
the number, and the whole pill wears the neutral button surface with a
hairline stroke so it reads as a single, intentional control rather than
three adjacent buttons. The value field itself wears the accent stroke
at rest and tightens to the active focus glow when focused, which is
what makes it the focal point of the row.
]]

local state = {}
state.__index = state
state.__type = "Stepper"

local utilities = script.Parent.Parent.utilities

local functions = require(script.Parent.Parent.functions)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local moveable = require(utilities.moveable)
local lockable = require(utilities.lockable)
local description = require(script.Parent.description)

--[[
Value, field and button motion all ride the shared service: `snappy`
carries hover/press feedback and value changes, `fast` follows the focus
ring. Nothing here is continuous enough to need its own spec.
]]
local motion = require(utilities.motion)
local hoverSpec = "snappy"
local focusSpec = "fast"

--[[
Cluster metrics, in one place. The whole cluster is a single pill: the
two buttons and the field share one rounded surface with hairline
dividers, so the row is symmetric around the value — the focal point
the design asks for. The field is 2px taller than the buttons (30 vs 28)
and carries the larger text, which is what makes it read as the primary
surface rather than a third button.
]]
local buttonSize = 28
local fieldWidth = 56
local fieldHeight = 30
local clusterGap = 6
local glyphSize = 14
local valueTextSize = 17
local clusterWidth = buttonSize * 2 + fieldWidth + clusterGap * 2
local clusterRadius = fieldHeight / 2

--[[ Decimal places a step needs (the slider's increment rule). ]]
local function placesFor(step: number): number
    local places = 0
    while places < 6 do
        local scaled = step * 10 ^ places
        if math.abs(scaled - math.round(scaled)) < 1e-9 then
            break
        end
        places += 1
    end
    return places
end

--[[
Round to that precision so repeated ± step arithmetic can never drift
(0.1 + 0.1 + 0.1 must display — and stay — 0.3, not 0.30000000000000004).
Typed entries go through the same rounding, so the field always shows
exactly what the value is.
]]
local function roundTo(value: number, places: number): number
    local scale = 10 ^ places
    return math.round(value * scale) / scale
end

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = element.name or element.Name or "Stepper",
        icon = tab.window:ResolveIcon(element.icon or element.Icon),
        description = element.description or element.Description,
        forgetState = element.forgetState or element.ForgetState or tab.forgetState,

        -- Range/step normalization mirrors the slider: swapped bounds are
        -- tolerated, a non-positive step falls back to 1, and `max` may be
        -- nil which leaves the control unbounded above.
        min = tonumber(element.min or element.Min) or 0,
        max = tonumber(element.max or element.Max),
        step = tonumber(element.step or element.Step or element.increment or element.Increment) or 1,

        callback = element.callback or element.Callback or function() end,
        _cancelingEdit = false,
    }, state)

    if self.max and self.max < self.min then
        self.min, self.max = self.max, self.min
    end
    if self.step <= 0 then
        self.step = 1
    end
    self._decimals = placesFor(self.step)

    -- Default state is 0, clamped into range (so a min of 5 starts at 5).
    self.value = self:_clamp(element.value or element.Value or 0)

    self.flag = element.flag
        or element.Flag
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

    --[[
    Title block: leading icon + name, like every other card. The
    description (subtitle) is attached as a wrapped line beneath the
    title — the same recipe the Stat uses, so a wrapped subtitle
    reserves exactly the room it renders in and the cluster rides up
    by the extra height.
    ]]
    description.attach(self)

    self.container = self.window:Create("Frame", {
        Size = UDim2.new(1, -(clusterWidth + 45), 0, 16),
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
        SortOrder = Enum.SortOrder.LayoutOrder,
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
        Text = locale.t(self.name),
        Size = UDim2.new(1, if self.icon then -21 else 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
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

    --[[
    The pill cluster: a single rounded surface carrying the two icon
    buttons and the value field together. The pill wears the neutral
    button surface with the surface stroke, and the value field sits on
    top of it (slightly larger) so the three controls read as one
    capsule rather than three independent buttons. The cluster rides up
    by the description's extra height, just like the bottom-anchored
    rows on every other card with a subtitle.
    ]]
    self.cluster = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -15, 0.5, -(self._descriptionExtra or 0) / 2),
        Size = UDim2.fromOffset(clusterWidth, fieldHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = self.main,
    }, { BackgroundColor3 = "NeutralButton" })

    self.window:Create("UICorner", {
        Parent = self.cluster,
        CornerRadius = UDim.new(0, clusterRadius),
    })

    self.clusterStroke = self.window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.cluster,
    }, { Color = "SurfaceStroke" })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, clusterGap),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.cluster,
    })

    self.minusButton, self.minusStroke = self:_buildStepButton("minus", 0)
    self:_buildField()
    self.plusButton, self.plusStroke = self:_buildStepButton("plus", 2)

    --[[ Interaction: one tap = one clamped step, both ends alike. ]]
    self.window:ConnectFor(self, self.minusButton.MouseButton1Click, function()
        if self:IsLocked() or not self.window:_interactive() then
            return
        end
        haptic.click()
        self:_pressButton(self.minusButton, "_minusHover")
        self:Decrement()
    end)

    self.window:ConnectFor(self, self.plusButton.MouseButton1Click, function()
        if self:IsLocked() or not self.window:_interactive() then
            return
        end
        haptic.click()
        self:_pressButton(self.plusButton, "_plusHover")
        self:Increment()
    end)

    self.window:_wireElementHover(self)
    self:_showValue(self.value)
    lockable.register(self, element)
    return self
end

--[[
One of the two icon buttons: a 28px rounded square nested inside the
shared pill, with the resolved glyph centred on it. The button is
transparent at rest so the pill's surface bleeds through (the whole
cluster is one capsule); a hover lifts the local surface to the neutral
hover colour and a press dips to the pressed surface. The vertical
dividers on each button give the row the look of three segments —
the value field in the middle is the focal point.
]]
function state:_buildStepButton(glyphName: string, layoutOrder: number)
    local window = self.window

    local button = window:Create("TextButton", {
        Text = "",
        TextTransparency = 1,
        Size = UDim2.fromOffset(buttonSize, buttonSize),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = self.cluster,
    }, { BackgroundColor3 = "NeutralButton" })

    window:Create("UICorner", {
        Parent = button,
        CornerRadius = UDim.new(0, buttonSize / 2),
    })

    local stroke = window:Create("UIStroke", {
        Transparency = 1,
        Parent = button,
    }, { Color = "SurfaceStroke" })

    local glyph = window:ResolveIcon(glyphName)
    if glyph then
        window:Create("ImageLabel", {
            Image = glyph,
            Size = UDim2.fromOffset(glyphSize, glyphSize),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ImageTransparency = 0.1,
            ZIndex = 6,
            Parent = button,
        }, { ImageColor3 = "ActionColor" })
    end

    local hoverKey = if layoutOrder == 0 then "_minusHover" else "_plusHover"
    window:ConnectFor(self, button.MouseEnter, function()
        if not self.window:_interactive() then
            return
        end
        self[hoverKey] = true
        motion.tween(button, { BackgroundColor3 = self.window.theme.NeutralButtonHover }, hoverSpec)
    end)

    window:ConnectFor(self, button.MouseLeave, function()
        self[hoverKey] = false
        motion.tween(button, { BackgroundColor3 = self.window.theme.NeutralButton }, hoverSpec)
    end)

    return button, stroke
end

--[[
Press feedback without a colour race: the tap dips the button to the
pressed surface and the delayed release returns it to whichever surface
the pointer is actually over (hover state is tracked per button).
]]
function state:_pressButton(button, hoverKey: string)
    motion.tween(button, { BackgroundColor3 = self.window.theme.ElementPressed }, focusSpec)
    task.delay(0.09, function()
        if self.window.unloaded or not button.Parent then
            return
        end
        local rest = if self[hoverKey] then self.window.theme.NeutralButtonHover else self.window.theme.NeutralButton
        motion.tween(button, { BackgroundColor3 = rest }, hoverSpec)
    end)
end

--[[
The value field — the focal point inside the pill. It is a real
TextBox dressed as the input family's field (FieldBackground + accent
stroke), but larger and wearing the accent stroke at rest so the eye
lands on the number first. Invalid text never lands: the sanitizer keeps
digits, dot and sign while typing, and a commit that does not parse
restores the displayed value.
]]
function state:_buildField()
    local window = self.window

    self.box = window:Create("Frame", {
        Size = UDim2.fromOffset(fieldWidth, fieldHeight),
        BorderSizePixel = 0,
        LayoutOrder = 1,
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = self.cluster,
    }, { BackgroundColor3 = "FieldBackground" })

    window:Create("UICorner", {
        Parent = self.box,
        CornerRadius = UDim.new(0, fieldHeight / 2),
    })

    self.boxStroke = window:Create("UIStroke", {
        Transparency = 0.55,
        Parent = self.box,
    }, { Color = "AccentStroke" })

    self._glowIdle = 0.85
    self.input = window:Create("TextBox", {
        Text = self:_format(self.value),
        Size = UDim2.new(1, -8, 0, valueTextSize + 2),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = valueTextSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        TextTransparency = 0.1,
        ZIndex = 6,
        Parent = self.box,
    }, { TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })

    -- While typing: keep digits, dots and signs only.
    window:ConnectFor(self, self.input:GetPropertyChangedSignal("Text"), function()
        local sanitized = self.input.Text:gsub("[^%d%.%-]", "")
        if sanitized ~= self.input.Text then
            self.input.Text = sanitized
        end
    end)

    window:ConnectFor(self, self.input.Focused, function()
        if self:IsLocked() or not self.window:_interactive() then
            self:CancelEditing()
            return
        end
        motion.tween(self.input, { TextTransparency = 0 }, focusSpec)
        motion.tween(self.boxStroke, { Transparency = 0.25 }, focusSpec)
    end)

    window:ConnectFor(self, self.input.FocusLost, function()
        motion.tween(self.input, { TextTransparency = 0.1 }, focusSpec)
        motion.tween(self.boxStroke, { Transparency = 0.55 }, focusSpec)
        if self._cancelingEdit then
            self._cancelingEdit = false
            return
        end
        if self:IsLocked() then
            return
        end
        self:_commit(self.input.Text)
    end)
end

function state:_format(value: number): string
    return string.format("%." .. self._decimals .. "f", value)
end

function state:_showValue(value: number)
    local text = self:_format(value)
    if self.input.Text ~= text then
        self.input.Text = text
    end
end

-- Round to the step's precision, then clamp into [min, max].
function state:_clamp(value: number): number
    value = roundTo(tonumber(value) or 0, self._decimals)
    return math.clamp(value, self.min, if self.max then self.max else math.huge)
end

--[[
Commit a typed edit: parse, clamp, rewrite the display. Unparseable
text restores the previous value without a callback — the field always
ends up showing the live value exactly.
]]
function state:_commit(text: string, skipCallback: boolean?)
    local parsed = tonumber(text)
    if parsed == nil or parsed ~= parsed or parsed == math.huge or parsed == -math.huge then
        self:_showValue(self.value)
        return
    end

    local changed = parsed ~= self.value
    self:Set(parsed, skipCallback)

    if changed and not skipCallback and not self.window._loading then
        self.window:_flashResult(self, true)
    end
end

-- End keyboard focus without committing. A lock preserves the
-- committed value and the visible draft, exactly like Input.
function state:CancelEditing()
    if not self.input then
        return
    end
    local focused = false
    local focusRead = pcall(function()
        focused = self.input:IsFocused()
    end)
    if focusRead and not focused then
        return
    end

    self._cancelingEdit = true
    pcall(function()
        self.input:ReleaseFocus()
    end)
    task.defer(function()
        self._cancelingEdit = false
    end)
end

function state:SetInteractionLocked(locked)
    if not self.input then
        return
    end
    self.input.TextEditable = not locked
    self.input.Interactable = not locked
end

function state:Get(): number
    return self.value
end

--[[
Set the value: rounded, clamped and displayed in real time. The
callback only fires when the value actually changes — a (−) tap at the
floor or a (+) tap at the ceiling is a deliberate no-op — and is
skipped entirely for `skipCallback` restores.
]]
function state:Set(value, skipCallback: boolean?)
    local nextValue = self:_clamp(value)
    local changed = nextValue ~= self.value
    self.value = nextValue
    self:_showValue(nextValue)

    if changed and not skipCallback then
        self.window:_runGuarded(self, self.callback, nextValue)
    end
    if changed then
        self.window:_persist(self)
    end
end

-- One (+) tap: add step and let Set clamp.
function state:Increment(skipCallback: boolean?)
    self:Set(self.value + self.step, skipCallback)
end

-- One (−) tap: subtract step; Set keeps the value at or above `min`.
function state:Decrement(skipCallback: boolean?)
    self:Set(self.value - self.step, skipCallback)
end

function state:_fieldGlow()
    if not self.glow then
        self.glow = self.window:CreateGlow(self.box, "FieldGlow", 20, self._glowIdle)
    end
    return self.glow
end

function state:_setShown(shown, animate)
    local w = self.window
    if shown then
        w:_revealCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = w.theme.FieldTransparency }, animate)
        w:_reveal(self.boxStroke, { Transparency = 0.55 }, animate)
        w:_reveal(self.input, { TextTransparency = 0.1 }, animate)
    else
        w:_hideCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.boxStroke, { Transparency = 1 }, animate)
        w:_reveal(self.input, { TextTransparency = 1 }, animate)
    end

    -- The pill cluster rests as the neutral button surface (0), the field
    -- above on the theme's field transparency; hidden, every part goes
    -- to 1. The two buttons inside the pill inherit the pill's transparency
    -- behaviour and the glyph on each button fades with its parent.
    w:_reveal(self.cluster, { BackgroundTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.clusterStroke, { Transparency = if shown then 0.85 else 1 }, animate)
    for index, button in { self.minusButton, self.plusButton } do
        local stroke = if index == 1 then self.minusStroke else self.plusStroke
        w:_reveal(button, { BackgroundTransparency = if shown then 0 else 1 }, animate)
        w:_reveal(stroke, { Transparency = if shown then 0.85 else 1 }, animate)
        for _, child in button:GetChildren() do
            if child:IsA("ImageLabel") then
                w:_reveal(child, { ImageTransparency = if shown then 0.1 else 1 }, animate)
            end
        end
    end
end

function state:_refreshTheme()
    motion.tween(self.box, { BackgroundTransparency = self.window.theme.FieldTransparency }, "smooth")
end

function state:_minWidth()
    local width = 40
    if self.icon then
        width += 22
    end
    width += functions.textWidth(self.window.theme.Font, 16, locale.resolve(self.name))
    width += 12
    width += clusterWidth + 15
    return math.max(width, 190)
end

moveable(state)
lockable(state)

return state
