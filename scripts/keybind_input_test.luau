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
-- The stub fires TextChanged on assignment, like the engine, so typing is
-- just a property write: no extra manual fire (a second fire would make a
-- dropped "7" indistinguishable from a real backspace).
local function focus()
    focused = true
    local shown = binding.keyLabel.Text
    binding.keyLabel.Focused:Fire()
    assert(not binding.recording, "Focus must not start recording")
    assert(binding.keyLabel.Text == shown, "Focus keeps the current binding visible to replace")
end
local function typeText(text)
    binding.keyLabel.Text = text
    TestPump(0.1)
end
local function stillEditing()
    assert(focused, "Editing must keep the field focused")
    assert(not binding.recording, "Editable input must never record")
end

-- The first letter is kept, uppercased, and persisted; all extra text is removed.
focus()
typeText("pasted")
assert(binding.value == Enum.KeyCode.P, "First typed letter must become the binding")
assert(binding.keyLabel.Text == "P", "Extra typed letters must be removed")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Settings must update")
assert(saves == 1, "Changed binding must be saved")
stillEditing()

-- Replacing the value works with one letter, without leaving the field.
typeText("q2")
assert(binding.value == Enum.KeyCode.Q and binding.keyLabel.Text == "Q", "Binding must be replaceable with one letter")
assert(saves == 2, "Replacement must be saved")
stillEditing()

-- Backspacing clears the binding but leaves the field ready for the next key.
typeText("")
assert(binding.value == Enum.KeyCode.Unknown, "Backspace must clear the binding")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown, "Cleared binding must update Settings")
assert(saves == 3, "Cleared binding must be saved")
assert(binding.keyLabel.Text == "", "Backspace must leave an empty field, not a stray label")
stillEditing()

-- A letter typed after the backspace becomes the new binding.
typeText("j")
assert(binding.value == Enum.KeyCode.J and binding.keyLabel.Text == "J", "A letter typed after backspacing must rebind")
assert(saves == 4, "Rebinding after backspace must be saved")
stillEditing()

-- Non-letters are dropped without replacing or clearing the current value.
typeText("7")
assert(binding.value == Enum.KeyCode.J, "Non-letter input must not change the binding")
assert(binding.keyLabel.Text == "", "Non-letter input must be dropped, not bound")
assert(saves == 4, "Rejected input must not be saved")
stillEditing()

-- Leaving the field restores the bound key's display.
binding.keyLabel:ReleaseFocus()
TestPump(0.1)
assert(not binding.recording, "Focus loss must not leave a recording session")
assert(binding.keyLabel.Text == "J", "Focus loss must show the bound key again")

-- Reopening the field still replaces the binding in one letter.
focus()
typeText("k")
assert(binding.value == Enum.KeyCode.K and binding.keyLabel.Text == "K", "A refocused field must rebind with one letter")
binding.keyLabel:ReleaseFocus()
TestPump(0.1)
print("Editable one-letter Settings keybind and persistence passed")
