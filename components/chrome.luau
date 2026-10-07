local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local motion = require(utilities.motion)
local fs = require(utilities.filesystem)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)

local shared = require(script.Parent.window.constants)
local collapsedWideSize = shared.collapsedWideSize
local collapsedIconOnlySize = shared.collapsedIconOnlySize

local chrome = {}

local dragThreshold = 5

-- The face's leading inset and the frame's trailing inset, as built below.
local faceIconInset = 16
local collapsedTextInset = 60

--[[
The label column: the wide capsule's own width minus the text frame's insets.
The labels are laid out at that fixed width rather than against the frame, so
the shrinking pill's edge cuts them off (see `chrome.morphCollapsedShape`)
instead of re-wrapping the words into a shape that is already leaving.
]]
local collapsedTextWidth = collapsedWideSize.X.Offset - collapsedTextInset

--[[
How long a tap stays half of a double tap. The single tap's restore waits it
out so a second tap can claim the gesture; long enough for a second touch,
short enough that a restore still reads as a direct answer to the press.
]]
local doubleTapWindow = 0.25

function chrome.buildCollapsedFace(window)
    local iconOnly = window.showIconOnly

    window.collapsedIcon = window:Create("ImageLabel", {
        Name = "CollapsedIcon",
        Visible = false,
        AnchorPoint = if iconOnly then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
        Position = if iconOnly then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, faceIconInset, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Image = window.showIcon,
        ZIndex = constants.zIndex.restoreContent,
        ImageTransparency = 1,
        Parent = window.main,
    }, { ImageColor3 = "TitlingColor" })

    -- PillCornerRadius drives tab pills and the collapsed capsule icon.
    window:Create("UICorner", {
        Parent = window.collapsedIcon,
    }, { CornerRadius = "PillCornerRadius" })

    local collapsedTextFrame = window:Create("Frame", {
        Name = "CollapsedText",
        Visible = false,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -collapsedTextInset, 0, 32),
        BackgroundTransparency = 1,
        --[[
        The frame is the capsule's text window: its width follows the pill's,
        so the labels — laid out at `collapsedTextWidth` and never re-flowed
        — are revealed and cut off at the pill's own edge when the shape
        changes (see `chrome.morphCollapsedShape`).
        ]]
        ClipsDescendants = true,
        ZIndex = constants.zIndex.restoreContent,
        Parent = window.main,
    })

    window.collapsedTextFrame = collapsedTextFrame

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = collapsedTextFrame,
    })

    window.collapsedTitle = window:Create("TextLabel", {
        Name = "Title",
        Text = window.showName,
        Size = UDim2.new(0, collapsedTextWidth, 0, 16),
        BackgroundTransparency = 1,
        FontFace = state.brandFont(Enum.FontWeight.Medium),
        RichText = true,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = constants.zIndex.restoreContent,
        TextTransparency = 1,
        Parent = collapsedTextFrame,
    }, { TextColor3 = "TitlingColor" })

    window.collapsedSubtitle = window:Create("TextLabel", {
        Name = "Subtitle",
        Text = locale.t("Tap to show"),
        Size = UDim2.new(0, collapsedTextWidth, 0, 14),
        BackgroundTransparency = 1,
        FontFace = state.brandFont(Enum.FontWeight.Medium),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.restoreContent,
        TextTransparency = 1,
        Parent = collapsedTextFrame,
    }, { TextColor3 = "TitlingColor" })

    window.collapsedInteract = window:Create("TextButton", {
        Name = "CollapsedInteract",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        Visible = false,
        ZIndex = constants.zIndex.restoreInteract,
        Parent = window.main,
    })

    chrome.bindCollapsedDrag(window)
end

function chrome.bindCollapsedDrag(window)
    local inputService = state.userInputService
    local isDragging, hasMoved = false, false
    local dragOffset, startMousePos = Vector2.zero, Vector2.zero
    local renderConnection

    local function getGuiInset()
        if window.screenGui and window.screenGui.IgnoreGuiInset then
            return state.guiService:GetGuiInset()
        end
        return Vector2.zero
    end

    local function cleanupDrag()
        isDragging = false
        if renderConnection then
            window:Disconnect(renderConnection)
            renderConnection = nil
        end
    end

    local function updateDrag()
        if not isDragging then
            cleanupDrag()
            return
        end
        if window.unloaded or not window.hidden or window.animating then
            cleanupDrag()
            return
        end

        local mousePos = inputService:GetMouseLocation()
        if not hasMoved and (mousePos - startMousePos).Magnitude < dragThreshold then
            return
        end
        if not (window.settings and window.settings.dragMinimisedBar == true) then
            --[[
            Travel is a move, not a tap, even when the capsule is not
            draggable: the gesture pair for a double tap is spent, and the
            release below is ignored because the drag is already cleaned up.
            ]]
            hasMoved = true
            window._lastCapsuleTap = nil
            cleanupDrag()
            return
        end
        hasMoved = true

        local newPos = mousePos + dragOffset + getGuiInset()
        window.main.Position = UDim2.fromOffset(newPos.X, newPos.Y)
    end

    --[[
    A single tap restores the window, but only after `doubleTapWindow`: a
    second tap within it claims the gesture and changes the capsule's shape
    instead. The parked restore is dropped by anything that makes the tap
    mean something else — a press that turns into a drag, a window that
    shows itself in the meantime, or the marker already answered by another
    tap — so a delay never turns into a stale restore.
    ]]
    local function parkRestore()
        local token = {}
        window._capsuleTapToken = token
        task.delay(doubleTapWindow, function()
            if window.unloaded or window._capsuleTapToken ~= token then
                return
            end
            window._capsuleTapToken = nil
            window._lastCapsuleTap = nil
            if window.hidden and not window.animating then
                window:ToggleHide()
            end
        end)
    end

    window:Connect(window.collapsedInteract.InputBegan, function(input, gameProcessed)
        if gameProcessed or not window.hidden or window.animating then
            return
        end
        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        -- The press claims the gesture: drop a restore the first tap parked.
        window._capsuleTapToken = nil

        isDragging, hasMoved = true, false
        if renderConnection then
            window:Disconnect(renderConnection)
            renderConnection = nil
        end
        renderConnection = window:Connect(state.runService.RenderStepped, updateDrag)
        startMousePos = inputService:GetMouseLocation()
        dragOffset = window.main.AbsolutePosition + window.main.AbsoluteSize * window.main.AnchorPoint - startMousePos
    end)

    window:Connect(inputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end
        if not isDragging then
            return
        end
        cleanupDrag()

        if hasMoved then
            window._collapsedPosition = window.main.Position
            window._lastCapsuleTap = nil
            return
        end

        haptic.click()
        local now = os.clock()
        local lastTap = window._lastCapsuleTap
        if lastTap and now - lastTap <= doubleTapWindow then
            window._lastCapsuleTap = nil
            window._capsuleTapToken = nil
            haptic.notify()
            chrome.morphCollapsedShape(window)
            return
        end

        window._lastCapsuleTap = now
        parkRestore()
    end)

    window:Connect(inputService.WindowFocusReleased, function()
        cleanupDrag()
    end)
