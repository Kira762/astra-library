local utilities = script.Parent.Parent.Parent.utilities
local functions = require(script.Parent.Parent.Parent.functions)
local icons = require(script.Parent.Parent.Parent.icons)
local image = require(script.Parent.Parent.Parent.images.image)
local locale = require(utilities.locale)
local motion = require(utilities.motion)
local state = require(utilities.Parent.core.state)

local themes = require(script.Parent.Parent.Parent.themes)
local coerceValue = themes.coerceValue
local deriveStrokes = themes.deriveStrokes
local resolveTheme = themes.resolve

local shared = require(script.Parent.constants)
local windowSurfaceColor = shared.windowSurfaceColor
local windowSurfaceTransparency = shared.windowSurfaceTransparency
local windowSurfaceGradientRotation = shared.windowSurfaceGradientRotation
local windowSurfaceGradientOffset = shared.windowSurfaceGradientOffset
local cornerKeys = shared.cornerKeys
local hasPerCornerRadius = shared.hasPerCornerRadius

local Window = require(script.Parent.class)

function Window:ResolveIcon(value, pack)
    return icons.resolve(value, pack)
end

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
            -- [[A list so the drift can be applied to more than one gradient
            -- [[surface; the window's own is currently the only one.]]
            local liveTargets = { self.windowGradient }

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

    -- [[Before the first show the window is invisible, so routing every
    -- Color3/number through a 0.5s tween only buys dozens of tween allocations
    -- on the startup path — nothing can be seen animating. Assign the end
    -- state directly; the values are identical to what the tweens would have
    -- settled on, and everything from the first entrance on still tweens.
    -- When the theme *can* be seen changing, the per-instance properties are
    -- batched into one motion-service tween each (instead of one TweenService
    -- tween per property), so a theme switch both animates as one gesture and
    -- hands ownership of every animated property to the service.]]
    local instantApply = self.hidden and not self.hasShownOnce
    local pendingThemeTweens: { [Instance]: { [string]: any } } = {}
    for instance, properties in self.themeProperties do
        for prop, binding in properties do
            local resolvedValue = if typeof(binding) == "table" then binding[2](self.theme[binding[1]]) else self.theme[binding]

            if instance[prop] == resolvedValue then
                continue
            end
            if not instantApply and (typeof(resolvedValue) == "Color3" or typeof(resolvedValue) == "number") then
                local batch = pendingThemeTweens[instance]
                if not batch then
                    batch = {}
                    pendingThemeTweens[instance] = batch
                end
                batch[prop] = resolvedValue
            else
                instance[prop] = resolvedValue
            end
        end
    end
    if not instantApply then
        for instance, batch in pendingThemeTweens do
            motion.tween(instance, batch, "smooth")
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
        local pill = self.theme.PillCornerRadius or UDim.new(0, 0)
        if self.windowCorner.CornerRadius ~= pill then
            motion.tween(self.windowCorner, { CornerRadius = pill }, "smooth")
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

function Window:StyleWindowSurface(frame): UIGradient
    frame.BackgroundColor3 = windowSurfaceColor
    return self:Create("UIGradient", {
        Rotation = windowSurfaceGradientRotation,
        Offset = windowSurfaceGradientOffset,

        Parent = frame,
    }, { Color = { "WindowColor", functions.toColorSequence } })
end

-- [[The window's own opacity once it is on screen. Kept beside the surface
-- [[style so callers state the same value without guessing.]]

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

function Window:_elementBackgroundTransparency(element)
    if element and element._collapsibleChild then
        return self.theme.CollapsibleChildElementTransparency or 0.75
    end
    return self.theme.ElementTransparency or 0
end

function Window:_elementStrokeTransparency(element, hover)
    if element and element._collapsibleChild then
        if hover then
            return self.theme.CollapsibleChildElementStrokeHoverTransparency
                or self.theme.CollapsibleChildElementStrokeTransparency
                or 1
        end
        return self.theme.CollapsibleChildElementStrokeTransparency or 1
    end
    return if hover then self.theme.ElementStrokeHoverTransparency else self.theme.ElementStrokeTransparency
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

function Window:_roundCorners(frame, corners, token)
    token = token or "CornerRoundness"
    if not corners or not hasPerCornerRadius then
        return self:Create("UICorner", {
            Parent = frame,
        }, { CornerRadius = token })
    end

    local props = { Parent = frame }
    local themeMap = {}
    for _, key in cornerKeys do
        props[key] = UDim.new(0, 0)
    end
    for _, corner in corners do
        props[corner] = nil         themeMap[corner] = token
    end

    return self:Create("UICorner", props, themeMap)
end

-- [[Companion to `_roundCorners` for a corner set an element flips with its own
-- [[state instead of once at construction: `corners` (default: all four, as in
-- [[`_roundCorners`) ride the `token` radius and every other corner of the frame
-- [[goes back to square, so a caller can move which of an inner surface's edges
-- [[match the container's arcs — a collapsible header is the card's bottom edge
-- [[only while it is closed. No theme binding is recorded here (`themeProperties`
-- [[still owns whatever `_roundCorners` bound), so a later `ChangeTheme` re-reads
-- [[`token` through this same call from the element instead of fighting it. There
-- [[is nothing to move on an engine without per-corner radii, where
-- [[`_roundCorners` already gave the frame one radius on all four corners, so the
-- [[call is a no-op there.]]

function Window:_setRoundedCorners(corner, corners, token)
    if not corner or not hasPerCornerRadius then
        return
    end

    local radius = if token then self.theme[token] else nil
    for _, key in cornerKeys do
        local wanted = radius ~= nil and (not corners or table.find(corners, key) ~= nil)
        local target = if wanted then radius else UDim.new(0, 0)
        if corner[key] ~= target then
            corner[key] = target
        end
    end
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
-- [[definition is shared rather than copied, so surfaces cannot drift into
-- [[near-miss shades of each other. Returns the gradient so callers can keep
-- [[it in step with the window's own (see _syncLiveAnimation).]]
