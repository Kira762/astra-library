local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local actionComponent = require(script.Parent.action)

local search = {}

local hoverTween = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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

local function setPillVisibility(window, visible, tweenInfo)
    state.tweenService
        :Create(window.searchPill, tweenInfo, {
            BackgroundTransparency = if visible then 0.9 else 1,
        })
        :Play()
    state.tweenService:Create(window.searchStroke, tweenInfo, { Transparency = if visible then 0.85 else 1 }):Play()
    state.tweenService:Create(window.searchShadow, tweenInfo, { Transparency = if visible then 0.92 else 1 }):Play()
    state.tweenService:Create(window.searchIcon, tweenInfo, { ImageTransparency = if visible then 0.65 else 1 }):Play()
    state.tweenService:Create(window.searchInput, tweenInfo, { TextTransparency = if visible then 0.2 else 1 }):Play()
end

local function setTabVisibility(window, visible, tweenInfo)
    if window.layout.mode == "sidebar" then
        return
    end
    for _, tab in window.tabs do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual(
                if visible then (if window.selectedTab == tab then "selected" else "unselected") else "hidden",
                tweenInfo
            )
        end
    end
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
        if unit.unit.descriptor then
            unit.unit.descriptor.main.Visible = isVisible
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
            descOrder = element.descriptor and element.descriptor.main.LayoutOrder,
        })

        mainFrame.LayoutOrder = order * 10
        mainFrame.Parent = window.searchPage
        mainFrame.Visible = true
        if element.descriptor then
            element.descriptor.main.LayoutOrder = order * 10 + 1
            element.descriptor.main.Parent = window.searchPage
            element.descriptor.main.Visible = true
        end
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
        if element.descriptor and element.descriptor.main and element.descriptor.main.Parent then
            element.descriptor.main.LayoutOrder = unit.descOrder
            element.descriptor.main.Parent = unit.homeParent
            element.descriptor.main.Visible = true
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

    setTabVisibility(window, false, hoverTween)
    task.delay(hoverTween.Time, function()
        if not window.unloaded and window._searching and window.layout.mode ~= "sidebar" then
            window.tabList.Visible = false
        end
    end)

    window.searchPill.Visible = true
    setPillVisibility(window, true, hoverTween)
    window.searchInput:CaptureFocus()

    state.tweenService:Create(window.searchAction.iconLabel, hoverTween, { ImageTransparency = hoverTransparency }):Play()
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

    setPillVisibility(window, false, hoverTween)
    task.delay(hoverTween.Time, function()
        if not window.unloaded and not window._searching then
            window.searchPill.Visible = false
        end
    end)

    if opts.showTabs then
        if window.layout.mode == "sidebar" and window._applySettingsLayout then
            window:_applySettingsLayout(window._settingsMode)
        else
            window.tabList.Visible = true
        end
        setTabVisibility(window, true, hoverTween)
    end

    state.tweenService:Create(window.searchAction.iconLabel, hoverTween, { ImageTransparency = defaultTransparency }):Play()
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
        PaddingTop = UDim.new(0, if window.layout.mode == "sidebar" then 53 else 10),
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

    local isSidebar = window.layout.mode == "sidebar"
    local pillTop = if isSidebar then window.layout.chromeHeight + 8 else window.layout.tabStripTop + 1

    window.searchPill = window:Create("Frame", {
        Name = "SearchBar",
        AnchorPoint = Vector2.new(if isSidebar then 1 else 0.5, 0),
        Position = UDim2.new(if isSidebar then 1 else 0.5, if isSidebar then -15 else 0, 0, pillTop),
        Size = UDim2.new(1, if isSidebar then -(window.layout.railWidth + 30) else -35, 0, 35),
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
