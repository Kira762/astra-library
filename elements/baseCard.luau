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

    -- [[A description grows the card here, before the title row is built, so
    -- [[the row centres in the base region instead of drifting down into the
    -- [[line (see elements/description.luau).]]
    description.attach(element)
    local centerScale, centerOffset = description.center(element, height)

    element.container = window:Create("Frame", {
        BorderSizePixel = 0,
        Parent = element.main,
        Size = UDim2.new(1, -rightPadding, 0, 16),
        Position = UDim2.new(0, 20, centerScale, centerOffset),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
    })

    -- [[`SortOrder = LayoutOrder` is explicit: the icon, the name and the
    -- [[circle-alert badge carry orders 0/1/2, and the layout's default sort
    -- [[(Name, as Roblox ships it) would put "InfoIcon" before "TextLabel".]]
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
            Image = element.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            LayoutOrder = 0,
            Parent = element.container,
        }, { ImageColor3 = "ContentColor" })
    end

    element.title = window:Create("TextLabel", {
        Text = (opts and opts.titleText) or element.name,
        Size = UDim2.new(1, if element.icon then -21 else 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = element.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- [[The badge, when there is one, joins the row right after the name and
    -- [[turns the title width-automatic (remembering the recipe above, which
    -- [[is what `:SetInfo(\"\")` restores).]] 
    infoHelper.attach(element, element.container)

    return element.main
end

-- [[Runtime writer for `:SetInfo(text)`: a text adds the badge right after
-- [[the name, an empty one removes it and gives the title its width back.]] 
function baseCard.setInfo(element: any, infoText: string?)
    infoHelper.set(element, infoText, element.container)
end

return baseCard
