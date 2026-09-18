local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local motion = require(utilities.motion)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local actionComponent = require(script.Parent.action)

local search = {}

-- [[The search overlay shares the library's hover spec for its fades; the
-- two task.delay beats below read the spec's duration so the pill never
-- hides while its fade is still running.]]
local HOVER_SPEC = "snappy"
local HOVER_SPEC_TIME = 0.25

local defaultTransparency = 0.6
local hoverTransparency = 0.2

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
        if tab.neglectSelector then
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

local function setPillVisibility(window, visible, spec)
    motion.tween(window.searchPill, { BackgroundTransparency = if visible then 0.9 else 1 }, spec)
    motion.tween(window.searchStroke, { Transparency = if visible then 0.85 else 1 }, spec)
    motion.tween(window.searchShadow, { Transparency = if visible then 0.92 else 1 }, spec)
    motion.tween(window.searchIcon, { ImageTransparency = if visible then 0.65 else 1 }, spec)
    motion.tween(window.searchInput, { TextTransparency = if visible then 0.2 else 1 }, spec)
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

    -- [[Elements of tabs the player has not opened yet are still hidden (see
    -- [[`Window:_markTabElementsPending`). The search lays every element out on
    -- [[its own page, so bring them all in first - exactly the state the old
    -- [[reveal left them in.]]
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

    collectElements(window)
    filterElements(window, "")
    window:_jumpTo(window.searchPage)

    window.searchPill.Visible = true
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
    task.delay(HOVER_SPEC_TIME, function()
        if not window.unloaded and not window._searching then
            window.searchPill.Visible = false
        end
    end)

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

function search.railWidth(window, railWidth)
    if window.searchPill then
        window.searchPill.Size = UDim2.new(1, -(railWidth + 30), 0, 35)
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
        PaddingTop = UDim.new(0, 53),
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

    local pillTop = window.layout.chromeHeight + 8

    window.searchPill = window:Create("Frame", {
        Name = "SearchBar",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -15, 0, pillTop),
        Size = UDim2.new(1, -(window.layout.railWidth + 30), 0, 35),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 10,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.main,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = window.searchPill,
    })

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
        Position = UDim2.new(0, 15, 0.5, 1),
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
        Position = UDim2.new(0, 40, 0.5, 0),
        Size = UDim2.new(1, -110, 0, 18),
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
end

return search
