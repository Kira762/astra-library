-- Editable focus events exercise the built-in Settings field.
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
assert(binding.keyLabel.TextEditable == true, "Settings binding must remain editable")
assert(binding.recording == false, "Editable settings binding must not start recording")

local focused = false
binding.keyLabel.IsFocused = function() return focused end
binding.keyLabel.ReleaseFocus = function()
    focused = false
    binding.keyLabel.FocusLost:Fire()
end
local saves = 0
window.SaveSettings = function() saves += 1 end
local textChanged = binding.keyLabel:GetPropertyChangedSignal("Text")
local function focus()
    focused = true
    binding.keyLabel.Focused:Fire()
    assert(not binding.recording, "Focus must not start recording")
end
local function typeText(text)
    binding.keyLabel.Text = text
    textChanged:Fire()
    TestPump(0.1)
end

-- The first letter is kept, uppercased, and persisted; all extra text is removed.
focus()
typeText("pasted")
assert(binding.value == Enum.KeyCode.P, "First typed letter must become the binding")
assert(binding.keyLabel.Text == "P", "Extra typed letters must be removed")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Settings must update")
assert(saves == 1, "Changed binding must be saved")
assert(not binding.recording, "Editable input must never record")

-- Replacing the value works without reopening a recording session.
typeText("q2")
assert(binding.value == Enum.KeyCode.Q and binding.keyLabel.Text == "Q", "Binding must be replaceable with one letter")
assert(saves == 2, "Replacement must be saved")

-- Empty text clears the binding and persists the cleared value.
typeText("")
assert(binding.value == Enum.KeyCode.Unknown, "Empty text must clear the binding")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown, "Cleared binding must update Settings")
assert(saves == 3, "Cleared binding must be saved")

-- Non-letters are rejected without replacing the current value.
typeText("7")
assert(binding.value == Enum.KeyCode.Unknown and binding.keyLabel.Text == "None", "Non-letter input must be rejected")

binding.keyLabel:ReleaseFocus()
TestPump(0.1)
assert(not binding.recording, "Focus loss must not leave a recording session")
print("Editable one-letter Settings keybind and persistence passed")
