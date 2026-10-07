local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local motion = require(utilities.motion)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local actionComponent = require(script.Parent.action)

local search = {}

--[[
The title-bar search field shares the library's hover spec for its fades,
but opening is a reveal rather than a fade: the pill's right edge is pinned
`SEARCH_ACTION_GAP` off the action group and only its width grows, so the
field expands from right to left out of the search action's side and folds
back into it on close. The two directions follow the motion vocabulary —
an entrance decelerates (`smooth`), an exit accelerates (`exit`) — and the
fold's own completion hides the pill, so it never disappears while it is
still moving.
]]
local HOVER_SPEC = "snappy"
local REVEAL_SPEC = "smooth"
local COLLAPSE_SPEC = "exit"
local SEARCH_TITLE_GAP = 16
local SEARCH_ACTION_GAP = 12
local SEARCH_HEIGHT = 35

local defaultTransparency = 0.6
local hoverTransparency = 0.2
local surfaceTransparency = 0.9

local function getElementText(element)
    if element.__type == "Group" or element.__type == "CollapsibleGroup" then
        local names = { element.name or "" }
        local function collectNames(group)
            for _, child in group.elements do
                if child.__type == "Group" or child.__type == "CollapsibleGroup" then
                    collectNames(child)
                elseif child.name then
                    table.insert(names, child.name)
                end
            end
        end
        collectNames(element)
        return table.concat(names, "\n")
    end
    return element.name or ""
end

local function getAllElements(window)
    local elements = {}
    for _, tab in window.tabs do
        --[[
        Locked tabs keep their contents private: their elements never
        reach the search index, so a search cannot leak a name.
        ]]
        if tab.neglectSelector or tab.locked then
            continue
        end
        for _, element in tab.elements do
            if element.__type ~= "Section" then
                table.insert(elements, element)
            end
        end
    end
    return elements
end

--[[
The field's glass: outline, glow, glyph and text fade with the hover spec
while the surface's own fill rides the reveal tween (see
`applySearchGeometry`), so the pill and its contents arrive as one piece.
]]
local function setPillVisibility(window, visible, spec)
    motion.tween(window.searchStroke, { Transparency = if visible then 0.85 else 1 }, spec)
    motion.tween(window.searchShadow, { Transparency = if visible then 0.92 else 1 }, spec)
    motion.tween(window.searchIcon, { ImageTransparency = if visible then 0.65 else 1 }, spec)
    motion.tween(window.searchInput, { TextTransparency = if visible then 0.2 else 1 }, spec)
end

--[[
The title and action groups stay put while the input occupies the gap
between them. Measure the free space from their rendered bounds so a long
window name or a narrow window cannot push the title or toolbar controls
out of place.

The field's width is automatic: it rests at the whole of the space the
title and subtitle leave behind, so a short title gives a wide field and a
long one a narrow field. Every measurement is expressed from the field's
right edge — it is pinned `SEARCH_ACTION_GAP` off the action group and any
width grows it left, so the title keeps its gap. Returns the right edge and
the width the field rests at, or nothing when the title bar is not built
yet.
]]
local function measureSearchPill(window)
    if not window.searchPill or not window.topbar or not window.titleContainer or not window.searchAction then
        return nil
    end

    local titleRight = window.titleContainer.AbsolutePosition.X
        + window.titleContainer.AbsoluteSize.X
        - window.topbar.AbsolutePosition.X
    local actionLeft = window.searchAction.action.AbsolutePosition.X - window.topbar.AbsolutePosition.X
    local leftLimit = titleRight + SEARCH_TITLE_GAP
    local rightLimit = actionLeft - SEARCH_ACTION_GAP
    local available = math.max(0, rightLimit - leftLimit)
    return rightLimit, available
end

--[[
The field's text box, sized from the width the field rests at rather than
the one it is animating through, so it scales with the pill as the reveal
opens instead of being re-cut every frame.
]]
local function sizeSearchInput(window, restWidth)
    if not window.searchInput then
        return
    end
    window.searchInput.Position = UDim2.new(0, 36, 0.5, 0)
    window.searchInput.Size = UDim2.new(1, -math.min(48, restWidth), 0, 18)
end

--[[
The field's geometry, stated the one way every path can use it: the pill's
left edge lands at `rightLimit - width`, so `width == 0` folds it flat
against the action side and any larger width grows it leftward.
]]
local function placeSearchPill(window, rightLimit, width, restWidth)
    window.searchPill.Position = UDim2.new(0, rightLimit - width, 0.5, 0)
    window.searchPill.Size = UDim2.fromOffset(width, SEARCH_HEIGHT)
    sizeSearchInput(window, restWidth)
end

