-- [[Shared base card layout and styling for Astra UI elements.]]
-- [[Handles standard background frame, theme strokes, hover overlay,]]
-- [[content container, icon, and title label.]]

local baseCard = {}

local description = require(script.Parent.description)
local infoHelper = require(script.Parent.infoHelper)

export type BaseCardOpts = {
    height: number?,
    rightPadding: number?,
    titleText: string?,
}

function baseCard.buildFull(element: any, opts: BaseCardOpts?): any
    local window = element.window
    local tab = element.tab
    local height = (opts and opts.height) or 41
    local rightPadding = (opts and opts.rightPadding) or 40

    element.main = window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, height),
        BorderSizePixel = 0,
        Name = element.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Parent = tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    element.stroke = window:StyleElementBody(element.main)
    element.hoverOverlay = window:CreateHoverOverlay(element.main)

    -- [[Legacy in-card description only if inlineDescription or inline flag is explicitly set.]]
    if element.inlineDescription or element.inline then
        description.attach(element)
    end
    local centerScale, centerOffset = description.center(element, height)

    element.container = window:Create("Frame", {
        BorderSizePixel = 0,
        Parent = element.main,
        Size = UDim2.new(1, -rightPadding, 0, 16),
        Position = UDim2.new(0, 20, centerScale, centerOffset),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })

    element.containerLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = element.container,
    })

    if element.icon then
        element.iconLabel = window:Create("ImageLabel", {
            Name = "Icon",
            Image = element.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            LayoutOrder = 0,
            ZIndex = 5,
            Parent = element.container,
        }, { ImageColor3 = "ContentColor" })
    end

    local rawDesc = element.description or element.Description or element.info or element.Info or element.tooltip or element.Tooltip
    local hasDesc = typeof(rawDesc) == "string" and rawDesc ~= ""

    element.title = window:Create("TextLabel", {
        Name = "Title",
        Text = (opts and opts.titleText) or element.name,
        Size = if hasDesc
            then UDim2.fromOffset(0, 16)
            else UDim2.new(1, if element.icon then -21 else 0, 0, 16),
        AutomaticSize = if hasDesc then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = 5,
        TextTransparency = 1,
        Parent = element.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    if hasDesc then
        window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = element.title,
        })
        infoHelper.attach(element, element.container, 2)
    end

    return element.main
end

function baseCard.setDescription(element: any, descText: string?)
    local cleaned = if typeof(descText) == "string" and descText ~= "" then descText else nil
    element.description = cleaned
    element.info = cleaned
    if cleaned then
        if element.infoButton then
            element.infoButton.Visible = true
            element.infoButton.ImageTransparency = 0.45
        elseif element.container or element.interact then
            local parent = element.container or element.interact
            if element.title and element.title.AutomaticSize == Enum.AutomaticSize.None then
                element.title.AutomaticSize = Enum.AutomaticSize.X
                element.title.Size = UDim2.fromOffset(0, 16)
                element.window:Create("UIFlexItem", {
                    FlexMode = Enum.UIFlexMode.Shrink,
                    Parent = element.title,
                })
            end
            infoHelper.attach(element, parent, 2)
            if element.infoButton then
                element.infoButton.ImageTransparency = 0.45
            end
        end
    elseif element.infoButton then
        element.infoButton.Visible = false
        if element.window and element.window._tooltipActiveAnchor == element.infoButton then
            local tooltip = require(script.Parent.Parent.components.tooltip)
            tooltip.hide(element.window, true)
        end
    end
end

function baseCard.setInfo(element: any, infoText: string?)
    baseCard.setDescription(element, infoText)
end

return baseCard
