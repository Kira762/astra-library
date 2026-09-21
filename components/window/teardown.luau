local utilities = script.Parent.Parent.Parent.utilities
local haptic = require(utilities.HapticEngine)
local motion = require(utilities.motion)
local overlayQueue = require(script.Parent.Parent.overlayQueue)
local state = require(utilities.Parent.core.state)
local tooltip = require(script.Parent.Parent.tooltip)

local Window = require(script.Parent.class)

function Window:Close()
    if self.animating or self.unloaded then
        return
    end
    tooltip.hide(self)
    self.animating = true
    self.hidden = true
    self.collapsedInteract.Visible = false
    self._closeTransitionId = (self._closeTransitionId or 0) + 1
    local transitionId = self._closeTransitionId
    local originalSize = self.main.Size
    local originalPosition = self.main.Position
    -- [[A close is a departure: the shell contracts on the `glide` spec (a
    -- symmetric ease reads as the window folding itself away) while the
    -- surface accelerates out on `exit`, so the window never lingers at the
    -- tail of its own goodbye.]]
    local contractTween = "glide"
    local fadeOutTween = "exit"
    local targetSize = UDim2.new(
        originalSize.X.Scale * 0.88,
        math.floor(originalSize.X.Offset * 0.88),
        originalSize.Y.Scale * 0.88,
        math.floor(originalSize.Y.Offset * 0.88)
    )

    self.main.ClipsDescendants = true
    self.main.AnchorPoint = Vector2.new(0.5, 0.5)
    self.main.Position = originalPosition
    -- [[The handle leaves with the window it belongs to, and leaves parked:
    -- [[a close is not a state the next entrance should inherit a look from.
    self.drag:disable()
    self:_fadeSurfaces(false, fadeOutTween)
    if self.title then
        motion.tween(self.title, { TextTransparency = 1 }, fadeOutTween)
    end
    if self.subtitle then
        motion.tween(self.subtitle, { TextTransparency = 1 }, fadeOutTween)
    end
    if self.topbarIcon then
        motion.tween(self.topbarIcon, { ImageTransparency = 1 }, fadeOutTween)
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
        self.drag:disable()
        self:Unload()
    end

    -- [[The surface accelerates out first (a separate tween from the
    -- contraction: one owner per property, and the fade never delays the
    -- settle path the teardown waits on).]]
    motion.tween(self.main, { BackgroundTransparency = 1 }, fadeOutTween)
    if not motion.tween(self.main, {
        Size = targetSize,
        Position = originalPosition,
    }, contractTween, finishClose) then
        -- [[Nothing animated, so the teardown just ran and the window's
        -- instances are gone — the corner below must not be touched.]]
        finishClose()
        if self.unloaded then
            return
        end
    end
    -- [[Collapse to a capsule using the theme's pill radius so a custom
    -- [[PillCornerRadius still reads on the closing shrink. A synchronous
    -- completion (the test harness plays tweens on the spot) may have torn
    -- the window down inside the call above; never touch the corner then.]]
    if not self.unloaded then
        motion.tween(self.windowCorner, { CornerRadius = self.theme.PillCornerRadius or UDim.new(0, 0) }, contractTween)
    end
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

-- [[The destructive half of an unload: kill tweens and connections, destroy
-- [[every instance the window owns (the detached graveyard a superseded
-- [[script's tail construction builds into, included) and clear the
-- [[bookkeeping. Runs either at once or, when a construction thread is still
-- [[suspended at a checkpoint, once that construction has gone quiet — see
-- [[`Window:Unload`.]]
function Window:_destroyTree()
    if self._treeDestroyed then
        return
    end
    self._treeDestroyed = true
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
    if self._constructionGraveyard then
        self._constructionGraveyard:Destroy()
        self._constructionGraveyard = nil
    end

                table.clear(self.connections)
    table.clear(self.instances)
    table.clear(self.themeProperties)
    table.clear(self.localeProperties)
    table.clear(self.controls)
    table.clear(self.tabs)
    -- [[overlayQueue.close already drained the queue into its safe resting
    -- [[shape (empty pending list, closed flag); wiping the table itself used
    -- [[to pull `pending` out from under the pump coroutine on its next resume
    -- [[(a `#nil` error racing an unload that landed mid-gate).]]
    self._overlayQueueRunning = false
end

-- [[Wait for the window's construction to go quiet, then destroy the tree.
-- [[Quiet is the same signal the startup reveal watches: two consecutive
-- [[frames with no thread suspended at a checkpoint and no pacing activity.
-- [[A superseded script's constructors resume into a window whose tree is
-- [[still whole, finish what they were building, and only then does the tree
-- [[go — anything they add after the destruction is detached by
-- [[`Window:Create` instead, so nothing here can crash them.]]
function Window:_destroyWhenConstructionQuiet()
    task.spawn(function()
        local stableFrames = 0
        while stableFrames < 2 and not self._treeDestroyed do
            local revision = self._constructionRevision
            task.wait()
            if (self._constructionBusy or 0) == 0 and revision == self._constructionRevision then
                stableFrames += 1
            else
                stableFrames = 0
            end
        end
        if not self._treeDestroyed then
            self:_destroyTree()
        end
    end)
end

function Window:Unload()
    if self._keybindCapture then self._keybindCapture:CancelCapture() end
    if self.unloaded then
        -- [[A repeat unload (hosts often end with one) has only the detached
        -- [[graveyard of a superseded script's tail construction left to
        -- [[clear; the tree itself is either already destroyed or already
        -- [[promised to the quiet-waiter above.]]
        if self._constructionGraveyard then
            self._constructionGraveyard:Destroy()
            self._constructionGraveyard = nil
        end
        return
    end
    -- Do not lose the final edit if the window closes inside the save debounce.
    if self._saveScheduled and self.configuration.autoSave and not self._loading then
        self._saveScheduled = false
        pcall(self.Save, self)
    end
    -- [[Release any open description before the screen GUI goes: the panel
    -- [[lives under it, and `tooltip.hideFor` bookkeeping should not outlive
    -- [[the window it belongs to. `unloaded` is raised first so the tooltip
    -- [[hides the panel outright instead of starting a fade whose instances
    -- [[are destroyed under it.]] 
    self.unloaded = true
    tooltip.hide(self)
    -- [[Stop the entrance queue with the window: an overlay that had not taken
    -- [[its turn yet has no layer to be built into any more, and the pump must
    -- [[not wake up on a window whose instances are about to be destroyed.]]
    overlayQueue.close(self)
    -- [[Vanish from the screen at once, even when the tree's destruction has
    -- [[to wait for an in-flight construction: the anti-duplicate guard must
    -- [[never show two windows, and a superseded script's constructors keep
    -- [[running against the tree underneath for as long as they need.]]
    if self.screenGui then
        self.screenGui.Parent = nil
    end
    if (self._constructionBusy or 0) > 0 then
        -- [[A constructor thread is suspended at a pacing checkpoint right
        -- [[now; destroying the tree would pull its half-built element out
        -- [[from under it the moment it resumes ("Window unloaded during
        -- [[construction"). Defer the destruction until that construction
        -- [[has gone quiet.]]
        self:_destroyWhenConstructionQuiet()
    else
        self:_destroyTree()
    end
end
