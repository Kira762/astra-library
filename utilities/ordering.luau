type OrderedElement = {
    main: GuiObject,
}

local function ordering(element: OrderedElement, order: number)
    element.main.LayoutOrder = order
end

return ordering
