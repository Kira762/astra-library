-- [[A key-capture control, never a free-form TextBox. Values are required A–Z
-- letters; callbacks and config flags use their uppercase string spelling.]]
local utilities = script.Parent.Parent.utilities
local baseCard = require(script.Parent.baseCard)
local description = require(script.Parent.description)
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
        description = props.description or props.Description,
        value = keys.letter(props.value or props.Value) or "K",
        callback = props.callback or props.Callback or function() end,
        forgetState = props.forgetState or props.ForgetState or tab.forgetState,
    }, Keybind)
    self.flag = props.flag or props.Flag or (not self.forgetState and tab.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)
    baseCard.buildFull(self, { height = 43, rightPadding = 128, titleText = locale.t(self.name) })
    self.keyButton = self.window:Create("TextButton", {
        Name = "Keycap",
        Text = self.value,
        TextSize = 15,
        TextTransparency = 1,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(94, 29),
        Position = UDim2.new(1, -15, description.center(self, 43)),
        AnchorPoint = Vector2.new(1, 0.5),
        Parent = self.main,
    }, { BackgroundColor3 = "FieldBackground", TextColor3 = "ContentColor", FontFace = "Font" })
    self.window:Create("UICorner", { Parent = self.keyButton }, { CornerRadius = "ElementCornerRadius" })
    self.window:ConnectFor(self, self.keyButton.MouseButton1Click, function()
        if self.capturing then
            self:CancelCapture()
        else
            self:Capture()
        end
    end)
    self.window:_wireElementHover(self)
    return self
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
    if self.window._keybindCapture then
        self.window._keybindCapture:CancelCapture()
    end
    self.window._keybindCapture = self
    self.capturing = true
    self.keyButton.Text = "Press A–Z"
    return true
end

function Keybind:CancelCapture()
    if self.window._keybindCapture == self then
        self.window._keybindCapture = nil
    end
    self.capturing = false
    self.keyButton.Text = self.value
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
