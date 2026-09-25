local utilities = script.Parent.Parent.Parent.utilities
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local log = require(utilities.log)
local motion = require(utilities.motion)
local persistence = require(utilities.persistence)
local state = require(utilities.Parent.core.state)
local tooltip = require(script.Parent.Parent.tooltip)

local themes = require(script.Parent.Parent.Parent.themes)
local firstColor = themes.firstColor

local shared = require(script.Parent.constants)
local lockScrimTransparency = shared.lockScrimTransparency
local lockedTextTransparency = shared.lockedTextTransparency

local Window = require(script.Parent.class)

function Window:_registerControl(element)
    if not element.flag or element.flag == "" or element.forgetState then
        return
    end

    local flag = element.flag
    if self.controls[flag] then
        local n = 2
        while self.controls[flag .. n] do
            n += 1
        end
        flag = flag .. n
    end

    element.flag = flag
    self.controls[flag] = element
    return flag
end

function Window:_restoreLate(element)
    if not self._loadedConfig or not element.flag or element.forgetState then
        return
    end

    local wasLoading = self._loading
    self._loading = true
    persistence.applyTo(element, self._loadedConfig[element.flag])
    self._loading = wasLoading
end

function Window:_persist(element)
    if not element.flag or element.forgetState or not self.configuration.autoSave or self._loading or self._saveScheduled then
        return
    end
    -- Default-on autosave must not write a whole file for every slider tick.
    self._saveScheduled = true
    task.delay(0.25, function()
        self._saveScheduled = false
        if not self.unloaded and self.configuration.autoSave and not self._loading then
            self:Save()
        end
    end)
end

function Window:_unregisterControl(element)
    if element.flag and self.controls[element.flag] == element then
        self.controls[element.flag] = nil
    end
end

function Window:_registerLockableElement(element)
    if not element or element._isLockable ~= true or element._lockSystemController then
        return false
    end

    self._lockableElements = self._lockableElements or {}
    self._lockableElementSet = self._lockableElementSet or {}
    self._lockableElementIds = self._lockableElementIds or {}
    if self._lockableElementSet[element] then
        return true
    end

    self._lockableElementSet[element] = true
    table.insert(self._lockableElements, element)
    self._lockableElementIds[element.elementId] = element

    -- Controls created after a mode change join the active cumulative tier.
    local mode = self._elementLockMode or 1
    self:_setElementLocked(element, (element.lockLevel or 5) <= mode, nil, "mode")
    return true
end

function Window:_unregisterLockableElement(element)
    if not element or not self._lockableElementSet or not self._lockableElementSet[element] then
        return false
    end

    self._lockableElementSet[element] = nil
    if self._lockableElementIds and self._lockableElementIds[element.elementId] == element then
        self._lockableElementIds[element.elementId] = nil
    end
    for index, registered in ipairs(self._lockableElements or {}) do
        if registered == element then
            table.remove(self._lockableElements, index)
            break
        end
    end
    return true
end

function Window:GetElementLockMode(): number
    return math.clamp(math.round(tonumber(self._elementLockMode) or 1), 1, 5)
end

--[[
The active tier is cumulative: an element assigned to level N stays locked
for every mode >= N. Mode 5 therefore locks every registered lockable
control. Manual locks are tracked separately and cannot be cleared by a
mode change (or use Unlock to bypass an active mode).
]]
function Window:SetElementLockMode(mode): number
    local nextMode = math.clamp(math.round(tonumber(mode) or self:GetElementLockMode()), 1, 5)
    self._elementLockMode = nextMode
    for _, element in ipairs(self._lockableElements or {}) do
        if element._isLockable == true then
            self:_setElementLocked(element, (element.lockLevel or 5) <= nextMode, nil, "mode")
        end
    end

    local picker = self._elementLockModePicker
    if picker and picker.mode ~= nextMode then
        picker:Set(nextMode, true)
    end
    return nextMode
end

