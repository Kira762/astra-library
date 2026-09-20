local utilities = script.Parent.Parent.Parent.utilities
local layouts = require(utilities.layouts)
local motion = require(utilities.motion)
local search = require(script.Parent.Parent.search)
local settingsComponent = require(script.Parent.Parent.settings)
local state = require(utilities.Parent.core.state)
local tabSelector = require(script.Parent.Parent.tabSelector)
local windowSizing = require(utilities.windowSizing)

local shared = require(script.Parent.constants)
local collapsedWideSize = shared.collapsedWideSize
local collapsedIconOnlySize = shared.collapsedIconOnlySize
local collapsedPosition = shared.collapsedPosition
local dragHandleGap = shared.dragHandleGap
local viewportCheckInterval = shared.viewportCheckInterval
local computeSize = shared.computeSize
local layoutKey = shared.layoutKey

local Window = require(script.Parent.class)

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
    if self.main.Position.X.Scale == 0.5 and self.main.Position.Y.Scale == 0.5 then
        -- [[Still anchored at the screen centre (the user has not dragged]]
        -- [[it): re-apply the resting centre for the new size.]]
        self:_recenterWindow(false)
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
    local tweenInfo = "fast"
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
    local implementation = layouts.implementation(modeName)
    implementation.Build(self, newLayout)
    -- [[The pane's corner and its edge stroke are part of the shell now
    -- [[(both layouts open one — see Window.new), so switching layouts only
    -- [[has to build the rail and re-apply the panes' widths below.
    implementation.ApplyWidth(self, self:_railWidth())
    self.elementsLayout.FillDirection = newLayout.pageDirection

    for _, tab in self.tabs do
        if not tab.neglectSelector then
            tab:_rebuildSelector()
            tab.topbarItem.Visible = self.elements.Visible and not self.hidden and not self.minimised
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
    end
    -- [[The rows above are brand-new instances, and the rail's width was
    -- [[applied before they existed. Re-applying it now lands the row state on
    -- [[the rows that actually live in the rail — icon-only rows in a
    -- [[collapsed rail (a rail that came back showing tab names), titles held
    -- [[inside a capped one (a rail that came back overflowing).
    self:_applyRailWidth()
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

-- [[Rail groups: the rail shows exactly one group at a time - main tabs]]
-- [[or settings tabs. Every rail filter reads these helpers so the two]]
-- [[of them cannot drift apart.]]

function Window:_clampedPosition(position: UDim2): UDim2
    if not self.settings or not self.settings.keepOnScreen then
        return position
    end
            if position.X.Scale ~= 0 or position.Y.Scale ~= 0 then
        return position
    end

    local screenSize = self.screenGui.AbsoluteSize
    local halfLeft = self.size.X.Offset / 2
    local halfRight = halfLeft
    local halfTop = self.size.Y.Offset / 2
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

-- [[The window's canonical resting position: dead centre of the screen.]]

function Window:_restingCenterPosition(): UDim2
    return UDim2.new(0.5, 0, 0.5, 0)
end

function Window:_recenterWindow(animate)
    local target = self:_restingCenterPosition()
    if self.hidden or self.minimised then
        -- [[Nothing is on screen to move; park the remembered position so]]
        -- [[the next restore lands centred.]]
        self._restorePosition = target
        return
    end
    if self.main.Position == target then
        return
    end
    if animate and not self.animating then
        -- [[A recenter slides the window sideways between resting places:
        -- the symmetric `glide` ease reads as deliberate, not reactive.]]
        motion.tween(self.main, { Position = target }, "glide")
        motion.tween(self.drag.drag, {
            Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + self.size.Y.Offset / 2 + dragHandleGap),
        }, "glide")
    else
        self.main.Position = target
        self:_syncDragBar()
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
