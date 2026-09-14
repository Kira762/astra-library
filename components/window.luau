local utilities = script.Parent.Parent.utilities
local image = require(script.Parent.Parent.images.image)
local icons = require(script.Parent.Parent.icons)
local functions = require(script.Parent.Parent.functions)
local persistence = require(utilities.persistence)
local constants = require(utilities.constants)
local motion = require(utilities.motion)
local locale = require(utilities.locale)
local log = require(utilities.log)
local haptic = require(utilities.HapticEngine)
local windowSizing = require(utilities.windowSizing)
local layouts = require(utilities.layouts)
local chrome = require(script.Parent.chrome)
local search = require(script.Parent.search)
local tabSelector = require(script.Parent.tabSelector)
local profilePanel = require(script.Parent.profilePanel)
local settingsComponent = require(script.Parent.settings)

local state = require(utilities.Parent.core.state)

local themes = require(script.Parent.Parent.themes)

local Window = {}
Window.__index = Window

local revealTween = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local tweenStyle = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local collapsedWideSize = UDim2.fromOffset(185, 50)
local collapsedIconOnlySize = UDim2.fromOffset(50, 50)
local collapsedPosition = UDim2.new(0.5, 0, 0, 20)
local toastsTopPosition = UDim2.new(0.5, 0, 0, 12)
local toastsTopWhenCollapsed = UDim2.new(0.5, 0, 0, collapsedPosition.Y.Offset + collapsedWideSize.Y.Offset + 12)
local toastPositionTween = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local toastWidth = 320

local compactRowHeight = 41

