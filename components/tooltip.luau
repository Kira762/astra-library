local tooltip = {}

local utilities = script.Parent.Parent.utilities

local motion = require(utilities.motion)
local locale = require(utilities.locale)
local functions = require(script.Parent.Parent.functions)

local hoverTween = "fast"
local minWidth = 80
local maxWidth = 240
local padX = 8
local padY = 5
local fontSize = 12
local lineHeight = 15

function tooltip.ensure(window)
    if window.elementTooltip then
        return window.elementTooltip
    end

    local tip = window:Create("Frame", {
        Name = "ElementTooltip",
        Size = UDim2.fromOffset(120, 26),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 500,
        Parent = window.screenGui,
    }, { BackgroundColor3 = "PopupSurface" })

    window.elementTooltip = tip

    window:Create("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = tip,
    })

    local stroke = window:Create("UIStroke", {
        Transparency = 1,
        Parent = tip,
    }, { Color = "ElementStroke" })
    window.elementTooltipStroke = stroke

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, padX),
        PaddingRight = UDim.new(0, padX),
        PaddingTop = UDim.new(0, padY),
        PaddingBottom = UDim.new(0, padY),
        Parent = tip,
    })

    local label = window:Create("TextLabel", {
        Name = "Label",
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = fontSize,
        TextWrapped = true,
        RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        ZIndex = 501,
        Parent = tip,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    window.elementTooltipLabel = label

    return tip
end

local function getViewport(): (number, number)
    local ws = nil
    pcall(function()
        ws = game:GetService("Workspace")
    end)
    if not ws then
        pcall(function()
            ws = workspace
        end)
    end
    local camera = ws and ws.CurrentCamera
    local viewport = camera and camera.ViewportSize
    local screenW = if viewport then viewport.X else 2000
    local screenH = if viewport then viewport.Y else 2000
    return screenW, screenH
end

function tooltip.calculatePosition(anchor: any, totalWidth: number, totalHeight: number): (number, number)
    local anchorPos = anchor.AbsolutePosition
    local anchorSize = anchor.AbsoluteSize
    local centerX = anchorPos.X + anchorSize.X / 2
    local idealX = centerX - totalWidth / 2
    local idealY = anchorPos.Y - totalHeight - 6

    local screenW, screenH = getViewport()

    local clampedX = math.clamp(idealX, 8, math.max(8, screenW - totalWidth - 8))
    local clampedY = idealY
    if clampedY < 6 then
        clampedY = anchorPos.Y + anchorSize.Y + 6
    end
    clampedY = math.clamp(clampedY, 6, math.max(6, screenH - totalHeight - 6))

    return clampedX, clampedY
end

function tooltip.show(window, anchor: any, text: string)
    if not anchor or not anchor.Parent or not text or text == "" then
        return
    end

    local tip = tooltip.ensure(window)
    local label = window.elementTooltipLabel
    local stroke = window.elementTooltipStroke
    if not tip or not label then
        return
    end

    local rawText = if locale.isToken(text) then locale.sourceOf(text) else text
    local resolvedText = locale.resolve(tostring(rawText or ""))
    label.Text = resolvedText

    local font = (window.theme and window.theme.Font) or Enum.Font.SourceSans
    local rawWidth = functions.textWidth(font, fontSize, resolvedText)
    local contentWidth = math.clamp(rawWidth, minWidth, maxWidth)
    local totalWidth = contentWidth + padX * 2
    local totalHeight
    if rawWidth > maxWidth then
        local measuredHeight = functions.textHeight(font, fontSize, resolvedText, maxWidth)
        totalHeight = math.max(26, measuredHeight + padY * 2)
    else
        totalHeight = math.max(26, lineHeight + padY * 2)
    end

    tip.Size = UDim2.fromOffset(totalWidth, totalHeight)

    local clampedX, clampedY = tooltip.calculatePosition(anchor, totalWidth, totalHeight)
    tip.Position = UDim2.fromOffset(clampedX, clampedY)
    tip.Visible = true

    window._tooltipHideToken = (window._tooltipHideToken or 0) + 1
    window._tooltipActiveAnchor = anchor

    motion.tween(anchor, { ImageTransparency = 0 }, hoverTween)
    motion.tween(tip, { BackgroundTransparency = 0 }, hoverTween)
    if stroke then
        motion.tween(stroke, { Transparency = 0.25 }, hoverTween)
    end
    motion.tween(label, { TextTransparency = 0 }, hoverTween)
end

function tooltip.updatePosition(window, anchor: any)
    local tip = window.elementTooltip
    if not tip or not tip.Visible or not anchor or not anchor.Parent then
        return
    end

    local totalWidth = tip.AbsoluteSize.X
    local totalHeight = tip.AbsoluteSize.Y
    if totalWidth <= 0 or totalHeight <= 0 then
        return
    end

    local clampedX, clampedY = tooltip.calculatePosition(anchor, totalWidth, totalHeight)
    tip.Position = UDim2.fromOffset(clampedX, clampedY)
end

function tooltip.hide(window, immediate: boolean?)
    local tip = window.elementTooltip
    if not tip then
        return
    end

    local stroke = window.elementTooltipStroke
    local label = window.elementTooltipLabel

    local token = (window._tooltipHideToken or 0) + 1
    window._tooltipHideToken = token

    local prevAnchor = window._tooltipActiveAnchor
    window._tooltipActiveAnchor = nil
    window._tooltipPinnedAnchor = nil

    if prevAnchor and prevAnchor.Parent then
        motion.tween(prevAnchor, { ImageTransparency = 0.45 }, hoverTween)
    end

    if immediate then
        tip.Visible = false
        tip.BackgroundTransparency = 1
        if stroke then
            stroke.Transparency = 1
        end
        if label then
            label.TextTransparency = 1
        end
        return
    end

    if not tip.Visible then
        return
    end

    motion.tween(tip, { BackgroundTransparency = 1 }, hoverTween)
    if stroke then
        motion.tween(stroke, { Transparency = 1 }, hoverTween)
    end
    if label then
        motion.tween(label, { TextTransparency = 1 }, hoverTween)
    end

    task.delay(0.2, function()
        if window._tooltipHideToken == token and tip.Parent and tip.BackgroundTransparency >= 0.95 then
            tip.Visible = false
        end
    end)
end

function tooltip.attach(element, anchorButton, descText: string)
    local window = element.window
    local justToggled = false

    local function getDescText()
        return element.description or element.Description or element.info or element.Info or element.tooltip or element.Tooltip or descText
    end

    local function openAndPin()
        local text = getDescText()
        if not text or text == "" then
            return
        end
        if window._tooltipActiveAnchor and window._tooltipActiveAnchor ~= anchorButton then
            if window._tooltipActiveAnchor.Parent then
                motion.tween(window._tooltipActiveAnchor, { ImageTransparency = 0.45 }, hoverTween)
            end
        end
        window._tooltipPinnedAnchor = anchorButton
        tooltip.show(window, anchorButton, text)
    end

    local function closePinned()
        tooltip.hide(window)
        window._tooltipPinnedAnchor = nil
    end

    -- Holding (MouseButton1Down / touch press down)
    window:ConnectFor(element, anchorButton.MouseButton1Down, function()
        if window._tooltipPinnedAnchor == anchorButton and window.elementTooltip and window.elementTooltip.Visible then
            closePinned()
            justToggled = true
        else
            openAndPin()
            justToggled = true
        end
    end)

    -- Tapping / Clicking
    window:ConnectFor(element, anchorButton.MouseButton1Click, function()
        if justToggled then
            justToggled = false
            return
        end
        if window._tooltipPinnedAnchor == anchorButton and window.elementTooltip and window.elementTooltip.Visible then
            closePinned()
        else
            openAndPin()
        end
    end)

    -- Desktop Hover
    window:ConnectFor(element, anchorButton.MouseEnter, function()
        motion.tween(anchorButton, { ImageTransparency = 0 }, hoverTween)
        if window._tooltipPinnedAnchor == nil then
            local text = getDescText()
            if text and text ~= "" then
                tooltip.show(window, anchorButton, text)
            end
        end
    end)

    window:ConnectFor(element, anchorButton.MouseLeave, function()
        if window._tooltipPinnedAnchor == anchorButton then
            -- Kept pinned open by tap or hold; stay visible and highlighted
            return
        end
        motion.tween(anchorButton, { ImageTransparency = 0.45 }, hoverTween)
        if window._tooltipActiveAnchor == anchorButton and window._tooltipPinnedAnchor == nil then
            tooltip.hide(window)
        end
    end)

    -- Track anchor movement / scroll
    window:ConnectFor(element, anchorButton:GetPropertyChangedSignal("AbsolutePosition"), function()
        if window._tooltipActiveAnchor == anchorButton and window.elementTooltip and window.elementTooltip.Visible then
            if not anchorButton.Visible or not anchorButton.Parent then
                tooltip.hide(window, true)
            else
                tooltip.updatePosition(window, anchorButton)
            end
        end
    end)
end

return tooltip
