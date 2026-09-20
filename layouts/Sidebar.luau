local sidebar = require(script.Parent.Parent.components.sidebar)

local Sidebar = {}

local function buildRail(window, layout)
    window.tabList = window:Create("ScrollingFrame", {
        Name = "Tabs",
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

function Sidebar.Build(window, layout)
    -- [[Tab rail band: the middle of the window's three surface shades
    -- [[(topbar darkest, rail one step lighter, elements lightest). Solid,
    -- [[flush under the topbar and against the elements edge; show/hide rides
    -- [[the frame's Visible flag as before. The bottom-left corner mirrors the
    -- [[window's silhouette for themes that round it.]]
    window.sidebar = window:Create("Frame", {
        Name = "Sidebar",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(0, layout.railWidth, 1, -layout.chromeHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.main,
    }, { BackgroundColor3 = "SidebarSurface" })
    window:_roundCorners(window.sidebar, { "BottomLeftRadius" })
    buildRail(window, layout)
end

function Sidebar.ApplyWidth(window, width)
    local layout = window.layout
    window.sidebar.Size = UDim2.new(0, width, 1, -layout.chromeHeight)
    window.elements.Size = UDim2.new(1, -width, 1, -layout.chromeHeight)
    window.bottomFade.Size = UDim2.new(1, -width, layout.fadeSize.Y.Scale, layout.fadeSize.Y.Offset)
    sidebar.applyRailRows(window, width, layout)
end

return Sidebar
