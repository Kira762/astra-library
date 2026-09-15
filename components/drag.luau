local Drag = {}
Drag.__index = Drag
Drag.__type = "Drag"

local utilities = script.Parent.Parent.utilities

local state = require(utilities.Parent.core.state)
local constants = require(utilities.constants)
local motion = require(utilities.motion)

function Drag.new(window, props)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Drag)

    self.drag = self.window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(150, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, self.window.size.Y.Offset / 2 + 15),
        ZIndex = constants.zIndex.drag,
        Visible = false,
        Parent = self.window.screenGui,
    })

    self.dragCosmetic = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
        ZIndex = constants.zIndex.drag,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 4),
        Parent = self.drag,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),
        Parent = self.dragCosmetic,
    })

    self.window:CreateGlow(self.dragCosmetic, Color3.fromRGB(255, 255, 255), 10, 0.5)

    self.dragInteract = self.window:Create("TextButton", {
        Active = true,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = constants.zIndex.drag,
        Parent = self.drag,
    })

    local isDragging = false
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
        local dragPos = UDim2.fromOffset(x, y + (self.window.main.Size.Y.Offset / 2 + 15))
        return mainPos, dragPos
    end

    self.window:Connect(self.drag.MouseEnter, function()
        if not isDragging and not self.window.hidden then
            motion.tween(self.dragCosmetic, { BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4) }, "fast")
        end
    end)

    self.window:Connect(self.drag.MouseLeave, function()
        if not isDragging and not self.window.hidden then
            motion.tween(self.dragCosmetic, { BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4) }, "fast")
        end
    end)

    local function endDrag()
        if not isDragging then
            return
        end
        isDragging = false

        if self._dragConnection then
            self.window:Disconnect(self._dragConnection)
            self._dragConnection = nil
        end

        if not self.window:_canDragCapsule() then
            return
        end

        motion.tween(self.dragCosmetic, { Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7 }, "settle")

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

            isDragging = true

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
                motion.tween(self.dragCosmetic, { Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0 }, "fast")
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
        if not isDragging then
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

return Drag
