local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local motion = require(utilities.motion)
local functions = require(script.Parent.Parent.functions)
local locale = require(utilities.locale)

local tabSelector = {}

local function getInitial(str: string?): string
    if type(str) ~= "string" or str == "" then
        return "?"
    end
    local nextOffset = utf8.offset(str, 2)
    local initial = if nextOffset then string.sub(str, 1, nextOffset - 1) else str
    return string.upper(initial)
end

tabSelector.states = {
    top = {
        selected = { background = 0, stroke = 0, content = 0 },
        hover = { background = 0.4, stroke = 0.3, content = 0.3 },
        unselected = { background = 0.8, stroke = 0.65, content = 0.5 },
        hidden = { background = 1, stroke = 1, content = 1 },
    },
    sidebar = {
        selected = { background = 0.4, stroke = 0.5, content = 0, shadow = 0.8 },
        hover = { background = 0.7, stroke = 0.8, content = 0.3, shadow = 1 },
        unselected = { background = 1, stroke = 1, content = 0.5, shadow = 1 },
        hidden = { background = 1, stroke = 1, content = 1, shadow = 1 },
    },
}

local function buildGradients(tab, item, stroke)
    tab.topbarItemGradient = tab.window:Create("UIGradient", {
        Rotation = 90,
        Parent = item,
    }, { Color = { "TabBackground", functions.toColorSequence } })

    tab.topbarItemStrokeGradient = tab.window:Create("UIGradient", {
        Rotation = 90,
        Parent = stroke,
    }, { Color = { "TabStroke", functions.toColorSequence } })
end

local function buildContent(tab, iconSize, useInitial)
    if useInitial and not tab.icon then
        tab.topbarItemInitial = tab.window:Create("TextLabel", {
            Text = getInitial(tab.name),
            Size = UDim2.fromOffset(iconSize, iconSize),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = iconSize - 4,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            TextTransparency = 1,
            Parent = tab.topbarItemContainer,
        }, { TextColor3 = "TabColor", FontFace = "Font" })
    end

    if tab.icon then
        tab.topbarItemIcon = tab.window:Create("ImageLabel", {
            Image = tab.icon,
            Size = UDim2.fromOffset(iconSize, iconSize),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            Parent = tab.topbarItemContainer,
        }, { ImageColor3 = "TabColor" })
    end

    if tab.name then
        tab.topbarItemTitle = tab.window:Create("TextLabel", {
            Text = locale.t(tab.name),
            Size = UDim2.fromOffset(0, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = 16,
            AutomaticSize = Enum.AutomaticSize.XY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            Parent = tab.topbarItemContainer,
        }, { TextColor3 = "TabColor", FontFace = "Font" })
    end
end

local function buildTopStyle(tab)
    tab.topbarItem = tab.window:Create("Frame", {
        Name = tab.name,
        Size = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        LayoutOrder = tab.customOrder or 0,
        Parent = tab.window.tabList,
    })

    tab.topbarItemInteract = tab.window:Create("TextButton", {
        Active = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        Parent = tab.topbarItem,
    })

    tab.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 14),
        Parent = tab.topbarItem,
    })

    tab.topbarItemStroke = tab.window:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,
        Parent = tab.topbarItem,
    })

    buildGradients(tab, tab.topbarItem, tab.topbarItemStroke)

    tab.topbarItemContainer = tab.window:Create("Frame", {
        Size = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = tab.topbarItem,
    })

    tab.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 13),
        PaddingRight = UDim.new(0, 14),
        Parent = tab.topbarItemContainer,
    })

    tab.topbarItemLayout = tab.window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tab.topbarItemContainer,
    })

    buildContent(tab, 16, false)
end

