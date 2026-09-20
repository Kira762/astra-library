local utilities = script.Parent.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local tooltip = require(script.Parent.Parent.tooltip)

local shared = require(script.Parent.constants)
local dragHandleGap = shared.dragHandleGap

local Window = require(script.Parent.class)

function Window:_bindKeybind()
    self:Connect(state.userInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then
            return
        end
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
    local hasMoved = false
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
            -- [[The frame's own size is used: mid-minimise it is shorter]]
            -- [[than window.size.]]
            local halfLeft = mainSize.X / 2
            local halfRight = halfLeft
            local halfTop = mainSize.Y / 2
            x = math.clamp(x, halfLeft + margin, math.max(halfLeft + margin, screenSize.X - halfRight - margin))
            y = math.clamp(y, halfTop + margin, math.max(halfTop + margin, screenSize.Y - halfTop - margin))
        end

        return UDim2.fromOffset(x, y)
    end

    local function endDrag()
        isDragging = false
        if hasMoved then
            -- [[The move is over: the handle drops back to its resting look
            -- [[and stays where it is — that faint pill under the window is
            -- [[the affordance the next drag starts from.
            hasMoved = false
            if self.drag then
                self.drag:setMoving(false)
            end
        end
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

        if not hasMoved then
            -- [[The pointer has left the threshold, so this is a move and not
            -- [[a click: bring the handle out for the length of it. Nothing is
            -- [[pointing at the handle (the gesture started on the topbar), so
            -- [[this is the one moment it has to show itself — the pill
            -- [[brightens here and settles back when the move ends.
            hasMoved = true
            tooltip.hide(self)
            if self.drag then
                self.drag:setMoving(true)
            end
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
                mainPos.Y.Offset + (self.main.Size.Y.Offset / 2 + dragHandleGap)
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
