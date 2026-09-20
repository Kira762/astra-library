local utilities = script.Parent.Parent.Parent.utilities
local chrome = require(script.Parent.Parent.chrome)
local constants = require(utilities.constants)
local image = require(script.Parent.Parent.Parent.images.image)
local locale = require(utilities.locale)
local motion = require(utilities.motion)
local overlayQueue = require(script.Parent.Parent.overlayQueue)
local search = require(script.Parent.Parent.search)
local state = require(utilities.Parent.core.state)
local tooltip = require(script.Parent.Parent.tooltip)

local shared = require(script.Parent.constants)
local contentRevealBeat = shared.contentRevealBeat
local dragHandleGap = shared.dragHandleGap
local windowSurfaceTransparency = shared.windowSurfaceTransparency

local Window = require(script.Parent.class)

function Window:Hide()
    tooltip.hide(self)
    -- Cancel pending startup reveal even while the window is still hidden.
    self._autoShowCancelled = true
    -- [[A window whose entrance is never going to happen (the cancelled
    -- [[auto-show above) must not keep the overlays it was already asked for
    -- [[parked behind an entrance that will not arrive.]]
    if not self.hasShownOnce then
        overlayQueue.resume(self)
    end
    if self.animating or self.hidden then
        return
    end

            if self._searching then
        search.close(self, { showTabs = false, jumpTo = self.selectedTab and self.selectedTab.tabPage })
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

    -- [[The fold: content leaves quickly (snappy fades), the shell glides
    -- into the capsule with the symmetric ease, and the capsule's face
    -- appears with a small settle overshoot so the fold ends on a landing,
    -- not a stop.]]
    local hideTween = "snappy"
    local surfaceTween = "glide"
    local cornerTween = "glide"
    local collapseShowTween = "settle"

            self._hideTransitionId = (self._hideTransitionId or 0) + 1
    local transitionId = self._hideTransitionId

    -- [[The handle folds away with the surface: the pill shrinks out first
    -- [[and the hitbox follows once the fade has read (the handle owns that
    -- [[timing, and stands down if a Show claims it back in the meantime).
    self.drag:fadeOut("fast")

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
        local iconLabel = self:_actionIconLabel(actionFrame)
        if iconLabel then
            motion.tween(iconLabel, { ImageTransparency = 1 }, hideTween)
        end
        if actionFrame:IsA("Frame") then
            self:_syncActionChrome(actionFrame, false, hideTween)
        end
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
        self.collapsedInteract.Visible = true
        self.animating = false
        self._revealing = false
    end

    if not motion.tween(self.main, { Size = collapsedSize, Position = collapsedPos }, surfaceTween, settleCollapse) then
        settleCollapse()
    end
    -- [[Capsule bar: theme PillCornerRadius (the default theme is a full pill).]]
    motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(0, 0) }, cornerTween)

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
    -- [[Either direction moves one surface between two shapes, and the handle
    -- [[is not one of them: it fades out with the shell and is handed back by
    -- [[the settle below (the fold's own `minimised` write turns it on again
    -- [[under the capsule, exactly as before).
    self.drag:fadeOut("fast")
    self.collapsedInteract.Visible = false

    -- [[Both directions of the minimise move one surface between two shapes,
    -- so both ride the same pair of specs: `smooth` carries the geometric
    -- unfold (a big decelerating move reads as arriving), `settle` lands the
    -- capsule face when folding away.]]
    local expandTween = "smooth"
    local surfaceTween = "smooth"

    self._hideTransitionId = (self._hideTransitionId or 0) + 1

    if self.minimised then
        self.minimised = false
        image.assign(self.minimiseAction.iconLabel, "Image", constants.icons.minimise)
        motion.tween(self.main, { Size = self.size }, expandTween)
        motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, expandTween)
        self:_fadeSurfaces(true, surfaceTween)	chrome.setCollapsedShown(self, false, surfaceTween)

        -- [[The expanded window has to fit: the capsule's own clamp only]]
        -- [[knew the capsule, so one dragged into a corner used to expand]]
        -- [[with the window hanging off the edge. Re-clamp now the full]]
        -- [[size is back (a no-op while it already fits).]]
        self:_clampToScreen()

        motion.tween(self.drag.drag, {
            Position = UDim2.new(
                self.main.Position.X.Scale,
                self.main.Position.X.Offset,
                self.main.Position.Y.Scale,
                self.main.Position.Y.Offset + self.size.Y.Offset / 2 + dragHandleGap
            ),
        }, expandTween)

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
            if self.unloaded or self.minimised or self.hidden then
                return
            end
            -- [[The window is back to its full size, so the handle is
            -- [[reachable again. It is handed back unseen (the pill was
            -- [[parked when the fold started) and waits for the pointer,
            -- [[exactly like the handle of a freshly opened window.
            self.drag:enable()
            self.animating = false
        end)
    else
        self.minimised = true
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
        motion.tween(self.main, { Size = UDim2.fromOffset(self.size.X.Offset, self.layout.topbarHeight) }, expandTween)
        -- [[Minimised bar reads as a theme-aware capsule (PillCornerRadius).]]
        motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(0, 0) }, expandTween)

        motion.tween(self.drag.drag, {
            Position = UDim2.new(
                self.main.Position.X.Scale,
                self.main.Position.X.Offset,
                self.main.Position.Y.Scale,
                self.main.Position.Y.Offset + self.layout.topbarHeight / 2 + dragHandleGap
            ),
        }, expandTween)

        task.delay(0.5, function()
            if self.unloaded then
                return
            end
            if self.minimised and not self.hidden then
                self:_syncDragBar()
                self.drag:enable()
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
    local dragOffset = if self.minimised then self.layout.topbarHeight / 2 + dragHandleGap else self.size.Y.Offset / 2 + dragHandleGap
    dragFrame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + dragOffset)
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

-- [[The window's surfaces, shown or hidden as one. The three painted bands
-- [[are part of this: the topbar band, the rail band and the elements pane
-- [[reach the window's edges, so a fold that left them behind would keep a
-- [[solid rectangle standing where the window is shrinking into its capsule
-- [[(and, with a pill radius, square corners poking out of it). They fade
-- [[out with the shell and fade back in with it, which is also how the
-- [[window's own entrance stays a single gesture.
function Window:_fadeSurfaces(shown, tweenInfo)
    local targets = {
        [self.windowShadow] = { Transparency = if shown then 0.6 else 1 },
        [self.windowStroke] = { Transparency = if shown then 0.95 else 1 },
        [self.bottomFade] = { BackgroundTransparency = if shown then 0 else 1 },
        [self.topbar] = { BackgroundTransparency = if shown then 0 else 1 },
    }

    if self.sidebar then
        targets[self.sidebar] = { BackgroundTransparency = if shown then 0 else 1 }
    end

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

    -- [[The cascade is the moment this page's elements are being looked at, so]]
    -- [[it owns the pending mark `_showTabElements` would otherwise clear in]]
    -- [[one frame: dropping the mark up front keeps a tab that is opened,]]
    -- [[hidden and opened again from queuing a second reveal behind this one.]]
    tab._elementsPending = false

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

-- [[The content half of an entrance, and the beat that keeps it out of the
-- [[shell's way. The frame, its surface, the corner and the topbar copy animate
-- [[first; the page's controls come in one cooldown later, as a cascade rather
-- [[than on a single frame, and the overlay queue is opened once that has been
-- [[committed. `entranceId` is the entrance generation: a window that is hidden
-- [[or shown again in the meantime drops the half-finished sequence and lets
-- [[the newer entrance own the page.]]

function Window:_stageContentReveal(beat, stepDelay, totalDuration, entranceId)
    task.spawn(function()
        if beat > 0 then
            task.wait(beat)
        end
        if self.unloaded or self._contentEntranceId ~= entranceId then
            return
        end

        self:_revealElements(stepDelay, totalDuration)

        -- [[Runs even when the cascade above bailed out (a hide, a minimise):
        -- [[overlays belong to the screen layer, not to the page, so nothing
        -- [[here may leave the queue parked on an entrance that never finished.
        -- [[`_firstShow`'s settle opens it as well; this is the later of the
        -- [[two, which is what makes the cards arrive behind the content.]]
        overlayQueue.resume(self)
    end)
end

function Window:Show()
        -- [[An unload retires every instance the window owns, including the ones
        -- [[the entrance tweens next, and a window closed before its deferred
        -- [[startup reveal ran still has that reveal queued (`library_entrypoint`).]]
        if self.animating or self.unloaded or not self.hidden then
        return
    end
    self.animating = true
    self._revealing = true
    -- [[The handle waits while the shell is in the air: it is handed back by
    -- [[whichever settle path this entrance takes (_firstShow or
    -- [[_quickRestore), and only an entrance that actually lands gets one.
    self.drag:disable()

    -- General's heavier content is never built here: settings panels build
    -- lazily on first open through _buildSettingsContent / buildContent.

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
        -- [[window was hidden: come back to the resting centre as it is]]
        -- [[*now* (the viewport may have changed since that position was]]
        -- [[recorded), so the window lands centred.]]
        restore = self:_restingCenterPosition()
    end
    local targetPos = self:_clampedPosition(restore)
    self._restorePosition = targetPos
    -- [[The restore unfolds one surface between two shapes: the shell glides
    -- (symmetric ease) while the corner springs open with a small overshoot,
    -- so the capsule visibly "pops" back into the window.]]
    local restoreTween = "glide"
    local restoreCornerTween = "settle"

    self.main.ClipsDescendants = true
    self.main.BackgroundTransparency = windowSurfaceTransparency
    self.topbar.Visible = true
    self:_setContentVisible(true)
    self:_setTabSectionsVisible(true)
    self:_setTabSectionsShown(true)
    -- [[Same two-beat structure as the first show, on the shorter restore
    -- [[timing: the shell comes back first and the page follows it, instead of
    -- [[every control on the page being rewritten on the frame the restore
    -- [[starts on.]]
    self._contentEntranceId = (self._contentEntranceId or 0) + 1
    local entranceId = self._contentEntranceId
    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
        if tab == self.selectedTab then
            self:_markTabElementsPending(tab)
        end
    end
    -- [[Restore the settings/normal rail split. The loop above leaves the
    -- [[selected tab marked: the staged reveal at the end of this function
    -- [[walks it one card per beat, the same way opening a tab does.]]
    self:_applySettingsLayout(self._settingsMode)
    self:_fadeSurfaces(true)

    -- [[The window is back on screen with this restore, so re-clamp now]]
    -- [[that its full size is measurable (above it was still collapsed]]
    -- [[from the Hide).]]
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
        local iconLabel = self:_actionIconLabel(actionFrame)
        if iconLabel then
            iconLabel.ImageTransparency = 0.6
        end
        if actionFrame:IsA("Frame") then
            self:_syncActionChrome(actionFrame, true)
        end
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
        -- [[The window is on screen and settled, so the handle is reachable
        -- [[again. Note it is *enabled*, not revealed: the pill was parked on
        -- [[the way out, so a restored window offers its handle to the pointer
        -- [[instead of announcing it.
        self.drag:enable()
        self.animating = false
        self._revealing = false
        -- [[The overlay gate opens with the shell, exactly as on the first
        -- [[show, and the staged reveal below re-opens it after the page has
        -- [[committed: whichever lands last is the one that lets a waiting
        -- [[card through, so the queue can never be left parked on a restore.]]
        overlayQueue.resume(self)
    end

    if not motion.tween(self.main, { Size = self.size, Position = targetPos }, restoreTween, settle) then
        settle()
    end
    motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, restoreCornerTween)
    self:_stageContentReveal(motion.step(contentRevealBeat * 0.6), 0.02, 0.4, entranceId)
end

function Window:_firstShow()
    self.drag:disable()
    self.main.Visible = true
    self.main.ClipsDescendants = true
    self.main.BackgroundTransparency = 1

    if self.main.Position.X.Scale == 0.5 and self.main.Position.Y.Scale == 0.5 then
        -- [[Still at the anchored resting spot (the user has not dragged]]
        -- [[it), so re-apply the resting centre as it is *now*: between]]
        -- [[building the frame and this first show the viewport can settle,]]
        -- [[and a recenter that ran while the window was still hidden only]]
        -- [[parked the remembered position.]]
        self:_recenterWindow(false)
    end

    self.main.Size = self.size
    self.windowScale.Scale = 0.94
    -- [[Entrance starts as a capsule (theme pill) then opens to CornerRoundness.]]
    self.windowCorner.CornerRadius = self.theme.PillCornerRadius or UDim.new(0, 0)
    -- [[Which entrance owns the staged content reveal below. A hide, a repeat
    -- [[show or a layout switch between now and then replaces it, and the
    -- [[older sequence stops instead of fighting the newer one for the page.]]
    self._contentEntranceId = (self._contentEntranceId or 0) + 1
    local entranceId = self._contentEntranceId
    self:_setContentVisible(true)
    self:_setTabSectionsVisible(true)
    self:_setTabSectionsShown(true)
    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected")
        end
        if tab == self.selectedTab then
            -- [[The page's controls are deliberately not shown here: writing
            -- [[every card on the frame the entrance opens on is what made the
            -- [[first show look instant and cost a hitch on pages with a lot on
            -- [[them. The mark stays on, and the staged reveal below clears it
            -- [[as it walks the page.]]
            self:_markTabElementsPending(tab)
        end
    end
    -- [[Restore the settings/normal rail split. The loop above leaves the
    -- [[selected tab marked and every other tab either shown or still marked
    -- [[for when it is opened; the staged reveal below walks the page that is
    -- [[actually on screen, one control per beat.]]
    self:_applySettingsLayout(self._settingsMode)
    local tweenInfo = "smooth"
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
        local iconLabel = self:_actionIconLabel(actionFrame)
        if iconLabel then
            iconLabel.ImageTransparency = 1
            motion.tween(iconLabel, { ImageTransparency = 0.6 }, tweenInfo)
        end
        if actionFrame:IsA("Frame") then
            self:_syncActionChrome(actionFrame, true, tweenInfo)
        end
    end

    self:_fadeSurfaces(true, tweenInfo)

    -- [[The entrance is the library's hero transition. Only UIScale moves:
    -- the main frame stays at its final size, so hundreds of descendants are
    -- not laid out again on every tween step. The Back/Out pop and surface
    -- fade make the load visible without front-loading the remaining content.
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
        -- [[The shell has landed: the handle becomes reachable (unseen, at the
        -- [[parked look the entrance started from) and the hover reveal takes
        -- [[it from there. This is the write that used to keep the handle off
        -- [[for the whole life of an expanded window.
        self.drag:enable()
        self.animating = false
        self._revealing = false
        -- [[The window is stable now, so park the selected tab in view and
        -- [[let saved values/callbacks begin only after the opening frame.]]
        self:_scrollSelectedTabIntoView(false)
        self:_refreshTabStripChrome()
        -- [[The shell has landed, so the entrance is over as far as the
        -- [[overlay queue is concerned. The staged reveal below opens the same
        -- [[gate again when it has committed the page; whichever of the two
        -- [[happens last is what lets a waiting notification through.]]
        overlayQueue.resume(self)
    end

    motion.tween(self.main, { BackgroundTransparency = windowSurfaceTransparency }, "emphasized")
    if not motion.tween(self.windowScale, { Scale = 1 }, "pop", settle) then
        settle()
    end
    motion.tween(self.windowCorner, { CornerRadius = self.theme.CornerRoundness }, "pop")

    -- [[Second beat of the entrance: the single cascade walks the page's
    -- [[controls in once the frame is close to its resting size, and only
    -- [[then do the queued notifications start arriving one at a
    -- [[time. Everything after `CreateWindow` — a host's
    -- [["loaded N modules" notifications, the optional-icon warning — rides
    -- [[that queue instead of sharing the frame the window itself opens on.]]
    self:_stageContentReveal(motion.step(contentRevealBeat), 0.02, 0.35, entranceId)

    local player = state.localPlayer
end

function Window:_updateWindowTitle()
    if not self.title then return end
    local text = self.name
    self.title.Text = locale.resolve(text)
end

function Window:_actionIconLabel(actionFrame)
    return actionFrame:FindFirstChild("ImageLabel")
end

-- [[Badge + divider follow their action frame: hidden with them, restored]]
-- [[with them. The badge restores to opaque only while it is meant to show.]]

function Window:_syncActionChrome(actionFrame, shown, tween)
    local badge = actionFrame:FindFirstChild("Badge")
    if badge then
        local badgeTarget = if shown and badge.Visible then 0 else 1
        if tween then
            motion.tween(badge, { BackgroundTransparency = badgeTarget }, tween)
        else
            badge.BackgroundTransparency = badgeTarget
        end
    end
    if actionFrame.Name == "Divider" then
        local dividerTarget = if shown then 0.8 else 1
        if tween then
            motion.tween(actionFrame, { BackgroundTransparency = dividerTarget }, tween)
        else
            actionFrame.BackgroundTransparency = dividerTarget
        end
    end
end

-- [[The topbar gear action's handler.]]

function Window:_resetCapsulePosition()
    if self.unloaded then
        return
    end
    -- Forget the drag override. The next collapse uses the default rectangle
    -- for the current capsule style; the expanded window's position is untouched.
    self._collapsedPosition = nil
    if self._collapsedShown and not self.animating then
        local position = self:_collapsedRect()
        motion.tween(self.main, { Position = position }, "glide")
    end
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
