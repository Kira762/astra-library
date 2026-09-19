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

    local resolvedText = locale.t(text)
    label.Text = resolvedText

    local font = window.theme.Font
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

    local anchorPos = anchor.AbsolutePosition
    local anchorSize = anchor.AbsoluteSize
    local centerX = anchorPos.X + anchorSize.X / 2
    local idealX = centerX - totalWidth / 2
    local idealY = anchorPos.Y - totalHeight - 6

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    local screenW = if viewport then viewport.X else 2000
    local screenH = if viewport then viewport.Y else 2000

    local clampedX = math.clamp(idealX, 8, math.max(8, screenW - totalWidth - 8))
    local clampedY = idealY
    if clampedY < 6 then
        clampedY = anchorPos.Y + anchorSize.Y + 6
    end
    clampedY = math.clamp(clampedY, 6, math.max(6, screenH - totalHeight - 6))

    tip.Position = UDim2.fromOffset(clampedX, clampedY)
    tip.Visible = true

    window._tooltipHideToken = (window._tooltipHideToken or 0) + 1
    window._tooltipActiveAnchor = anchor

    motion.tween(tip, { BackgroundTransparency = 0 }, hoverTween)
    if stroke then
        motion.tween(stroke, { Transparency = 0.25 }, hoverTween)
    end
    motion.tween(label, { TextTransparency = 0 }, hoverTween)
end

function tooltip.hide(window)
    local tip = window.elementTooltip
    if not tip or not tip.Visible then
        return
    end

    local stroke = window.elementTooltipStroke
    local label = window.elementTooltipLabel

    local token = (window._tooltipHideToken or 0) + 1
    window._tooltipHideToken = token
    window._tooltipActiveAnchor = nil

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

function tooltip.attach(element, anchorButton, infoText: string)
    local window = element.window

    window:ConnectFor(element, anchorButton.MouseEnter, function()
        motion.tween(anchorButton, { ImageTransparency = 0 }, hoverTween)
        tooltip.show(window, anchorButton, element.info or infoText)
    end)

    window:ConnectFor(element, anchorButton.MouseLeave, function()
        motion.tween(anchorButton, { ImageTransparency = 0.45 }, hoverTween)
        if window._tooltipActiveAnchor == anchorButton then
            tooltip.hide(window)
        end
    end)

    window:ConnectFor(element, anchorButton.MouseButton1Click, function()
        if window._tooltipActiveAnchor == anchorButton and window.elementTooltip and window.elementTooltip.Visible then
            tooltip.hide(window)
        else
            tooltip.show(window, anchorButton, element.info or infoText)
        end
    end)

    window:ConnectFor(element, anchorButton:GetPropertyChangedSignal("AbsolutePosition"), function()
        if window._tooltipActiveAnchor == anchorButton then
            tooltip.hide(window)
        end
    end)
end

return tooltip
