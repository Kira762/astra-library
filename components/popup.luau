local Popup = {}
Popup.__index = Popup
Popup.__type = "Popup"

local utilities = script.Parent.Parent.utilities
local motion = require(utilities.motion)
local state = require(utilities.Parent.core.state)
local functions = require(script.Parent.Parent.functions)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local log = require(utilities.log)
local haptic = require(utilities.HapticEngine)

-- [[The dialog arrives on the shared vocabulary: the card glides the last
-- few pixels to centre on `smooth` (a large surface decelerating), surfaces
-- fade on `normal`, copy on `snappy`, the backdrop dims quickest of all so
-- focus lands on the card. Closing plays the same paths in reverse on
-- `snappy` — a dialog leaves quicker than it came.]]
local cardShowTween, fadeInTween, textFadeTween, backdropTween = "smooth", "normal", "snappy", "fast"

local cardWidth = 400
local cardPadLeft = 22
local cardPadTop = 24
local cardPadBottom = 22
local sectionGap = 16
local contentInnerWidth = cardWidth - cardPadLeft * 2

local titleFontSize = 18
local subtitleFontSize = 14
local bodyFontSize = 15
local iconSize = 16
local boxIconSize = 22
local maxContentHeight = 300
local contentPadding = 4
local contentInnerWidthPadded = contentInnerWidth - contentPadding * 2

local boxPadLeft = 16
local boxPadTop = 13
local boxIconPad = 20
local boxDescPad = 10
local boxTitleFontSize = 15
local boxDescFontSize = 14
local boxIconSpacing = 8
local boxContentPad = 10
local footerHeight = 40
local footerSpacing = 8
local buttonTextSize = 16

local backdropTransparency = 0.5
local popupStack = {}

local lastEscapeInput = nil

local function cleanupStack()
    for i = #popupStack, 1, -1 do
        local popup = popupStack[i]
        if popup._closed or not popup.screenGui.Parent then
            table.remove(popupStack, i)
        end
    end
end

local function isTopmost(popup)
    cleanupStack()
    return popupStack[#popupStack] == popup
end

function Popup.new(window, props)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = props.title or props.Title or "Popup",
        subtitle = props.subtitle or props.Subtitle,
        content = props.content or props.Content,
        icon = window:ResolveIcon(props.icon or props.Icon),
        boxes = props.boxes or props.Boxes,
        options = props.options or props.Options,
        dismissable = if props.dismissable ~= nil
            then props.dismissable
            elseif props.Dismissable ~= nil then props.Dismissable
            else true,
        _reveal = {},
        _connections = {},
        _closed = false,
    }, Popup)

    if not self.options or #self.options == 0 then
        self.options = { { text = "Okay" } }
    end

    self:_build()
    cleanupStack()
    table.insert(popupStack, self)
    task.spawn(function()
        self:_show()
    end)

    return self
end

function Popup:_fade(instance, prop, to)
    table.insert(self._reveal, { instance = instance, prop = prop, to = to })
    return instance
end

function Popup:_build()
    local window = self.window
    local hasIcon = self.icon ~= nil and self.icon ~= 0 and self.icon ~= ""

    -- Only keep one UI: place popup layers within window.screenGui when available
    local rootGui = window.screenGui
    if not rootGui or not rootGui.Parent then
        rootGui = window:Create("ScreenGui", {
            Name = state.httpService:GenerateGUID(false),
            IgnoreGuiInset = true,
            ResetOnSpawn = false,
            Enabled = true,
            DisplayOrder = constants.displayOrder.popup,
            ZIndexBehavior = Enum.ZIndexBehavior.Global,
            Parent = state.guiContainer,
        })
    end
    self.screenGui = rootGui

    self.popupContainer = window:Create("Frame", {
        Name = "PopupContainer",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 200000,
        Parent = self.screenGui,
    })

    self.backdrop = window:Create("Frame", {
        Name = "Backdrop",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Active = true,
        BackgroundTransparency = 1,
        ZIndex = 200000,
        Parent = self.popupContainer,
    })
    self:_fade(self.backdrop, "BackgroundTransparency", backdropTransparency)

    self.card = window:Create("Frame", {
        Name = "Card",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.fromOffset(cardWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Active = true,
        BorderSizePixel = 0,
        ZIndex = 200001,
        BackgroundTransparency = 1,
        Parent = self.popupContainer,
    })
    self:_fade(self.card, "BackgroundTransparency", 0)

    window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),
        Parent = self.card,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    window:Create("UICorner", {
        Parent = self.card,
    }, { CornerRadius = "CornerRoundness" })

    self.cardStroke = window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.card,
    }, { Color = "SurfaceStroke" })
    self:_fade(self.cardStroke, "Transparency", 0.95)

    self.cardShadow = window:CreateGlow(self.card, "ShadowColor", 26, 1)
    self:_fade(self.cardShadow, "Transparency", 0.55)

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, cardPadLeft),
        PaddingRight = UDim.new(0, cardPadLeft),
        PaddingTop = UDim.new(0, cardPadTop),
        PaddingBottom = UDim.new(0, cardPadBottom),
        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, sectionGap),
        Parent = self.card,
    })

    local headerHeight = self:_measureHeader(hasIcon)
    self:_buildHeader(hasIcon, headerHeight)
    local contentHeight = self:_buildContent()
    self:_buildFooter()

    local sectionCount = 2 + (contentHeight > 0 and 1 or 0)
    local totalHeight = cardPadTop
        + headerHeight
        + contentHeight
        + footerHeight
        + cardPadBottom
        + sectionGap * (sectionCount - 1)
    self.card.Size = UDim2.fromOffset(cardWidth, totalHeight)
    self.card.AutomaticSize = Enum.AutomaticSize.None

    if self.dismissable then
        table.insert(
            self._connections,
            window:Connect(self.backdrop.InputBegan, function(input)
                if
                    input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch
                then
                    self:Close()
                end
            end)
        )
        table.insert(
            self._connections,
            window:Connect(state.userInputService.InputBegan, function(input, gameProcessed)
                if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape and isTopmost(self) then
                    if input == lastEscapeInput then
                        return
                    end
                    lastEscapeInput = input
                    self:Close()
                end
            end)
        )
    end
