local sidebar = require(script.Parent.Parent.components.sidebar)

local Sidebar = {}

function Sidebar.Build(window, layout)
    sidebar.buildBand(window, layout, false, layout.railWidth)
end

function Sidebar.ApplyWidth(window, width)
    local layout = window.layout
    window.sidebar.Size = UDim2.new(0, width, 1, -layout.chromeHeight)
    window.elements.Size = UDim2.new(1, -width, 1, -layout.chromeHeight)
    window.bottomFade.Size = UDim2.new(1, -width, layout.fadeSize.Y.Scale, layout.fadeSize.Y.Offset)
    sidebar.applyRailRows(window, width, layout)
end

return Sidebar