--[[
`_restoreLate` restores a control that arrives after the configuration was
loaded. This is the case it cannot reach: a persisted value whose control
does not exist yet. The element-lock tier is exactly that, because its
control is the Settings → Controls picker and settings panels build lazily
on first open — so a saved Mode 5 had nothing to restore into at startup.
The page came up unlocked and only locked once the player opened that panel
or nudged the picker, which read as the tier not being saved at all. The
window therefore answers for the state it owns directly; a live control of
the same flag wins and restores through the normal path instead.
]]
function Window:_restoreUnowned(values)
    if typeof(values) ~= "table" or self.controls[shared.elementLockModeFlag] then
        return
    end
    local stored = tonumber(values[shared.elementLockModeFlag])
    if stored then
        self:SetElementLockMode(stored)
    end
end

--[[
The save-side mirror: a configuration written before the Settings panel was
ever opened still carries the active tier, so a saved config stays a
complete snapshot (and a host that drives the modes through
`SetElementLockMode` alone persists them too).
]]
function Window:_unownedConfigValues()
    if self.controls[shared.elementLockModeFlag] then
        return nil
    end
    return { [shared.elementLockModeFlag] = self:GetElementLockMode() }
end

function Window:_setElementLocked(element, locked, message, source)
    if not element or element.window ~= self or element._isLockable ~= true or element._lockSystemController then
        return false
    end

    source = source or "manual"
    locked = locked == true
    if source == "mode" then
        element._modeLocked = locked
    else
        element._manualLocked = locked
        element._manualLockReason = if locked and type(message) == "string" and message ~= "" then message else nil
    end

    local nextLocked = element._manualLocked == true or element._modeLocked == true
    local nextMessage = if element._manualLocked then element._manualLockReason else nil
    local wasLocked = element.locked == true
    if wasLocked == nextLocked and element._lockMessage == nextMessage then
        return false
    end

    element.locked = nextLocked
    element._lockMessage = nextMessage

    -- Stop only transient gestures. Values, selection, callbacks and layout
    -- are untouched; an expanded control stays expanded under its scrim.
    if nextLocked and not wasLocked then
        if element.CancelCapture then
            element:CancelCapture()
        end
        if element.CancelEditing then
            element:CancelEditing()
        end
        if element.dragging and element._endDrag then
            element:_endDrag()
        end
    end
    if element.SetInteractionLocked then
        element:SetInteractionLocked(nextLocked)
    end

    local lockSurface = element.lockSurface or element.main
    if not lockSurface then
        return true
    end
    if not element.lockScrim then
        self:_buildLockScrim(element)
    end

    -- The scrim arrives on the shared hover spec. The delayed hide runs
    -- only after it fades and re-checks the live lock state before hiding.
    local lockSpec = "snappy"
    if nextLocked then
        element.lockScrim.Visible = true
    end
    motion.tween(element.lockScrim, {
        BackgroundTransparency = if nextLocked then lockScrimTransparency else 1,
    }, lockSpec)
    if not nextLocked then
        task.delay(0.25, function()
            if not element.locked and element.lockScrim and element.lockScrim.Parent then
                element.lockScrim.Visible = false
            end
        end)
    end

    local label = element.descriptionLabel
    if label then
        -- Manual lock reasons retain their historic copy, but an automatic
        -- mode lock never replaces the description line (which could resize
        -- a wrapped card). The scrim itself is the restricted-state cue.
        if element._manualLocked then
            element._descriptionBefore = element._descriptionBefore or label.Text
            label.Text = locale.resolve(nextMessage or "This element is locked.")
        elseif element._descriptionBefore then
            label.Text = element._descriptionBefore
            element._descriptionBefore = nil
        end

        motion.tween(label, {
            TextTransparency = if nextLocked then lockedTextTransparency else 0.45,
        }, lockSpec)
    end
    return true
end

