local utilities = script.Parent.Parent.Parent.utilities
local chrome = require(script.Parent.Parent.chrome)
local constants = require(utilities.constants)
local haptic = require(utilities.HapticEngine)
local icons = require(script.Parent.Parent.Parent.icons)
local layouts = require(utilities.layouts)
local locale = require(utilities.locale)
local log = require(utilities.log)
local motion = require(utilities.motion)
local overlayQueue = require(script.Parent.Parent.overlayQueue)
local search = require(script.Parent.Parent.search)
local state = require(utilities.Parent.core.state)

local themes = require(script.Parent.Parent.Parent.themes)
local resolveTheme = themes.resolve

local shared = require(script.Parent.constants)
local constructionFrameBudget = shared.constructionFrameBudget
local constructionInstanceBudget = shared.constructionInstanceBudget
local computeSize = shared.computeSize
local layoutKey = shared.layoutKey

local Window = require(script.Parent.class)

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

        local layout = layouts.sidebar -- [[layout is controlled via Settings (Astra Settings → Bar Layout); CreateWindow no longer takes sidebarLayout]]
    local providedIcon = props.icon or props.Icon

    local self = setmetatable({
        name = props.name or props.Name or "Astra Window",
        subheading = props.subtitle or props.Subtitle,
        layout = layout,
        size = computeSize(layout.mode),
        instances = {},
        connections = {},

        -- Cleared by the entrypoint after the caller's initial construction
        -- has been quiet for two frames. Checkpoints continue after the window
        -- appears so the remaining controls cannot freeze its entrance.
        _startupComplete = false,
        -- [[Placeholder for the entrance queue: the queue's own shape (pending
        -- list, gate flags) is completed by `queueFor` in
        -- `components/overlayQueue.luau` on first use, so what lives here is
        -- only "the window has somewhere to put its overlays", which is what
        -- lets `Unload` clear it unconditionally.]]
        _overlayQueue = {},
        _overlayQueueRunning = false,

        icon = icons.resolve(providedIcon or "Astra"),
        showName = props.showName or props.ShowName or "Astra",
        showIcon = icons.resolve(providedIcon or "Astra"),
                showIconOnly = props.showIconOnly or props.ShowIconOnly or false,

        themeProperties = {},
        localeProperties = {},
        tabs = {},
        tabSections = {},
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
        mouseOverride = false,         keepOnScreen = true,         haptics = false,
        dragMinimisedBar = false,
        antiWindowDuplicate = true,
        layoutMode = layout.mode,
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
        BackgroundTransparency = 1,
        -- [[Roblox gives every GuiObject a 1px border by default. The border
        -- draws the frame's rectangular outline — straight lines that ignore
        -- the UICorner arcs — so on the rounded window it painted a hard
        -- square edge across all four corners once the surface faded in.
        -- The window's silhouette is the UICorner's job alone.]]
        BorderSizePixel = 0,
        Visible = false,
        Parent = self.screenGui,
    })

    -- Scale is used only for the first entrance. Animating the Frame's Size
    -- forces every descendant layout to recompute on every tween step; UIScale
    -- gives the same soft pop without turning a large window into a layout
    -- hotspot while it opens.
    self.windowScale = self:Create("UIScale", {
        Scale = 1,
        Parent = self.main,
    })

    self.drag = require(script.Parent.Parent.drag).new(self)

    self.windowCorner = self:Create("UICorner", {

        Parent = self.main,
    }, { CornerRadius = "CornerRoundness" })

    self.windowStroke = self:Create("UIStroke", {
                Transparency = 1,
        Parent = self.main,
    }, { Color = "SurfaceStroke" })

    self.windowGradient = self:StyleWindowSurface(self.main)

    self.bottomFade = self:Create("Frame", {
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = self.layout.fadeSize,
        ZIndex = constants.zIndex.bottomFade,

        BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "WindowSurface" })

    self.bottomFadeCorner = self:_roundCorners(self.bottomFade, self.layout.fadeCorners)

    -- [[The fade dissolves the last rows into the plane they are scrolling
    -- [[out of, so it is drawn in that plane's own colour (`WindowSurface`,
    -- [[the same token the elements pane is painted with) and only its
    -- [[opacity ramps. It used to take `WindowColor`'s first keypoint — the
    -- [[shade of the window gradient at the bottom — which is a different
    -- [[colour from the plane over it: a soft dark bar under a lighter pane.
    self.bottomFadeGradient = self:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, 0.2),
        Transparency = self.layout.fadeTransparency,

        Parent = self.bottomFade,
    })

    -- [[The topbar band. It is the window's top plane: painted flat in
    -- [[TopbarSurface (the darkest of the three), full width, and the one
    -- [[band that owns the window's top edge — so it carries the top corner
    -- [[arcs. `Active` makes the empty part of the band a drag handle
    -- [[(components/window/input.luau); the title, actions and tab rows sit
    -- [[on top of it as its children, which is where they already were.]]
    self.topbar = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, self.layout.topbarHeight),
        Active = true,

        Parent = self.main,
    }, { BackgroundColor3 = "TopbarSurface" })

    self.topbarCorner = self:_roundCorners(self.topbar, self.layout.chromeCorners)

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

        self.windowShadow = self:CreateGlow(self.main, "ShadowColor", 20, 1)

    -- [[The elements pane. The third plane: painted flat in `WindowSurface`,
    -- [[the lightest of the three, reaching the window's right and bottom
    -- [[edges — so it owns the bottom-right corner arc. The faint
    -- [[SurfaceStroke edge stays: it is the seam between the pane and the
    -- [[rail band beside it, and it follows the arc (Border mode) instead
    -- [[of cutting across it.]]
    self.elements = self:Create("Frame", {
        Size = UDim2.new(1, 0, 1, -self.layout.chromeHeight),
        Position = UDim2.fromScale(1, 1),
        AnchorPoint = Vector2.new(1, 1),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,

        Parent = self.main,
    }, { BackgroundColor3 = "WindowSurface" })

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
    -- [[Settings tab shell landed; hand the frame back before the action
    -- [[buttons and search chrome are added.]]
    self:_constructionCheckpoint(true)

    require(script.Parent.Parent.action).new(self, {
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

    self.minimiseAction = require(script.Parent.Parent.action).new(self, {
        name = "Minimise",
        icon = constants.icons.minimise,
        order = 2,

        callback = function()
            self:ToggleHide()
        end,
    })

    self.settingsAction = require(script.Parent.Parent.action).new(self, {
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
    -- [[Toolbar complete; another frame before persisted settings are read
    -- [[and applied (a disk read, the theme pass and possibly a layout swap).]]
    self:_constructionCheckpoint(true)

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

    haptic.setContainer(self.screenGui)     haptic.setEnabled(self.settings.haptics)
    chrome.buildCollapsedFace(self)

    self:_constructionCheckpoint(true)
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

    -- [[Overlays wait for the window's own entrance before any of them starts]]
    -- [[building: the gate opens when that entrance lands (in `_firstShow`,]]
    -- [[after its settle and the reveal cascade that follows it). A host that]]
    -- [[fires a notification between CreateWindow and the first show still gets it —]]
    -- [[just behind the window instead of on top of it.]]
    overlayQueue.pause(self)

    return self
end

-- Yield at a completed construction boundary when the current frame has
-- spent its budget. Batches are limited by both CPU time and instance count,
-- and the check is unconditional: components that build lazily after startup
-- (late settings panels) use this directly so a deferred build can never
-- monopolise a frame either. Yields land on the
-- next Heartbeat (not another deferred task in the same frame).

function Window:_paceBudget(force)
    local now = os.clock()
    local last = self._constructionClock or now
    local count = #self.instances
    if
        not force
        and now - last < constructionFrameBudget
        and count - (self._constructionInstances or 0) < constructionInstanceBudget
    then
        self._constructionClock = last
        return
    end
    self._constructionRevision = (self._constructionRevision or 0) + 1
    self._constructionBusy = (self._constructionBusy or 0) + 1
    task.wait()
    self._constructionBusy -= 1
    assert(not self.unloaded, "Window unloaded during construction")
    self._constructionClock = os.clock()
    self._constructionInstances = #self.instances
end

-- Startup-only checkpoint: element constructors stream in between the shell's
-- first reveal and the build going quiet, so yielding is gated to that window.
-- `force` marks an explicit shell phase boundary inside Window.new (where
-- `_constructed` is still false). Every boundary yields whole, completed
-- objects, never half a control, so each constructor resumes with a fully
-- usable object.

function Window:_constructionCheckpoint(force)
    if self._startupComplete or (not force and not self._constructed) then
        return
    end
    self:_paceBudget(force)
end

-- Configuration restoration can execute host callbacks. Apply a small group,
-- then return a frame to rendering so a large saved configuration cannot make
-- the freshly-opened window hitch. This is called only by persistenceConfig.

function Window:_loadCheckpoint(appliedCount)
    if appliedCount % 6 == 0 then
        task.wait()
        assert(not self.unloaded, "Window unloaded while loading configuration")
    end
end

-- [[The "Animation speed" setting owns the motion service's time scale. It is
-- applied from the window (not only from the settings control) so a window
-- built from persisted settings, a configuration load and a live change all
-- reach the same state; an unknown persisted value falls back to `normal`
-- instead of leaving the library on whatever the last window used.]]