end

--[[
The capsule changing shape: double-tapping the pill folds it down to the
icon-only circle, and double-tapping the circle opens it back into the pill.

The geometry moves as one: the shell tweens to the other shape's size while
its centre shifts by half that change, which pins the pill's left edge and
its vertical centre for the whole movement — so the shape leaves and arrives
right to left, the far edge travelling in to meet the icon. The face rides
the same movement: the icon glides between its 16px inset and the circle's
centre, and the text frame narrows with the pill, cutting the labels off at
the pill's own edge instead of fading them.
]]
function chrome.morphCollapsedShape(window)
    if window.animating or window.unloaded or not window.hidden or not window._collapsedShown then
        return false
    end

    local iconOnly = not window.showIconOnly
    local size = if iconOnly then collapsedIconOnlySize else collapsedWideSize
    --[[
    Both endpoints of the move were clamped when the pill was dragged, and the
    widening one is the rectangle the pill already had, so no re-clamp is
    needed: nothing can end off screen that was not already there.
    ]]
    local delta = (size.X.Offset - window.main.Size.X.Offset) / 2
    local position = window.main.Position

    window.showIconOnly = iconOnly
    window._capsuleMorphId = (window._capsuleMorphId or 0) + 1
    local morphId = window._capsuleMorphId
    window.animating = true

    motion.tween(window.collapsedIcon, {
        AnchorPoint = if iconOnly then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
        Position = if iconOnly then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, faceIconInset, 0.5, 0),
    }, "glide")

    if not iconOnly then
        --[[
        The widening pill reveals the labels as it travels, so they have to be
        there to be revealed — a capsule that started icon-only has never had
        them painted in.
        ]]
        window.collapsedTextFrame.Visible = true
        motion.tween(window.collapsedTitle, { TextTransparency = 0 }, "glide")
        motion.tween(window.collapsedSubtitle, { TextTransparency = 0.5 }, "glide")
    end

    local function settle()
        if window.unloaded or window._capsuleMorphId ~= morphId then
            return
        end
        window.animating = false
        -- The capsule remembers the place it was left in, in either shape.
        window._collapsedPosition = window.main.Position
        if iconOnly then
            window.collapsedTextFrame.Visible = false
        end
    end

    local moved = motion.tween(window.main, {
        Size = size,
        Position = UDim2.new(position.X.Scale, position.X.Offset + delta, position.Y.Scale, position.Y.Offset),
    }, "glide", settle)

    if not moved then
        settle()
    end
    return true
end

function chrome.isNewUser()
    local player = state.localPlayer
    if not player then
        return false
    end

    if typeof(fs.isfile) ~= "function" or typeof(fs.writefile) ~= "function" then
        return true
    end

    local path = state.fileSystemManager:getPath("profile.txt")
    local userId = tostring(player.UserId)
    local isNew = true

    pcall(function()
        if fs.isfile(path) then
            isNew = fs.readfile(path) ~= userId
        end
    end)

    pcall(function()
        fs.writefile(path, userId)
    end)

    return isNew
end

--[[
The capsule's face (icon, title, subtitle) fades in with `spec` — a
motion-service spec name (the fold plays "settle"), so the collapse answers
the speed setting like everything else — or applies instantly when no spec
is given (the silent state-sync path).
]]
function chrome.setCollapsedShown(window, shown, spec)
    --[[
    Visibility is authoritative: never paint the restore face behind an open
    window or during its fold, even if an earlier fade is still running.
    ]]
    shown = shown and window.hidden and window._collapsedShown == true
    window.collapsedIcon.Visible = shown
    window.collapsedTextFrame.Visible = shown and not window.showIconOnly
    local targets = {
        [window.collapsedIcon] = { ImageTransparency = if shown then 0 else 1 },
    }

    if not window.showIconOnly then
        targets[window.collapsedTitle] = { TextTransparency = if shown then 0 else 1 }
        targets[window.collapsedSubtitle] = { TextTransparency = if shown then 0.5 else 1 }
    end

    for instance, properties in targets do
        if spec then
            motion.tween(instance, properties, spec)
        else
            for prop, value in properties do
                instance[prop] = value
            end
        end
    end
end

return chrome
