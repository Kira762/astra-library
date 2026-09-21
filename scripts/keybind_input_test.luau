-- The settings shortcut is a required, editable one-letter TextBox.
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
assert(field.input and field.input.ClassName == "TextBox", "Key capture uses an editable TextBox")
assert(field.input.Size.X.Offset == 34, "Key input is only one-letter wide")
assert(field.descriptionLabel == nil, "Keybind has no description row")
assert(field.value == "K" and window.settings.toggleKeybind == Enum.KeyCode.K, "Default is a required K")

local saves = 0
window.SaveSettings = function() saves += 1 end

-- Focusing the field clears only the editing buffer; typing a letter commits
-- it, normalises it, and releases capture without toggling the window.
field.input.Focused:Fire()
assert(field.capturing and field.input.Text == "", "focus enters one-letter editing")
field.input.Text = "p"
TestPump(0.05)
assert(field.value == "P" and not field.capturing and saves == 1, "typed letter commits once")
assert(field.input.Text == "P", "committed letter remains visible")
assert(not window.hidden, "editing does not hide the window")

-- A pasted string is reduced to one letter; invalid text is rejected without
-- clearing the required current value.
field.input.Focused:Fire()
field.input.Text = "AB"
TestPump(0.05)
assert(field.value == "A" and #field.input.Text == 1, "multi-letter input is reduced to one letter")
local beforeInvalid = field.value
field.input.Focused:Fire()
field.input.Text = "1"
assert(field.capturing and field.value == beforeInvalid, "invalid input keeps capture and current value")
field.input.FocusLost:Fire()
assert(not field.capturing and field.input.Text == beforeInvalid, "invalid edit restores the previous letter")

-- Public capture still supports keyboard input for hosts and for the menu
-- setting. The focused keybind is allowed through the global input guard.
field:Capture()
local inputService = Astra.Core.state.userInputService
inputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, false)
TestPump(0.05)
assert(field.value == "P" and not field.capturing, "programmatic capture accepts a letter")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "settings remains a KeyCode")

field:Capture()
for _, key in { Enum.KeyCode.Space, Enum.KeyCode.F1, Enum.KeyCode.One, Enum.KeyCode.Backspace, Enum.KeyCode.Unknown } do
    inputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = key }, false)
    TestPump(0.05)
    assert(field.capturing and field.value == "P", "non-letters cannot bind or clear")
end
inputService.InputBegan:Fire({ UserInputType = Enum.KeyCode.Unknown, KeyCode = Enum.KeyCode.Unknown }, false)
assert(field.capturing and field.value == "P", "non-keyboard input cannot bind")
inputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape }, false)
assert(not field.capturing and field.value == "P", "Escape cancels without clearing")

assert(field:Set("p") and saves == 3, "unchanged values normalise without saving")
for _, bad in { "", "none", "MB2", "Space", "AB", "1", " P ", Enum.UserInputType.MouseButton2, Enum.KeyCode.Space } do
    assert(not field:Set(bad) and field.value == "P", "programmatic invalid bindings leave the letter intact")
end
assert(not field:Set(nil), "Nil cannot clear a required binding")

-- Capture cancellation follows window focus, lock, tab and visibility changes.
field:Capture()
inputService.WindowFocusReleased:Fire()
assert(not field.capturing, "focus loss cancels capture")
field:Capture()
field:Lock()
assert(not field.capturing and not field:Capture(), "lock ends and refuses capture")
field:Unlock()
field:Capture()
window.rfSettings:Select()
TestPump(0.6)
assert(not field.capturing and not field:Capture(), "leaving the tab cancels capture")
controls:Select()
TestPump(0.6)
field:Capture()
window:Hide()
TestPump(0.6)
assert(not field.capturing, "hiding cancels capture")

local tab = window:CreateTab({ name = "Capture layouts" })
local group = tab:CreateGroup({ direction = "column" })
local grouped = group:CreateKeybind({ name = "Grouped", value = "a", flag = "grouped" })
local fold = tab:CreateCollapsibleGroup({ name = "Shortcuts", elements = {
    { type = "Keybind", name = "Primary", value = "B", flag = "primary" },
    { type = "Keybind", name = "Secondary", value = "C", flag = "secondary" },
} })
tab:Select()
window:Show()
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
window:Unload()
print("KEYBIND: editable one-letter field, capture, cancellation, groups and settings validation passed")