end

function Popup:_buildHeader(hasIcon, headerHeight)
    local window = self.window

    local headerFrame = window:Create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, headerHeight),
        LayoutOrder = 1,
        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, boxIconPad),
        Parent = headerFrame,
    })

    if hasIcon then
        self:_fade(
            window:Create("ImageLabel", {
                Image = self.icon,
                Size = UDim2.fromOffset(iconSize, iconSize),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                ImageTransparency = 1,
                Parent = headerFrame,
            }, { ImageColor3 = "TitlingColor" }),
            "ImageTransparency",
            0
        )
    end

    local textFrame = window:Create("Frame", {
        Name = "Text",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasIcon and -(iconSize + boxIconPad) or 0, 0, self._columnH),
        LayoutOrder = 2,
        Parent = headerFrame,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = textFrame,
    })

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(self.title),
            Size = UDim2.new(1, 0, 0, self._titleH),
            BackgroundTransparency = 1,
            TextSize = titleFontSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            Parent = textFrame,
        }, { TextColor3 = "TitlingColor", FontFace = "Font" }),
        "TextTransparency",
        0
    )

    if self.subtitle and self.subtitle ~= "" then
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(self.subtitle),
                Size = UDim2.new(1, 0, 0, self._subH),
                BackgroundTransparency = 1,
                TextSize = subtitleFontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = 2,
                TextTransparency = 1,
                Parent = textFrame,
            }, { TextColor3 = "TitlingColor", FontFace = "Font" }),
            "TextTransparency",
            0.55
        )
    end
end

function Popup:_buildContent()
    if (not self.content or self.content == "") and (not self.boxes or #self.boxes == 0) then
        return 0
    end

    local window = self.window
    local measuredContentHeight = if self.boxes and #self.boxes > 0 then self:_measureBoxes() else self:_measureText()
    local scrollHeight = math.min(measuredContentHeight, maxContentHeight) + contentPadding * 2

    local scrollFrame = window:Create("ScrollingFrame", {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, scrollHeight),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2,
        ScrollBarImageTransparency = 1,
        Parent = self.card,
    })
    self:_fade(scrollFrame, "ScrollBarImageTransparency", 0.8)

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, contentPadding),
        PaddingRight = UDim.new(0, contentPadding),
        PaddingTop = UDim.new(0, contentPadding),
        PaddingBottom = UDim.new(0, contentPadding),
        Parent = scrollFrame,
    })

    if self.boxes and #self.boxes > 0 then
        window:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, boxIconSpacing),
            Parent = scrollFrame,
        })
        for i, box in self.boxes do
            self:_buildBox(scrollFrame, box, i)
        end
    else
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(self.content),
                Size = UDim2.new(1, 0, 0, measuredContentHeight),
                BackgroundTransparency = 1,
                TextSize = bodyFontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                TextTransparency = 1,
                Parent = scrollFrame,
            }, { TextColor3 = "ContentColor", FontFace = "Font" }),
            "TextTransparency",
            0.5
        )
    end

    return scrollHeight
end