--[[
Animates the field to `width` and, while opening, brings its fill in with
the same tween — the surface and its glass are then one movement, and
`motion.tween` keeps a single tween per instance, so a reveal that reverses
mid-flight replaces the movement instead of fighting it.

`onCompleted` runs when the movement ends, including on the spot when there
is nothing left to animate (the target is already showing, or motion is
off) — that nil return is exactly `motion.tween` meaning "already done".
]]
local function tweenSearchPill(window, rightLimit, width, restWidth, revealing, onCompleted)
    sizeSearchInput(window, restWidth)

    local tween = motion.tween(window.searchPill, {
        Position = UDim2.new(0, rightLimit - width, 0.5, 0),
        Size = UDim2.fromOffset(width, SEARCH_HEIGHT),
        BackgroundTransparency = if revealing then surfaceTransparency else 1,
    }, if revealing then REVEAL_SPEC else COLLAPSE_SPEC, onCompleted)

    if not tween and onCompleted then
        onCompleted()
    end
end

--[[
Where the field belongs right now. `mode` is the movement it should be in:
"open" grows the field into the free space, "close" folds it into the action
side, and nil puts it at rest — the resting geometry with no movement at
all.

Every measurement path goes through here, and `window._searchReveal` names
the movement in flight so one of them arriving mid-movement (a window
resize, a rail change) re-targets it from where it is instead of dropping
the field at a geometry it has not reached yet. A tween replaced by the
opposite direction is cancelled by the motion service, so its completion
never runs and the new direction owns the flag.
]]
local function applySearchGeometry(window, mode)
    local rightLimit, restWidth = measureSearchPill(window)
    if not rightLimit then
        return
    end

    if not mode then
        window._searchReveal = nil
        placeSearchPill(window, rightLimit, restWidth, restWidth)
        return
    end

    window._searchReveal = mode
    if mode == "close" then
        tweenSearchPill(window, rightLimit, 0, restWidth, false, function()
            window._searchReveal = nil
            if not window.unloaded and not window._searching then
                window.searchPill.Visible = false
            end
        end)
        return
    end

    --[[
    Open from the width already showing: a reveal that restarts while the
    field is still folding continues from where it is rather than jumping
    flat and growing again.
    ]]
    local startWidth = math.clamp(window.searchPill.Size.X.Offset, 0, restWidth)
    placeSearchPill(window, rightLimit, startWidth, restWidth)
    tweenSearchPill(window, rightLimit, restWidth, restWidth, true, function()
        window._searchReveal = nil
    end)
end

--[[
A re-measure: a window resize, a rail change, a layout switch. The movement
in flight (if any) is re-targeted; a resting field keeps sitting in the
free space it has.
]]
local function positionSearchPill(window)
    applySearchGeometry(window, window._searchReveal)
end

local function setTabVisibility(window, visible, tweenInfo)
end

local function filterElements(window, query)
    query = string.lower(query or "")
    local hasVisible = false
    for _, unit in window._searchUnits do
        local isVisible = query == "" or string.find(unit.text, query, 1, true) ~= nil
        unit.unit.main.Visible = isVisible
        if unit.homeExpanded ~= nil then
            unit.unit:_setExpanded(if query ~= "" and isVisible then true else unit.homeExpanded, false)
        end
        hasVisible = hasVisible or isVisible
    end
    window.searchEmpty.Visible = not hasVisible and query ~= ""
end

local function collectElements(window)
    window._searchUnits = {}
    local order = 0

    --[[
    Elements of tabs the player has not opened yet are still hidden (see
    `Window:_markTabElementsPending`). The search lays every element out on
    its own page, so bring them all in first - exactly the state the old
    reveal left them in.
    ]]
    for _, tab in pairs(window.tabs) do
        if tab._elementsPending then
            window:_showTabElements(tab)
        end
    end
    for _, element in getAllElements(window) do
        order += 1
        local mainFrame = element.main
        table.insert(window._searchUnits, {
            unit = element,
            homeExpanded = if element.__type == "CollapsibleGroup" then element._expanded else nil,
            text = string.lower(getElementText(element)),
            homeParent = mainFrame.Parent,
            homeOrder = mainFrame.LayoutOrder,
        })

        mainFrame.LayoutOrder = order * 10
        mainFrame.Parent = window.searchPage
        mainFrame.Visible = true
    end
end

local function restoreElements(window)
    for _, unit in window._searchUnits do
        local element = unit.unit
        if unit.homeExpanded ~= nil then
            element:_setExpanded(unit.homeExpanded, false)
        end
        if element.main and element.main.Parent then
            element.main.LayoutOrder = unit.homeOrder
            element.main.Parent = unit.homeParent
            element.main.Visible = true
        end
    end
    window._searchUnits = {}
end

function search.open(window)
    if window._searching or window.minimised or not window:_interactive() then
        return
    end
    search.buildContent(window)
    window:_applyRailWidth()
    window._searching = true

    -- The field is shown collapsed against the action side and grows leftward
    -- from there; it reads `window._searchReveal` for the direction.
    window.searchPill.Visible = true
    applySearchGeometry(window, "open")

    collectElements(window)
    filterElements(window, "")
    window:_jumpTo(window.searchPage)

    setPillVisibility(window, true, HOVER_SPEC)
    window.searchInput:CaptureFocus()

    motion.tween(window.searchAction.iconLabel, { ImageTransparency = hoverTransparency }, HOVER_SPEC)
