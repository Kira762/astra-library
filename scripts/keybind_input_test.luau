-- Settings keybinds use the normal button-backed Keybind element.
local window = Astra:CreateWindow({ name = "Keybind input test" })
TestPump(0.6)
window:Show()
TestPump(0.6)
window:_buildSettingsContent(window.rfSettings)

local binding
-- [[Settings controls live inside Collapsible Groups now, so the menu]]
-- [[binding is one level below the tab's top-level elements.]]
local function scan(elements)
    for _, control in elements do
        if control.isMenuToggle then
            return control
        end
        if control.elements then
            local found = scan(control.elements)
            if found then
                return found
            end
        end
    end
    return nil
end
binding = scan(window.rfSettings.elements)
assert(binding, "Settings must expose the menu binding")
assert(binding.__type == "Keybind", "Settings must keep the menu binding on a Keybind element")
assert(binding.box.ClassName == "TextButton", "Binding must use the original clickable key cap")
assert(binding.keyLabel.ClassName == "TextLabel", "Binding must not create a separate editable input")
assert(binding.recording == false, "Settings binding starts idle")

local saves = 0
window.SaveSettings = function() saves += 1 end

local function clickCap()
    binding.box.MouseButton1Click:Fire()
    TestPump(0.1)
end

local function press(key, processed)
    Astra.Core.state.userInputService.InputBegan:Fire({
        UserInputType = Enum.UserInputType.Keyboard,
        KeyCode = key,
    }, processed == true)
    TestPump(0.1)
end

local function pressMouse(inputType, processed)
    Astra.Core.state.userInputService.InputBegan:Fire({
        UserInputType = inputType,
        KeyCode = Enum.KeyCode.Unknown,
    }, processed == true)
    TestPump(0.1)
end

clickCap()
assert(binding.recording, "Clicking the cap must start recording")
assert(binding.keyLabel.Text == "Recording", "Recording state must show on the key cap")
press(Enum.KeyCode.P, true) -- Text-focused/game-processed input must still capture while recording.
assert(binding.value == Enum.KeyCode.P, "Processed input must bind while recording")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Settings must update")
assert(saves == 1, "Changed binding must be saved")
assert(not binding.recording, "Capture must end after a key")
assert(not window.hidden, "Rebinding must not hide the window")
assert(binding.keyLabel.Text == "P", "Cap must show the new binding")

clickCap()
press(Enum.KeyCode.Escape, true)
assert(binding.value == Enum.KeyCode.P and saves == 1, "Escape must cancel without saving")

clickCap()
press(Enum.KeyCode.Backspace, true)
assert(binding.value == Enum.KeyCode.Unknown, "Backspace must clear")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown, "Clear must update Settings")
assert(saves == 2, "Clear must save")
assert(binding.keyLabel.Text == "None", "Cleared binding must show None on the cap")

-- Reject conflicts without saving or replacing the previous key.
local tab = window:CreateTab({ name = "Other controls" })
tab:CreateKeybind({ name = "Reserved", value = Enum.KeyCode.R })
clickCap()
press(Enum.KeyCode.R, true)
assert(binding.value == Enum.KeyCode.Unknown and saves == 2, "Conflicts must not save")
assert(not binding.recording, "Rejected conflicts must leave recording mode")

-- Mouse bindings still use the same capture path.
clickCap()
pressMouse(Enum.UserInputType.MouseButton2, true)
assert(binding.value == Enum.UserInputType.MouseButton2, "Right mouse must bind")
assert(saves == 3, "Mouse binding must save")
assert(binding.keyLabel.Text == "MB2", "Mouse binding uses the cap's short label")

-- A pending cancellation must not clear a newly started recording session.
clickCap()
binding:_stopRecording()
clickCap()
TestPump(0.1)
assert(window._recordingKeybind == binding, "Restarting recording must keep ownership")
press(Enum.KeyCode.P, true)
assert(saves == 4, "Restarted recording must accept a key")

binding:Lock()
clickCap()
assert(not binding.recording, "Locked cap must ignore clicks")
binding:Unlock()

-- Outside recording, the newly saved key must still toggle the window.
Astra.Core.state.userInputService.InputBegan:Fire({
    UserInputType = Enum.UserInputType.Keyboard,
    KeyCode = Enum.KeyCode.P,
}, false)
TestPump(0.6)
assert(window.hidden, "New key must toggle the window after recording")
print("Keybind button capture, Settings updates, conflicts, locking and toggle passed")
