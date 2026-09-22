local coreState = require(script.Parent.Parent.core.state)
local motion = require(script.Parent.motion)
local textService = coreState.textService

local odometer = {}
odometer.__index = odometer

local reelCells = 20

local function measureText(font, size, text)
    local params = Instance.new("GetTextBoundsParams")
    params.Text = text
    params.Font = font
    params.Size = size
    params.Width = math.huge
    local ok, bounds = pcall(textService.GetTextBoundsAsync, textService, params)
    return if ok then bounds else Vector2.new(size * 0.6, size)
end

local metricsCache = {}
local cacheCount = 0
local cacheLimit = 64
local function fontMetrics(metricFont, metricSize)
        local cacheKey = tostring(metricFont.Family)
        .. "|"
        .. tostring(metricFont.Weight)
        .. "|"
        .. tostring(metricFont.Style)
        .. "|"
        .. tostring(metricSize)
    local entry = metricsCache[cacheKey]
    if entry then
        return entry
    end

    local advances, widest = {}, 0
    for measuredDigit = 0, 9 do
        local glyphWidth = math.ceil(measureText(metricFont, metricSize, tostring(measuredDigit)).X)
        advances[measuredDigit] = glyphWidth
        if glyphWidth > widest then
            widest = glyphWidth
        end
    end
    entry = { advance = advances, maxWidth = widest }
    if cacheCount >= cacheLimit then
        metricsCache = {}
        cacheCount = 0
    end
    metricsCache[cacheKey] = entry
    cacheCount += 1
    return entry
end

function odometer.new(window, container, options)
    options = options or {}
    local self = setmetatable({
        window = window,
        container = container,
        textSize = options.textSize or 16,
        transparency = options.transparency or 1,         duration = options.duration or 0.55,
        slots = {},         length = 0,     }, odometer)

    self.roll = TweenInfo.new(self.duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

            self.zIndex = math.max(container.ZIndex + 1, 6)

            self.height = math.ceil(self.textSize)

                local metrics = fontMetrics(window.theme.Font, self.textSize)
    self.advance = metrics.advance
    self.maxWidth = metrics.maxWidth

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = options.alignment or Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),

        Parent = container,
    })

    return self
end