-- [[The window's own surface, defined once. Everything that has to read as
-- [["the window background" — the frame itself and the profile card beside it —
-- [[is styled through Window:StyleWindowSurface, so the two can never drift
-- [[into near-miss shades of each other: same base colour, same WindowColor
-- [[gradient (theme token + the same rotation/offset, so a theme change moves
-- [[both together) and the same opacity once shown.]]
local windowSurfaceColor = Color3.fromRGB(255, 255, 255)
local windowSurfaceTransparency = 0
local windowSurfaceGradientRotation = 270
local windowSurfaceGradientOffset = Vector2.new(0, -0.1)

local lockScrimTransparency = 0.55
local lockedTextTransparency = 0.55

local epsilon = 0.04
local scrollbarWidth = 8

local viewportCheckInterval = 2

local function computeSize(mode): UDim2
    local size = state.workspace.CurrentCamera
    return windowSizing.fit(size and size.ViewportSize, mode)
end

local cornerKeys = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" }

local hasPerCornerRadius = (function()
    return (
        pcall(function()
            local instance = Instance.new("UICorner")
            instance.TopLeftRadius = UDim.new(0, 1)
            instance:Destroy()
        end)
    )
end)()

local function layoutFor(isSidebar)
    return if isSidebar then layouts.sidebar else layouts.top
end

local function layoutKey(layout)
    if layout.mode == "sidebar" and layout.forceCollapsed then
        return "collapsedSidebar"
    end
    return layout.mode
end

local coerceValue = themes.coerceValue
local firstColor = themes.firstColor
local deriveStrokes = themes.deriveStrokes
local resolveTheme = themes.resolve

local function updateToastPosition(window, animate)
    local toastsTop = window._toastsTop
    if not toastsTop then
        return
    end

    local targetPos = if window._collapsedShown then toastsTopWhenCollapsed else toastsTopPosition
    if not animate or toastsTop.Position == targetPos then
        toastsTop.Position = targetPos
        return
    end

    state.tweenService:Create(toastsTop, toastPositionTween, { Position = targetPos }):Play()
end

function Window:ResolveIcon(value, pack)
    return icons.resolve(value, pack)
end

function Window.new(props)
    props = if typeof(props) == "table" then props else {}

                if props.translations or props.Translations then
        locale.register(props.translations or props.Translations)
    end
    if props.translator or props.Translator then
        locale.translator = props.translator or props.Translator
    end
    locale.setActive(props.locale or props.Locale or locale.detect())

            local fallbackFont = props.fallbackFont or props.FallbackFont
    if fallbackFont then
        state.setFallbackFont(fallbackFont)
    end

        local layout = layouts.top -- [[layout is controlled via Settings (Astra Settings → Bar Layout); CreateWindow no longer takes sidebarLayout]]
    local providedIcon = props.icon or props.Icon

    local self = setmetatable({
        name = props.name or props.Name or "Astra Window",
        subheading = props.subtitle or props.Subtitle,
        layout = layout,
        size = computeSize(layout.mode),
        instances = {},
        connections = {},

        icon = icons.resolve(providedIcon or "Sirius"),
        showName = props.showName or props.ShowName or "Astra",
        showIcon = icons.resolve(providedIcon or "Astra"),
                showIconOnly = props.showIconOnly or props.ShowIconOnly or false,
                profileText = nil,

        themeProperties = {},
        localeProperties = {},
        tabs = {},
        tabSections = {},
        tags = {},
        selectedTab = nil,
        _settingsLayoutActive = false,
        _settingsTabs = {},
        _settingsMode = false,
        theme = resolveTheme(props.theme or props.Theme),

        controls = {},

        configuration = (function()
            -- Legacy overrides remain accepted, but normal usage needs no config table.
            local config = props.configuration or props.Configuration or {}
            local save = config.autoSave
            if save == nil then save = config.AutoSave end
            local load = config.autoLoad
            if load == nil then load = config.AutoLoad end
            return {
                autoSave = if save == nil then true else save == true,
                autoLoad = if load == nil then true else load == true,
                fileName = config.fileName or config.FileName or "Astra-Hub",
                customFolder = config.customFolder or config.CustomFolder or "AstraConfigs",
            }
        end)(),
    }, Window)

            self.Flags = setmetatable({}, {
        __index = function(_, key)
            local control = self.controls[key]
            return control and control.value
        end,
        __newindex = function(_, key, value)
            local control = self.controls[key]
            if not control then
                log.warn("Astra: no flag '" .. tostring(key) .. "' to set")
                return
            end
            control:Set(value)
        end,
        __iter = function()
            local key
            return function()
                local value
                key, value = next(self.controls, key)
                if key then
                    return key, value.value
                end
                return nil
            end
        end,
    })

            self.settings = {
        toggleKeybind = Enum.KeyCode.K,
        theme = if type(props.theme or props.Theme) == "string" then string.lower(props.theme or props.Theme) else "default",
        mouseOverride = true,         keepOnScreen = true,         welcomeToast = true,         haptics = false,
        dragMinimisedBar = false,
        showProfile = true,
        showFullUsername = false,
        profileSide = "right",
        antiWindowDuplicate = true,
        layoutMode = layout.mode,
        activeSubTab = 1,
        motionSpeed = "normal",
        autoSaveConfig = self.configuration.autoSave,
        autoLoadConfig = self.configuration.autoLoad,
    }
        self._layoutTransitioning = false

        self.screenGui = self:Create("ScreenGui", {
        Name = state.httpService:GenerateGUID(false),
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = constants.displayOrder.window,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,

        Parent = state.guiContainer,
    })
        self.main = self:Create("Frame", {
        Name = self.name,
        ZIndex = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = self.size,
        BackgroundTransparency = 1,         Visible = false,
        Parent = self.screenGui,
    })

    self.drag = require(script.Parent.drag).new(self)

    self.windowCorner = self:Create("UICorner", {

        Parent = self.main,
    }, { CornerRadius = "CornerRoundness" })

    self.windowStroke = self:Create("UIStroke", {
                Transparency = 1,
        Parent = self.main,
    }, { Color = "SurfaceStroke" })

    self.windowGradient = self:StyleWindowSurface(self.main)

                self.bottomFade = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = self.layout.fadeSize,
        ZIndex = constants.zIndex.bottomFade,

                BackgroundTransparency = 1,
        Parent = self.main,
    })

    self.bottomFadeCorner = self:_roundCorners(self.bottomFade, self.layout.fadeCorners)

    self.bottomFadeGradient = self:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, 0.2),
        Transparency = self.layout.fadeTransparency,

        Parent = self.bottomFade,
    }, {
                        Color = {
            "WindowColor",
            function(color)
                return ColorSequence.new(functions.toColorSequence(color).Keypoints[1].Value)
            end,
        },
    })

        self.topbar = self:Create("Frame", {

        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, self.layout.topbarHeight),
                        Active = true,

        Parent = self.main,
    })

    self.topContainer = self:Create("Frame", {
        Size = UDim2.new(0, 300, 0, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,

        Parent = self.topbar,
    })

    self.topContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.topContainer,
    })

    self.titleContainer = self:Create("Frame", {
        Size = UDim2.fromOffset(50, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        LayoutOrder = 1,

        Parent = self.topContainer,
    })

    self.titleContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    if self.name then
        self.title = self:Create("TextLabel", {
                        Text = locale.t(self.name),
            FontFace = state.brandFont(Enum.FontWeight.Medium),

            Size = UDim2.fromOffset(50, 20),
            AutomaticSize = Enum.AutomaticSize.X,

            BackgroundTransparency = 1,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

                        TextTransparency = 1,
            Parent = self.titleContainer,
        }, { FontFace = "Font", TextColor3 = "TitlingColor" })
    end

    if self.icon then
        self.topbarIcon = self:Create("ImageLabel", {
            Image = self.icon,

            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(32, 32),

                        ImageTransparency = 1,
            Parent = self.topContainer,
        }, { ImageColor3 = "TitlingColor" })
    end

    if self.subheading then
        self.subtitle = self:Create("TextLabel", {
                        Text = locale.t(self.subheading),
            Size = UDim2.fromOffset(50, 12),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

                        TextTransparency = 1,
            Parent = self.titleContainer,
        }, { TextColor3 = "TitlingColor", FontFace = "Font" })
    end

    self.tagContainer = self:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 25, 0.5, 0),
        Size = UDim2.fromOffset(50, 24),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Visible = false,

        Parent = self.topContainer,
    })

    self.tagContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tagContainer,
    })


        self.windowShadow = self:CreateGlow(self.main, "ShadowColor", 20, 1)

                self.elements = self:Create("Frame", {
        Size = UDim2.new(1, 0, 1, -self.layout.chromeHeight),
        Position = UDim2.fromScale(1, 1),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,

        Parent = self.main,
    })

    if self.layout.mode == "sidebar" then
        self.elementsCorner = self:_roundCorners(self.elements, self.layout.cardCorners)

        self.elementsStroke = self:Create("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,

                        Transparency = 1,
            Parent = self.elements,
        }, { Color = "SurfaceStroke" })

                        self:Create("UIGradient", {
            Rotation = self.layout.cardStrokeRotation,
            Transparency = self.layout.cardStrokeTransparency,

            Parent = self.elementsStroke,
        })
    end

    self.elementsLayout = self:Create("UIPageLayout", {
        Padding = UDim.new(0, 0),
        FillDirection = self.layout.pageDirection,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

                        ScrollWheelInputEnabled = false,
        GamepadInputEnabled = false,
        TouchInputEnabled = false,

        EasingStyle = Enum.EasingStyle.Exponential,
        TweenTime = 0.4,

        Parent = self.elements,
    })

            local initialLayout = layouts.implementation(layoutKey(self.layout))
    initialLayout.Build(self, self.layout)
    initialLayout.ApplyWidth(self, self:_railWidth())

        self.actionContainer = self:Create("Frame", {

        AnchorPoint = Vector2.new(1, 0.5),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 24),
        Position = UDim2.new(1, -20, 0.5, 0),
        BackgroundTransparency = 1,

        Parent = self.topbar,
    })

    self.actionsListLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.actionContainer,
    })

    self:_constructionCheckpoint(true)

    self.rfSettings = self:CreateTab({
        name = "General",
        icon = "sliders-horizontal",
        customOrder = 1001,
        forgetState = true,
        isSettingsTab = true,
    })
    self.rfSettings._isSettingsTab = true
    self._settingsTabs = { self.rfSettings }

    require(script.Parent.action).new(self, {
        name = "Close",
        icon = constants.icons.close,
        order = 1,

        callback = function()
            self:Popup({
                title = "Close window?",
                content = "Are you sure you want to close this window?",
                options = {
                    { text = "Cancel" },
                    {
                        text = "Close",
                        style = "primary",
                        callback = function()
                            self:Close()
                        end,
                    },
                },
            })
        end,
    })

    self.minimiseAction = require(script.Parent.action).new(self, {
        name = "Minimise",
        icon = constants.icons.minimise,
        order = 2,

        callback = function()
            self:ToggleHide()
        end,
    })

    self.settingsAction = require(script.Parent.action).new(self, {
        name = "Settings",
        icon = constants.icons.settings,
        order = 3,
        linkedTab = self.rfSettings,

        callback = function()
            self:_toggleSettingsMode()
        end,
    })

    search.build(self)
        self:_applyRailWidth()

    self.unloaded = false
    self.minimised = false
    self.hidden = true
    self.animating = false
    self._revealing = false
    self.hasShownOnce = false
    self._collapsedShown = false

        self:LoadSettings()
    self:ChangeTheme(self.settings.theme)
    if self.settings.layoutMode == "collapsedSidebar"
        or (self.settings.layoutMode and self.settings.layoutMode ~= self.layout.mode)
    then
        self:_setLayoutMode(self.settings.layoutMode)
    end

    haptic.setContainer(self.screenGui)     haptic.setEnabled(self.settings.haptics)     chrome.buildCollapsedFace(self)

    self:_constructionCheckpoint(true)
    profilePanel.build(self)
    profilePanel.setSubtitle(self, self.profileText)
    if profilePanel.isEnabled(self) then
        self.main.Position = self:_profileCenterPosition()
    end
    task.defer(function()
        if self.unloaded or state.localPlayer or not self.profilePanel then
            return
        end
        local deadline = os.clock() + 2
        local connection
        connection = state.runService.RenderStepped:Connect(function()
            if self.unloaded then
                connection:Disconnect()
                return
            end
            if state.localPlayer or os.clock() > deadline then
                connection:Disconnect()
                if state.localPlayer and self.profilePanel then
                    profilePanel.applyIdentity(self)
                    profilePanel.setShown(self, true, profilePanel.settleInfo)
                    -- [[The player may have arrived after construction, when]]
                    -- [[the panel was still disabled and the window was not]]
                    -- [[shifted. If the window is still anchored at the]]
                    -- [[screen centre (the user has not dragged it), centre]]
                    -- [[the window + panel pair now.]]
                    if self.main.Position.X.Scale == 0.5 and self.main.Position.Y.Scale == 0.5 then
                        self:_recenterForProfile(true)
                    end
                end
            end
        end)
        -- [[The connection already exists here, so it is adopted into the]]
        -- [[window's list directly: Window:Connect takes a *signal* and calls]]
        -- [[:Connect on it, which threw on a connection object and killed this]]
        -- [[waiter — the profile card then stayed hidden even with "Show]]
        -- [[profile" on.]]
        table.insert(self.connections, connection)
    end)
    self:_bindKeybind()
    self:_bindMouseOverride()
    self:_bindTopbarDrag()
    self:_watchViewport()
    self:_updateWindowTitle()

    self:_applyMotionSetting()
    self:_syncLiveAnimation()

    -- [[Construction is complete: settings tab content may now be built]]
    -- [[lazily on first open (it is skipped while the window is still]]
    -- [[being constructed, e.g. by the first-tab auto-select).]]
    self._constructed = true

    return self
end

-- Yield only at completed construction boundaries, never halfway through a
-- control. Limit startup batches by both CPU time and instance count. The
-- synchronous API is preserved: callers resume with fully usable objects.
function Window:_constructionCheckpoint(force)
    if self.hasShownOnce or (not force and not self._constructed) then
        return
    end
    self._constructionRevision = (self._constructionRevision or 0) + 1
    local now = os.clock()
    local last = self._constructionClock or now
    local count = #self.instances
    if force or now - last >= 0.004 or count - (self._constructionInstances or 0) >= 80 then
        self._constructionBusy = (self._constructionBusy or 0) + 1
        task.wait() -- next Heartbeat, not another deferred task in this frame
        self._constructionBusy -= 1
        assert(not self.unloaded, "Window unloaded during construction")
        self._constructionClock = os.clock()
        self._constructionInstances = #self.instances
    else
        self._constructionClock = last
    end
end

-- [[The "Animation speed" setting owns the motion service's time scale. It is
-- applied from the window (not only from the settings control) so a window
-- built from persisted settings, a configuration load and a live change all
-- reach the same state; an unknown persisted value falls back to `normal`
-- instead of leaving the library on whatever the last window used.]]
function Window:_applyMotionSetting()
    if not motion.setProfile(self.settings.motionSpeed) then
        self.settings.motionSpeed = "normal"
        motion.setProfile("normal")
    end
end

function Window:_syncLiveAnimation()
    if not self.theme.LiveAnimation then
        self._liveAnimating = false         return
    end
    if self._liveAnimating then
        return     end

    self._liveAnimating = true
            self._liveGeneration = (self._liveGeneration or 0) + 1
    local generation = self._liveGeneration
    task.spawn(function()
        local forward = true
        -- [[Shared spec from the motion service: the ambient drift is long
        -- enough that re-creating its TweenInfo per cycle was pure waste.]]
        local liveTweenInfo = motion.spec("drift")

        while self._liveGeneration == generation and self._liveAnimating and not self.unloaded do
            -- [[The card beside the window is the same surface, so it rides the
            -- [[same animation: a static card next to a live window would show
            -- [[two different shades of the same gradient. It is read fresh
            -- [[each cycle because the card is rebuilt from scratch whenever
            -- [[the layout or the theme changes.]]
            local liveTargets = { self.windowGradient }
            local panelGradient = self.profilePanelGradient
            if panelGradient then
                table.insert(liveTargets, panelGradient)
            end

            local tweens = {}
            for _, gradient in liveTargets do
                local tween = state.tweenService:Create(gradient, liveTweenInfo, {
                    Offset = Vector2.new(if forward then 0.4 else -0.2, 0),
                    Rotation = (if forward then 220 else 280),
                })
                table.insert(tweens, tween)
                tween:Play()
            end

            self._liveTweens = tweens
            tweens[1].Completed:Wait()
            forward = not forward
        end
        if self._liveGeneration == generation then
            self._liveAnimating = false
            self._liveTweens = nil
        end
    end)
end

function Window:ChangeTheme(themeInput)
            local themeTable = if typeof(themeInput) == "table" then themeInput else resolveTheme(themeInput)
    for key, value in themeTable do
        self.theme[key] = coerceValue(key, value)
    end
        if typeof(themeInput) == "table" then
        deriveStrokes(self.theme, themeTable)
    end

    for instance, properties in self.themeProperties do
        for prop, binding in properties do
            local resolvedValue = if typeof(binding) == "table" then binding[2](self.theme[binding[1]]) else self.theme[binding]

            if instance[prop] == resolvedValue then
                continue
            end
            if typeof(resolvedValue) == "Color3" or typeof(resolvedValue) == "number" then
                state.tweenService:Create(instance, tweenStyle, { [prop] = resolvedValue }):Play()
            else
                instance[prop] = resolvedValue
            end
        end
    end

                    if self.hidden then
                        self._themeRefreshPending = true
    else
        self:_refreshElementThemes()
    end

    self:_syncLiveAnimation()
    -- [[A theme can change the row title font, hence the rail width.]]
    self:_applyContentRailWidth()

    -- [[Capsule / minimised bar: keep the live corner on the theme's pill
    -- [[radius so ChangeTheme restyles the bar without needing a re-collapse.]]
    if self.windowCorner and (self._collapsedShown or self.minimised) and not self.animating then
        local pill = self.theme.PillCornerRadius or UDim.new(1, 0)
        if self.windowCorner.CornerRadius ~= pill then
            state.tweenService:Create(self.windowCorner, tweenStyle, { CornerRadius = pill }):Play()
        end
    end
end

function Window:_refreshElementThemes()
    for _, tab in self.tabs do
        for _, element in tab.elements do
            if element._refreshTheme then
                element:_refreshTheme()
            end
        end
    end
end

function Window:CreateTab(props)
    assert(not self.unloaded, "Cannot create a tab on an unloaded window.")
    local tab = require(script.Parent.Parent.elements.tab).new(self, props)

    table.insert(self.tabs, tab)

    if not tab.neglectSelector then
        local isFirst = true
        for _, existingTab in self.tabs do
            if existingTab ~= tab and not existingTab.neglectSelector and existingTab._isSettingsTab == tab._isSettingsTab then
                isFirst = false
                break
            end
        end
        if isFirst then
            tab:Select(true)
        end

                        if not self.hidden and not self.minimised then
            tab.topbarItem.Visible = true
            tab:_applyVisual(
                if self.selectedTab == tab then "selected" else "unselected",
                TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            )
        end
        -- [[A runtime-created tab may belong to the other rail.]]
        -- [[Re-apply the rail filter so it lands in the correct rail.]]
        self:_applySettingsLayout(self._settingsMode)
    end

    self:_constructionCheckpoint(false)
    return tab
end

function Window:CreateSection(props)
    assert(not self.unloaded, "Cannot create a section on an unloaded window.")
    local section = require(script.Parent.Parent.elements.tabSection).new(self, props)
    table.insert(self.tabSections, section)

            if not section.inert and not self.hidden and not self.minimised then
        section:_setVisible(true)
        section:_setShown(true, false)
    end

    return section
end

function Window:_setTabSectionsShown(shown, tweenInfo)
    for _, section in self.tabSections do
        section:_setShown(shown, tweenInfo)
    end
end

function Window:_setTabSectionsVisible(visible)
    for _, section in self.tabSections do
        section:_setVisible(visible)
    end
end

function Window:CreateTag(props)
    assert(not self.unloaded, "Cannot create a tag on an unloaded window.")
    local tag = require(script.Parent.Parent.elements.tag).new(self, props)
    table.insert(self.tags, tag)
    return tag
end

function Window:_registerControl(element)
    if not element.flag or element.flag == "" or element.forgetState then
        return
    end

    local flag = element.flag
    if self.controls[flag] then
        local n = 2
        while self.controls[flag .. n] do
            n += 1
        end
        flag = flag .. n
    end

    element.flag = flag
    self.controls[flag] = element
    return flag
end

function Window:_restoreLate(element)
    if not self._loadedConfig or not element.flag or element.forgetState then
        return
    end

    local wasLoading = self._loading
    self._loading = true     persistence.applyTo(element, self._loadedConfig[element.flag])
    self._loading = wasLoading
end

function Window:_persist(element)
    if not element.flag or element.forgetState or not self.configuration.autoSave or self._loading or self._saveScheduled then
        return
    end
    -- Default-on autosave must not write a whole file for every slider tick.
    self._saveScheduled = true
    task.delay(0.25, function()
        self._saveScheduled = false
        if not self.unloaded and self.configuration.autoSave and not self._loading then
            self:Save()
        end
    end)
end

function Window:_unregisterControl(element)
    if element.flag and self.controls[element.flag] == element then
        self.controls[element.flag] = nil
    end
end

function Window:_keybindUsing(keybind, source)
    if typeof(keybind) ~= "EnumItem" or keybind == Enum.KeyCode.Unknown then
        return nil
    end
    local function find(elements)
        for _, element in ipairs(elements) do
            if element ~= source and element.__type == "Keybind" and element.value == keybind then
                return element
            end
            if element.elements then
                local match = find(element.elements)
                if match then return match end
            end
        end
        return nil
    end
    for _, tab in self.tabs do
        local match = find(tab.elements)
        if match then return match end
    end
    return nil
end

function Window:Notify(props)
    if self.unloaded then
        return     end
    if not self.notifications then
        self.notifications = self:Create("Frame", {
            Name = "Notifications",
            Size = UDim2.new(0, 300, 0, 800),
            Position = UDim2.new(1, -20, 1, -20),
            AnchorPoint = Vector2.new(1, 1),
            BackgroundTransparency = 1,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
                                    Padding = UDim.new(0, 0),

            Parent = self.notifications,
        })
    end

    return require(script.Parent.Parent.components.notification).new(self, props)
end

function Window:Toast(props)
    if self.unloaded then
        return
    end

        props = if typeof(props) == "table" then props else {}
    local position = props.position or props.Position or "Top"
    local isTop = typeof(position) ~= "string" or position:lower() ~= "bottom"
    props.position = if isTop then "Top" else "Bottom"
    local toastKey = if isTop then "_toastsTop" else "_toastsBottom"
    local container = self[toastKey]

    if not container then
        container = self:Create("Frame", {
            Name = "Toasts",
            Size = UDim2.new(0, toastWidth, 1, -24),
            Position = if isTop then toastsTopPosition else UDim2.new(0.5, 0, 1, -12),
            AnchorPoint = if isTop then Vector2.new(0.5, 0) else Vector2.new(0.5, 1),
            BackgroundTransparency = 1,
            ZIndex = constants.zIndex.toast,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = if isTop then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 0),

            Parent = container,
        })

        self[toastKey] = container

                        if isTop then
            updateToastPosition(self, false)
        end
    end

    return require(script.Parent.Parent.components.toast).new(self, props, container)
end

function Window:Popup(props)
    if self.unloaded then
        return
    end
    return require(script.Parent.Parent.components.popup).new(self, props)
end

function Window:Close()
    if self.animating or self.unloaded then
        return
    end
    self.animating = true
    self.hidden = true
    self.collapsedInteract.Visible = false
    self._closeTransitionId = (self._closeTransitionId or 0) + 1
    local transitionId = self._closeTransitionId
    local originalSize = self.main.Size
    local originalPosition = self.main.Position
    local closeTweenInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    local targetSize = UDim2.new(
        originalSize.X.Scale * 0.88,
        math.floor(originalSize.X.Offset * 0.88),
        originalSize.Y.Scale * 0.88,
        math.floor(originalSize.Y.Offset * 0.88)
    )

    self.main.ClipsDescendants = true
    self.main.AnchorPoint = Vector2.new(0.5, 0.5)
    self.main.Position = originalPosition
    self.drag.drag.Visible = false
    self:_fadeSurfaces(false, closeTweenInfo)
    if self.title then
        motion.tween(self.title, { TextTransparency = 1 }, closeTweenInfo)
    end
    if self.subtitle then
        motion.tween(self.subtitle, { TextTransparency = 1 }, closeTweenInfo)
    end
    if self.topbarIcon then
        motion.tween(self.topbarIcon, { ImageTransparency = 1 }, closeTweenInfo)
    end
    for _, tag in self.tags do
        tag:_setShown(false, closeTweenInfo)
    end
    self:_fadeSelectedElementsOut()
    -- [[The contraction goes through the motion service so the close answers
    -- the speed setting like the rest of the window. A nil return means
    -- nothing was animated (motion switched off, or the frame is already
    -- where the transition was heading): the teardown still has to run, or
    -- the window would stay alive and invisible.]]
    local closed = false
    local function finishClose()
        if closed or self.unloaded or self._closeTransitionId ~= transitionId then
            return
        end
        closed = true
        self.drag.drag.Visible = false
        self:Unload()
    end

    if not motion.tween(self.main, {
        Size = targetSize,
        Position = originalPosition,
        BackgroundTransparency = 1,
    }, closeTweenInfo, finishClose) then
        -- [[Nothing animated, so the teardown just ran and the window's
        -- instances are gone — the corner below must not be touched.]]
        finishClose()
        if self.unloaded then
            return
        end
    end
    -- [[Collapse to a capsule using the theme's pill radius so a custom
    -- [[PillCornerRadius still reads on the closing shrink.]]
    motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(1, 0) }, closeTweenInfo)
end

function Window:Hide()
    -- Cancel pending startup reveal even while the window is still hidden.
    self._autoShowCancelled = true
    if self.animating or self.hidden then
        return
    end

            if self._searching then
        search.close(self, { showTabs = false, jumpTo = self.selectedTab and self.selectedTab.tabPage })
    end

            if self._recordingKeybind then
        self._recordingKeybind:_stopRecording()
    end

    self.animating = true
    self._revealing = true
    self.hidden = true
    self.collapsedInteract.Visible = false
                if self.minimised then
        self.minimised = false
        image.assign(self.minimiseAction.iconLabel, "Image", self:ResolveIcon(constants.icons.minimise))     end

        self._restorePosition = self.main.Position

    local collapsedPos, collapsedSize = self:_collapsedRect()

    local hideTween = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local surfaceTween = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    local cornerTween = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    local collapseShowTween = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

            self._hideTransitionId = (self._hideTransitionId or 0) + 1
    local transitionId = self._hideTransitionId

            state.tweenService
        :Create(self.drag.dragCosmetic, hideTween, { Size = UDim2.fromOffset(0, 4), BackgroundTransparency = 1 })
        :Play()
    task.delay(0.18, function()
        if self.unloaded or not self.hidden or self._hideTransitionId ~= transitionId then
            return
        end
        self.drag.drag.Visible = false
    end)

            self:_fadeSurfaces(false, hideTween)

    if self.title then
        motion.tween(self.title, { TextTransparency = 1 }, hideTween)
    end
    if self.subtitle then
        motion.tween(self.subtitle, { TextTransparency = 1 }, hideTween)
    end
    if self.topbarIcon then
        motion.tween(self.topbarIcon, { ImageTransparency = 1 }, hideTween)
    end

    for _, actionFrame in ipairs(self.actionContainer:GetChildren()) do
        if actionFrame:IsA("Frame") then
            motion.tween(actionFrame.ImageLabel, { ImageTransparency = 1 }, hideTween)
        end
    end

    for _, tag in self.tags do
        tag:_setShown(false, hideTween)
    end

    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual("hidden", hideTween)
        end
    end
    self:_setTabSectionsShown(false, hideTween)

    self:_fadeSelectedElementsOut()

    -- [[Same contract as the close: settle from the tween's Completed, or
    -- immediately when there was nothing to animate.]]
    local collapsed = false
    local function settleCollapse()
                        if collapsed or self.unloaded or not self.hidden or self._hideTransitionId ~= transitionId then
            return
        end
        collapsed = true

                        self._collapsedShown = true
        updateToastPosition(self, true)
        self.collapsedInteract.Visible = true
        self.animating = false
        self._revealing = false
    end

    if not motion.tween(self.main, { Size = collapsedSize, Position = collapsedPos }, surfaceTween, settleCollapse) then
        settleCollapse()
    end
    -- [[Capsule bar: theme PillCornerRadius (Gen2 default is a full pill).]]
    motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(1, 0) }, cornerTween)

    self.topbar.Visible = true
    self:_setContentVisible(false)
    chrome.setCollapsedShown(self, true, collapseShowTween)
end

function Window:ToggleHide()
    if self.animating then
        return
    end
    if self.hidden then
        self:Show()
    else
        self:Hide()
    end
end

function Window:ToggleMinimise()
    if self.animating or self.hidden then
        return
    end

        if self._searching then
        search.close(self, { showTabs = true })
    end

    self.animating = true
    self.drag.drag.Visible = false
    self.collapsedInteract.Visible = false

    local expandTween = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local surfaceTween = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    self._hideTransitionId = (self._hideTransitionId or 0) + 1

    if self.minimised then
        self.minimised = false
        self.drag.drag.Visible = false
        image.assign(self.minimiseAction.iconLabel, "Image", constants.icons.minimise)
        state.tweenService:Create(self.main, expandTween, { Size = self.size }):Play()
        motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, expandTween)
        self:_fadeSurfaces(true, surfaceTween)	chrome.setCollapsedShown(self, false, surfaceTween)

        -- [[The card comes back with the expanded window and the pair has]]
        -- [[to fit: the capsule's own clamp only knew the capsule, so one]]
        -- [[dragged into a corner used to expand with the window — or its]]
        -- [[card — hanging off the edge. Re-clamp now the panel is shown]]
        -- [[again (a no-op while the pair already fits, and while the card]]
        -- [[is off).]]
        self:_clampToScreen()

        state.tweenService
            :Create(self.drag.drag, expandTween, {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + self.size.Y.Offset / 2 + 15
                ),
            })
            :Play()

                        task.delay(0.2, function()
            if self.unloaded or self.minimised or self.hidden then
                return             end
            self:_setContentVisible(true)

            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = true
                    tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected", surfaceTween)
                end
            end
            -- [[Restore the settings/normal rail split; the loop above shows all tabs.]]
            self:_applySettingsLayout(self._settingsMode)
            self:_setTabSectionsVisible(true)
            self:_setTabSectionsShown(true, surfaceTween)

            self:_revealElements(0.035, 0.4)
        end)

        task.delay(0.5, function()
            self.animating = false
        end)
    else
        self.minimised = true
        self.drag.drag.Visible = false
        image.assign(self.minimiseAction.iconLabel, "Image", self:ResolveIcon(constants.icons.maximise))
                        self:_fadeSelectedElementsOut()
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector and tab.topbarItem then
                tab:_applyVisual("hidden", surfaceTween)
            end
        end
        self:_setTabSectionsShown(false, surfaceTween)

        task.delay(0.3, function()
            if self.unloaded or not self.minimised then
                return             end
            self:_setContentVisible(false)
            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = false
                end
            end
            self:_setTabSectionsVisible(false)
        end)

        self:_fadeSurfaces(false, surfaceTween)	chrome.setCollapsedShown(self, true, surfaceTween)
        state.tweenService
            :Create(self.main, expandTween, { Size = UDim2.fromOffset(self.size.X.Offset, self.layout.topbarHeight) })
            :Play()
        -- [[Minimised bar reads as a theme-aware capsule (PillCornerRadius).]]
        motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(1, 0) }, expandTween)

        state.tweenService
            :Create(self.drag.drag, expandTween, {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + self.layout.topbarHeight / 2 + 15
                ),
            })
            :Play()

        task.delay(0.5, function()
            if self.unloaded then
                return
            end
            if self.minimised and not self.hidden then
                self:_syncDragBar()
                self.drag.drag.Visible = true
            end
            self.animating = false
        end)
    end
end

function Window:_syncDragBar()
    local dragFrame = self.drag and self.drag.drag
    if not dragFrame then
        return
    end
    local pos = self.main.Position
    local dragOffset = if self.minimised then self.layout.topbarHeight / 2 + 15 else self.size.Y.Offset / 2 + 15
    dragFrame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + dragOffset)
end

function Window:_clampedPosition(position: UDim2): UDim2
    if not self.settings or not self.settings.keepOnScreen then
        return position
    end
            if position.X.Scale ~= 0 or position.Y.Scale ~= 0 then
        return position
    end

    local screenSize = self.screenGui.AbsoluteSize
    -- [[The window and its profile card travel as one unit, so the clamp]]
    -- [[keeps the *pair* in view: the card adds its width + gap to one]]
    -- [[side and, being taller than a short window, raises the vertical]]
    -- [[half-extent too. Clamping the window alone let the card be dragged]]
    -- [[off the edge while "keep window on screen" was still satisfied.]]
    local halfLeft, halfRight, halfTop = profilePanel.pairHalfSize(self)
    local margin = 8
        local x = math.clamp(position.X.Offset, halfLeft + margin, math.max(halfLeft + margin, screenSize.X - halfRight - margin))
    local y = math.clamp(position.Y.Offset, halfTop + margin, math.max(halfTop + margin, screenSize.Y - halfTop - margin))
    if x == position.X.Offset and y == position.Y.Offset then
        return position
    end
    return UDim2.fromOffset(x, y)
end

function Window:_clampToScreen()
    self.main.Position = self:_clampedPosition(self.main.Position)
end

-- [[The window's canonical resting position. With the profile panel]]
-- [[enabled, the window + gap + panel are treated as one unit and that]]
-- [[unit is centred: the window itself sits half a panel away from the]]
-- [[screen centre, on the opposite side of the panel, so neither side of]]
-- [[the pair looks cramped.]]
function Window:_profileCenterPosition(): UDim2
    local shift = profilePanel.shiftFor(self)
    if shift <= 0 then
        return UDim2.new(0.5, 0, 0.5, 0)
    end
    local left = (self.settings.profileSide or "right") == "left"
    return UDim2.new(0.5, if left then shift else -shift, 0.5, 0)
end

function Window:_recenterForProfile(animate)
    local target = self:_profileCenterPosition()
    if self.hidden or self.minimised then
        -- [[Nothing is on screen to move; park the remembered position so]]
        -- [[the next restore lands centred for the current panel state.]]
        self._restorePosition = target
        return
    end
    if self.main.Position == target then
        return
    end
    if animate and not self.animating then
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
        state.tweenService:Create(self.main, tweenInfo, { Position = target }):Play()
        state.tweenService
            :Create(
                self.drag.drag,
                tweenInfo,
                { Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + self.size.Y.Offset / 2 + 15) }
            )
            :Play()
    else
        self.main.Position = target
        self:_syncDragBar()
    end
end

function Window:_applyWindowSize()
    if self.unloaded then
        return
    end
    -- [[Desktop/PC: newSize tracks the viewport (responsive, min/max protected).]]
    -- [[Mobile: windowSizing.fit returns the fixed mobile profile on every call, so]]
    -- [[viewport changes (rotation, keyboard, inset) never resize the window here.]]
    local newSize = computeSize(self.layout.mode)
    local sizeChanged = newSize ~= self.size
    self.size = newSize
    -- [[Nothing moved: no rail write, no layout invalidation. This is the
    -- [[window's steady state - the viewport poll below calls this every
    -- [[couple of seconds for the whole session, and the rail write used to
    -- [[happen before the check.]]
    if not sizeChanged and not self._pendingResize then
        return
    end
    -- [[The rail follows the window's size, its layout and its tabs, all of
    -- [[which are in step by the time this runs: it only has to be written
    -- [[when one of them moved, which is what this function is for.]]
    self:_applyRailWidth()
    if self.hidden or self.minimised or self.animating or self._revealing then
        self._pendingResize = true
        return
    end
    self._pendingResize = false
    self.main.Size = newSize
    self:_clampToScreen()
    self:_syncDragBar()
    -- [[A viewport change (rotation, inset, keyboard) can turn the profile]]
    -- [[panel on or off: there may suddenly be room for it, or none.]]
    -- [[Re-evaluate its visibility alongside the resize and keep the card]]
    -- [[height matched to the window height.]]
    profilePanel.layout(self)
    profilePanel.setShown(self, true, nil)
    if self.main.Position.X.Scale == 0.5 and self.main.Position.Y.Scale == 0.5 then
        -- [[Still anchored at the screen centre (the user has not dragged]]
        -- [[it): re-apply the resting centre for the new panel state.]]
        self:_recenterForProfile(false)
    end
end

-- [[Effective rail width. Non-sidebar and collapsed rails keep the existing]]
-- [[fixed behavior; the expanded responsive rail instead hugs the widest]]
-- [[visible tab row (railContentWidth), capped by the window's available]]
-- [[space so the elements area always keeps at least half the window.]]
function Window:_railWidth()
    local base = layouts.railWidthFor(self.layout, self.size.X.Offset)
    if self.layout.mode ~= "sidebar" or self.layout.forceCollapsed then
        return base
    end
    if base < (self.layout.railWidth :: number) then
        return base
    end
    local content = tabSelector.railContentWidth(self, self.layout)
    if content <= 0 then
        return base
    end
    local cap = math.floor(self.size.X.Offset * 0.5)
    return math.min(content, cap)
end

function Window:_applyContentRailWidth()
    if self.layout.mode ~= "sidebar" or self.layout.forceCollapsed then
        return
    end
    local implementation = layouts.implementation(layoutKey(self.layout))
    implementation.ApplyWidth(self, self:_railWidth())
end

function Window:_applyRailWidth()
    local implementation = layouts.implementation(layoutKey(self.layout))
    implementation.ApplyWidth(self, self:_railWidth())

    if self._settingsLayoutActive or self.selectedTab == self.rfSettings then
        self:_applySettingsLayout(true)
    end
end

function Window:_watchViewport()
    local cameraConnection: RBXScriptConnection? = nil
    local pending = false

    local function scheduleUpdate()
                if pending then
            return
        end
        pending = true
        task.defer(function()
            pending = false
            self:_applyWindowSize()
        end)
    end

    local function rebindCamera()
        if cameraConnection then
            self:Disconnect(cameraConnection)
            cameraConnection = nil
        end
        local camera = state.workspace.CurrentCamera
        if camera then
            cameraConnection = self:Connect(camera:GetPropertyChangedSignal("ViewportSize"), scheduleUpdate)
        end
        scheduleUpdate()
    end

    self:Connect(state.workspace:GetPropertyChangedSignal("CurrentCamera"), rebindCamera)
    rebindCamera()

            local elapsed = 0
    self:Connect(state.runService.Heartbeat, function(dt: number)
        elapsed += dt
        if elapsed < viewportCheckInterval then
            return
        end
        elapsed = 0
        self:_applyWindowSize()
    end)
end

function Window:_bindKeybind()
    self:Connect(state.userInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed or self._recordingKeybind then
            return         end
        if input.KeyCode == self.settings.toggleKeybind or input.UserInputType == self.settings.toggleKeybind then
            self:ToggleHide()
        end
    end)
end

function Window:_bindMouseOverride()
    local inputService = state.userInputService

    local function shouldOverride()
        return self.settings.mouseOverride and not self.hidden and not self.minimised
    end

    local function restoreMouse()
        if not shouldOverride() then
            return
        end
                        if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            return
        end
        if inputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            inputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not inputService.MouseIconEnabled then
            inputService.MouseIconEnabled = true
        end
    end

            self:Connect(inputService:GetPropertyChangedSignal("MouseBehavior"), restoreMouse)
    self:Connect(inputService:GetPropertyChangedSignal("MouseIconEnabled"), restoreMouse)

            self:Connect(inputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            restoreMouse()
        end
    end)

        self._freeMouse = restoreMouse
end

function Window:_bindTopbarDrag()
    local inputService = state.userInputService
    local isDragging = false
    local dragOffset = Vector2.zero
    local renderConnection
    local startMousePos = Vector2.zero

            local guiInset = Vector2.zero
    if self.screenGui and self.screenGui.IgnoreGuiInset then
        guiInset = state.guiService:GetGuiInset()
    end

    local function getConstrainedPosition()
        local rawPos = inputService:GetMouseLocation() + dragOffset + guiInset
        local x, y = rawPos.X, rawPos.Y

        if self.settings and self.settings.keepOnScreen then
            local mainSize = self.main.AbsoluteSize
            local screenSize = self.screenGui.AbsoluteSize
            local margin = 8
            -- [[Clamp the window + profile card pair rather than the window]]
            -- [[alone, so a drag cannot leave the card hanging off the]]
            -- [[screen. The frame's own size is passed in: mid-minimise it]]
            -- [[is shorter than window.size.]]
            local halfLeft, halfRight, halfTop = profilePanel.pairHalfSize(self, mainSize.X, mainSize.Y)
            x = math.clamp(x, halfLeft + margin, math.max(halfLeft + margin, screenSize.X - halfRight - margin))
            y = math.clamp(y, halfTop + margin, math.max(halfTop + margin, screenSize.Y - halfTop - margin))
        end

        return UDim2.fromOffset(x, y)
    end

    local function endDrag()
        isDragging = false
        if renderConnection then
            self:Disconnect(renderConnection)
            renderConnection = nil
        end
    end

    local function updateDrag()
        if not isDragging then
            endDrag()
            return
        end
        if self.unloaded or not self:_canDragCapsule() then
            endDrag()
            return
        end

        -- [[Do not reposition the window for a simple click/tap. Wait until]]
        -- [[the pointer has actually moved before treating the gesture as drag.]]
        local pointer = inputService:GetMouseLocation()
        if (pointer - startMousePos).Magnitude < 4 then
            return
        end

        local constrainedPos = getConstrainedPosition()
        if self.main.Position == constrainedPos then
            return
        end
        self.main.Position = constrainedPos
        if self.drag and self.drag.drag then
            local mainPos = self.main.Position
            self.drag.drag.Position = UDim2.new(
                mainPos.X.Scale,
                mainPos.X.Offset,
                mainPos.Y.Scale,
                mainPos.Y.Offset + (self.main.Size.Y.Offset / 2 + 15)
            )
        end
    end

                local function isOverInteractive(x, y)
        for _, region in { self.tabList, self.actionContainer } do
            local absPos, absSize = region.AbsolutePosition, region.AbsoluteSize
            if x >= absPos.X and x <= absPos.X + absSize.X and y >= absPos.Y and y <= absPos.Y + absSize.Y then
                return true
            end
        end
        return false
    end

    self:Connect(self.topbar.InputBegan, function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if not self:_canDragCapsule() then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        if isOverInteractive(input.Position.X, input.Position.Y) then
            return
        end

                if not self:_interactive() then
            return
        end

        isDragging = true
        if renderConnection then
            self:Disconnect(renderConnection)
            renderConnection = nil
        end
        renderConnection = self:Connect(state.runService.RenderStepped, updateDrag)

        if self.screenGui and self.screenGui.IgnoreGuiInset then
            guiInset = state.guiService:GetGuiInset()
        end

        startMousePos = inputService:GetMouseLocation()
        dragOffset = self.main.AbsolutePosition + self.main.AbsoluteSize * self.main.AnchorPoint - inputService:GetMouseLocation()
    end)

    self:Connect(inputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            endDrag()
        end
    end)

            self:Connect(inputService.WindowFocusReleased, function()
        endDrag()
    end)
end

function Window:_buildSettingsUI()
    settingsComponent.buildUI(self)
end

function Window:_buildSettingsContent(tab)
    settingsComponent.buildContent(self, tab)
end

-- [[Profile card content owned by the host. Accepts either the legacy
-- [[subtitle string (nil clears it and falls back to the @username line) or a
-- [[table carrying the card's host-supplied rows:
-- [[  window:SetProfile({ subtitle = "…", key = "…", tier = "PREMIUM",
-- [[    whitelist = { status = "Active", daysLeft = 14 } })
-- [[Anything not supplied reads "—" on the card; Astra holds no key or
-- [[whitelist store of its own.]]
function Window:SetProfile(profile)
    local data = profilePanel.setProfile(self, profile)
    self.profileText = data and data.subtitle or nil
    return self.profileText
end

function Window:SaveSettings()
    return persistence.saveSettings(self)
end

function Window:LoadSettings()
    local loaded = persistence.loadSettings(self)
    self.configuration.autoSave = self.settings.autoSaveConfig
    self.configuration.autoLoad = self.settings.autoLoadConfig
    -- [[The animation-speed setting lives in the same file, and the motion
    -- service is a library-wide singleton, so it is re-applied here rather
    -- than only when the settings control is touched — otherwise a window
    -- that loaded settings would animate at whatever the last one used.]]
    self:_applyMotionSetting()
    -- [["Reveal profile details" depends on "Show profile", and a settings]]
    -- [[file written before that rule (or edited by hand) can carry reveal]]
    -- [[= on with the card off. Normalise the pair on the way in, so the]]
    -- [[card never unmasks identity data while it is hidden and the toggle]]
    -- [[is built showing the truth.]]
    profilePanel.syncReveal(self)
    return loaded
end

function Window:_roundCorners(frame, corners)
    if not corners or not hasPerCornerRadius then
        return self:Create("UICorner", {
            Parent = frame,
        }, { CornerRadius = "CornerRoundness" })
    end

    local props = { Parent = frame }
    local themeMap = {}
    for _, key in cornerKeys do
        props[key] = UDim.new(0, 0)
    end
    for _, corner in corners do
        props[corner] = nil         themeMap[corner] = "CornerRoundness"
    end

    return self:Create("UICorner", props, themeMap)
end

function Window:_setElementLocked(element, locked, message)
    locked = locked == true
                local wasLocked = element.locked == true
    if wasLocked == locked and not (locked and message) then
        return
    end
    element.locked = locked

    if not element.lockScrim then
        self:_buildLockScrim(element)
    end

    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if locked then
        element.lockScrim.Visible = true
    end
    state.tweenService
        :Create(element.lockScrim, tweenInfo, {
            BackgroundTransparency = if locked then lockScrimTransparency else 1,
        })
        :Play()
    if not locked then
        task.delay(tweenInfo.Time, function()
            if not element.locked and element.lockScrim and element.lockScrim.Parent then
                element.lockScrim.Visible = false             end
        end)
    end

        local label = element.descriptionLabel
    if not label then
        return
    end

    if locked then
                        element._descriptionBefore = element._descriptionBefore or label.Text
        label.Text = locale.resolve(message or "This element is locked.")
    elseif element._descriptionBefore then
        label.Text = element._descriptionBefore
        element._descriptionBefore = nil
    end

    state.tweenService
        :Create(label, tweenInfo, {
            TextTransparency = if locked then lockedTextTransparency else 0.45,
        })
        :Play()
end

function Window:_buildLockScrim(element)
    element.lockScrim = self:Create("TextButton", {
        Name = "ElementLock",
        Active = true,
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = constants.zIndex.elementLock,
        Visible = false,

                        BackgroundTransparency = 1,
        Parent = element.main,
    }, { BackgroundColor3 = { "WindowColor", firstColor } })

    self:Create("UICorner", {
        Parent = element.lockScrim,
    }, { CornerRadius = "ElementCornerRadius" })
end

-- [[Topbar tab-strip chrome: the strip is inset from the window edge and a]]
-- [[gradient fade marks whichever edge is clipping tabs. Runs off canvas/]]
-- [[size change signals (see Topbar.Build) and skips writes when the target]]
-- [[state is unchanged, so steady-state cost is one comparison per signal.]]
function Window:_refreshTabStripChrome()
    local strip = self.tabList
    local fadeLeft = self.tabFadeLeft
    local fadeRight = self.tabFadeRight
    if self.layout.mode ~= "top" or not strip or not strip.Parent then
        return
    end

    local rightClipped = strip.AbsoluteCanvasSize.X > strip.AbsoluteWindowSize.X + 0.5
    if fadeRight and fadeRight.Parent and fadeRight.Visible ~= rightClipped then
        fadeRight.Visible = rightClipped
    end

    local scrolledFromLeft = strip.CanvasPosition.X > 0.5
    if fadeLeft and fadeLeft.Parent and fadeLeft.Visible ~= scrolledFromLeft then
        fadeLeft.Visible = scrolledFromLeft
    end
end

-- [[Keep the selected pill inside the strip's viewport after a selection.]]
-- [[Children of the ScrollingFrame sit in canvas space, so item.Position]]
-- [[is the tab's offset along the strip without any absolute-position]]
-- [[math; the inset keeps the landing a touch clear of the edge fades.]]
function Window:_scrollSelectedTabIntoView(tweened)
    local strip = self.tabList
    if self.layout.mode ~= "top" or not strip or not strip.Parent then
        return
    end

    local tab = self.selectedTab
    local item = tab and (not tab.neglectSelector) and tab.topbarItem
    if not item or not item.Parent then
        return
    end

    local inset = self.layout.tabStripInset or 22
    local viewport = strip.AbsoluteWindowSize.X
    local maxScroll = math.max(0, strip.AbsoluteCanvasSize.X - viewport)
    local left = item.Position.X.Offset
    local right = left + item.AbsoluteSize.X
    local pos = strip.CanvasPosition.X

    -- [[Move the strip only when the pill is clipped or pressed up
    -- [[against an edge fade; a comfortably visible tab stays put, so
    -- [[selecting it does not re-scroll the strip for no reason.]]
    local target = nil
    if left < pos + inset then
        target = left - inset
    elseif right > pos + viewport - inset then
        target = right + inset - viewport
    end
    if target == nil then
        return
    end
    target = math.clamp(target, 0, maxScroll)
    if math.abs(pos - target) < 1 then
        return
    end

    if tweened then
        motion.tween(strip, { CanvasPosition = Vector2.new(target, 0) }, "snappy")
    else
        strip.CanvasPosition = Vector2.new(target, 0)
    end
end

function Window:_setLayoutMode(modeName)
    if self.unloaded then
        return false
    end
    if self.animating or self.minimised or (self.hidden and self.hasShownOnce) then
        return false
    end
    local newLayout = layouts.get(modeName)
    local oldKey = layoutKey(self.layout)
    if not newLayout or modeName == oldKey then
        return false
    end
    if self._layoutTransitioning then
        return false
    end
    self._layoutTransitioning = true
    self._layoutTransitionId = (self._layoutTransitionId or 0) + 1
    local transitionId = self._layoutTransitionId
    local tweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    self:_fadeSurfaces(false, tweenInfo)
    self:_fadeSelectedElementsOut()
    for _, tab in self.tabs do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual("hidden", tweenInfo)
        end
    end
    task.wait(0.12)
    if self.unloaded then
        self._layoutTransitioning = false
        return false
    end
    if self._searching then
        search.close(self, { showTabs = true, jumpTo = self.selectedTab and self.selectedTab.tabPage })
    end
    local oldKey = layoutKey(self.layout)
    self.layout = newLayout
    self.settings.layoutMode = modeName
    if self.sidebar then
        self:DestroySubtree(self.sidebar)
        self.sidebar = nil
    elseif self.tabList then
        self:DestroySubtree(self.tabList)
    end
    -- [[The edge fades live beside the topbar strip, so they are topbar]]
    -- [[chrome: tear them down on the way out of "top" mode.]]
    if self.tabFadeLeft then
        self:DestroySubtree(self.tabFadeLeft)
        self.tabFadeLeft = nil
    end
    if self.tabFadeRight then
        self:DestroySubtree(self.tabFadeRight)
        self.tabFadeRight = nil
    end
    local implementation = layouts.implementation(modeName)
    implementation.Build(self, newLayout)
    if newLayout.mode == "sidebar" then
        if not self.elementsCorner then
            self.elementsCorner = self:_roundCorners(self.elements, newLayout.cardCorners)
            self.elementsStroke = self:Create("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Transparency = 1,
                Parent = self.elements,
            }, { Color = "SurfaceStroke" })
            self:Create("UIGradient", {
                Rotation = newLayout.cardStrokeRotation,
                Transparency = newLayout.cardStrokeTransparency,
                Parent = self.elementsStroke,
            })
        end
    else
        if self.elementsCorner then
            self.elementsCorner.CornerRadius = UDim.new(0, 0)
        end
        if self.elementsStroke then
            self.elementsStroke.Transparency = 1
        end
        self.elements.Size = UDim2.new(1, 0, 1, -newLayout.chromeHeight)
        self.bottomFade.Size = UDim2.new(1, 0, newLayout.fadeSize.Y.Scale, newLayout.fadeSize.Y.Offset)
    end
    implementation.ApplyWidth(self, self:_railWidth())
    self.elementsLayout.FillDirection = newLayout.pageDirection

    for _, tab in self.tabs do
        if not tab.neglectSelector then
            tab:_rebuildSelector()
            tab.topbarItem.Visible = self.elements.Visible and not self.hidden and not self.minimised
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
    end
    self:_applySettingsLayout(self._settingsMode)
    if self.selectedTab then
        self:_jumpTo(self.selectedTab.tabPage)
        self.selectedTab:_applyVisual("selected")
    end
    self:_fadeSurfaces(true, tweenInfo)
    self:_setTabSectionsShown(true, tweenInfo)
    task.spawn(function()
        if not self.unloaded and self._layoutTransitionId == transitionId then
            self:_revealElements(0.02, 0.5, transitionId)
        end
    end)
    self._layoutTransitioning = false
    return oldKey ~= modeName
end
function Window:_applySettingsLayout(isSettings)
    settingsComponent.applySettingsLayout(self, isSettings)
end

-- [[Shared by the topbar gear action and the profile panel's gear.]]
function Window:_toggleSettingsMode()
    settingsComponent.toggleSettingsMode(self)
end

function Window:_setSettingsMode(active)
    settingsComponent.setSettingsMode(self, active)
    self:_updateWindowTitle()
end

function Window:_updateWindowTitle()
    if not self.title then return end
    local text = self.name
    self.title.Text = locale.resolve(text)
end

function Window:_setContentVisible(visible)
    self.elements.Visible = visible
    if not visible then
        self.tabList.Visible = false
        if self.sidebar then
            self.sidebar.Visible = false
        end
        return
    end

    self:_applySettingsLayout(self._settingsMode)
end

function Window:_fadeSurfaces(shown, tweenInfo)
    local targets = {
        [self.windowShadow] = { Transparency = if shown then 0.6 else 1 },
        [self.windowStroke] = { Transparency = if shown then 0.95 else 1 },
        [self.bottomFade] = { BackgroundTransparency = if shown then 0 else 1 },
    }

    if self.elementsStroke then
        targets[self.elements] = {
            BackgroundTransparency = if shown then self.layout.cardTransparency else 1,
        }
        targets[self.elementsStroke] = { Transparency = if shown then 0 else 1 }
    end

    for instance, props in targets do
        if tweenInfo then
            motion.tween(instance, props, tweenInfo)
        else
            for prop, value in props do
                instance[prop] = value
            end
        end
    end

    profilePanel.setShown(self, shown, tweenInfo)
end

function Window:_fadeSelectedElementsOut()
    if self.selectedTab then
        -- [[These elements are the ones about to be transparent: the tab is
        -- [[marked so that opening it again shows them (the reveal below
        -- [[handles the tab that is on screen).]]
        self:_markTabElementsPending(self.selectedTab)
        for _, element in ipairs(self.selectedTab.elements) do
            element:_setShown(false, true)
        end
    end
end

-- [[Show every element of one tab (instantly) and clear its pending mark.]]
function Window:_showTabElements(tab)
    tab._elementsPending = false
    for _, element in ipairs(tab.elements) do
        element:_setShown(true, false)
    end
end

-- [[Mark a tab whose elements are hidden and must be shown when it is next
-- [[seen. Only two things hide an element: the fade above (the tab that was on
-- [[screen) and being registered while the window is hidden; everything else
-- [[is shown on the spot. A tab that is not the current page of
-- [[`self.elements` cannot be looked at (UIPageLayout keeps the other pages
-- [[out of the render), so the mark is honoured when the player opens the tab
-- [[(`tab:Select`) or when the search pulls its elements onto its own page -
-- [[the two moments they can be seen. This replaces walking every tab's
-- [[elements on every open just to keep the tabs nobody had opened in step.]]
function Window:_markTabElementsPending(tab)
    tab._elementsPending = true
end

function Window:_revealElements(stepDelay, totalDuration, layoutTransitionId)
    local function isStillValid()
        return not self.unloaded
            and not self.hidden
            and not self.minimised
            and (layoutTransitionId == nil or self._layoutTransitionId == layoutTransitionId)
    end

    if not isStillValid() then
        return
    end

    local tab = self.selectedTab
    if not tab then
        return
    end

    local page = tab.tabPage
    local viewTop = page.AbsolutePosition.Y
    local viewBottom = viewTop + page.AbsoluteWindowSize.Y

    -- [[The cascade's pace belongs to the motion service as well: a relaxed
    -- profile spreads the reveal further, a snappy one tightens it, and with
    -- animation off (step 0) every element appears on the same frame instead
    -- of the coroutine yielding a frame per element.]]
    local step = motion.step(stepDelay)
    local maxReveals = if step > 0 then math.floor(totalDuration / step) else math.huge
    local revealed = 0
    for _, element in ipairs(tab.elements) do
        if not isStillValid() then
            return
        end
        local elemTop = element.main.AbsolutePosition.Y
        local isVisible = (elemTop + element.main.AbsoluteSize.Y) > viewTop and elemTop < viewBottom
        if isVisible then
            element:_setShown(true, true)
            revealed += 1
            if step > 0 and revealed <= maxReveals then
                task.wait(step)
                if not isStillValid() then
                    return
                end
            end
        else
            element:_setShown(true, false)         end
    end
end

function Window:Show()
        if self.animating or not self.hidden then
        return
    end
    self.animating = true
    self._revealing = true
    self.drag.drag.Visible = false

                if self.configuration.autoLoad and not self._autoLoaded then
        self._autoLoaded = true
        local ok, err = pcall(self.Load, self)
        if not ok then
            log.warn("Astra: Failed to load configuration - " .. tostring(err))
        end
    end

    -- A window with no host tabs starts on General: it is genuinely being
    -- viewed now, so populate it just as selecting Settings would.
    if self.selectedTab and self.selectedTab._isSettingsTab then
        self:_buildSettingsContent(self.selectedTab)
    end

    self.hidden = false
    self.minimised = false
    self._collapsedShown = false
    chrome.setCollapsedShown(self, false)

        if self._themeRefreshPending then
        self._themeRefreshPending = false
        self:_refreshElementThemes()
    end

    self.collapsedInteract.Visible = false
    if self._freeMouse then
        self._freeMouse()
    end

    if self.hasShownOnce then
        self:_quickRestore()
    else
        self.hasShownOnce = true
        self.main.Visible = true
        if not self.unloaded then
            self:_firstShow()
        end
    end
end

function Window:_quickRestore()
    local restore = self._restorePosition
    if not restore or (restore.X.Scale == 0.5 and restore.Y.Scale == 0.5) then
        -- [[Never dragged — or parked by a recenter that ran while the]]
        -- [[window was hidden: come back to the pair's resting centre for]]
        -- [[the panel state as it is *now* (the player, the viewport or the]]
        -- [[setting may have changed since that position was recorded), so]]
        -- [[the window and its card land centred together.]]
        restore = self:_profileCenterPosition()
    end
    local targetPos = self:_clampedPosition(restore)
    self._restorePosition = targetPos
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    self.main.ClipsDescendants = true
    self.main.BackgroundTransparency = windowSurfaceTransparency
    self.topbar.Visible = true
    self:_setContentVisible(true)
    self:_setTabSectionsVisible(true)
    self:_setTabSectionsShown(true)
    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
        if tab == self.selectedTab then
            self:_showTabElements(tab)
        end
    end
    -- [[Restore the settings/normal rail split; the loop above shows the
    -- [[selected tab's elements (the others are either already shown or still
    -- [[marked to show when they are opened).]]
    self:_applySettingsLayout(self._settingsMode)
    self:_fadeSurfaces(true)

    -- [[The card is back on screen with this restore, and the pair — not]]
    -- [[the window alone — has to fit: re-clamp now that pairHalfSize can]]
    -- [[see it (above, the panel was still hidden from the Hide).]]
    targetPos = self:_clampedPosition(targetPos)
    self._restorePosition = targetPos

    if self.topbarIcon then
        self.topbarIcon.ImageTransparency = 0
    end
    if self.title then
        self.title.TextTransparency = 0
    end
    if self.subtitle then
        self.subtitle.TextTransparency = 0.7
    end
    for _, actionFrame in ipairs(self.actionContainer:GetChildren()) do
        if actionFrame:IsA("Frame") and actionFrame.ImageLabel then
            actionFrame.ImageLabel.ImageTransparency = 0.6
        end
    end

    for _, tag in self.tags do
        tag:_setShown(true, false)
    end
    -- [[Same contract as the first show: run the settle path from the tween's
    -- Completed, or immediately when there is no tween (motion switched off),
    -- so `animating` is never left set.]]
    local restored = false
    local function settle()
        if restored or self.hidden or self.unloaded then
            return
        end
        restored = true
        self.main.ClipsDescendants = false
        self._collapsedShown = false
        self:_syncDragBar()
        self.drag.drag.Visible = false
        self.animating = false
        self._revealing = false
        updateToastPosition(self, true)
    end

    if not motion.tween(self.main, { Size = self.size, Position = targetPos }, tweenInfo, settle) then
        settle()
    end
    motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, tweenInfo)
end
function Window:_firstShow()
    self.drag.drag.Visible = false
    self.main.Visible = true
    self.main.ClipsDescendants = true
    self.main.BackgroundTransparency = 1

    if self.main.Position.X.Scale == 0.5 and self.main.Position.Y.Scale == 0.5 then
        -- [[Still at the anchored resting spot (the user has not dragged]]
        -- [[it), so centre the window + profile card pair for the panel]]
        -- [[state as it is *now*. Between building the frame and this first]]
        -- [[show the local player can turn up, the viewport can settle or]]
        -- [["Show profile" can arrive from disk — any of which moves the]]
        -- [[pair's centre — and a recenter that ran while the window was]]
        -- [[still hidden only parked the remembered position.]]
        self:_recenterForProfile(false)
    end

    local openingSize = UDim2.new(
        self.size.X.Scale * 0.88,
        math.floor(self.size.X.Offset * 0.88),
        self.size.Y.Scale * 0.88,
        math.floor(self.size.Y.Offset * 0.88)
    )
    self.main.Size = openingSize
    -- [[Entrance starts as a capsule (theme pill) then opens to CornerRoundness.]]
    self.windowCorner.CornerRadius = self.theme.PillCornerRadius or UDim.new(1, 0)
    self:_setContentVisible(true)
    self:_setTabSectionsVisible(true)
    self:_setTabSectionsShown(true)
    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
        if tab == self.selectedTab then
            self:_showTabElements(tab)
        end
    end
    -- [[Restore the settings/normal rail split; the loop above shows the
    -- [[selected tab's elements (the others are either already shown or still
    -- [[marked to show when they are opened).]]
    self:_applySettingsLayout(self._settingsMode)
    for _, tag in self.tags do
        tag:_setShown(false, false)
    end
    local tweenInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    if self.topbarIcon then
        self.topbarIcon.ImageTransparency = 1
        motion.tween(self.topbarIcon, { ImageTransparency = 0 }, tweenInfo)
    end
    if self.title then
        self.title.TextTransparency = 1
        motion.tween(self.title, { TextTransparency = 0 }, tweenInfo)
    end
    if self.subtitle then
        self.subtitle.TextTransparency = 1
        motion.tween(self.subtitle, { TextTransparency = 0.7 }, tweenInfo)
    end
    for _, actionFrame in ipairs(self.actionContainer:GetChildren()) do
        if actionFrame:IsA("Frame") and actionFrame.ImageLabel then
            actionFrame.ImageLabel.ImageTransparency = 1
            motion.tween(actionFrame.ImageLabel, { ImageTransparency = 0.6 }, tweenInfo)
        end
    end

    for _, tag in self.tags do
        tag:_setShown(true, tweenInfo)
    end
    self:_fadeSurfaces(true, tweenInfo)

    -- [[The entrance is the library's hero transition, so the frame lands on
    -- the motion service's "pop" spec: the same 0.38s as before, but with a
    -- small Back/Out overshoot, so the window springs the last pixels into
    -- place instead of easing into them. The corner rides the same spec.
    --
    -- The settle path has to run either way: motion.tween returns no tween
    -- when animation is switched off (the "Instant" speed profile), and a
    -- window that never animates must not be left with `animating` set.]]
    local settled = false
    local function settle()
        if settled or self.unloaded then
            return
        end
        settled = true
        self.main.ClipsDescendants = false
        self:_syncDragBar()
        self.drag.drag.Visible = false
        self.animating = false
        self._revealing = false
        -- [[The window reached its final size: the strip's viewport is]]
        -- [[stable now, so park the selected tab in view (it was computed]]
        -- [[at full size during construction, but the entrance shrank the]]
        -- [[window to 88%, which clamped CanvasPosition along the way).]]
        self:_scrollSelectedTabIntoView(false)
        self:_refreshTabStripChrome()
    end

    if not motion.tween(self.main, {
        BackgroundTransparency = windowSurfaceTransparency,
        Size = self.size,
    }, "pop", settle) then
        settle()
    end
    motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, "pop")

    local player = state.localPlayer
    if player and self.settings.welcomeToast and chrome.isNewUser() then
        self:Toast({
            title = player.DisplayName,
            subtitle = locale.resolve("Signed in as"),
            subtitleAbove = true,
            avatar = player.UserId,
            minWidth = 220,
        })
    end
end

function Window:GetPath()
    return persistence.getPath(self)
end

function Window:Save(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.save(self, name)
end

function Window:Load(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.load(self, name)
end

function Window:_applyNamedConfig(name)
    if not self:Load(name) then
        return false
    end
            local _, path = persistence.getPath(self)
    self._loadedConfigPath = path
    self:Save()
    return true
end

function Window:ListConfigs()
    return persistence.list(self)
end

function Window:DeleteConfig(name)
    return persistence.delete(self, name)
end

function Window:Get(flag)
    local control = self.controls[flag]
    return control and control.value
end

function Window:Set(flag, value)
    local control = self.controls[flag]
    if not control then
        return false
    end
    control:Set(value)
    return true
end

function Window:_jumpTo(page)
    if not page then
        return
    end
    if page.Parent == self.elements then
        self.elementsLayout:JumpTo(page)
    end
end

function Window:Navigate(tab)
    if tab == nil then
        return
    end

    local found
    for _, tab in self.tabs do
                if tab == tab or tab.name == tab or tab.tabPage == tab then
            found = tab
            break
        end
    end

    if not found then
        return
    end
    found:Select()
end

function Window:Create(className, props, themeBindings)
    assert(typeof(className) == "string", "Invalid argument #1 (string expected)")
    local instance = Instance.new(className)

            if themeBindings and self.theme then
        for prop, binding in themeBindings do
            instance[prop] = (
                if typeof(binding) == "table" then binding[2](self.theme[binding[1]]) else self.theme[binding]
            )
        end

        self.themeProperties[instance] = themeBindings
    end

    if props then
        for prop, value in props do
            if locale.isToken(value) then
                self:_bindLocale(instance, prop, locale.sourceOf(value))
            else
                image.assign(instance, prop, value)
            end
        end
    end

    table.insert(self.instances, instance)
    return instance
end

function Window:_bindLocale(instance, prop, token)
    instance[prop] = locale.resolve(token)

    local bindings = self.localeProperties[instance]
    if not bindings then
        bindings = {}
        self.localeProperties[instance] = bindings
    end
    bindings[prop] = token
end

function Window:SetLocale(localeId)
    locale.setActive(localeId)
    for instance, bindings in self.localeProperties do
        for prop, token in bindings do
            instance[prop] = locale.resolve(token)
        end
    end
    -- [[Translated row titles may measure differently.]]
    self:_applyContentRailWidth()
end

function Window:SetTranslator(translator)
    locale.translator = translator
end

function Window:RegisterTranslations(translations)
    locale.register(translations)
    self:SetLocale(locale.current)
end

-- [[The window's own background, applied to any frame: the base colour the
-- [[WindowColor gradient is laid over, and the gradient itself (same theme
-- [[token, rotation and offset as the frame the window is built from). The
-- [[profile card beside the window calls this too, so "the card is the window
-- [[in miniature" is enforced by construction instead of by two copies of the
-- [[same numbers that can drift apart. Returns the gradient so callers can
-- [[keep it in step with the window's own (see _syncLiveAnimation).]]
function Window:StyleWindowSurface(frame): UIGradient
    frame.BackgroundColor3 = windowSurfaceColor
    return self:Create("UIGradient", {
        Rotation = windowSurfaceGradientRotation,
        Offset = windowSurfaceGradientOffset,

        Parent = frame,
    }, { Color = { "WindowColor", functions.toColorSequence } })
end

-- [[The window's own opacity once it is on screen. Kept beside the surface
-- [[style so the card can state the same value without guessing.]]
function Window:WindowSurfaceTransparency(): number
    return windowSurfaceTransparency
end

function Window:CreateGlow(parent, color, blurRadius, transparency)
    local props = {
        BlurRadius = UDim.new(0, blurRadius),
        Transparency = transparency,
        ZIndex = -1,

        Parent = parent,
    }

    if typeof(color) == "string" then
        return self:Create("UIShadow", props, {
            Color = {
                color,
                function(color)
                    return if typeof(color) == "ColorSequence" then color.Keypoints[1].Value else color
                end,
            },
        })
    end

    props.Color = color
    return self:Create("UIShadow", props)
end

function Window:_flashResult(element, ok)
    local box = element.box
    if not box then
        return
    end
    local glow = if element._fieldGlow then element:_fieldGlow() else element.glow
    local boxStroke = element.boxStroke
    local flashColor = ok and constants.accent.on or self.theme.ErrorColor
    local flashStroke = ok and constants.accent.onStroke or self.theme.ErrorStrokeColor
    -- [[Hoisted out of the function: these two are fixed, and the flash runs
    -- on every element callback that reports a result.]]
    local flashTween = TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local restoreTween = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    motion.tween(box, { BackgroundColor3 = flashColor }, flashTween)
    if boxStroke then
        motion.tween(boxStroke, { Color = flashStroke, Transparency = 0.4 }, flashTween)
    end
    if glow then
        motion.tween(glow, { Color = flashStroke, Transparency = 0.6 }, flashTween)
    end

        element._flashToken = (element._flashToken or 0) + 1
    local token = element._flashToken
    task.delay(0.22, function()
        if element._flashToken ~= token then
            return
        end
        motion.tween(box, { BackgroundColor3 = self.theme.FieldBackground }, restoreTween)
        if boxStroke then
            motion.tween(boxStroke, { Color = self.theme.SurfaceStroke, Transparency = 0.85 }, restoreTween)
        end
        if glow then
            motion.tween(glow, { Color = self.theme.FieldGlow, Transparency = element._glowIdle or 1 }, restoreTween)
        end
    end)
end

function Window:CreateHoverOverlay(parent)
    local overlay = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 1,

        Parent = parent,
    })

    self:Create("UICorner", {
        Parent = overlay,
    }, { CornerRadius = "ElementCornerRadius" })

    return overlay
end

function Window:_wireElementHover(element, options)
    local theme = self.theme
    -- [[Containers may scope the hover to a sub-frame (the collapsible
    -- header) instead of the whole element, and rest their title on a
    -- different theme token. Keys, not values, so a runtime theme change
    -- still flows through: the closures below read the theme live.]]
    options = if typeof(options) == "table" then options else {}
    local hoverTarget = options.target or element.main
    local titleRestKey = options.titleRestKey or "ContentColor"
    local titleHoverKey = options.titleHoverKey or "ElementTextHoverColor"

    -- [[Hover feedback is the single most-repeated animation in the library
    -- (every element, every pointer move across a grid), so it goes through
    -- the motion service: the spec is shared instead of allocated per event,
    -- and an enter/leave pair on the same element can no longer leave two
    -- tweens interpolating the same stroke — the second cancels the first.]]
    self:ConnectFor(element, hoverTarget.MouseEnter, function()
        if not self:_interactive() then
            return         end
        motion.tween(
            element.stroke,
            { Transparency = theme.ElementStrokeHoverTransparency, Color = theme.ElementStrokeHover },
            "snappy"
        )
        motion.tween(element.title, { TextColor3 = theme[titleHoverKey] }, "snappy")
        if element.hoverOverlay then
            motion.tween(element.hoverOverlay, { BackgroundTransparency = 0.97 }, "snappy")
        end
    end)

    self:ConnectFor(element, hoverTarget.MouseLeave, function()
        motion.tween(
            element.stroke,
            { Transparency = theme.ElementStrokeTransparency, Color = theme.ElementStroke },
            "snappy"
        )
        motion.tween(element.title, { TextColor3 = theme[titleRestKey] }, "snappy")
        if element.hoverOverlay then
            motion.tween(element.hoverOverlay, { BackgroundTransparency = 1 }, "snappy")
        end
    end)
end

function Window:_runGuarded(element, fn, ...)
            if element.locked then
        return
    end

    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            return fn(table.unpack(args, 1, args.n))
        end)
        if ok or element._errored then
            return
        end
        element._errored = true

        local flashTarget = element.flashTarget or element.main
        local errorTween = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        motion.tween(flashTarget, { BackgroundColor3 = self.theme.ErrorColor }, errorTween)
        motion.tween(element.stroke, { Color = self.theme.ErrorStrokeColor }, errorTween)
                if element.title then
            element.title.Text = locale.resolve("Error, log recorded in console.")
        end

        log.warn(
            `Astra encountered an error, with the callback for a {element.__type} component named '{element.name}':`
        )
        log.print(err)

        task.wait(1)

        if element.title then
            element.title.Text = locale.resolve(element.name)
        end
        motion.tween(
            flashTarget,
            { BackgroundColor3 = Color3.fromRGB(255, 255, 255) },
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        )
        motion.tween(
            element.stroke,
            { Color = self.theme.ElementStroke },
            TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        )
        element._errored = false
    end)
end

function Window:StyleElementBody(frame)
    self:Create("UIGradient", {
        Rotation = 270,

        Parent = frame,
    }, { Color = "ElementGradient" })

    self:Create("UICorner", {
        Parent = frame,
    }, { CornerRadius = "ElementCornerRadius" })

    return self:Create("UIStroke", {
        Transparency = 1,

        Parent = frame,
    }, { Color = "ElementStroke", Transparency = "ElementStrokeTransparency" })
end

function Window:_buildCompactRow(tab, name, zIndex)
    local row = self:Create("Frame", {
        Name = name,
        Size = UDim2.fromOffset(0, compactRowHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        ClipsDescendants = true,         BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,
        Parent = tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    local stroke = self:StyleElementBody(row)

        self:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,
        Parent = row,
    })

        self:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = row,
    })

        local button = self:Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,         AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactRowHeight),
        BorderSizePixel = 0,
        TextTransparency = 1,
        ZIndex = zIndex or 1,

        Parent = row,
    })

    self:Create("UICorner", {
        Parent = button,
    }, { CornerRadius = "ElementCornerRadius" })

    return row, stroke, button
end

function Window:StyleElementPanel(frame)
    self:Create("UIGradient", {
        Rotation = 270,

        Parent = frame,
    }, { Color = "ElementGradient" })

    self:Create("UICorner", {
        Parent = frame,
    }, { CornerRadius = "ElementCornerRadius" })

    local stroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,
        Parent = frame,
    })

    self:Create("UIGradient", {
        Rotation = 270,

        Parent = stroke,
    }, { Color = "ElementStrokeGradient" })

    return stroke
end

function Window:_reveal(instance, targets, animate, tweenInfo)
    if not instance then
        return
    end
    -- [[Skip work when the target state is already applied: the cascade (and
    -- a window that is shown, hidden and shown again) asks the same elements
    -- to reveal repeatedly.]]
    local needsUpdate = false
    for prop, value in targets do
        if instance[prop] ~= value then
            needsUpdate = true
            break
        end
    end
    if not needsUpdate then
        return
    end

    if animate then
        -- [[The tween goes through the motion service, which shares the spec
        -- and cancels an in-flight tween on the same property — the cascade
        -- asks every element on the page to show on one frame, and a
        -- hidden/reshown window used to stack a second reveal on the first.]]
        motion.tween(instance, targets, tweenInfo or revealTween)
    else
        for prop, value in targets do
            instance[prop] = value
        end
    end
end

function Window:_revealCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = self.theme.ElementStrokeTransparency }, animate)
    self:_reveal(element.title, { TextTransparency = 0 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = self.theme.ElementTransparency or 0 }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 0 }, animate)
    end
    if element.descriptionLabel then
        self:_reveal(element.descriptionLabel, { TextTransparency = 0.45 }, animate)
    end
end

function Window:_hideCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = 1 }, animate)
    self:_reveal(element.title, { TextTransparency = 1 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = 1 }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 1 }, animate)
    end
    if element.descriptionLabel then
        self:_reveal(element.descriptionLabel, { TextTransparency = 1 }, animate)
    end
end

function Window:_resetCapsulePosition()
    if self.unloaded then
        return
    end
    -- Forget the drag override. The next collapse uses the default rectangle
    -- for the current capsule style; the expanded window's position is untouched.
    self._collapsedPosition = nil
    if self._collapsedShown and not self.animating then
        local position = self:_collapsedRect()
        motion.tween(self.main, { Position = position }, tweenStyle)
    end
end

function Window:_collapsedRect()
    local size = if self.showIconOnly then collapsedIconOnlySize else collapsedWideSize
        if self._collapsedPosition then
        return self._collapsedPosition, size
    end
    local position = UDim2.new(
        collapsedPosition.X.Scale,
        collapsedPosition.X.Offset,
        collapsedPosition.Y.Scale,
        collapsedPosition.Y.Offset + size.Y.Offset / 2
    )
    return position, size
end

function Window:_interactive()
    return not self.animating and not self.hidden
end

function Window:_canDragCapsule()
    if self.hidden or self.animating then
        return false
    end
    return not self.minimised or (self.settings and self.settings.dragMinimisedBar == true)
end

function Window:_settled()
    return not self.hidden and not self._revealing
end

function Window:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

function Window:ConnectFor(element, signal, callback)
    local connection = self:Connect(signal, callback)
    element.connections = element.connections or {}
    table.insert(element.connections, connection)
    return connection
end

function Window:Disconnect(connection)
    if not connection then
        return
    end
    local index = table.find(self.connections, connection)
    if index then
        table.remove(self.connections, index)
    end
    connection:Disconnect()
end

function Window:DestroySubtree(root)
    if not root then
        return
    end

    local descendants = { [root] = true }
    for _, desc in root:GetDescendants() do
        descendants[desc] = true
    end
    for i = #self.instances, 1, -1 do
        local inst = self.instances[i]
        if descendants[inst] then
            table.remove(self.instances, i)
            self.themeProperties[inst] = nil
            self.localeProperties[inst] = nil
        end
    end

    root:Destroy()
end

function Window:DisconnectMany(element, connections)
    if not connections or #connections == 0 then
        return
    end

    local removed = {}
    for _, conn in connections do
        removed[conn] = true
        conn:Disconnect()
    end

    local function compact(list)
        if not list then
            return
        end
        local write = 0
        for i = 1, #list do
            local conn = list[i]
            if not removed[conn] then
                write += 1
                list[write] = conn
            end
        end
        for i = #list, write + 1, -1 do
            list[i] = nil
        end
    end

    compact(self.connections)
    if element and element ~= self then
        compact(element.connections)
    end
end

function Window:DestroySubtrees(roots)
    if not roots or #roots == 0 then
        return
    end

    local descendants = {}
    for _, root in roots do
        descendants[root] = true
        for _, desc in root:GetDescendants() do
            descendants[desc] = true
        end
    end

    local write = 0
    for i = 1, #self.instances do
        local inst = self.instances[i]
        if descendants[inst] then
            self.themeProperties[inst] = nil
            self.localeProperties[inst] = nil
        else
            write += 1
            self.instances[write] = inst
        end
    end
    for i = #self.instances, write + 1, -1 do
        self.instances[i] = nil
    end

    for _, root in roots do
        root:Destroy()
    end
end

function Window:Unload()
    -- Do not lose the final edit if the window closes inside the save debounce.
    if not self.unloaded and self._saveScheduled and self.configuration.autoSave and not self._loading then
        self._saveScheduled = false
        pcall(self.Save, self)
    end
    self.unloaded = true
            haptic.teardown()
    haptic.releaseContainer(self.screenGui)
    for _, liveTween in self._liveTweens or {} do
        liveTween:Cancel()
    end
    self._liveTweens = nil
    for i = #self.connections, 1, -1 do
        self.connections[i]:Disconnect()
    end
    for i = #self.instances, 1, -1 do
        self.instances[i]:Destroy()
    end

                table.clear(self.connections)
    table.clear(self.instances)
    table.clear(self.themeProperties)
    table.clear(self.localeProperties)
    table.clear(self.controls)
    table.clear(self.tabs)
end

return Window
