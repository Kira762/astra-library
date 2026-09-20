local layouts = {}

local sidebarLayout = require(script.Parent.Parent.layouts.Sidebar)
local sidebarCollapsedLayout = require(script.Parent.Parent.layouts.SidebarCollapsed)

local topbarHeightConstant = 64

export type Mode = "sidebar"

export type Layout = {
    mode: Mode,

    topbarHeight: number,
    chromeHeight: number,

    pageDirection: Enum.FillDirection,

    fadeSize: UDim2,
    fadeTransparency: NumberSequence,
    fadeCorners: { string }?,

    railWidth: number?,
    railCollapsedWidth: number?,
    railCollapseBelow: number?,
    rowHeight: number?,
    rowCornerRadius: number?,
    rowSpacing: number?,
    railPadding: number?,
    rowInset: number?,
    rowPadding: number?,
    rowContentSpacing: number?,
    rowIconSize: number?,
    cardTransparency: number?,
    cardStrokeRotation: number?,
    cardStrokeTransparency: NumberSequence?,

    -- [[Which corners of the window's silhouette each chrome band owns. The
    -- [[bands are painted flat and reach the window's edges, and nothing
    -- [[clips a descendant to the frame's arc, so a band that touches an
    -- [[edge has to carry that edge's arcs itself — otherwise a theme with
    -- [[`CornerRoundness` shows a square corner behind the rounded
    -- [[silhouette (see the window_corners suite). A band that meets
    -- [[another band keeps its inner corners square, or the arc would cut a
    -- [[notch of the window base out of it.]]
    chromeCorners: { string }?,
    railCorners: { string }?,
    cardCorners: { string }?,
    fadeCorners: { string }?,
    forceCollapsed: boolean?,
}

layouts.sidebar = {
    mode = "sidebar" :: Mode,

    topbarHeight = topbarHeightConstant,
    chromeHeight = topbarHeightConstant,

    railWidth = 219,
    railCollapsedWidth = 64,
    railCollapseBelow = 520,

    rowHeight = 38,
    rowCornerRadius = 0,
    rowSpacing = 4,
    railPadding = 17,
    rowInset = 15,
    rowPadding = 10,
    rowContentSpacing = 6,
    rowIconSize = 20,

    pageDirection = Enum.FillDirection.Vertical,

    -- [[The pane is its own flat plane (`WindowSurface`) now, so it shows at
    -- [[full opacity instead of as a 2%-white sheet over the window gradient
    -- [[behind it — the window gradient is the base only, and the corner
    -- [[arcs are the one place it still shows through.]]
    cardTransparency = 0,
    cardStrokeRotation = 55,
    -- [[Topbar band (top edge), rail band (bottom-left, below the topbar)
    -- [[and elements pane (bottom-right). See the `chromeCorners` note in
    -- [[the Layout type above.]]
    chromeCorners = { "TopLeftRadius", "TopRightRadius" },
    railCorners = { "BottomLeftRadius" },
    cardCorners = { "BottomRightRadius" },
    cardStrokeTransparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.128, 0.95),
        NumberSequenceKeypoint.new(0.414, 0.985),
        NumberSequenceKeypoint.new(1, 1),
    }),

    fadeSize = UDim2.new(1, 0, 0, 55),
    fadeTransparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.377, 0),
        NumberSequenceKeypoint.new(1, 1),
    }),
    fadeCorners = { "BottomRightRadius" },
} :: Layout

local collapsedSidebarLayout = table.clone(layouts.sidebar)
collapsedSidebarLayout.forceCollapsed = true

local implementments = {
    sidebar = sidebarLayout,
    collapsedSidebar = sidebarCollapsedLayout,
}

function layouts.get(requestedMode: unknown): Layout?
    if requestedMode == "sidebar" then
        return layouts.sidebar
    elseif requestedMode == "collapsedSidebar" then
        return collapsedSidebarLayout
    end
    return nil
end

function layouts.implementation(requestedMode: unknown)
    return implementments[requestedMode]
end

function layouts.railWidthFor(layout: Layout, viewportWidth: number): number
    if layout.mode ~= "sidebar" then
        return 0
    end
    local expandedWidth = layout.railWidth :: number
    if layout.forceCollapsed or viewportWidth < (layout.railCollapseBelow :: number) then
        return layout.railCollapsedWidth :: number
    end
    return expandedWidth
end

return layouts
