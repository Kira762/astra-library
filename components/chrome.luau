local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local motion = require(utilities.motion)
local fs = require(utilities.filesystem)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)

local chrome = {}

local dragThreshold = 5

function chrome.buildCollapsedFace(window)
    local iconOnly = window.showIconOnly

    window.collapsedIcon = window:Create("ImageLabel", {
        Name = "CollapsedIcon",
        Visible = false,
        AnchorPoint = if iconOnly then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
        Position = if iconOnly then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 16, 0.5, 0),
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
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
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
        Size = UDim2.new(1, 0, 0, 16),
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
        Size = UDim2.new(1, 0, 0, 14),
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
            hasMoved = true
            cleanupDrag()
            return
        end
        hasMoved = true

        local newPos = mousePos + dragOffset + getGuiInset()
        window.main.Position = UDim2.fromOffset(newPos.X, newPos.Y)
    end

    window:Connect(window.collapsedInteract.InputBegan, function(input, gameProcessed)
        if gameProcessed or not window.hidden or window.animating then
            return
        end
        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

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
            return
        end

        haptic.click()
        window:ToggleHide()
    end)

    window:Connect(inputService.WindowFocusReleased, function()
        cleanupDrag()
    end)
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