function odometer:_reel(reelIndex)
    local slot = self.slots[reelIndex]
    if slot.reel then
        return slot.reel
    end

    local cell = self.window:Create("Frame", {
        Name = "Reel",
        Size = UDim2.fromOffset(self.maxWidth, self.height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = self.zIndex,

        Parent = self.container,
    })

    local strip = self.window:Create("Frame", {
        Size = UDim2.fromOffset(self.maxWidth, self.height),
        AnchorPoint = Vector2.new(0.5, 0),         Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = self.zIndex,

        Parent = cell,
    })

    --[[
    Rows are created on demand (see _rows): a reel only ever shows the
    contiguous band of rows its current transition walks over, so building
    all `reelCells` of them upfront left up to 19 clipped, never-visible
    TextLabels behind every digit of every readout — the single largest
    instance cost in the library (a Stat built 42 text labels for one
    value). Positions and glyphs are unchanged, so nothing about the roll
    looks different.
    ]]
    local reel = {
        cell = cell,
        strip = strip,
        digit = 0,
        target = 0,
        stripTween = nil,
        sizeTween = nil,
        rows = {},
    }
    slot.reel = reel
    return reel
end

--[[
Materialises the rows a transition needs, and only those. `rowIndex` is
the strip's own row number (0-9 is the digit, 10-19 the repeated digit
the downward roll travels through), matching _reelRoll's maths.
]]
function odometer:_row(reel, rowIndex)
    local label = reel.rows[rowIndex]
    if label then
        return label
    end

    label = self.window:Create("TextLabel", {
        Text = tostring(rowIndex % 10),
        Position = UDim2.fromOffset(0, rowIndex * self.height),
        Size = UDim2.fromOffset(self.maxWidth, self.height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = self.transparency,
        ZIndex = self.zIndex,

        Parent = reel.strip,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    reel.rows[rowIndex] = label
    return label
end

function odometer:_rows(reel, lowRow, highRow)
    lowRow = math.max(0, lowRow)
    highRow = math.min(reelCells - 1, highRow)
    for rowIndex = lowRow, highRow do
        self:_row(reel, rowIndex)
    end
end

function odometer:_static(staticIndex)
    local staticSlot = self.slots[staticIndex]
    if staticSlot.static then
        return staticSlot.static
    end

    local staticLabel = self.window:Create("TextLabel", {
        Name = "Static",
        Size = UDim2.fromOffset(0, self.height),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = self.transparency,
        ZIndex = self.zIndex,

        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    staticSlot.static = staticLabel
    return staticLabel
end

local function cancelTweens(reelState)
    if reelState.stripTween then
        reelState.stripTween:Cancel()
        reelState.stripTween = nil
    end
    if reelState.sizeTween then
        reelState.sizeTween:Cancel()
        reelState.sizeTween = nil
    end
end

function odometer:_reelSnap(snapReel, snapDigit)
    cancelTweens(snapReel)
    self:_rows(snapReel, snapDigit, snapDigit)
    snapReel.cell.Size = UDim2.fromOffset(self.advance[snapDigit], self.height)
    snapReel.strip.Position = UDim2.new(0.5, 0, 0, -snapDigit * self.height)
    snapReel.digit = snapDigit
    snapReel.target = snapDigit
end

function odometer:_reelRoll(rollReel, rollDigit, up)
        if rollReel.stripTween or rollReel.sizeTween then
        self:_reelSnap(rollReel, rollReel.target)
    end

    local currentDigit = rollReel.digit
    if currentDigit == rollDigit then
        return
    end

    local fromRow, toRow
    if up then
        fromRow = currentDigit
        toRow = currentDigit + (rollDigit - currentDigit) % 10     else
        fromRow = currentDigit + 10         toRow = fromRow - (currentDigit - rollDigit) % 10
    end

    self:_rows(rollReel, math.min(fromRow, toRow), math.max(fromRow, toRow))
    rollReel.strip.Position = UDim2.new(0.5, 0, 0, -fromRow * self.height)
    rollReel.target = rollDigit

        --[[
        `motion.spec` rescales the reel's TweenInfo with the active speed
    profile (cached per info), so the digit roll answers the same
    "Animation speed" setting as every other surface.
        ]]
    local roll = motion.spec(self.roll)
    local stripTween = coreState.tweenService:Create(rollReel.strip, roll, {
        Position = UDim2.new(0.5, 0, 0, -toRow * self.height),
    })
    local sizeTween = coreState.tweenService:Create(rollReel.cell, roll, {
        Size = UDim2.fromOffset(self.advance[rollDigit], self.height),
    })
    rollReel.stripTween = stripTween
    rollReel.sizeTween = sizeTween
    stripTween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed and rollReel.stripTween == stripTween then
            self:_reelSnap(rollReel, rollDigit)
        end
    end)
    stripTween:Play()
    sizeTween:Play()
    rollReel.digit = rollDigit
end

function odometer:_putDigit(digitIndex, digitValue, up, animate)
    local digitReel = self:_reel(digitIndex)
    local wasHidden = not digitReel.cell.Visible
    digitReel.cell.Visible = true
    digitReel.cell.LayoutOrder = -digitIndex
    if self.slots[digitIndex].static then
        self.slots[digitIndex].static.Visible = false
    end
    if animate and not wasHidden then
        self:_reelRoll(digitReel, digitValue, up)
    else
        self:_reelSnap(digitReel, digitValue)
    end
end

function odometer:_putStatic(staticPutIndex, staticChar)
    local staticTarget = self:_static(staticPutIndex)
    if not staticTarget.Visible then
                staticTarget.TextTransparency = self.transparency
    end
    staticTarget.Text = staticChar
    staticTarget.Visible = true
    staticTarget.LayoutOrder = -staticPutIndex
    if self.slots[staticPutIndex].reel then
        self.slots[staticPutIndex].reel.cell.Visible = false
    end
end

function odometer:_hide(hideIndex)
    local hideSlot = self.slots[hideIndex]
    if not hideSlot then
        return
    end
    if hideSlot.reel then
        hideSlot.reel.cell.Visible = false
    end
    if hideSlot.static then
        hideSlot.static.Visible = false
    end
end

function odometer:_render(renderValue, renderAnimate, up)
    renderValue = tostring(renderValue)

        if renderValue == self._lastText then
        return
    end
    self._lastText = renderValue

            local chars = {}
    for _, codepoint in utf8.codes(renderValue) do
        table.insert(chars, utf8.char(codepoint))
    end

    local charCount = #chars
    for i = 0, math.max(charCount, self.length) - 1 do
        self.slots[i] = self.slots[i] or {}
        if i < charCount then
            local glyphChar = chars[charCount - i]             if glyphChar:match("%d") then
                self:_putDigit(i, tonumber(glyphChar), up, renderAnimate)
            else
                self:_putStatic(i, glyphChar)
            end
        else
            self:_hide(i)
        end
    end
    self.length = charCount
end

function odometer:to(targetValue, up)
    self:_render(targetValue, true, up)
end

function odometer:snap(snapValue)
    self:_render(snapValue, false, true)
end

function odometer:reveal(targetTransparency, revealTweenInfo, revealOverride)
    self.transparency = targetTransparency
    for _, revealSlot in self.slots do
        if revealSlot.static and revealSlot.static.Visible then
            self.window:_reveal(revealSlot.static, { TextTransparency = targetTransparency }, revealTweenInfo, revealOverride)
        end
        if revealSlot.reel then
            for _, revealLabel in revealSlot.reel.strip:GetChildren() do
                if revealLabel:IsA("TextLabel") then
                    self.window:_reveal(revealLabel, { TextTransparency = targetTransparency }, revealTweenInfo, revealOverride)
                end
            end
        end
    end
end

return odometer
