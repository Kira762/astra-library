local infoHelper = {}

local tooltip = require(script.Parent.Parent.components.tooltip)

function infoHelper.attach(element: any, parentContainer: any, layoutOrder: number?): any
    local descText = element.description or element.Description or element.info or element.Info or element.tooltip or element.Tooltip
    if not descText or descText == "" then
        if element.infoButton then
            element.infoButton.Visible = false
        end
        return nil
    end

    if element.infoButton and element.infoButton.Parent == parentContainer then
        element.infoButton.Visible = true
        return element.infoButton
    end

    local window = element.window
    local icon = window:ResolveIcon(element.infoIcon or element.InfoIcon or "circle-alert")
    if not icon or icon == "circle-alert" then
        icon = window:ResolveIcon("alert-circle")
    end

    local infoButton = window:Create("ImageButton", {
        Name = "InfoIcon",
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = icon,
        ImageTransparency = 1,
        LayoutOrder = layoutOrder or 2,
        ZIndex = 15,
        Parent = parentContainer,
    }, { ImageColor3 = "ContentColor" })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.None,
        Parent = infoButton,
    })

    tooltip.attach(element, infoButton, descText)
    element.infoButton = infoButton
    return infoButton
end

return infoHelper
