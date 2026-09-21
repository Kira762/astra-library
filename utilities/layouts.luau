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
    cardCorners: { string }?,
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
    -- [[The rail's rows are inset `rowInset` from the rail's edges, so they
    -- [[read as chips rather than as full-bleed bands — and a chip wants the
    -- [[element-card radius, the tier one step inside the shell's own arc.]]
    rowCornerRadius = 8,
    rowSpacing = 4,
    railPadding = 17,
    rowInset = 15,
    rowPadding = 10,
    rowContentSpacing = 6,
    rowIconSize = 20,

    pageDirection = Enum.FillDirection.Vertical,

    -- [[The elements area is a solid band, not a floating card: it is fully
    -- [[opaque (cardTransparency 0) and its top-left corner is square, so the
    -- [[content sits flush against the topbar and the tab rail. Only the
    -- [[window's own bottom-right silhouette corner stays rounded, and the
    -- [[nearly-invisible card stroke is the sole separator between the
    -- [[sections instead of an empty gap.]]
    cardTransparency = 0,
    cardStrokeRotation = 55,
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
    fadeCorners = { "BottomLeftRadius", "BottomRightRadius" },
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
