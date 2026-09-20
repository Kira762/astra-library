local sidebar = require(script.Parent.Parent.components.sidebar)

local SidebarCollapsed = {}

function SidebarCollapsed.Build(window, layout)
    sidebar.buildBand(window, layout, true, layout.railCollapsedWidth)
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