function Popup:_buildBox(scrollFrame, box, index)
    local window = self.window
    box = if typeof(box) == "table" then box else { title = tostring(box) }
    local hasBoxIcon = box.icon ~= nil and box.icon ~= 0 and box.icon ~= ""
    local boxHeight, titleHeight, descHeight, contentHeight = self:_measureBox(box)

    local boxFrame = window:Create("Frame", {
        Name = "Box",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -boxContentPad, 0, boxHeight),
        LayoutOrder = index,
        BackgroundTransparency = 1,
        Parent = scrollFrame,
    })
    self:_fade(boxFrame, "BackgroundTransparency", 0)

    local boxStroke = window:StyleElementPanel(boxFrame)
    self:_fade(boxStroke, "Transparency", window.theme.ElementStrokeTransparency)

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, boxPadLeft),
        PaddingRight = UDim.new(0, boxPadLeft),
        PaddingTop = UDim.new(0, boxPadTop),
        PaddingBottom = UDim.new(0, boxPadTop),
        Parent = boxFrame,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, boxDescPad),
        Parent = boxFrame,
    })

    if hasBoxIcon then
        self:_fade(
            window:Create("ImageLabel", {
                Image = box.icon,
                Size = UDim2.fromOffset(boxIconSize, boxIconSize),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                ImageTransparency = 1,
                Parent = boxFrame,
            }, { ImageColor3 = "ContentColor" }),
            "ImageTransparency",
            0
        )
    end

    local textBox = window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasBoxIcon and -(boxIconSize + boxDescPad) or 0, 0, contentHeight),
        LayoutOrder = 2,
        Parent = boxFrame,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = textBox,
    })

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(box.title or box.Title or ""),
            Size = UDim2.new(1, 0, 0, titleHeight),
            BackgroundTransparency = 1,
            TextSize = boxTitleFontSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            Parent = textBox,
        }, { TextColor3 = "ContentColor", FontFace = "TitleFont" }),
        "TextTransparency",
        0
    )

    local description = box.description or box.Description
    if description and description ~= "" then
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(description),
                Size = UDim2.new(1, 0, 0, descHeight),
                BackgroundTransparency = 1,
                TextSize = boxDescFontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                LayoutOrder = 2,
                TextTransparency = 1,
                Parent = textBox,
            }, { TextColor3 = "ContentColor", FontFace = "Font" }),
            "TextTransparency",
            0.65
        )
    end
end

function Popup:_buildFooter()
    local window = self.window

    local footerFrame = window:Create("Frame", {
        Name = "Footer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, footerHeight),
        LayoutOrder = 3,
        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, footerSpacing),
        Parent = footerFrame,
    })

    for i, option in self.options do
        self:_buildButton(footerFrame, option, i)
    end
end

function Popup:_buildButton(footerFrame, option, index)
    local window = self.window
    option = if typeof(option) == "table" then option else { text = tostring(option) }
    local style = option.style or option.Style or "neutral"
    local text = option.text or option.Text or option.name or option.Name or "Okay"
    local callback = option.callback or option.Callback

    local bgColor, hoverColor, strokeColor, strokeTransparency
    if style == "primary" then
        bgColor, hoverColor, strokeColor, strokeTransparency =
            window.theme.AccentColor, window.theme.AccentStroke, window.theme.AccentStroke, 0.1
    elseif style == "danger" then
        bgColor, hoverColor, strokeColor, strokeTransparency =
            window.theme.ErrorColor, window.theme.ErrorStrokeColor, window.theme.ErrorStrokeColor, 0
    else
        bgColor, hoverColor, strokeColor, strokeTransparency =
            window.theme.NeutralButton, window.theme.NeutralButtonHover, window.theme.NeutralButtonStroke, 0.85
    end

    local buttonFrame = window:Create("Frame", {
        Name = "Button",
        BackgroundColor3 = bgColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, footerHeight),
        LayoutOrder = index,
        BackgroundTransparency = 1,
        Parent = footerFrame,
    })
    self:_fade(buttonFrame, "BackgroundTransparency", 0)

    window:Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = buttonFrame })
    window:Create("UICorner", { Parent = buttonFrame }, { CornerRadius = "ElementCornerRadius" })

    local buttonStroke = window:Create("UIStroke", {
        Color = strokeColor,
        Transparency = 1,
        Parent = buttonFrame,
    })
    self:_fade(buttonStroke, "Transparency", strokeTransparency)

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(text),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            TextSize = buttonTextSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = functions.contrastText(bgColor),
            TextTransparency = 1,
            Parent = buttonFrame,
        }, { FontFace = "Font" }),
        "TextTransparency",
        0
    )

    local buttonInteract = window:Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = buttonFrame,
    })

    local buttonHoverTween = "snappy"
    table.insert(
        self._connections,
        window:Connect(buttonInteract.MouseEnter, function()
            if self._closed then
                return
            end
            motion.tween(buttonFrame, { BackgroundColor3 = hoverColor }, buttonHoverTween)
        end)
    )
    table.insert(
        self._connections,
        window:Connect(buttonInteract.MouseLeave, function()
            motion.tween(buttonFrame, { BackgroundColor3 = bgColor }, buttonHoverTween)
        end)
    )

    table.insert(
        self._connections,
        window:Connect(buttonInteract.MouseButton1Click, function()
            if self._closed then
                return
            end
            haptic.click()
            motion.tween(buttonStroke, { Transparency = 1 }, buttonHoverTween)
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback)
                    if not ok then
                        log.warn("Astra: popup button '" .. text .. "' callback errored:")
                        log.print(err)
                    end
                end)
            end
            self:Close()
        end)
    )
