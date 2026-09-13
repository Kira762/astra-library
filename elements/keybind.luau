local state = {}
state.__index = state
state.__type = "Keybind"

local constants = script.Parent.Parent.utilities

local Keybind = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(constants.moveable)
local name = require(constants.lockable)
local flag = require(constants.locale)
local value = require(constants.constants)
local isMenuToggle = require(constants.HapticEngine)
local hold = require(constants.enums)
local holdThreshold = require(constants.log)

local callback = value.pillResizeInfo
local onChanged = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local element = {
    [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
}

local function frame(isRecording)
    if typeof(isRecording) ~= "EnumItem" or isRecording == Enum.KeyCode.Unknown then
        return "None"
    end
    return element[isRecording] or isRecording.Name
end

local function connection(a18)
    if typeof(a18) == "EnumItem" then
        return a18
    end
    if type(a18) == "string" then
        local ok, a19 = pcall(function()
            return Enum.KeyCode[a18]
        end)
        if ok and a19 then
            return a19
        end
        local a20, a21 = pcall(function()
            return Enum.UserInputType[a18]
        end)
        if a20 and a21 and element[a21] then
            return a21
        end
    end
    return Enum.KeyCode.Unknown
end

function state.new(tab, a22)
    a22 = if typeof(a22) == "table" then a22 else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = a22.name or a22.Name or "Keybind",
        icon = tab.window:ResolveIcon(a22.icon or a22.Icon),
        description = a22.description or a22.Description,
        forgetState = a22.forgetState or a22.ForgetState or tab.forgetState,

                        isMenuToggle = a22.isMenuToggle or a22.IsMenuToggle or false,

                callback = a22.callback or a22.Callback or function() end,
                onChanged = a22.onChanged or a22.OnChanged or function() end,

                        hold = a22.hold or a22.Hold or false,
        holdThreshold = a22.holdThreshold or a22.HoldThreshold or 0.2,

        recording = false,
    }, state)

    self.value = connection(a22.value or a22.Value or a22.default or a22.Default)

    self.flag = a22.flag
        or a22.Flag
        or (not self.forgetState and tab.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.main)

        self.container = self.window:Create("Frame", {
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            ImageTransparency = 1,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = flag.t(self.name),
        Size = UDim2.fromOffset(150, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 5,

        TextTransparency = 1,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

        self.box = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0, 20),
        Size = UDim2.fromOffset(40, 30),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,
        Parent = self.main,
    }, { BackgroundColor3 = "FieldBackground" })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.box,
    })

    self.boxStroke = self.window:Create("UIStroke", {
        Transparency = 1,
        Parent = self.box,
    }, { Color = "SurfaceStroke" })

        self.glow = self.window:CreateGlow(self.box, "FieldGlow", 20, 1)
    self._glowIdle = 0.9
    -- Use a focusable field, like Input, rather than a button under a label.
    self.keyLabel = self.window:Create("TextBox", {
        Text = frame(self.value),
        ClearTextOnFocus = false,
        MultiLine = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,

        TextTransparency = 1,
        Parent = self.box,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.window:ConnectFor(self, self.keyLabel.Focused, function()
        if self.locked or not self.window:_interactive() then
            self.keyLabel:ReleaseFocus()
            return
        end
        isMenuToggle.click()
        self:_startRecording()
    end)

    self.window:ConnectFor(self, self.keyLabel.FocusLost, function()
        -- Clicking away cancels; only captured keys may change the binding.
        if self.recording then
            self:_stopRecording()
        else
            self.keyLabel.Text = frame(self.value)
        end
    end)

                    self.window:ConnectFor(self, Keybind.userInputService.InputBegan, function(a23, a24)
        -- A game may mark the input as processed, but recording must still
        -- receive it so rebinding does not immediately fall back to the old key.
        if a24 and not self.recording then
            return
        end
        if self.recording then
            self:_capture(a23)
            return
        end
                        if self.window._recordingKeybind then
            return
        end
        if self:_matches(a23) then
            if self.hold then
                self:_beginHold(a23)
            else
                self.window:_runGuarded(self, self.callback, self.value)
            end
        end
    end)

    self.window:_wireElementHover(self)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    self:_sizeBox(false)
    return self
end

function state:_sizeBox(a25)
    local a26 = math.clamp(tab.textWidth(self.window.theme.Font, 15, self.keyLabel.Text) + 28, 40, 200)
    if a25 then
        Keybind.tweenService:Create(self.box, callback, { Size = UDim2.fromOffset(a26, 30) }):Play()
    else
        self.box.Size = UDim2.fromOffset(a26, 30)
    end
end

function state:_startRecording()
        local a27 = self.window._recordingKeybind
    if a27 and a27 ~= self then
        a27:_stopRecording()
    end
    self.recording = true
    self.window._recordingKeybind = self
    self.keyLabel.Text = flag.resolve("Recording")
    self:_sizeBox(true)
    Keybind.tweenService:Create(self.glow, onChanged, { Transparency = 0.7 }):Play()
    Keybind.tweenService:Create(self.keyLabel, onChanged, { TextTransparency = 0 }):Play()
end

function state:_stopRecording()
    self.recording = false
    if self.keyLabel:IsFocused() then
        self.keyLabel:ReleaseFocus()
    end
                if self.window._recordingKeybind == self then
        local window = self.window
        task.defer(function()
            if window._recordingKeybind == self and not self.recording then
                window._recordingKeybind = nil
            end
        end)
    end
    self.keyLabel.Text = frame(self.value)
    self:_sizeBox(true)
    Keybind.tweenService:Create(self.glow, onChanged, { Transparency = 0.9 }):Play()
    Keybind.tweenService:Create(self.keyLabel, onChanged, { TextTransparency = 0.6 }):Play()
end

function state:_capture(a28)
    local a29
    if a28.UserInputType == Enum.UserInputType.Keyboard then
        if a28.KeyCode == Enum.KeyCode.Escape then
            self:_stopRecording()
            return
        end
        if a28.KeyCode == Enum.KeyCode.Backspace then
            self:_bind(Enum.KeyCode.Unknown)
            return
        end
        a29 = a28.KeyCode
    elseif
        a28.UserInputType == Enum.UserInputType.MouseButton2
        or a28.UserInputType == Enum.UserInputType.MouseButton3
    then
        a29 = a28.UserInputType
    end
    if not a29 then
        return
    end

    if self.isMenuToggle then
                        local a30 = self.window:_keybindUsing(a29, self)
        if a30 then
            self.window:Notify({
                title = flag.resolve("Keybind unavailable"),
                content = string.format(
                    flag.resolve("%s is bound to %s. Kept %s."),
                    frame(a29),
                    a30.name,
                    frame(self.value)
                ),
            })
            self:_stopRecording()
            self.window:_flashResult(self, false)             return
        end
    elseif a29 == self.window.settings.toggleKeybind then
                        self.window:Notify({
            title = flag.resolve("Keybind unavailable"),
            content = string.format(
                flag.resolve("%s is the menu toggle key. Kept %s."),
                frame(a29),
                frame(self.value)
            ),
        })
        self:_stopRecording()
        self.window:_flashResult(self, false)         return
    end

    self:_bind(a29)
end

function state:_bind(a31)
    self.value = a31
    self:_stopRecording()
    self.window:_runGuarded(self, self.onChanged, a31)
    self.window:_persist(self)

    self.window:_flashResult(self, true) end

function state:_matches(a32)
    local v = self.value
    if typeof(v) ~= "EnumItem" or v == Enum.KeyCode.Unknown then
        return false
    end
    if v.EnumType == Enum.KeyCode then
        return a32.KeyCode == v
    elseif v.EnumType == Enum.UserInputType then
        return a32.UserInputType == v
    end
    return false
end

function state:_beginHold(a33)
    if self._holding or self._holdPress then
        return     end
    local a34 = {}
    self._holdPress = a34

            local a35 = a33.KeyCode
    local a36 = a33.UserInputType

    task.delay(self.holdThreshold, function()
        if self._holdPress ~= a34 then
            return         end
        if self.window.unloaded then
            return
        end
        self._holding = true
        self.window:_runGuarded(self, self.callback, true)
    end)

                local a37
    a37 = self.window:ConnectFor(self, Keybind.userInputService.InputEnded, function(a38)
        local a39 = if a35 ~= Enum.KeyCode.Unknown
            then a38.KeyCode == a35
            else a38.UserInputType == a36
        if not a39 then
            return
        end
                if self.connections then
            local a40 = table.find(self.connections, a37)
            if a40 then
                table.remove(self.connections, a40)
            end
        end
        self.window:Disconnect(a37)
        if self._holdPress == a34 then
            self._holdPress = nil
        end
        if self._holding then
            self._holding = false
            self.window:_runGuarded(self, self.callback, false)
        end
    end)
end

function state:Set(a41, a42)
    local a43 = connection(a41)

            if a43 ~= Enum.KeyCode.Unknown then
        if self.isMenuToggle then
            local a44 = self.window:_keybindUsing(a43, self)
            if a44 then
                holdThreshold.warn(
                    "Astra: "
                        .. frame(a43)
                        .. " is bound to '"
                        .. tostring(a44.name)
                        .. "'; kept "
                        .. frame(self.value)
                )
                return
            end
        elseif a43 == self.window.settings.toggleKeybind then
            holdThreshold.warn("Astra: " .. frame(a43) .. " is the menu toggle key; kept " .. frame(self.value))
            return
        end
    end

    self.value = a43
    if self.recording then
        self:_stopRecording()     else
        self.keyLabel.Text = frame(self.value)
        self:_sizeBox(true)
    end

    if not a42 then
        self.window:_runGuarded(self, self.onChanged, self.value)
        self.window:_persist(self)
    end
end

function state:_serialize()
    return { tostring(self.value.EnumType), self.value.Value }
end

function state:_deserialize(a45)
        local a46 = tostring(a45[1]):gsub("^Enum%.", "")
    local a47, a48 = pcall(function()
        return Enum[a46]
    end)
    if not a47 or not a48 then
        return
    end

    local a49 = hold.itemFromValue(a48, a45[2])
    if a49 then
        self:Set(a49)
    end
end

function state:_setShown(a50, a51)
    local w = self.window
    if a50 then
        w:_revealCommon(self, a51)
        w:_reveal(self.box, { BackgroundTransparency = w.theme.FieldTransparency }, a51)
        w:_reveal(self.boxStroke, { Transparency = 0.85 }, a51)
        w:_reveal(self.keyLabel, { TextTransparency = 0.6 }, a51)
        w:_reveal(self.glow, { Transparency = 0.9 }, a51)
    else
        w:_hideCommon(self, a51)
        w:_reveal(self.box, { BackgroundTransparency = 1 }, a51)
        w:_reveal(self.boxStroke, { Transparency = 1 }, a51)
        w:_reveal(self.keyLabel, { TextTransparency = 1 }, a51)
        w:_reveal(self.glow, { Transparency = 1 }, a51)
    end
end

function state:_refreshTheme()
    Keybind.tweenService
        :Create(
            self.box,
            TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = self.window.theme.FieldTransparency }
        )
        :Play()
end

props(state)
name(state)

return state