end

function search.close(window, opts)
    if not window._searching then
        return
    end
    opts = opts or {}
    window._searching = false

    window.searchInput.Text = ""
    window.searchInput:ReleaseFocus()
    window.searchEmpty.Visible = false

    restoreElements(window)
    local jumpTarget = if opts.jumpTo == nil then window.selectedTab and window.selectedTab.tabPage else opts.jumpTo
    if jumpTarget then
        window:_jumpTo(jumpTarget)
    end

    setPillVisibility(window, false, HOVER_SPEC)
    --[[
    Fold the field back into the action side. It hides when the movement
    ends — or on the spot, when there is nothing left to animate — so the
    pill is never taken off screen while it is still collapsing.
    ]]
    applySearchGeometry(window, "close")

    if opts.showTabs then
        if window._applySettingsLayout then
            window:_applySettingsLayout(window._settingsMode)
        else
            window.tabList.Visible = true
        end
    end

    motion.tween(window.searchAction.iconLabel, { ImageTransparency = defaultTransparency }, HOVER_SPEC)
end

function search.toggle(window)
    if window._searching then
        search.close(window, { showTabs = true })
    else
        search.open(window)
    end
end

function search.railWidth(window)
    if window._searching then
        positionSearchPill(window)
    end
end

function search.buildContent(window)
    if window.searchPage then
        return
    end

    window.searchPage = window:Create("ScrollingFrame", {
        Name = "Search",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2000,
        Parent = window.elements,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = window.searchPage,
    })

    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 33),
        Parent = window.searchPage,
    })

    window.searchEmpty = window:Create("TextLabel", {
        Name = "NoResults",
        Text = locale.t("No results"),
        FontFace = state.brandFont(Enum.FontWeight.Medium),
        TextSize = 15,
        TextTransparency = 0.6,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        Size = UDim2.fromOffset(200, 20),
        Visible = false,
        ZIndex = 3,
        Parent = window.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    --[[
    The field is built flat against the action side and only ever given a
    width by `applySearchGeometry`, so its first open animates like every
    other one instead of appearing at a stale resting width.
    ]]
    window.searchPill = window:Create("Frame", {
        Name = "SearchBar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(0, SEARCH_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 10,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.topbar,
    })

    --[[
    The field floats in the topbar's open space beside the title; it wears
    the element tier rather than the shell's own arc and leaves the title
    and action groups in their normal positions.
    ]]
    window:Create("UICorner", {
        Parent = window.searchPill,
    }, { CornerRadius = "ElementCornerRadius" })

    window.searchStroke = window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,
        Transparency = 1,
        Parent = window.searchPill,
    })

    window.searchShadow = window:Create("UIShadow", {
        BlurRadius = UDim.new(0, 20),
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = -1,
        Transparency = 1,
        Parent = window.searchPill,
    })

    window.searchIcon = window:Create("ImageLabel", {
        Image = "rbxassetid://" .. tostring(constants.icons.search),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 1),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ZIndex = 10,
        ImageTransparency = 1,
        Parent = window.searchPill,
    }, { ImageColor3 = "ContentColor" })

    window.searchInput = window:Create("TextBox", {
        Text = "",
        PlaceholderText = locale.t("Search all pages"),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 36, 0.5, 0),
        Size = UDim2.new(1, -48, 0, 18),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        ZIndex = 10,
        TextTransparency = 1,
        Parent = window.searchPill,
    }, { TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })

    window:Connect(window.searchInput:GetPropertyChangedSignal("Text"), function()
        if window._searching then
            filterElements(window, window.searchInput.Text)
        end
    end)

    window:Connect(window.main:GetPropertyChangedSignal("Size"), function()
        if not window._searching then
            return
        end
        task.defer(function()
            if window._searching and not window.unloaded then
                positionSearchPill(window)
            end
        end)
    end)

    --[[
    The title and subtitle size themselves to their text, so the space the
    field rests in moves with them: a title that changes while the field is
    open re-fits it to the room it now has.
    ]]
    window:Connect(window.titleContainer:GetPropertyChangedSignal("AbsoluteSize"), function()
        if not window._searching then
            return
        end
        task.defer(function()
            if window._searching and not window.unloaded then
                positionSearchPill(window)
            end
        end)
    end)
end

function search.build(window)
    window._searching = false
    window.searchAction = actionComponent.new(window, {
        name = "Search",
        icon = constants.icons.search,
        order = 4,
        callback = function()
            search.toggle(window)
        end,
    })
    window.searchAction.isLit = function()
        return window._searching
    end

    window:Connect(state.userInputService.InputBegan, function(input)
        if not window._searching or input.KeyCode ~= Enum.KeyCode.Escape then
            return
        end
        if state.userInputService:GetFocusedTextBox() ~= window.searchInput then
            return
        end
        search.close(window, { showTabs = true })
    end)
end

return search