function Window:_buildLockScrim(element)
    local parent = element.lockSurface or element.main
    if not parent then
        return
    end
    --[[
    The scrim must read as a pure overlay, never as a layout item: any
    GuiObject child of a UIListLayout host joins that layout, so a scrim
    parented onto a layout-managed surface takes a slot beside the
    surface's own content and shoves it around the moment the element
    locks (compact rows shipped exactly that shift). Layouts belong on an
    inner content frame — see `Window:_buildCompactRow`. Loud warning so
    a new element cannot silently reintroduce lock-time layout shifts.
    ]]
    for _, child in ipairs(parent:GetChildren()) do
        if
            child:IsA("UIListLayout")
            or child:IsA("UIGridLayout")
            or child:IsA("UITableLayout")
            or child:IsA("UIPageLayout")
        then
            log.warn(
                `Astra: {element.__type} '{element.name}' lock surface hosts a {child.ClassName}; the lock scrim will join its layout and shift the content when locked. Move the layout onto an inner content frame.`
            )
            break
        end
    end
    element.lockScrim = self:Create("TextButton", {
        Name = "ElementLock",
        Active = true,
        AutoButtonColor = false,
        Selectable = false,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = constants.zIndex.elementLock,
        Visible = false,
        BackgroundTransparency = 1,
        Parent = parent,
    }, { BackgroundColor3 = { "WindowColor", firstColor } })

    element.lockScrimCorner = self:Create("UICorner", {
        Parent = element.lockScrim,
    }, { CornerRadius = "ElementCornerRadius" })

    -- The two header-based containers (CollapsibleGroup / Isolated) keep
    -- their lock surface on the header band, whose own corners flip
    -- between collapsed (all four) and expanded (top only) so the band
    -- squares off against the divider. The scrim must wear the same
    -- corners or a locked, expanded header would show rounded bottom
    -- arcs over a straight seam.
    if element.headerCorner and element.lockScrimCorner then
        for _, key in ipairs(shared.cornerKeys) do
            element.lockScrimCorner[key] = element.headerCorner[key]
        end
    end
end

function Window:_flashResult(element, ok)
    local box = element.box
    if not box then
        return
    end
    local glow = if element._fieldGlow then element:_fieldGlow() else element.glow
    local boxStroke = element.boxStroke
    local flashColor = ok and constants.accent.on or self.theme.ErrorColor
    local flashStroke = ok and constants.accent.onStroke or self.theme.ErrorStrokeColor
    --[[
    Hoisted out of the function: these two are fixed, and the flash runs
    on every element callback that reports a result.
    ]]
    local flashTween = "fast"
    local restoreTween = "normal"

    motion.tween(box, { BackgroundColor3 = flashColor }, flashTween)
    if boxStroke then
        motion.tween(boxStroke, { Color = flashStroke, Transparency = 0.4 }, flashTween)
    end
    if glow then
        motion.tween(glow, { Color = flashStroke, Transparency = 0.6 }, flashTween)
    end

        element._flashToken = (element._flashToken or 0) + 1
    local token = element._flashToken
    task.delay(0.22, function()
        if element._flashToken ~= token then
            return
        end
        motion.tween(box, { BackgroundColor3 = self.theme.FieldBackground }, restoreTween)
        if boxStroke then
            motion.tween(boxStroke, { Color = self.theme.SurfaceStroke, Transparency = 0.85 }, restoreTween)
        end
        if glow then
            motion.tween(glow, { Color = self.theme.FieldGlow, Transparency = element._glowIdle or 1 }, restoreTween)
        end
    end)
end

function Window:_wireElementHover(element, options)
    local theme = self.theme
    --[[
    Containers may scope the hover to a sub-frame (the collapsible
    header) instead of the whole element, and rest their title on a
    different theme token. Keys, not values, so a runtime theme change
    still flows through: the closures below read the theme live.
    ]]
    options = if typeof(options) == "table" then options else {}
    local hoverTarget = options.target or element.main
    local titleRestKey = options.titleRestKey or "ContentColor"
    local titleHoverKey = options.titleHoverKey or "ElementTextHoverColor"

    --[[
    A title that wears a colour of its own cannot rest on a theme key. The
    Mode Picker's title follows the left icon's RGB (and the selected mode
    can override it), and the leave path below used to settle it back onto
    `titleRestKey` — so one pass of the pointer took the colour off the
    title for good, and only the next mode change brought it back. An
    element that owns its title colour answers `_titleRestColor()`; the
    answer is read live on every event, so a mode, icon or theme change
    flows through without re-wiring. Nil (or no method) keeps the element
    on the theme language exactly as before. While an element owns the
    colour the enter path leaves the title alone instead of flashing the
    theme's hover white over it: the stroke and the hover overlay carry
    the feedback, and the title stays the colour the config asked for.
    ]]
    local function ownedTitleColor()
        if element._titleRestColor then
            return element:_titleRestColor()
        end
        return nil
    end

    --[[
    Hover feedback is the single most-repeated animation in the library
    (every element, every pointer move across a grid), so it goes through
    the motion service: the spec is shared instead of allocated per event,
    and an enter/leave pair on the same element can no longer leave two
    tweens interpolating the same stroke — the second cancels the first.
    ]]
    self:ConnectFor(element, hoverTarget.MouseEnter, function()
        if not self:_interactive() then
            return         end
        motion.tween(
            element.stroke,
            { Transparency = self:_elementStrokeTransparency(element, true), Color = theme.ElementStrokeHover },
            "snappy"
        )
        if not ownedTitleColor() then
            motion.tween(element.title, { TextColor3 = theme[titleHoverKey] }, "snappy")
        end
        if element.hoverOverlay then
            motion.tween(element.hoverOverlay, { BackgroundTransparency = 0.97 }, "snappy")
        end
    end)

    self:ConnectFor(element, hoverTarget.MouseLeave, function()
        motion.tween(
            element.stroke,
            { Transparency = self:_elementStrokeTransparency(element, false), Color = theme.ElementStroke },
            "snappy"
        )
        motion.tween(element.title, { TextColor3 = ownedTitleColor() or theme[titleRestKey] }, "snappy")
        if element.hoverOverlay then
            motion.tween(element.hoverOverlay, { BackgroundTransparency = 1 }, "snappy")
        end
    end)