end

function Popup:_measureHeader(hasIcon)
    local availableWidth = contentInnerWidth - (if hasIcon then iconSize + boxIconPad else 0)
    self._titleH = functions.textHeight(self.window.theme.Font, titleFontSize, locale.resolve(self.title), availableWidth)
    self._subH = if self.subtitle and self.subtitle ~= ""
        then functions.textHeight(self.window.theme.Font, subtitleFontSize, locale.resolve(self.subtitle), availableWidth)
        else 0
    self._columnH = self._titleH + (if self._subH > 0 then 3 + self._subH else 0)
    return math.max(self._columnH, if hasIcon then iconSize else 0)
end

function Popup:_measureText()
    return functions.textHeight(self.window.theme.Font, bodyFontSize, locale.resolve(self.content), contentInnerWidthPadded)
end

function Popup:_measureBox(box)
    box = if typeof(box) == "table" then box else { title = tostring(box) }
    local hasBoxIcon = box.icon ~= nil and box.icon ~= 0 and box.icon ~= ""
    local availableWidth = contentInnerWidthPadded - boxContentPad - boxPadLeft * 2 - (if hasBoxIcon then boxIconSize + boxDescPad else 0)

    local titleHeight = functions.textHeight(
        self.window.theme.TitleFont,
        boxTitleFontSize,
        locale.resolve(box.title or box.Title or ""),
        availableWidth
    )
    local descHeight = 0
    local description = box.description or box.Description
    if description and description ~= "" then
        descHeight = functions.textHeight(self.window.theme.Font, boxDescFontSize, locale.resolve(description), availableWidth)
    end

    local contentHeight = titleHeight + (if descHeight > 0 then 3 + descHeight else 0)
    local boxHeight = math.max(contentHeight, if hasBoxIcon then boxIconSize else 0) + boxPadTop * 2
    return boxHeight, titleHeight, descHeight, contentHeight
end

function Popup:_measureBoxes()
    local totalHeight = 0
    for i, box in self.boxes do
        totalHeight += (self:_measureBox(box))
        if i < #self.boxes then
            totalHeight += boxIconSpacing
        end
    end
    return totalHeight
end

function Popup:_show()
    if self._closed or not (self.screenGui and self.screenGui.Parent) then
        return
    end

    haptic.notify()

    -- Aesthetic canvas-style modal entrance with fluid deceleration
    motion.tween(self.card, { Position = UDim2.new(0.5, 0, 0.5, 0) }, "modal")

    for _, reveal in self._reveal do
        local tweenInfo = if reveal.instance == self.backdrop then backdropTween else fadeInTween
        motion.tween(reveal.instance, { [reveal.prop] = reveal.to }, tweenInfo)
    end
end

function Popup:Close()
    if self._closed then
        return
    end
    self._closed = true

    local index = table.find(popupStack, self)
    if index then
        table.remove(popupStack, index)
    end

    for _, conn in self._connections do
        self.window:Disconnect(conn)
    end
    self._connections = {}

    if not (self.screenGui and self.screenGui.Parent) then
        return
    end

    if self._closeConnection then
        self._closeConnection:Disconnect()
        self._closeConnection = nil
    end

    local closeTween = state.tweenService:Create(
        self.card,
        motion.spec("dropdownClose"),
        { Position = UDim2.new(0.5, 0, 0.5, 10) }
    )
    self._closeConnection = closeTween.Completed:Connect(function(playbackState)
        local oldConnection = self._closeConnection
        self._closeConnection = nil
        if oldConnection then
            oldConnection:Disconnect()
        end
        if playbackState == Enum.PlaybackState.Completed and self._closed then
            if self.popupContainer and self.popupContainer.Parent then
                self.window:DestroySubtree(self.popupContainer)
            elseif self.screenGui and self.screenGui.Parent and self.screenGui ~= self.window.screenGui then
                self.window:DestroySubtree(self.screenGui)
            end
        end
    end)
    closeTween:Play()

    for _, reveal in self._reveal do
        motion.tween(reveal.instance, { [reveal.prop] = 1 }, "dropdownClose")
    end
end

return Popup