local function buildSidebarStyle(tab, layout)
    tab.topbarItem = tab.window:Create("Frame", {
        Name = tab.name,
        Size = UDim2.new(1, -layout.rowInset * 2, 0, layout.rowHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        LayoutOrder = tab.customOrder or 0,
        Parent = tab.window.tabList,
    })

    tab.topbarItemInteract = tab.window:Create("TextButton", {
        Active = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        Parent = tab.topbarItem,
    })

    tab.window:Create("UICorner", {
        CornerRadius = UDim.new(0, layout.rowCornerRadius),
        Parent = tab.topbarItem,
    })

    tab.topbarItemStroke = tab.window:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,
        Parent = tab.topbarItem,
    })

    buildGradients(tab, tab.topbarItem, tab.topbarItemStroke)

    tab.topbarItemShadow = tab.window:Create("UIShadow", {
        BlurRadius = UDim.new(0, 20),
        Color = Color3.fromRGB(255, 255, 255),
        Offset = UDim2.new(0, 0, 0, -15),
        Spread = UDim2.new(0, 10, 0, -30),
        ZIndex = -1,
        Transparency = 1,
        Parent = tab.topbarItem,
    })

    tab.topbarItemContainer = tab.window:Create("Frame", {
        Size = UDim2.new(1, -layout.rowPadding, 0, 24),
        Position = UDim2.new(0, layout.rowPadding, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = tab.topbarItem,
    })

    tab.topbarItemLayout = tab.window:Create("UIListLayout", {
        Padding = UDim.new(0, layout.rowContentSpacing),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tab.topbarItemContainer,
    })

    buildContent(tab, layout.rowIconSize, true)
end

-- [[Whether the rail is currently at its icon-only width. The rail's own Size
-- [[is the source of truth: it is written by ApplyWidth (the layout's Build
-- [[sizes it too), and row rebuilds happen after that. A window whose rail has
-- [[not been built yet falls back to the layout's requested width.]]
function tabSelector.railCollapsed(window, layout)
    if layout.mode ~= "sidebar" then
        return false
    end
    if layout.forceCollapsed then
        return true
    end
    local sidebar = window.sidebar
    local width = if sidebar then sidebar.Size.X.Offset else (layout.railWidth :: number)
    return width <= (layout.railCollapsedWidth :: number)
end

function tabSelector.build(tab, layoutMode)
    if layoutMode.mode == "sidebar" or layoutMode.forceCollapsed then
        buildSidebarStyle(tab, layoutMode)
        -- [[A row has to be born in whatever state the rail is in right now.
        -- [[Rows are rebuilt after the rail is sized (a layout switch, or a tab
        -- [[created while the rail is icon-only), and a row built as an
        -- [[expanded one keeps its title: in a 64px rail that leaked "El…" of
        -- [[the tab name past the icon instead of the icon-only row.
        if tabSelector.railCollapsed(tab.window, layoutMode) then
            tabSelector.setRowCollapsed(tab, true, layoutMode)
        end
    else
        buildTopStyle(tab)
    end
end

-- [[Responsive sidebar sizing: the tab names drive the rail's width. The]]
-- [[longest visible row sets the rail's natural width, so every row (which]]
-- [[stays full-rail, as before) shares the width of the longest tab, and]]
-- [[the elements area takes back whatever the rail frees up. The window's]]
-- [[available space is the cap, so a long name wraps in place instead of]]
-- [[swallowing the content area.]]

local function inCurrentRail(window, tab)
    -- [[Parent guards out rows destroyed mid-layout-switch: their parent]]
    -- [[rail is gone before the rebuilt rows exist, and a destroyed]]
    -- [[instance must not have properties written to it.]]
    return not tab.neglectSelector
        and tab.topbarItem ~= nil
        and tab.topbarItem.Parent ~= nil
        and window:_railGroup(tab) == window:_activeRail()
end

local function rowNaturalWidth(tab, window, layout)
    local width = layout.rowPadding * 2
    if tab.icon then
        width += layout.rowIconSize
        if tab.name then
            width += layout.rowContentSpacing
        end
    end
    if tab.name then
        width += functions.textWidth(window.theme.Font, 16, locale.resolve(tab.name))
    end
    return width
end

-- [[The rail width at which the widest row in the current rail group fits]]
-- [[exactly (row insets included). 0 when the group is empty.]]
function tabSelector.railContentWidth(window, layout)
    local maxRow = 0
    for _, tab in window.tabs do
        if inCurrentRail(window, tab) then
            maxRow = math.max(maxRow, rowNaturalWidth(tab, window, layout))
        end
    end
    if maxRow <= 0 then
        return 0
    end
    return maxRow + layout.rowInset * 2
end

-- [[Rows stay full-rail; this only holds a title inside its row when the]]
-- [[rail's available width capped below the name's natural width.]]
function tabSelector.relayoutSidebarRows(window, layout, railWidth)
    if layout.mode ~= "sidebar" or layout.forceCollapsed then
        return
    end
    if not window.sidebar then
        return
    end
    railWidth = railWidth or layout.railWidth
    if railWidth <= (layout.railCollapsedWidth :: number) then
        -- [[Collapsed rail: icon-only rows, nothing to hold.]]
        return
    end

    local rowWidth = railWidth - layout.rowInset * 2
    if rowWidth <= 0 then
        return
    end

    for _, tab in window.tabs do
        if inCurrentRail(window, tab) then
            local title = tab.topbarItemTitle
            if title and tab.name then
                local slot = rowWidth - layout.rowPadding * 2
                    - (if tab.icon then layout.rowIconSize + layout.rowContentSpacing else 0)
                if
                    slot >= 24
                    and functions.textWidth(window.theme.Font, 16, locale.resolve(tab.name)) > slot
                then
                    -- [[Capped: hold the label inside the row; its existing]]
                    -- [[TextWrapped then keeps the name readable.]]
                    title.Size = UDim2.fromOffset(slot, 16)
                    title.AutomaticSize = Enum.AutomaticSize.Y
                else
                    title.Size = UDim2.fromOffset(0, 16)
                    title.AutomaticSize = Enum.AutomaticSize.XY
                end
            end
        end
    end
end

function tabSelector.setRowCollapsed(tab, collapsed, layout)
    -- [[Parent check: during a layout-mode switch the previous rail's rows]]
    -- [[are destroyed before the rebuilt ones exist, and properties must]]
    -- [[not be written to a destroyed instance.]]
    if layout.mode ~= "sidebar" or not tab.topbarItem or not tab.topbarItem.Parent then
        return
    end

    if tab.topbarItemTitle then
        if collapsed then
            -- [[Icon-only rows must never leak a title while the rail is being
            -- [[collapsed. Hide the label before the layout contracts; the
            -- [[icon remains visible throughout the transition.]]
            tab.topbarItemTitle.Visible = false
            tab.topbarItemTitle.TextTransparency = 1
        else
            tab.topbarItemTitle.Visible = true
            motion.tween(tab.topbarItemTitle, { TextTransparency = 0 }, "fast")
        end
    end
    if tab.topbarItemInitial then
        tab.topbarItemInitial.Visible = collapsed
    end
    -- [[An icon-only row is a square tile the height of the row. The rail is
    -- [[64px wide, so a full-rail row (inset 15px each side) was 34x38: the
    -- [[icon sat 7px from its sides but 9px from its top and bottom, which
    -- [[reads as an off-centre glyph. The square tile keeps the list's
    -- [[centring and leaves the icon the same clearance on all four edges.
    tab.topbarItem.Size = if collapsed
        then UDim2.fromOffset(layout.rowHeight :: number, layout.rowHeight :: number)
        else UDim2.new(1, -(layout.rowInset :: number) * 2, 0, layout.rowHeight :: number)
    local rowPadding = if collapsed then 0 else layout.rowPadding
    tab.topbarItemContainer.Size = UDim2.new(1, -rowPadding, 0, 24)
    tab.topbarItemContainer.Position = UDim2.new(0, rowPadding, 0.5, 0)
    tab.topbarItemLayout.HorizontalAlignment = if collapsed
        then Enum.HorizontalAlignment.Center
        else Enum.HorizontalAlignment.Left
end

function tabSelector.applyVisual(tab, visualState, tweenInfo)
    local targets = {
        [tab.topbarItem] = { BackgroundTransparency = visualState.background },
        [tab.topbarItemStroke] = { Transparency = visualState.stroke },
    }

    if tab.topbarItemIcon then
        targets[tab.topbarItemIcon] = { ImageTransparency = visualState.content }
    end
    if tab.topbarItemTitle then
        targets[tab.topbarItemTitle] = { TextTransparency = visualState.content }
    end
    if tab.topbarItemInitial then
        targets[tab.topbarItemInitial] = { TextTransparency = visualState.content }
    end
    if tab.topbarItemShadow and visualState.shadow then
        targets[tab.topbarItemShadow] = { Transparency = visualState.shadow }
    end

    for instance, properties in targets do
        if tweenInfo then
            -- [[`tweenInfo` is a motion spec (name or TweenInfo): routing the
            -- pill states through the service gives them the shared curve,
            -- the time scale and one owner per property.]]
            motion.tween(instance, properties, tweenInfo)
        else
            for prop, value in properties do
                instance[prop] = value
            end
        end
    end
end

return tabSelector