end

function Window:_runGuarded(element, fn, ...)
    if element and element.locked then
        return
    end

    local args = table.pack(...)
    task.spawn(function()
        if element and element.locked then
            return
        end
        local ok, err = pcall(function()
            return fn(table.unpack(args, 1, args.n))
        end)
        if ok or element._errored then
            return
        end
        element._errored = true

        local flashTarget = element.flashTarget or element.main
        local errorTween = "snappy"
        motion.tween(flashTarget, { BackgroundColor3 = self.theme.ErrorColor }, errorTween)
        motion.tween(element.stroke, { Color = self.theme.ErrorStrokeColor }, errorTween)
                if element.title then
            element.title.Text = locale.resolve("Error, log recorded in console.")
        end

        log.warn(
            `Astra encountered an error, with the callback for a {element.__type} component named '{element.name}':`
        )
        log.print(err)

        task.wait(1)

        if element.title then
            element.title.Text = locale.resolve(element.name)
        end
        motion.tween(
            flashTarget,
            { BackgroundColor3 = Color3.fromRGB(255, 255, 255) },
            "normal"
        )
        motion.tween(
            element.stroke,
            { Color = self.theme.ElementStroke },
            "emphasized"
        )
        element._errored = false
    end)
end

function Window:_reveal(instance, targets, animate, tweenInfo)
    if not instance then
        return
    end
    --[[
    Skip work when the target state is already applied: the cascade (and
    a window that is shown, hidden and shown again) asks the same elements
    to reveal repeatedly.
    ]]
    local needsUpdate = false
    for prop, value in targets do
        if instance[prop] ~= value then
            needsUpdate = true
            break
        end
    end
    if not needsUpdate then
        return
    end

    if animate then
        --[[
        The tween goes through the motion service, which shares the spec
        and cancels an in-flight tween on the same property — the cascade
        asks every element on the page to show on one frame, and a
        hidden/reshown window used to stack a second reveal on the first.
        ]]
        motion.tween(instance, targets, tweenInfo or "normal")
    else
        for prop, value in targets do
            instance[prop] = value
        end
    end
end

function Window:_revealCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = self:_elementStrokeTransparency(element, false) }, animate)
    self:_reveal(element.title, { TextTransparency = 0 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = self:_elementBackgroundTransparency(element) }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 0 }, animate)
    end
    if element.descriptionLabel then
        self:_reveal(element.descriptionLabel, { TextTransparency = 0.45 }, animate)
    end
end

function Window:_hideCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = 1 }, animate)
    self:_reveal(element.title, { TextTransparency = 1 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = 1 }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 1 }, animate)
    end
    if element.descriptionLabel then
        self:_reveal(element.descriptionLabel, { TextTransparency = 1 }, animate)
    end
    --[[
    The floating description is placed in screen space, so an element
    that stops being drawn (the window hid, the tab changed, the page
    scrolled away) has to take its own description with it. Every hide
    path in the library funnels through here.
    ]]
    tooltip.hideFor(self, element)
end
