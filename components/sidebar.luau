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

-- [[The rail band, and the rail inside it. One builder for both layouts: the
-- [[expanded rail and the collapsed one differ only by the width they open
-- [[at and the name they carry (the settings rail and the search opening
-- [[read `window.sidebar`, `window.tabList`).
--
-- [[The band is a painted plane — the theme's `SidebarSurface`, flat — so the
-- [[tab rows sit on a colour of their own instead of on whatever the window
-- [[gradient happens to be at that height, and the boundary with the elements
-- [[pane is the two planes meeting rather than a gutter. Nothing clips a
-- [[band to the window's silhouette, so the band carries the bottom-left
-- [[corner arc itself (the second from the bottom owns the window's bottom
-- [[edge; the topbar band owns the top one).
function sidebar.buildBand(window, layout, collapsed, width)
    window.sidebar = window:Create("Frame", {
        Name = if collapsed then "CollapsedSidebar" else "Sidebar",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(0, width, 1, -layout.chromeHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.main,
    }, { BackgroundColor3 = "SidebarSurface" })

    window:_roundCorners(window.sidebar, layout.railCorners)

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
    -- [[The rail is collapsed only when it is at the icon-only width. The]]
    -- [[responsive rail otherwise hugs the widest tab name, which is often]]
    -- [[narrower than the fixed 219px rail the layout used to have.]]
    local isCollapsed = width <= (layout.railCollapsedWidth :: number)
    for _, tab in window.tabs do
        if not tab.neglectSelector then
            tabSelector.setRowCollapsed(tab, isCollapsed, layout)
        end
    end
    tabSelector.relayoutSidebarRows(window, layout, width)
end

return sidebar
