local sidebar = require(script.Parent.Parent.components.sidebar)

local SidebarCollapsed = {}

local function buildRail(window, layout)
    window.tabList = window:Create("ScrollingFrame", {
        Name = "CollapsedTabs",
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

function SidebarCollapsed.Build(window, layout)
    -- [[Icon-only rail: same surface contract as the expanded rail
    -- [[(layouts/Sidebar.luau) — the middle band of the window's three
    -- [[section shades, solid and flush.]]
    window.sidebar = window:Create("Frame", {
        Name = "CollapsedSidebar",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(0, layout.railCollapsedWidth, 1, -layout.chromeHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.main,
    }, { BackgroundColor3 = "SidebarSurface" })
    window:_roundCorners(window.sidebar, { "BottomLeftRadius" })
    buildRail(window, layout)
end

function SidebarCollapsed.ApplyWidth(window)
    local layout = window.layout
    local width = layout.railCollapsedWidth
    window.sidebar.Size = UDim2.new(0, width, 1, -layout.chromeHeight)
    window.elements.Size = UDim2.new(1, -width, 1, -layout.chromeHeight)
    window.bottomFade.Size = UDim2.new(1, -width, layout.fadeSize.Y.Scale, layout.fadeSize.Y.Offset)
    sidebar.applyRailRows(window, width, layout)
end

return SidebarCollapsed
