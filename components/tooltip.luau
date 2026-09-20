-- Programmatic floating descriptions (Window:ShowTooltip / HideTooltip).
-- Functional-element info badges and their gesture bindings were removed.
-- State remains window-local and text is resolved before measurement.

local tooltip = {}

local coreState = require(script.Parent.Parent.core.state)

local motion = require(script.Parent.Parent.utilities.motion)
local locale = require(script.Parent.Parent.utilities.locale)
local functions = require(script.Parent.Parent.functions)

local minWidth = 80
local maxWidth = 240
local padX = 8
local padY = 5
local fontSize = 12
local lineHeight = 15
local gap = 6
local edge = 8
local zIndex = 500

-- [[RichText hosts: measure the words, not the markup.]] 
local function plain(text: string): string
    return (text:gsub("<[^>]+>", ""))
end

-- [[Resolve a locale token or a plain string into the text to draw. Anything
-- [[else is drawn by its string form, so an element that stored `info` as a
-- [[number still gets a description instead of silence.]] 
local function resolve(text: unknown): string?
    if locale.isToken(text) then
        return locale.resolve(locale.sourceOf(text))
    end
    if text == nil or text == "" then
        return nil
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    return locale.resolve(text)
end

-- [[The viewport the panel positions itself in, with the screen GUI as the
-- [[fallback for hosts that have no camera (the test harnesses run without
-- [[one) and a desktop-sized guess as the last resort.]] 
local function viewport(window): (number, number)
    local camera = coreState.workspace and coreState.workspace.CurrentCamera
    local size = camera and camera.ViewportSize
    if size and size.X and size.X > 0 and size.Y and size.Y > 0 then
        return size.X, size.Y
    end
    local guiSize = window.screenGui and window.screenGui.AbsoluteSize
    if guiSize and guiSize.X and guiSize.X > 0 and guiSize.Y and guiSize.Y > 0 then
        return guiSize.X, guiSize.Y
    end
    return 1920, 1080
end

-- [[The panel's parent is the screen GUI; when that GUI does not ignore the
-- [[top inset its own origin sits below the viewport's, so the screen-space
-- [[position has to drop that inset back out.]] 
local function insetY(window): number
    local gui = window.screenGui
    if gui and gui.IgnoreGuiInset == false then
        return 36
    end
    return 0
end

function tooltip.ensure(window)
    if window.elementTooltip then
        return window.elementTooltip
    end

    local tip = window:Create("Frame", {
        Name = "ElementTooltip",
        Size = UDim2.fromOffset(120, 26),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = zIndex,
        Parent = window.screenGui,
    }, { BackgroundColor3 = "PopupSurface" })

    window.elementTooltip = tip

    window:Create("UICorner", {
        CornerRadius = UDim.new(0, 0),
        Parent = tip,
    })

    local stroke = window:Create("UIStroke", {
        Transparency = 1,
        Parent = tip,
    }, { Color = "ElementStroke" })
    window.elementTooltipStroke = stroke

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, padX),
        PaddingRight = UDim.new(0, padX),
        PaddingTop = UDim.new(0, padY),
        PaddingBottom = UDim.new(0, padY),
        Parent = tip,
    })

    local label = window:Create("TextLabel", {
        Name = "Label",
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = fontSize,
        TextWrapped = true,
        RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        ZIndex = zIndex + 1,
        Parent = tip,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    window.elementTooltipLabel = label

    return tip
end

-- [[Whether the panel is on screen, optionally narrowed to one anchor.]] 
function tooltip.isOpen(window, anchor: any?): boolean
    local tip = window.elementTooltip
    if not tip or tip.Visible ~= true then
        return false
    end
    return anchor == nil or window._tooltipAnchor == anchor
end

-- [[The badge whose description is open, or nil.]] 
function tooltip.anchorOf(window): any
    return window._tooltipAnchor
end

function tooltip.show(window, anchor: any, text: unknown, pinned: boolean?, owner: any?)
    if not anchor or not anchor.Parent then
        return
    end

    local resolved = resolve(text)
    if not resolved or resolved == "" then
        return
    end

    local tip = tooltip.ensure(window)
    local label = window.elementTooltipLabel
    local stroke = window.elementTooltipStroke
    if not tip or not label then
        return
    end

    -- [[The guard above may have switched this panel to another anchor; a
    -- [[stale hide token would otherwise close the newer description.]] 
    window._tooltipHideToken = (window._tooltipHideToken or 0) + 1
    window._tooltipAnchor = anchor
    window._tooltipPinned = pinned == true
    window._tooltipOwner = owner

    label.Text = resolved

    local font = window.theme and window.theme.Font
    local measured = plain(resolved)
    local rawWidth = if font then functions.textWidth(font, fontSize, measured) else 0
    local contentWidth = math.clamp(rawWidth, minWidth, maxWidth)
    local totalWidth = contentWidth + padX * 2
    local totalHeight
    if rawWidth > maxWidth and font then
        local measuredHeight = functions.textHeight(font, fontSize, measured, maxWidth)
        totalHeight = math.max(26, measuredHeight + padY * 2)
    else
        totalHeight = math.max(26, lineHeight + padY * 2)
    end

    tip.Size = UDim2.fromOffset(totalWidth, totalHeight)

    local anchorPos = anchor.AbsolutePosition
    local anchorSize = anchor.AbsoluteSize
    local screenW, screenH = viewport(window)
    local inset = insetY(window)

    local idealX = anchorPos.X + anchorSize.X / 2 - totalWidth / 2
    local idealY = anchorPos.Y - totalHeight - gap
    if idealY < edge then
        -- [[No room above: the description flips under the badge.]] 
        idealY = anchorPos.Y + anchorSize.Y + gap
    end

    local clampedX = math.clamp(idealX, edge, math.max(edge, screenW - totalWidth - edge))
    local clampedY = math.clamp(idealY - inset, edge, math.max(edge, screenH - totalHeight - edge))

    tip.Position = UDim2.fromOffset(clampedX, clampedY)
    tip.Visible = true

    motion.tween(tip, { BackgroundTransparency = 0 }, hoverTween)
    if stroke then
        motion.tween(stroke, { Transparency = 0.25 }, hoverTween)
    end
    motion.tween(label, { TextTransparency = 0 }, hoverTween)
end

function tooltip.hide(window)
    local tip = window.elementTooltip

    -- [[State first: a hide that arrives while the panel is still fading must
    -- [[still release the anchor, or the next tap would "close" a description
    -- [[it thinks is open. The close token is bumped even when nothing was on
    -- [[screen: a press that was waiting out its hold is cancelled by any
    -- [[close, so a window hiding (or a tab switching) mid-press cannot leave
    -- [[a description appearing behind its back.]] 
    window._tooltipCloseToken = (window._tooltipCloseToken or 0) + 1
    window._tooltipAnchor = nil
    window._tooltipPinned = nil
    window._tooltipOwner = nil

    if not tip or not tip.Visible then
        return
    end

    -- [[An unload is already destroying the screen GUI this panel lives in, so
    -- [[there is no fade to run: the panel stops being drawn now, while it can
    -- [[still be touched. A fade started here would either be interrupted and
    -- [[leave `Visible` true on a dead GUI, or reach a panel that no longer
    -- [[exists.]] 
    if window.unloaded then
        window._tooltipHideToken = (window._tooltipHideToken or 0) + 1
        tip.Visible = false
        tip.BackgroundTransparency = 1
        local goneStroke = window.elementTooltipStroke
        if goneStroke then
            goneStroke.Transparency = 1
        end
        local goneLabel = window.elementTooltipLabel
        if goneLabel then
            goneLabel.TextTransparency = 1
        end
        return
    end

    local stroke = window.elementTooltipStroke
    local label = window.elementTooltipLabel

    local token = (window._tooltipHideToken or 0) + 1
    window._tooltipHideToken = token

    motion.tween(tip, { BackgroundTransparency = 1 }, hoverTween)
    if stroke then
        motion.tween(stroke, { Transparency = 1 }, hoverTween)
    end
    if label then
        motion.tween(label, { TextTransparency = 1 }, hoverTween)
    end

    -- [[The fade owns the last word: the panel only stops being drawn once it
    -- [[is fully transparent, and only if nothing has re-opened it since. An
    -- [[unload during the fade is the one path that does not come back here -
    -- [[it has already hidden the panel outright.]] 
    task.delay(0.2, function()
        if window.unloaded then
            return
        end
        if window._tooltipHideToken == token and tip.BackgroundTransparency >= 0.95 then
            tip.Visible = false
        end
    end)
end

-- [[Close the description when it belongs to one element (the element was
-- [[hidden, the tab changed, the text was cleared).]] 
function tooltip.hideFor(window, owner: any)
    if owner ~= nil and window._tooltipOwner ~= owner then
        return
    end
    tooltip.hide(window)
end

-- [[Tap semantics, in the order a player experiences them:
-- [[  * nothing open (touch, or the first desktop tap) -> open, pinned,
-- [[  * a hover preview open on this badge -> pin it, so the tap the player
-- [[    just made does not throw away what they were reading,
-- [[  * a pinned description open on this badge -> close it.
-- [[Returns whether a description is open afterwards.]] 
function tooltip.toggle(window, anchor: any, text: unknown, owner: any?)
    if tooltip.isOpen(window, anchor) and window._tooltipPinned then
        tooltip.hide(window)
        return false
    end
    tooltip.show(window, anchor, text, true, owner)
    return true
end

return tooltip
