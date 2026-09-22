local tabSelector = require(script.Parent.tabSelector)
local search = require(script.Parent.search)

local sidebar = {}

function sidebar.maskUsername(name)
    name = tostring(name or "")
    if name == "" then
        return "****"
    end
    return string.sub(name, 1, math.min(3, #name)) .. "****"
end

function sidebar.buildTabRail(window, layout, collapsed)
    window.tabList = window:Create("ScrollingFrame", {
        Name = if collapsed then "CollapsedTabs" else "Tabs",
        Active = true,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Parent = window.sidebar,
    })
    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, layout.railPadding),
        PaddingBottom = UDim.new(0, layout.railPadding),
        Parent = window.tabList,
    })
    window.tabListLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, layout.rowSpacing),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = window.tabList,
    })
end

function sidebar.applyRailRows(window, width, layout)
    search.railWidth(window, width)
    --[[
    The rail is collapsed only when it is at the icon-only width. The
    responsive rail otherwise hugs the widest tab name, which is often
    narrower than the fixed 219px rail the layout used to have.
    ]]
    local isCollapsed = width <= (layout.railCollapsedWidth :: number)
    for _, tab in window.tabs do
        if not tab.neglectSelector then
            tabSelector.setRowCollapsed(tab, isCollapsed, layout)
        end
    end
    tabSelector.relayoutSidebarRows(window, layout, width)
end

return sidebar
