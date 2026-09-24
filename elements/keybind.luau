--[[
A compact, editable single-letter key control. The TextBox gives the
control a real caret and lets a user replace the letter in place, while the
shared capture path keeps programmatic Capture/CancelCapture and the window
shortcut guard working the same way. Values are always uppercase A–Z.
]]
local utilities = script.Parent.Parent.utilities
local baseCard = require(script.Parent.baseCard)
local locale = require(utilities.locale)
local keys = require(utilities.keybind)
local haptic = require(utilities.HapticEngine)
local moveable = require(utilities.moveable)
local lockable = require(utilities.lockable)

local Keybind = {}
Keybind.__index = Keybind
Keybind.__type = "Keybind"

function Keybind.new(tab, props)
    props = if type(props) == "table" then props else {}
    local self = setmetatable({
        tab = tab,
        window = tab.window,
        name = props.name or props.Name or "Keybind",
        icon = tab.window:ResolveIcon(props.icon or props.Icon or "keyboard"),
        --[[
        Keybinds intentionally have no description row. The field is a
        small one-letter affordance, so extra copy only pushes the control
        away from the rest of the compact settings surface.
        ]]
        value = keys.letter(props.value or props.Value) or "K",
        callback = props.callback or props.Callback or function() end,
        forgetState = props.forgetState or props.ForgetState or tab.forgetState,
        capturing = false,
        _editing = false,
        _syncingText = false,
    }, Keybind)
    self.flag = props.flag or props.Flag or (not self.forgetState and tab.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    --[[
    The field is deliberately only wide enough for one glyph. A TextBox,
    rather than a TextButton, lets the user click into the value, delete
    it while editing and type a replacement. The value is restored if the
    edit is cancelled or focus is lost without a valid letter.
    ]]
    baseCard.buildFull(self, { height = 43, rightPadding = 64, titleText = locale.t(self.name) })
    self.keyButton = self.window:Create("TextBox", {
        Name = "Keycap",
        Text = self.value,
        PlaceholderText = "",
        TextSize = 15,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextWrapped = false,
        TextEditable = true,
        MultiLine = false,
        ClearTextOnFocus = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(34, 29),
        Position = UDim2.new(1, -15, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Parent = self.main,
    }, { BackgroundColor3 = "FieldBackground", TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })
    --[[
    Keep the intuitive `input` handle for hosts that want to inspect or
    focus the editable field; `keyButton` remains the compatibility name.
    ]]
    self.input = self.keyButton
    self.window:Create("UICorner", { Parent = self.keyButton }, { CornerRadius = "ElementCornerRadius" })

    self.window:ConnectFor(self, self.keyButton.Focused, function()
        if not self:_canCapture() then
            self:_writeText(self.value)
            self.keyButton:ReleaseFocus()
            return
        end
        if not self.capturing then
            self:Capture()
        end
        self._editing = true
        --[[
        Clear only after focus is granted. This makes the next typed or
        pasted character replace the old binding instead of appending to
        it, while an empty edit can still be cancelled safely.
        ]]
        self:_writeText("")
    end)

    self.window:ConnectFor(self, self.keyButton:GetPropertyChangedSignal("Text"), function()
        if self._syncingText or not self.capturing then
            return
        end

        local raw = tostring(self.keyButton.Text or "")
        local normalized = raw:upper():gsub("[^A-Z]", "")
        local letter = normalized:sub(1, 1)
        if raw ~= letter then
            self:_writeText(letter)
        end

        if letter ~= "" then
            self:Set(letter)
        elseif raw ~= "" then
            self.window:_flashResult(self, false)
        end
    end)

    self.window:ConnectFor(self, self.keyButton.FocusLost, function()
        self._editing = false
        if not self.capturing then
            return
        end

        local letter = keys.letter(self.keyButton.Text)
        if letter then
            self:Set(letter)
        else
            self:CancelCapture()
        end
    end)

    self.window:_wireElementHover(self)
    lockable.register(self, props)
    return self
end

function Keybind:_writeText(value)
    if not self.keyButton or not self.keyButton.Parent then
        return
    end
    self._syncingText = true
    self.keyButton.Text = value
    self._syncingText = false
end

function Keybind:_canCapture()
    if not self._shown or self.locked or self.window.unloaded or self.window.minimised
        or self.window._searching or not self.window:_interactive() or not self.main.Parent
    then
        return false
    end
    local owner = self.tab
    while owner do
        if owner.locked or (owner.__type == "CollapsibleGroup" and not owner._expanded) then
            return false
        end
        if owner.__type == "Tab" then
            return self.window.selectedTab == owner
        end
        owner = owner.tab
    end
    return false
end

function Keybind:Capture()
    if not self:_canCapture() then
        return false
    end
    if self.window._keybindCapture and self.window._keybindCapture ~= self then
        self.window._keybindCapture:CancelCapture()
    end
    self.window._keybindCapture = self
    self.capturing = true
    return true
end

function Keybind:CancelCapture()
    if self.window._keybindCapture == self then
        self.window._keybindCapture = nil
    end
    self.capturing = false
    self._editing = false
    self:_writeText(self.value)
    if self.keyButton and self.keyButton.Parent then
        --[[
        ReleaseFocus is safe when Capture was called from the public API
        without the TextBox ever being focused; pcall also keeps the
        library compatible with lightweight host stubs.
        ]]
        pcall(function()
            self.keyButton:ReleaseFocus()
        end)
    end
end

function Keybind:SetInteractionLocked(locked)
    if not self.keyButton then
        return
    end
    self.keyButton.TextEditable = not locked
    self.keyButton.Interactable = not locked
end

function Keybind:_captureInput(input)
    if not self:_canCapture() then
        self:CancelCapture()
        return
    end
    if input.KeyCode == Enum.KeyCode.Escape then
        self:CancelCapture()
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    local letter = keys.letter(input.KeyCode)
    if not letter then
        self.window:_flashResult(self, false)
        return
    end
    self:Set(letter)
end

function Keybind:Set(value, silent)
    local letter = keys.letter(value)
    if not letter then
        return false
    end
    local changed = letter ~= self.value
    self.value = letter
    self:CancelCapture()
    if changed and not silent then
        haptic.click()
        self.window:_runGuarded(self, self.callback, letter)
        self.window:_persist(self)
        self.window:_flashResult(self, true)
    end
    return true
end

function Keybind:_setShown(shown, animate)
    self._shown = shown
    if shown then
        self.window:_revealCommon(self, animate)
    else
        self:CancelCapture()
        self.window:_hideCommon(self, animate)
    end
    self.window:_reveal(self.keyButton, {
        BackgroundTransparency = if shown then self.window.theme.FieldTransparency else 1,
        TextTransparency = if shown then 0 else 1,
    }, animate)
end

moveable(Keybind)
lockable(Keybind)
return Keybind
