-- The settings shortcut is a required letter-capture element, not a TextBox.
local window = Astra:CreateWindow({ name = "Keybind test" })
TestPump(1)
window:_buildSettingsUI()
assert(window.rfSettings.name == "Overview", "Settings opens information first")
local controls
for _, tab in window._settingsTabs do
    if tab.name == "Controls" then controls = tab end
end
assert(controls, "Purpose-based Controls tab exists")
controls:Select()
TestPump(1)
local field
for _, control in controls.elements do
    if control.name == "Toggle Keybind" then field = control end
end
assert(field and field.__type == "Keybind", "Settings uses the dedicated Keybind")
assert(field.input == nil and field.keyButton.ClassName == "TextButton", "Key capture is not text input")
assert(field.value == "K" and window.settings.toggleKeybind == Enum.KeyCode.K, "Default is a required K")
local saves = 0
window.SaveSettings = function() saves += 1 end
local inputService = Astra.Core.state.userInputService
local function press(key, processed, inputType)
    inputService.InputBegan:Fire({ UserInputType = inputType or Enum.UserInputType.Keyboard, KeyCode = key }, processed == true)
    TestPump(0.05)
end
field.keyButton.MouseButton1Click:Fire()
assert(field.capturing and field.keyButton.Text == "Press A–Z", "Click enters capture")
press(Enum.KeyCode.K)
assert(not window.hidden and not field.capturing and saves == 0, "Capturing the current toggle must not hide or save")
field:Capture()
for _, key in { Enum.KeyCode.Space, Enum.KeyCode.F1, Enum.KeyCode.One, Enum.KeyCode.Backspace, Enum.KeyCode.Unknown } do
    press(key)
    assert(field.capturing and field.value == "K" and saves == 0, "Non-letters cannot bind or clear")
end
press(Enum.KeyCode.Unknown, false, Enum.UserInputType.MouseButton2)
assert(field.capturing and field.value == "K", "Mouse buttons cannot bind")
press(Enum.KeyCode.P, true)
assert(field.value == "K", "Game-processed keys cannot bind")
inputService._focusedTextBox = {}
press(Enum.KeyCode.P)
assert(field.value == "K", "Typing in another text box cannot bind")
inputService._focusedTextBox = nil
press(Enum.KeyCode.P)
assert(field.value == "P" and not field.capturing and saves == 1, "One letter commits once")
assert(window.settings.toggleKeybind == Enum.KeyCode.P and not window.hidden, "Setting remains a KeyCode and capture does not toggle")
assert(field:Set("p") and saves == 1, "Unchanged values normalise without saving")
for _, bad in { "", "none", "MB2", "Space", "AB", "1", " P ", Enum.UserInputType.MouseButton2, Enum.KeyCode.Space } do
    assert(not field:Set(bad) and field.value == "P", "Programmatic invalid bindings leave the letter intact")
end
assert(not field:Set(nil), "Nil cannot clear a required binding")
field:Capture()
press(Enum.KeyCode.Escape)
assert(not field.capturing and field.value == "P", "Escape cancels without clearing")
field:Capture()
field.keyButton.MouseButton1Click:Fire()
assert(not field.capturing, "Click again cancels capture")
field:Capture()
inputService.WindowFocusReleased:Fire()
assert(not field.capturing, "Focus loss cancels capture")
field:Capture()
field:Lock()
assert(not field.capturing and not field:Capture(), "Lock ends and refuses capture")
field:Unlock()
field:Capture()
window.rfSettings:Select()
TestPump(0.6)
assert(not field.capturing and not field:Capture(), "Leaving the tab cancels capture and hidden controls cannot capture")
controls:Select()
TestPump(0.6)
field:Capture()
window:Hide()
TestPump(0.6)
assert(not field.capturing, "Hiding cancels capture")
press(Enum.KeyCode.P)
TestPump(0.6)
assert(not window.hidden, "Bound letter restores the window")
press(Enum.KeyCode.P, true)
assert(not window.hidden, "Processed keys never toggle")
press(Enum.KeyCode.P)
TestPump(0.6)
assert(window.hidden, "The new binding hides the window outside capture")
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Capture layouts" })
local group = tab:CreateGroup({ direction = "column" })
local grouped = group:CreateKeybind({ name = "Grouped", value = "a", flag = "grouped" })
local fold = tab:CreateCollapsibleGroup({ name = "Shortcuts", elements = {
    { type = "Keybind", name = "Primary", value = "B", flag = "primary" },
    { type = "Keybind", name = "Secondary", value = "C", flag = "secondary" },
} })
tab:Select()
TestPump(0.6)
assert(grouped.value == "A" and window.controls.grouped == grouped, "Column keybind registers uppercase flag")
fold:_setExpanded(true, false)
local first, second = fold.elements[1], fold.elements[2]
assert(first:Capture(), "Declarative keybind captures")
assert(second:Capture() and not first.capturing, "Only one capture owner")
fold:_setExpanded(false, false)
assert(not second.capturing and window._keybindCapture == nil, "Collapsing cancels capture")
grouped:Capture()
tab:Remove()
assert(window._keybindCapture == nil, "Removing a tab clears its capture owner")
local manager = Astra.Settings.newManager({ toggleKeybind = Enum.KeyCode.Space })
assert(manager:get("toggleKeybind") == Enum.KeyCode.K, "Invalid initial settings fall back to K")
assert(not manager:set("toggleKeybind", Enum.KeyCode.Space), "Settings validator rejects non-letters")
assert(manager:set("toggleKeybind", "z") and manager:get("toggleKeybind") == Enum.KeyCode.Z, "Settings validator normalises letters")
controls:Select()
TestPump(0.6)
field:Capture()
window:Unload()
assert(window._keybindCapture == nil, "Unload clears capture")
print("KEYBIND: required letters, capture, cancellation, focus, groups, flags and settings validation passed")
