local layouts = {}

local topbarLayout = require(script.Parent.Parent.layouts.Topbar)
local sidebarLayout = require(script.Parent.Parent.layouts.Sidebar)
local sidebarCollapsedLayout = require(script.Parent.Parent.layouts.SidebarCollapsed)

local topbarHeightConstant = 64

local tabStripTopOffset = topbarHeightConstant - 1
local tabStripRowHeight = 38
local chromeGap = 3

export type Mode = "top" | "sidebar"

export type Layout = {
    mode: Mode,

        topbarHeight: number,
    chromeHeight: number,

            pageDirection: Enum.FillDirection,

            fadeSize: UDim2,
    fadeTransparency: NumberSequence,
    fadeCorners: { string }?,

        tabStripTop: number?,
    tabStripHeight: number?,
    tabStripInset: number?,

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

layouts.top = {
    mode = "top" :: Mode,

    topbarHeight = topbarHeightConstant,
    chromeHeight = tabStripTopOffset + tabStripRowHeight + chromeGap,

    tabStripTop = tabStripTopOffset,
    tabStripHeight = tabStripRowHeight,

    -- [[Margin between the window edge and the tab strip. The strip's]]
    -- [[ScrollingFrame is inset by this much on each side, so overflowing]]
    -- [[tabs clip inside the window instead of running into its border.]]
    tabStripInset = 22,

    pageDirection = Enum.FillDirection.Horizontal,

            fadeSize = UDim2.new(1, 0, -0.093, 100),
    fadeTransparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.4414, 0),
        NumberSequenceKeypoint.new(0.7007, 0.631),
        NumberSequenceKeypoint.new(1, 1),
    }),
} :: Layout

layouts.sidebar = {
    mode = "sidebar" :: Mode,

    topbarHeight = topbarHeightConstant,
    chromeHeight = topbarHeightConstant,

            railWidth = 219,
            railCollapsedWidth = 64,
    railCollapseBelow = 520,

    rowHeight = 38,
    rowCornerRadius = 14,
    rowSpacing = 4,
        railPadding = 17,
    rowInset = 15,
    rowPadding = 10,
    rowContentSpacing = 6,
    rowIconSize = 20,

    pageDirection = Enum.FillDirection.Vertical,

    cardTransparency = 0.98,
    cardStrokeRotation = 55,
            cardCorners = { "TopLeftRadius", "BottomRightRadius" },
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
    top = topbarLayout,
    sidebar = sidebarLayout,
    collapsedSidebar = sidebarCollapsedLayout,
}

function layouts.get(requestedMode: unknown): Layout?
    if requestedMode == "sidebar" then
        return layouts.sidebar
    elseif requestedMode == "collapsedSidebar" then
        return collapsedSidebarLayout
    elseif requestedMode == "top" then
        return layouts.top
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
