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
    self._loading = true     persistence.applyTo(element, self._loadedConfig[element.flag])
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

function Window:_setElementLocked(element, locked, message)
    locked = locked == true
                local wasLocked = element.locked == true
    if wasLocked == locked and not (locked and message) then
        return
    end
    element.locked = locked

    if not element.lockScrim then
        self:_buildLockScrim(element)
    end

    -- [[The lock scrim arrives on the shared hover spec; the unlock delay
    -- tracks its duration so the scrim never hides after it has faded.]]
    local lockSpec = "snappy"

    if locked then
        element.lockScrim.Visible = true
    end
    motion.tween(element.lockScrim, {
        BackgroundTransparency = if locked then lockScrimTransparency else 1,
    }, lockSpec)
    if not locked then
        task.delay(0.25, function()
            if not element.locked and element.lockScrim and element.lockScrim.Parent then
                element.lockScrim.Visible = false             end
        end)
    end

        local label = element.descriptionLabel
    if not label then
        return
    end

    if locked then
                        element._descriptionBefore = element._descriptionBefore or label.Text
        label.Text = locale.resolve(message or "This element is locked.")
    elseif element._descriptionBefore then
        label.Text = element._descriptionBefore
        element._descriptionBefore = nil
    end

    motion.tween(label, {
        TextTransparency = if locked then lockedTextTransparency else 0.45,
    }, lockSpec)
end

function Window:_buildLockScrim(element)
    element.lockScrim = self:Create("TextButton", {
        Name = "ElementLock",
        Active = true,
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = constants.zIndex.elementLock,
        Visible = false,

                        BackgroundTransparency = 1,
        Parent = element.main,
    }, { BackgroundColor3 = { "WindowColor", firstColor } })

    self:Create("UICorner", {
        Parent = element.lockScrim,
    }, { CornerRadius = "ElementCornerRadius" })
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
    -- [[Hoisted out of the function: these two are fixed, and the flash runs
    -- on every element callback that reports a result.]]
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
    -- [[Containers may scope the hover to a sub-frame (the collapsible
    -- header) instead of the whole element, and rest their title on a
    -- different theme token. Keys, not values, so a runtime theme change
    -- still flows through: the closures below read the theme live.]]
    options = if typeof(options) == "table" then options else {}
    local hoverTarget = options.target or element.main
    local titleRestKey = options.titleRestKey or "ContentColor"
    local titleHoverKey = options.titleHoverKey or "ElementTextHoverColor"

    -- [[Hover feedback is the single most-repeated animation in the library
    -- (every element, every pointer move across a grid), so it goes through
    -- the motion service: the spec is shared instead of allocated per event,
    -- and an enter/leave pair on the same element can no longer leave two
    -- tweens interpolating the same stroke — the second cancels the first.]]
    self:ConnectFor(element, hoverTarget.MouseEnter, function()
        if not self:_interactive() then
            return         end
        motion.tween(
            element.stroke,
            { Transparency = self:_elementStrokeTransparency(element, true), Color = theme.ElementStrokeHover },
            "snappy"
        )
        motion.tween(element.title, { TextColor3 = theme[titleHoverKey] }, "snappy")
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
        motion.tween(element.title, { TextColor3 = theme[titleRestKey] }, "snappy")
        if element.hoverOverlay then
            motion.tween(element.hoverOverlay, { BackgroundTransparency = 1 }, "snappy")
        end
    end)
end

function Window:_runGuarded(element, fn, ...)
            if element.locked then
        return
    end

    local args = table.pack(...)
    task.spawn(function()
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
    -- [[Skip work when the target state is already applied: the cascade (and
    -- a window that is shown, hidden and shown again) asks the same elements
    -- to reveal repeatedly.]]
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
        -- [[The tween goes through the motion service, which shares the spec
        -- and cancels an in-flight tween on the same property — the cascade
        -- asks every element on the page to show on one frame, and a
        -- hidden/reshown window used to stack a second reveal on the first.]]
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
    if element.tapIcon then
        self:_reveal(element.tapIcon, { ImageTransparency = 0.5 }, animate)
    end
    if element.infoButton then
        self:_reveal(element.infoButton, { ImageTransparency = 0.45 }, animate)
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
    if element.tapIcon then
        self:_reveal(element.tapIcon, { ImageTransparency = 1 }, animate)
    end
    if element.infoButton then
        self:_reveal(element.infoButton, { ImageTransparency = 1 }, animate)
    end
    if element.descriptionLabel then
        self:_reveal(element.descriptionLabel, { TextTransparency = 1 }, animate)
    end
    -- [[The floating description is placed in screen space, so an element
    -- [[that stops being drawn (the window hid, the tab changed, the page
    -- [[scrolled away) has to take its own description with it. Every hide
    -- [[path in the library funnels through here.]] 
    tooltip.hideFor(self, element)
end
