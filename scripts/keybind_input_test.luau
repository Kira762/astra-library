-- Focus events exercise the same path used by the built-in Settings field.
local window = Astra:CreateWindow({ name = "Keybind input test" })
TestPump(0.6)
window:Show()
TestPump(0.6)
window:_buildSettingsContent(window.rfSettings)
local binding
for _, control in window.rfSettings.elements do
    if control.isMenuToggle then binding = control; break end
end
assert(binding, "Settings must expose the menu binding")
assert(binding.keyLabel.ClassName == "TextBox", "Binding must be focusable")

-- The lightweight GUI stubs don't implement TextBox focus management.
local focused = false
binding.keyLabel.IsFocused = function() return focused end
binding.keyLabel.ReleaseFocus = function()
    focused = false
    binding.keyLabel.FocusLost:Fire()
end
local function focus()
    focused = true
    binding.keyLabel.Focused:Fire()
    assert(binding.recording, "Focus must start recording")
end
local function press(key)
    Astra.Core.state.userInputService.InputBegan:Fire({
        UserInputType = Enum.UserInputType.Keyboard,
        KeyCode = key,
    }, true) -- TextBoxes mark keystrokes as processed.
    TestPump(0.1)
end
local saves = 0
window.SaveSettings = function() saves += 1 end
focus()
press(Enum.KeyCode.P)
assert(binding.value == Enum.KeyCode.P, "Processed input must bind")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Settings must update")
assert(saves == 1, "Changed binding must be saved")
assert(not focused and not binding.recording, "Capture must release focus")
assert(not window.hidden, "Rebinding must not hide the window")
assert(binding.keyLabel.Text == "P", "Field must show the new binding")

focus()
press(Enum.KeyCode.Escape)
assert(binding.value == Enum.KeyCode.P and saves == 1, "Escape must cancel")
focus()
binding.keyLabel.Text = "invalid pasted text"
binding.keyLabel:ReleaseFocus()
TestPump(0.1)
assert(binding.keyLabel.Text == "P" and saves == 1, "Blur must restore binding")
focus()
press(Enum.KeyCode.Backspace)
assert(binding.value == Enum.KeyCode.Unknown, "Backspace must clear")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown, "Clear must update Settings")
assert(saves == 2, "Clear must save")
print("Keybind focus and Settings updates passed")

-- Reject conflicts without saving or replacing the previous key.
local tab = window:CreateTab({ name = "Other controls" })
tab:CreateKeybind({ name = "Reserved", value = Enum.KeyCode.R })
focus()
press(Enum.KeyCode.R)
assert(binding.value == Enum.KeyCode.Unknown and saves == 2, "Conflicts must not save")

-- Mouse bindings must still work while the TextBox owns focus.
focus()
Astra.Core.state.userInputService.InputBegan:Fire({
    UserInputType = Enum.UserInputType.MouseButton2,
    KeyCode = Enum.KeyCode.Unknown,
}, true)
TestPump(0.1)
assert(binding.value == Enum.UserInputType.MouseButton2, "Right mouse must bind")
assert(saves == 3, "Mouse binding must save")

-- A pending cancellation must not clear a newly started recording session.
focus()
binding.keyLabel:ReleaseFocus()
focus()
TestPump(0.1)
assert(window._recordingKeybind == binding, "Refocus must keep recording ownership")
press(Enum.KeyCode.P)
assert(saves == 4, "Refocused field must accept a key")

binding:Lock()
focused = true
binding.keyLabel.Focused:Fire()
assert(not focused and not binding.recording, "Locked field must reject focus")
binding:Unlock()

-- Outside recording, the newly saved key must still toggle the window.
Astra.Core.state.userInputService.InputBegan:Fire({
    UserInputType = Enum.UserInputType.Keyboard,
    KeyCode = Enum.KeyCode.P,
}, false)
TestPump(0.6)
assert(window.hidden, "New key must toggle the window after recording")
print("Keybind conflicts, mouse capture, refocus, locking and toggle passed")
