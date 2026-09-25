--[[
Runtime coverage for the cumulative Elements Lock System.

The test pins automatic usage metadata, the five cumulative tiers, state and
callback preservation, input guards, late element registration, the built-in
five-mode controller, its fixed color ramp and its Mode 5 escape path.
]]

local function expect(condition, message)
	if not condition then
		error("ELEMENT LOCK FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"ELEMENT LOCK FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function containsUsage(value, tag)
	if type(value) == "string" then
		return value == tag
	end
	if type(value) == "table" then
		return table.find(value, tag) ~= nil
	end
	return false
end

local function eqColor(color, r, g, b, message)
	local actualR = math.floor(color.R * 255 + 0.5)
	local actualG = math.floor(color.G * 255 + 0.5)
	local actualB = math.floor(color.B * 255 + 0.5)
	if actualR ~= r or actualG ~= g or actualB ~= b then
		error(
			("ELEMENT LOCK FAIL: %s (got %d,%d,%d, want %d,%d,%d)"):format(
				message,
				actualR,
				actualG,
				actualB,
				r,
				g,
				b
			),
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Element Lock Test" })
TestPump(0.5)
window:Show()
TestPump(0.5)
local tab = window:CreateTab({ name = "Controls" })

local callbacks = { button = 0, toggle = 0, input = 0, dropdown = 0, about = 0 }
local link = tab:CreateLink({
	name = "Help Link",
	id = "helpLink",
	usage = { "host:documentation", "analytics:read" },
	link = "https://example.com/help",
})
local input = tab:CreateInput({
	name = "Username",
	id = "usernameInput",
	usage = "host:profile",
	value = "committed",
	callback = function()
		callbacks.input += 1
	end,
})
local dropdown = tab:CreateDropdown({
	name = "Theme Selector",
	id = "themeSelector",
	options = { "Light", "Dark" },
	value = "Light",
	callback = function()
		callbacks.dropdown += 1
	end,
})
local keybind = tab:CreateKeybind({ name = "Shortcut", id = "shortcutKey", value = "K" })
local toggle = tab:CreateToggle({
	name = "Create Toggle",
	id = "createToggle",
	value = true,
	lockLevel = 3,
	callback = function()
		callbacks.toggle += 1
	end,
})
local saveButton = tab:CreateButton({
	name = "Save",
	id = "saveButton",
	lockLevel = 3,
	callback = function()
		callbacks.button += 1
	end,
})
local deleteButton = tab:CreateButton({
	name = "Delete",
	id = "deleteButton",
	lockGroup = "sensitive",
	callback = function() end,
})
local advancedSlider = tab:CreateSlider({
	name = "Advanced Slider",
	id = "advancedSlider",
	lockLevel = 5,
	range = { 0, 100 },
	value = 40,
})
local customPicker = tab:CreateModePicker({
	title = "Custom Picker",
	id = "customPicker",
	lockLevel = 3,
	modes = { { label = "A" }, { label = "B" }, { label = "C" } },
})
local aboutCard = tab:CreateAboutCard({
	name = "About",
	rows = { { label = "Version", value = "1" } },
	action = {
		id = "aboutAction",
		usage = "host:about-action",
		name = "Open details",
		callback = function()
			callbacks.about += 1
		end,
	},
})
local staticAbout = tab:CreateAboutCard({ name = "Static About", rows = {} })
local group = tab:CreateCollapsibleGroup({
	name = "Expandable Group",
	description = "Click to expand without losing the values inside.",
	elements = {},
})
local isolated = tab:CreateIsolated({
	name = "Changelog Container",
	elements = {
		{ type = "Changelog", name = "Updates", entries = { { title = "Test", changes = {} } } },
	},
})
local inertButton = tab:CreateButton({ name = "No Action" })
local text = tab:CreateText({ name = "Section Title", text = "Settings" })
local divider = tab:CreateDivider({ text = "Static divider" })
local stat = tab:CreateStat({ name = "Static value", value = 42 })
local duplicateInputA = tab:CreateInput({ name = "Duplicate", value = "A" })
local duplicateInputB = tab:CreateInput({ name = "Duplicate", value = "B" })
TestPump(0.3)
local groupDescriptionText = group.descriptionLabel.Text
local groupHeightBeforeLock = group.main.Size.Y.Offset

-- All exposed functional controls receive a stable public lock usage tag.
for _, element in {
	link,
	input,
	dropdown,
	keybind,
	toggle,
	saveButton,
	deleteButton,
	advancedSlider,
	customPicker,
	aboutCard,
	group,
	isolated,
	duplicateInputA,
	duplicateInputB,
} do
	expect(type(element.usageTag) == "string", element.__type .. " is tagged")
	expect(containsUsage(element.usage, element.usageTag), element.__type .. " usage contains its lock tag")
	expect(element.usageTag == "lockable:astra:" .. element.elementId, element.__type .. " tag uses the required namespace")
end

eq(toggle.usageTag, "lockable:astra:createToggle", "toggle uses the documented usage format")
eq(input.usageTag, "lockable:astra:usernameInput", "input uses its explicit element id")
eq(link.lockLevel, 2, "Links default to the standard tier")
eq(input.lockLevel, 2, "Inputs default to the standard tier")
eq(dropdown.lockLevel, 2, "Dropdowns default to the standard tier")
eq(keybind.lockLevel, 2, "Keybinds default to the standard tier")
eq(toggle.lockLevel, 3, "Toggles default to the important-actions tier")
eq(saveButton.lockLevel, 3, "Buttons default to the important-actions tier")
eq(deleteButton.lockLevel, 4, "sensitive lockGroup maps to Level 4")
eq(advancedSlider.lockLevel, 5, "explicit levels can defer a control to Mode 5")
eq(customPicker.lockLevel, 3, "Mode Pickers default to the important-actions tier")
eq(aboutCard.lockLevel, 3, "About Card actions default to the important-actions tier")
eq(group.lockLevel, 5, "Collapsible Groups default to the remaining tier")
eq(isolated.lockLevel, 5, "Isolated changelog headers default to the remaining tier")
expect(containsUsage(link.usage, "host:documentation"), "existing usage value is preserved")
expect(containsUsage(link.usage, "analytics:read"), "all existing usage values are preserved")
expect(containsUsage(input.usage, "host:profile"), "existing scalar usage is preserved")
eq(duplicateInputA.elementId, "duplicate", "generated ids begin with a normalized name")
eq(duplicateInputB.elementId, "duplicate2", "duplicate generated ids stay unique per window")
expect(aboutCard.usageTag == "lockable:astra:aboutAction", "About Card action id and usage are carried onto its callback element")

-- Static elements and buttons without real actions stay out of the registry.
for _, element in { staticAbout, text, divider, stat, inertButton } do
	eq(element.usageTag, nil, element.__type .. " has no lock tag")
	eq(element.lockUsage, nil, element.__type .. " has no lock metadata")
end
expect(not inertButton:IsLocked(), "a no-callback button is not locked")
inertButton:Lock("must not become lockable")
expect(not inertButton:IsLocked(), "Lock is a no-op for a non-functional button")

local managed = table.clone(window._lockableElements)
local previous = {}
for mode = 1, 5 do
	eq(window:SetElementLockMode(mode), mode, "mode setter accepts Mode " .. tostring(mode))
	for _, element in ipairs(managed) do
		local locked = element:IsLocked()
		local expected = element.lockLevel <= mode
		eq(locked, expected, element.elementId .. " follows its cumulative level at Mode " .. tostring(mode))
		if previous[element] then
			expect(locked, element.elementId .. " never unlocks at a higher mode")
		end
		previous[element] = locked
	end
end
for _, element in ipairs(managed) do
	expect(element:IsLocked(), "Mode 5 locks every element carrying " .. tostring(element.usageTag))
end
eq(group.descriptionLabel.Text, groupDescriptionText, "mode locking does not replace a description line")
eq(group.main.Size.Y.Offset, groupHeightBeforeLock, "mode locking does not resize an expandable group")
expect(group.main.Visible, "mode locking never hides the element")
expect(group.lockScrim.Visible, "locked elements show a visible disabled scrim")
eq(window:SetElementLockMode(99), 5, "mode setter clamps to the five-mode ceiling")
eq(window:SetElementLockMode(-1), 1, "mode setter clamps to Mode 1")

-- Mode flips neither rewrite callbacks nor reset committed values/selections.
window:SetElementLockMode(2)
toggle:Set(true, true)
local toggleCallback = toggle.callback
local toggleValue = toggle.value
window:SetElementLockMode(3)
expect(toggle:IsLocked(), "Mode 3 locks the toggle")
eq(toggle.value, toggleValue, "locking retains the toggle's changed value")
eq(toggle.callback, toggleCallback, "locking preserves the toggle callback function")
local beforeToggleCalls = callbacks.toggle
toggle.interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(toggle.value, toggleValue, "a locked toggle ignores user interaction")
eq(callbacks.toggle, beforeToggleCalls, "a locked toggle does not run its callback")
window:SetElementLockMode(2)
expect(not toggle:IsLocked(), "lowering the mode unlocks only the controls above its tier")
toggle.interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(toggle.value, false, "an unlocked toggle still changes normally")
eq(callbacks.toggle, beforeToggleCalls + 1, "unlocking restores the original callback")

eq(dropdown.value[1], "Light", "dropdown selected state remains intact across the mode matrix")

-- An open dropdown remains expanded and selection/callback state is unchanged.
window:SetElementLockMode(1)
dropdown:_open()
TestPump(0.2)
local dropdownOpenHeight = dropdown.main.Size.Y.Offset
local dropdownCallback = dropdown.callback
local dropdownCallsBefore = callbacks.dropdown
window:SetElementLockMode(2)
expect(dropdown:IsLocked(), "Mode 2 locks dropdown interaction")
expect(dropdown._isOpen, "locking does not close an open dropdown")
eq(dropdown.main.Size.Y.Offset, dropdownOpenHeight, "locking preserves the open dropdown layout")
eq(dropdown.value[1], "Light", "locking retains the dropdown selection")
eq(dropdown.callback, dropdownCallback, "locking preserves the dropdown callback")
dropdown._optionFrames[2].interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(dropdown.value[1], "Light", "a locked dropdown ignores option clicks")
eq(callbacks.dropdown, dropdownCallsBefore, "a locked dropdown cannot run its callback")
window:SetElementLockMode(1)
dropdown._optionFrames[2].interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(dropdown.value[1], "Dark", "unlocking restores dropdown selection")
eq(callbacks.dropdown, dropdownCallsBefore + 1, "unlocking restores the same dropdown callback")

-- Locking an input cancels focus, not its draft or committed value.
window:SetElementLockMode(1)
local inputCallback = input.callback
local inputCallbacksBefore = callbacks.input
local focused = true
input.input.IsFocused = function()
	return focused
end
input.input.ReleaseFocus = function()
	focused = false
	input.input.FocusLost:Fire()
end
input.input.Text = "uncommitted"
local inputWidthBeforeLock = input.input.Size.X.Offset
window:SetElementLockMode(2)
expect(input:IsLocked(), "Mode 2 locks a standard input")
eq(input.value, "committed", "locking does not change the committed input value")
eq(input.input.Text, "uncommitted", "locking preserves the visible edit buffer")
eq(input.input.Size.X.Offset, inputWidthBeforeLock, "locking does not resize the input")
eq(callbacks.input, inputCallbacksBefore, "locking never fires the input callback")
eq(input.callback, inputCallback, "locking preserves the input callback function")
expect(not focused, "locking ends active text focus")
input.input.Focused:Fire()
eq(input.input.Text, "uncommitted", "a locked input preserves its draft and cannot recommit it")

-- Callback buttons are guarded before they can run while locked.
window:SetElementLockMode(3)
expect(saveButton:IsLocked(), "Mode 3 locks important action buttons")
local buttonCallback = saveButton.callback
local buttonCallsBefore = callbacks.button
saveButton.interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(callbacks.button, buttonCallsBefore, "a locked button cannot fire its callback")
eq(saveButton.callback, buttonCallback, "button callback remains attached while locked")
window:SetElementLockMode(2)
saveButton.interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(callbacks.button, buttonCallsBefore + 1, "the same callback works after unlocking")

window:SetElementLockMode(3)
local aboutCallback = aboutCard.action.callback
aboutCard.actionButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(callbacks.about, 0, "a locked About Card action cannot fire")
eq(aboutCard.action.callback, aboutCallback, "About Card action callback remains attached")
window:SetElementLockMode(2)
aboutCard.actionButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(callbacks.about, 1, "unlocking restores the About Card action callback")

-- Manual locks compose with mode locks instead of being erased by mode changes.
window:SetElementLockMode(2)
deleteButton:Lock("Manual lock")
window:SetElementLockMode(4)
expect(deleteButton:IsLocked(), "the Level 4 mode and manual source compose")
deleteButton:Unlock()
expect(deleteButton:IsLocked(), "Unlock cannot bypass an active mode lock")
deleteButton:Lock("Manual lock")
window:SetElementLockMode(1)
expect(deleteButton:IsLocked(), "a mode decrease cannot clear a manual lock")
deleteButton:Unlock()
expect(not deleteButton:IsLocked(), "Unlock clears the manual source when the mode allows input")

-- Elements created during Mode 5 are locked immediately without losing state.
window:SetElementLockMode(5)
local lateToggle = tab:CreateToggle({ name = "Late control", value = true, lockLevel = 2 })
expect(lateToggle:IsLocked(), "late functional controls inherit the active mode")
eq(lateToggle.value, true, "late registration preserves the initial value")

-- Built-in Settings exposes one fixed, exempt five-mode controller.
window:_buildSettingsUI()
local controlsTab
for _, settingsTab in ipairs(window._settingsTabs) do
	if settingsTab.name == "Controls" then
		controlsTab = settingsTab
		break
	end
end
expect(controlsTab ~= nil, "built-in Controls settings tab exists")
controlsTab:Select()
TestPump(0.6)
local controller = window._elementLockModePicker
expect(controller ~= nil and controller.__type == "ModePicker", "built-in lock system uses the ModePicker element")
eq(#controller.modes, 5, "controller has exactly five modes")
eq(controller.minModes, 5, "controller cannot shrink below five modes")
eq(controller.maxModes, 5, "controller cannot exceed five modes")
for index, mode in ipairs(controller.modes) do
	eq(mode.label, "Mode " .. tostring(index), "controller label at index " .. tostring(index))
	expect(type(mode.description) == "string" and #mode.description > 0, "mode " .. tostring(index) .. " has description")
end
expect(not controller.allow_mode_add_remove, "controller modes are fixed")
expect(not controller:IsLocked(), "Mode Picker controller remains unlocked in Mode 5")
eq(controller.usageTag, nil, "the controller is exempt from lockable usage metadata")
eq(controller.usage, nil, "the controller cannot be included in Mode 5's lock-all set")
eq(controller.flag, "astra.elementLockMode", "controller mode persists with the config")
expect(window.controls[controller.flag] == controller, "controller joins config persistence")
local added = controller:AddMode({ label = "Six" })
local removed = controller:RemoveMode(5)
expect(not added and not removed, "fixed controller rejects add/remove")

controller:Set(1, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 1, "controller selects Mode 1")
eqColor(controller.fill.BackgroundColor3, 234, 242, 255, "Mode 1 uses the lightest blue")
controller:Set(5, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 5, "controller selects Mode 5")
eqColor(controller.fill.BackgroundColor3, 29, 63, 168, "Mode 5 uses the darkest blue")
expect(string.find(controller.subtitle, "Mode 5", 1, true) ~= nil, "subtitle makes the active mode obvious")
expect(not controller:IsLocked(), "Mode 5 cannot lock its own mode controller")
for _, element in ipairs(window._lockableElements) do
	if element.usageTag then
		expect(element:IsLocked(), "Mode 5 locks every tagged element after settings build: " .. element.usageTag)
	end
end
controller:Lock("must remain usable")
expect(not controller:IsLocked(), "manual Lock cannot disable the system controller")
controller.resetButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(window:GetElementLockMode(), 1, "the visible Mode 5 reset button returns to Mode 1")
controller:Set(2, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 2, "the unlocked controller can always lower the active mode")
eq(controller.mode, 2, "controller UI remains synchronized with the window mode")
window:SetElementLockMode(4)
TestPump(0.2)
eq(controller.mode, 4, "external admin mode changes synchronize the built-in controller")
window:SetElementLockMode(2)
eq(controller.mode, 2, "external admin can lower the controller mode again")

window:Unload()
TestPump(0.5)
eq(window._elementLockModePicker, nil, "window teardown releases the built-in controller reference")
eq(window:SetElementLockMode(3), 3, "mode API remains safe after teardown")
print("ELEMENT LOCK: usage metadata, cumulative modes, guarded input, state preservation and controller passed")
