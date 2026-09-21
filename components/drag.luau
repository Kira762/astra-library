local Drag = {}
Drag.__index = Drag
Drag.__type = "Drag"

local utilities = script.Parent.Parent.utilities

local state = require(utilities.Parent.core.state)
local constants = require(utilities.constants)
local motion = require(utilities.motion)

-- [[The handle's look, written once. The window's settle paths and this
-- [[module's own hover/drag states all land on these four specs, so the pill
-- [[can never be left at a size or a transparency nothing owns:
--
-- [[  * `hover`  — the pointer is on the handle;
-- [[  * `grab`   — the handle is what is being dragged (the window follows);
-- [[  * `idle`   — the faint hint it rests at once the window has been moved:
-- [[               48px wide, 3px tall, centred under the window. This is the
-- [[               pill in the reference screenshot — it shows up on a move
-- [[               and stays as a "you can grab me" affordance until the
-- [[               window leaves the screen;
-- [[  * `parked` — off the screen: the pill shrinks to nothing instead of
-- [[               being left mid-hover for the next entrance to inherit.
local handleThickness = 3
local handleHover = { Size = UDim2.fromOffset(64, handleThickness), BackgroundTransparency = 0.5 }
local handleGrab = { Size = UDim2.fromOffset(56, handleThickness), BackgroundTransparency = 0 }
local handleIdle = { Size = UDim2.fromOffset(48, handleThickness), BackgroundTransparency = 0.7 }
local handleParked = { Size = UDim2.fromOffset(0, handleThickness), BackgroundTransparency = 1 }

-- [[Half the thickness, so the pill the states above describe actually reads
-- [[as one: the width tweens 0 -> 48 -> 56 -> 64 while the height never
-- [[moves, and a square 3px bar looks like a stray line under the window.]]
local handleRadius = UDim.new(0, handleThickness / 2)

-- [[How long the pill takes to shrink away before the hitbox that carries it
-- [[may be switched off without cutting the fade short: the `fast` spec the
-- [[fade itself rides (0.16s) plus a frame.
local handleFadeTime = 0.18

-- [[The handoff between the window and this module, named so the two ends
-- [[cannot drift: `Window:_syncDragBar` and every position this file writes
-- [[place the handle's centre this far below the window's bottom edge.
local handleGap = 22

-- [[Where the pill comes to rest: the hover look when the pointer is already
-- [[on the handle, the idle hint otherwise. Both the end of the handle's own
-- [[drag and the end of a topbar move settle through here.
local function restingLook(self)
    return if self.hovering then handleHover else handleIdle
end

function Drag.new(window, props)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Drag)

    -- Small centered detached handle below window, not overlapping
    -- Gap = 22px from window bottom edge to handle center
    --
    -- [[The hitbox is deliberately wider than the pill it carries (80px vs the
    -- [[48px idle pill): a 3px-tall white line is a hard thing to point at, so
    -- [[the region that answers the pointer is generous and the pill grows
    -- [[into it.
    --
    -- [[It starts off. A hidden parent takes MouseEnter/MouseLeave with it, so
    -- [[the window owns the moment the handle becomes reachable: `Drag:enable`
    -- [[from each of its settle paths (_firstShow, _quickRestore, the minimise
    -- [[settle), `Drag:disable` / `Drag:fadeOut` from Hide, Close and the fold.
    -- [[Without that the reveal below could never fire in the expanded window —
    -- [[the handle was left off by ten writes and turned on by one.
    self.drag = self.window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(80, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, self.window.size.Y.Offset / 2 + handleGap),
        ZIndex = constants.zIndex.drag,
        Visible = false,
        Parent = self.window.screenGui,
    })

    self.dragCosmetic = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = constants.zIndex.drag,
        BackgroundTransparency = handleParked.BackgroundTransparency,
        Size = handleParked.Size,
        Parent = self.drag,
    })

    self.window:Create("UICorner", {
        CornerRadius = handleRadius,
        Parent = self.dragCosmetic,
    })

    self.window:CreateGlow(self.dragCosmetic, Color3.fromRGB(255, 255, 255), 8, 0.6)

    self.dragInteract = self.window:Create("TextButton", {
        Active = true,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = constants.zIndex.drag,
        Parent = self.drag,
    })

    -- [[Handle state. `dragging` is the handle itself being dragged (the
    -- [[window follows it), `moving` the window being moved by its topbar
    -- [[(the pill brightens for that, and the hover reveal must not fight it)
    -- [[and `hovering` the pointer resting on the handle — what `restingLook`
    -- [[reads when a move ends.
    self.dragging = false
    self.moving = false
    self.hovering = false

    -- [[Bumped by every transition that takes the handle over. A `fadeOut`
    -- [[waiting to switch the hitbox off stands down when a later entrance
    -- [[(or a move) has claimed the handle in the meantime.
    self._handleToken = 0

    local dragOffset = nil

    local guiInset = Vector2.zero
    local screenGui = self.window.screenGui

    if screenGui and screenGui.IgnoreGuiInset then
        guiInset = state.guiService:GetGuiInset()
    end

    local function getMousePosition()
        local mouseLocation = state.userInputService and state.userInputService:GetMouseLocation()
            or Vector2.new(0, 0)
        local offset = dragOffset or Vector2.new(0, 0)
        local insetVal = guiInset or Vector2.new(0, 0)

        return mouseLocation + offset + insetVal
    end

    local function constrainPosition()
        local position = getMousePosition()
        local x, y = position.X, position.Y

        if self.window.settings and self.window.settings.keepOnScreen then
            local mainSize = self.window.main.AbsoluteSize
            local screenSize = self.window.screenGui.AbsoluteSize
            local margin = 8
            local halfWidth, halfHeight = mainSize.X / 2, mainSize.Y / 2
            x = math.clamp(x, halfWidth + margin, math.max(halfWidth + margin, screenSize.X - halfWidth - margin))
            y = math.clamp(y, halfHeight + margin, math.max(halfHeight + margin, screenSize.Y - halfHeight - margin))
        end

        local mainPos = UDim2.fromOffset(x, y)
        local dragPos = UDim2.fromOffset(x, y + (self.window.main.Size.Y.Offset / 2 + handleGap))
        return mainPos, dragPos
    end

    -- [[Hover reveal. `hovering` is recorded even while a move is running —
    -- [[it is where the pill has to settle when that move ends — but the tween
    -- [[stands down then: a window being dragged under the pointer would
    -- [[otherwise flicker the pill between the hover and idle looks as its own
    -- [[movement sweeps the handle past the cursor.
    self.window:Connect(self.drag.MouseEnter, function()
        self.hovering = true
        if self.dragging or self.moving or self.window.hidden then
            return
        end
        motion.tween(self.dragCosmetic, handleHover, "fast")
    end)

    self.window:Connect(self.drag.MouseLeave, function()
        self.hovering = false
        if self.dragging or self.moving or self.window.hidden then
            return
        end
        motion.tween(self.dragCosmetic, handleIdle, "fast")
    end)

    local function endDrag()
        if not self.dragging then
            return
        end
        self.dragging = false

        if self._dragConnection then
            self.window:Disconnect(self._dragConnection)
            self._dragConnection = nil
        end

        if not self.window:_canDragCapsule() then
            return
        end

        motion.tween(self.dragCosmetic, restingLook(self), "settle")

        -- [[The capsule settling back after a drag is the spring's moment:
        -- a short overshoot that reads as weight, not lag.]]
        local mainPos, dragPos = constrainPosition()
        motion.tween(self.window.main, { Position = mainPos }, "spring")
        motion.tween(self.drag, { Position = dragPos }, "spring")
    end

    local lerpSmoothing = 1e-7
    local smoothVelocity = 1e-60
    local renderStepHandler

    self.window:Connect(self.dragInteract.InputBegan, function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if not self.window:_canDragCapsule() then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            if not self.window:_interactive() then
                return
            end

            self.dragging = true

            if self._dragConnection then
                self.window:Disconnect(self._dragConnection)
                self._dragConnection = nil
            end

            if screenGui and screenGui.IgnoreGuiInset then
                guiInset = state.guiService:GetGuiInset()
            end

            dragOffset = self.window.main.AbsolutePosition
                + self.window.main.AbsoluteSize * self.window.main.AnchorPoint
                - state.userInputService:GetMouseLocation()
            if not self.window.hidden then
                motion.tween(self.dragCosmetic, handleGrab, "fast")
            end

            self._dragConnection = self.window:Connect(state.runService.RenderStepped, renderStepHandler)
        end
    end)

    self.window:Connect(state.userInputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            endDrag()
        end
    end)

    self.window:Connect(state.userInputService.WindowFocusReleased, endDrag)

    renderStepHandler = function(dt)
        if not self.dragging then
            if self._dragConnection then
                self.window:Disconnect(self._dragConnection)
                self._dragConnection = nil
            end
            return
        end

        if self.window.unloaded or not self.window:_canDragCapsule() then
            endDrag()
            return
        end

        local mainPos, dragPos = constrainPosition()

        self.window.main.Position = self.window.main.Position:Lerp(mainPos, 1 - lerpSmoothing ^ dt)
        self.drag.Position = self.drag.Position:Lerp(dragPos, 1 - smoothVelocity ^ dt)
    end

    return self
end

-- [[The handle's lifecycle, driven by the window — the only thing that knows
-- [[whether the window is on screen, settled, or on its way out.
--
-- [[`enable` is called from every settle path (Window:_firstShow,
-- [[_quickRestore, the minimise settle): the hitbox turns on so the pointer
-- [[can find the handle, and the pill keeps whatever look its own states left
-- [[it at — a handle that has just helped move the window stays faintly
-- [[visible (that is the reveal the user is looking for), while one that has
-- [[never been touched waits unseen instead of announcing itself under every
-- [[window that opens.
function Drag:enable()
    self._handleToken += 1
    self.drag.Visible = true
end

-- [[Off the screen at once — a close, or the entrance a Show starts with: the
-- [[hitbox goes and the pill is parked at nothing, so the next entrance starts
-- [[from an unseen handle rather than at whatever look the last hover left
-- [[behind.
function Drag:disable()
    self._handleToken += 1
    self.drag.Visible = false
    motion.tween(self.dragCosmetic, handleParked, "fast")
end

-- [[Off the screen with the fade read first, for the exits that fold or fade
-- [[the window away: the pill shrinks away now and the hitbox follows once the
-- [[fade is over, so the handle never cuts out from under the pointer. The
-- [[token makes a pending hide stand down when a later entrance (or a move)
-- [[has claimed the handle in the meantime.
function Drag:fadeOut(spec: string?)
    self._handleToken += 1
    local token = self._handleToken
    local window = self.window

    motion.tween(self.dragCosmetic, handleParked, spec or "fast")
    task.delay(handleFadeTime, function()
        if token ~= self._handleToken or window.unloaded then
            return
        end
        self.drag.Visible = false
    end)
end

-- [[The window is being moved by its topbar (or by a drag started while it is
-- [[minimised): the pill brightens for the length of the move and settles back
-- [[to its resting look when the move ends. This is the one moment the handle
-- [[has to show itself without being pointed at — the drag began on the
-- [[topbar, so no MouseEnter is coming. It also re-arms the hitbox, so a
-- [[handle that some earlier exit switched off cannot swallow the move.
function Drag:setMoving(active: boolean)
    active = active == true
    if self.moving == active then
        return
    end
    self.moving = active

    if active then
        self._handleToken += 1
        self.drag.Visible = true
        motion.tween(self.dragCosmetic, handleHover, "fast")
        return
    end

    if self.window.hidden then
        -- [[The window left the screen mid-move (a hide, a close): the pill
        -- [[belongs to that exit now and stays parked.
        return
    end
    motion.tween(self.dragCosmetic, restingLook(self), "settle")
end

return Drag
