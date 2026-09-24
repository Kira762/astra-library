--[[
Exhaustive regression guard for the three recurring bug classes:

  Lock tiers  — Mode 1 leaves automatically tiered controls unlocked
  Text/locale — SetSubtitle uses Window:_bindLocale (string + updates)
  Layout      — placement preserved, corners mirror, track geometry intact

This is the exhaustive harness referenced by skills/astra-guard. It must
stay green — a red run is a contract violation, not a flake.
]]

local function expect(condition, message)
	if not condition then
		error("GUARD FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(("GUARD FAIL: %s (got %s, want %s)"):format(message, tostring(actual), tostring(wanted)), 0)
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
		error(("GUARD FAIL: %s (got %d,%d,%d, want %d,%d,%d)"):format(message, actualR, actualG, actualB, r, g, b), 0)
	end
end

-- ── bootstrap window + tab ──────────────────────────────────────────────
local window = Astra:CreateWindow({ name = "Guard Invariants" })
TestPump(0.5)
window:Show()
TestPump(0.5)
local tab = window:CreateTab({ name = "Guard" })

local callbacks = { button = 0, toggle = 0, input = 0, dropdown = 0, about = 0 }

-- 12 lockable + explicit Level 1 probe
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
	callback = function() callbacks.input += 1 end,
})
local dropdown = tab:CreateDropdown({
	name = "Theme Selector",
	id = "themeSelector",
	options = { "Light", "Dark" },
	value = "Light",
	callback = function() callbacks.dropdown += 1 end,
})
local keybind = tab:CreateKeybind({ name = "Shortcut", id = "shortcutKey", value = "K" })
local toggle = tab:CreateToggle({
	name = "Create Toggle",
	id = "createToggle",
	value = true,
	lockLevel = 3,
	callback = function() callbacks.toggle += 1 end,
})
local saveButton = tab:CreateButton({
	name = "Save",
	id = "saveButton",
	lockLevel = 3,
	callback = function() callbacks.button += 1 end,
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
		callback = function() callbacks.about += 1 end,
	},
})
local group = tab:CreateCollapsibleGroup({
	name = "Expandable Group",
	description = "Guard harness group.",
	elements = {},
})
local isolated = tab:CreateIsolated({
	name = "Changelog Container",
	elements = {
		{ type = "Changelog", name = "Updates", entries = { { title = "Test", changes = {} } } },
	},
})
-- explicit Level 1 probe — only thing that should lock at Mode 1
local minorToggle = tab:CreateToggle({
	name = "Minor Toggle",
	id = "minorToggle",
	lockLevel = 1,
	value = false,
	callback = function() end,
})

-- non-lockable: 8
local staticAbout = tab:CreateAboutCard({ name = "Static About", rows = {} })
local inertButton = tab:CreateButton({ name = "No Action" })
local text = tab:CreateText({ name = "Section Title", text = "Settings" })
local divider = tab:CreateDivider({ text = "Static divider" })
local stat = tab:CreateStat({ name = "Static value", value = 42 })
local section = tab:CreateSection({ name = "Guard Section" })
local footer = tab:CreateFooter({ parts = { { text = "Guard footer" } } })
local rowGroup = tab:CreateGroup()
TestPump(0.3)
local groupDescriptionText = group.descriptionLabel.Text
local groupHeightBeforeLock = group.main.Size.Y.Offset

-- ── A: lock registry + automatic tiers ──────────────────────────────────
for _, element in {
	link, input, dropdown, keybind, toggle, saveButton,
	deleteButton, advancedSlider, customPicker, aboutCard,
	group, isolated, minorToggle,
} do
	expect(type(element.usageTag) == "string", element.__type .. " is tagged")
	expect(containsUsage(element.usage, element.usageTag), element.__type .. " usage contains its lock tag " .. tostring(element.usageTag))
	expect(element.usageTag == "lockable:astra:" .. element.elementId, element.__type .. " tag uses required namespace got " .. tostring(element.usageTag))
end
eq(toggle.usageTag, "lockable:astra:createToggle", "toggle uses documented usage format")
eq(input.usageTag, "lockable:astra:usernameInput", "input uses explicit id")
eq(minorToggle.usageTag, "lockable:astra:minorToggle", "explicit Level 1 keeps explicit id")
eq(link.lockLevel, 2, "Links default to standard tier (2)")
eq(input.lockLevel, 2, "Inputs default to standard tier (2)")
eq(dropdown.lockLevel, 2, "Dropdowns default to standard tier (2)")
eq(keybind.lockLevel, 2, "Keybinds default to standard tier (2)")
eq(toggle.lockLevel, 3, "Toggles default to important tier (3)")
eq(saveButton.lockLevel, 3, "Buttons default to important tier (3)")
eq(deleteButton.lockLevel, 4, "sensitive lockGroup maps to Level 4")
eq(advancedSlider.lockLevel, 5, "explicit 5 deferred to Mode 5")
eq(customPicker.lockLevel, 3, "ModePickers default to tier 3")
eq(aboutCard.lockLevel, 3, "AboutCard actions default to tier 3")
eq(group.lockLevel, 5, "CollapsibleGroups default to remaining tier (5)")
eq(isolated.lockLevel, 5, "Isolated headers default to remaining tier (5)")
eq(minorToggle.lockLevel, 1, "explicit lockLevel=1 honored")
expect(containsUsage(link.usage, "host:documentation"), "existing usage preserved (host:documentation)")
expect(containsUsage(link.usage, "analytics:read"), "existing usage preserved (analytics:read)")
expect(containsUsage(input.usage, "host:profile"), "scalar usage preserved")
expect(aboutCard.usageTag == "lockable:astra:aboutAction", "AboutCard action id carried onto callback element")

-- ── B: non-lockable excluded ────────────────────────────────────────────
for _, element in { staticAbout, text, divider, stat, inertButton, section, footer } do
	eq(element.usageTag, nil, element.__type .. " has no lock tag")
	eq(element.lockUsage, nil, element.__type .. " has no lock metadata")
	expect(element._isLockable ~= true, element.__type .. " is not lockable via _isLockable")
end
-- Group container itself is non-lockable
eq(rowGroup.usageTag, nil, "Group container has no lock tag")
expect(not inertButton:IsLocked(), "no-callback button not locked")
inertButton:Lock("must not become lockable")
expect(not inertButton:IsLocked(), "Lock is no-op for non-functional button")

-- ── C: cumulative modes — Mode 1 must not lock auto-tiered ──────────────
-- First verify Mode 1 in isolation: only explicit 1 should be locked
window:SetElementLockMode(1)
TestPump(0.1)
expect(minorToggle:IsLocked(), "Mode 1 locks explicit Level 1")
for _, element in { link, input, dropdown, keybind, toggle, saveButton, customPicker, aboutCard } do
	expect(not element:IsLocked(), element.elementId .. " must stay unlocked at Mode 1 (auto tier) — got locked")
end
for _, element in { deleteButton, advancedSlider, group, isolated } do
	expect(not element:IsLocked(), element.elementId .. " must stay unlocked at Mode 1 (higher tier)")
end

-- Now sweep Mode 2..5 cumulative
local managed = table.clone(window._lockableElements)
local function isManaged(el) for _, m in ipairs(managed) do if m == el then return true end end return false end
local previous = {}
for mode = 1, 5 do
	eq(window:SetElementLockMode(mode), mode, "setter accepts Mode " .. tostring(mode))
	TestPump(0.05)
	for _, element in ipairs(managed) do
		local locked = element:IsLocked()
		local expected = element.lockLevel <= mode
		eq(locked, expected, element.elementId .. " follows cumulative level at Mode " .. tostring(mode) .. " (level " .. tostring(element.lockLevel) .. ")")
		if previous[element] then
			expect(locked, element.elementId .. " never unlocks at higher mode")
		end
		previous[element] = locked
	end
end
for _, element in ipairs(managed) do
	expect(element:IsLocked(), "Mode 5 locks every tagged element: " .. tostring(element.usageTag))
end
eq(group.descriptionLabel.Text, groupDescriptionText, "mode locking does not replace description line")
eq(group.main.Size.Y.Offset, groupHeightBeforeLock, "mode locking does not resize expandable group")
expect(group.main.Visible, "mode locking never hides element")

-- clamp
eq(window:SetElementLockMode(99), 5, "mode clamps to ceiling")
eq(window:SetElementLockMode(-1), 1, "mode clamps to floor")
window:SetElementLockMode(1)
TestPump(0.1)

-- ── D: placement invariant — Position/Size/Parent unchanged at Mode 5 ────
local snapshots = {}
local function snapOf(frame) return frame and frame.__props and frame.__props or nil end
local allElements = {
	button = saveButton, toggle = toggle, slider = advancedSlider,
	inputEl = input, dropdownEl = dropdown, keybindEl = keybind,
	linkEl = link, picker = customPicker, about = aboutCard,
	groupEl = group, isolatedEl = isolated, statEl = stat,
	textEl = text, dividerEl = divider, sectionEl = section, footerEl = footer,
}
for key, element in pairs(allElements) do
	local main = element.main
	expect(main ~= nil, key .. " has main")
	local pos = main.Position
	local size = main.Size
	snapshots[key] = {
		pos = { X = { Scale = pos.X.Scale, Offset = pos.X.Offset }, Y = { Scale = pos.Y.Scale, Offset = pos.Y.Offset } },
		size = { X = { Scale = size.X.Scale, Offset = size.X.Offset }, Y = { Scale = size.Y.Scale, Offset = size.Y.Offset } },
		parent = main.Parent,
		visible = main.Visible,
	}
end
window:SetElementLockMode(5)
TestPump(0.3)
for key, element in pairs(allElements) do
	local main = element.main
	local before = snapshots[key]
	local pos = main.Position
	local size = main.Size
	expect(pos.X.Scale == before.pos.X.Scale and pos.X.Offset == before.pos.X.Offset, key .. " Position X unchanged at Mode 5 (guard layout)")
	expect(pos.Y.Scale == before.pos.Y.Scale and pos.Y.Offset == before.pos.Y.Offset, key .. " Position Y unchanged at Mode 5")
	expect(size.X.Scale == before.size.X.Scale and size.X.Offset == before.size.X.Offset, key .. " Size X unchanged at Mode 5")
	expect(size.Y.Scale == before.size.Y.Scale and size.Y.Offset == before.size.Y.Offset, key .. " Size Y unchanged at Mode 5")
	eq(main.Parent, before.parent, key .. " Parent unchanged at Mode 5")
	expect(main.Visible ~= false, key .. " stays visible at Mode 5")
	if element._isLockable == true then
		expect(element.lockScrim ~= nil, key .. " lockScrim built")
		expect(element.lockScrim.__props.Visible == true, key .. " scrim visible at Mode 5")
		eq(element.lockScrim.__props.ZIndex, 60, key .. " scrim ZIndex 60")
	end
end
-- reset for later sections
window:SetElementLockMode(1)
TestPump(0.2)

-- ── E: corner sync — header vs scrim (both containers) ──────────────────
local function cornerOffsets(cornerInstance)
	if not cornerInstance or not cornerInstance.__props then return nil end
	-- corners are stored as individual radius keys on the UICorner instance props
	local tl = cornerInstance.__props.TopLeftRadius
	local tr = cornerInstance.__props.TopRightRadius
	local bl = cornerInstance.__props.BottomLeftRadius
	local br = cornerInstance.__props.BottomRightRadius
	return {
		topLeft = tl and tl.Offset or 0,
		topRight = tr and tr.Offset or 0,
		bottomLeft = bl and bl.Offset or 0,
		bottomRight = br and br.Offset or 0,
	}
end
local function assertCornerPair(element, label, wantExpanded)
	-- force mode so scrim exists, then check expanded vs collapsed
	window:SetElementLockMode(5)
	TestPump(0.1)
	element:_setExpanded(wantExpanded, false)
	TestPump(0.2)
	local header = cornerOffsets(element.headerCorner)
	local scrim = cornerOffsets(element.lockScrimCorner)
	expect(header ~= nil and scrim ~= nil, label .. " has both header and scrim corners")
	if wantExpanded then
		eq(header.topLeft, 8, label .. " expanded header topLeft 8")
		eq(header.topRight, 8, label .. " expanded header topRight 8")
		eq(header.bottomLeft, 0, label .. " expanded header bottomLeft 0")
		eq(header.bottomRight, 0, label .. " expanded header bottomRight 0")
		eq(scrim.topLeft, 8, label .. " expanded scrim topLeft 8")
		eq(scrim.topRight, 8, label .. " expanded scrim topRight 8")
		eq(scrim.bottomLeft, 0, label .. " expanded scrim bottomLeft 0")
		eq(scrim.bottomRight, 0, label .. " expanded scrim bottomRight 0")
	else
		eq(header.topLeft, 8, label .. " collapsed header topLeft 8")
		eq(header.topRight, 8, label .. " collapsed header topRight 8")
		eq(header.bottomLeft, 8, label .. " collapsed header bottomLeft 8")
		eq(header.bottomRight, 8, label .. " collapsed header bottomRight 8")
		eq(scrim.topLeft, 8, label .. " collapsed scrim topLeft 8")
		eq(scrim.topRight, 8, label .. " collapsed scrim topRight 8")
		eq(scrim.bottomLeft, 8, label .. " collapsed scrim bottomLeft 8")
		eq(scrim.bottomRight, 8, label .. " collapsed scrim bottomRight 8")
	end
end
assertCornerPair(group, "CollapsibleGroup", false)
assertCornerPair(group, "CollapsibleGroup", true)
assertCornerPair(isolated, "Isolated", false)
assertCornerPair(isolated, "Isolated", true)
-- leave collapsed
group:_setExpanded(false, false)
isolated:_setExpanded(false, false)
TestPump(0.1)
window:SetElementLockMode(1)
TestPump(0.1)

-- ── F: controller exempt + locale-bound subtitle ─────────────────────────
window:_buildSettingsUI()
local controlsTab
for _, t in ipairs(window._settingsTabs) do if t.name == "Controls" then controlsTab = t break end end
expect(controlsTab ~= nil, "Controls settings tab exists")
controlsTab:Select()
TestPump(0.6)
local controller = window._elementLockModePicker
expect(controller ~= nil and controller.__type == "ModePicker", "built-in lock uses ModePicker")
eq(#controller.modes, 5, "controller has five modes")
eq(controller.minModes, 5, "controller cannot shrink below five")
eq(controller.maxModes, 5, "controller cannot exceed five")
for i, mode in ipairs(controller.modes) do eq(mode.label, "Mode " .. tostring(i), "controller label " .. tostring(i)) end
expect(not controller.allow_mode_add_remove, "controller modes fixed")
eq(controller.usageTag, nil, "controller exempt from lockable usage")
eq(controller.usage, nil, "controller cannot be in Mode 5 lock-all")
eq(controller.flag, "astra.elementLockMode", "controller persists via flag")
expect(window.controls[controller.flag] == controller, "controller in persistence")
local added = controller:AddMode({ label = "Six" })
local removed = controller:RemoveMode(5)
expect(not added and not removed, "fixed controller rejects add/remove")
-- controller must stay unlocked even at Mode 5
controller:Set(5, true)
TestPump(0.2)
expect(not controller:IsLocked(), "controller remains unlocked at Mode 5")
eq(controller._isLockable, false, "controller _isLockable false")
controller:Lock("must remain usable")
expect(not controller:IsLocked(), "manual Lock cannot disable controller")
-- Mode 1 subtitle is unlocked wording and is a string, locale-bound
controller:Set(1, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 1, "controller selects Mode 1")
expect(type(controller.subtitle) == "string", "Mode 1 subtitle is string")
expect(string.find(controller.subtitle, "Mode 1", 1, true) ~= nil, "Mode 1 subtitle mentions Mode 1")
expect(string.find(controller.subtitle, "unlocked", 1, true) ~= nil, "Mode 1 subtitle documents unlocked default")
expect(type(controller.subtitleLabel.Text) == "string", "controller subtitle Text is string (not token table)")
eqColor(controller.fill.BackgroundColor3, 234, 242, 255, "Mode 1 uses lightest blue")
controller:Set(5, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 5, "controller selects Mode 5")
eqColor(controller.fill.BackgroundColor3, 29, 63, 168, "Mode 5 uses darkest blue")
expect(string.find(controller.subtitle, "Mode 5", 1, true) ~= nil, "Mode 5 subtitle obvious")
expect(type(controller.subtitleLabel.Text) == "string", "Mode 5 subtitle Text is string")
expect(not controller:IsLocked(), "Mode 5 cannot lock its own controller")

-- regular ModePicker locale binding (the bug class)
local localePicker = tab:CreateModePicker({
	title = "Locale Picker",
	id = "localePicker",
	modes = { { label = "A" }, { label = "B" }, { label = "C" } },
})
TestPump(0.2)
localePicker:SetSubtitle("Hello world")
expect(type(localePicker.subtitle) == "string", "regular picker subtitle is string after SetSubtitle")
expect(type(localePicker.subtitleLabel.Text) == "string", "regular picker subtitle Text is string")
-- locale update path: RegisterTranslations + SetLocale should re-resolve
window:RegisterTranslations({ fr = { ["Hello world"] = "Bonjour le monde" } })
window:SetLocale("fr")
TestPump(0.2)
eq(localePicker.subtitleLabel.Text, "Bonjour le monde", "regular picker subtitle updates on locale change via _bindLocale")
-- also controller subtitle must be bound — change locale and verify still string
expect(type(controller.subtitleLabel.Text) == "string", "controller subtitle Text stays string after locale switch")
window:SetLocale("en")
TestPump(0.2)

-- controller reset + mode sync
controller:Set(5, true)
TestPump(0.2)
controller.resetButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(window:GetElementLockMode(), 1, "visible reset button returns to Mode 1")
controller:Set(2, true)
TestPump(0.2)
eq(window:GetElementLockMode(), 2, "controller can lower active mode")
eq(controller.mode, 2, "controller UI stays synchronized")

-- ── G: manual vs mode composition + late element ────────────────────────
window:SetElementLockMode(2)
deleteButton:Lock("Manual lock")
window:SetElementLockMode(4)
expect(deleteButton:IsLocked(), "Level 4 mode + manual compose")
deleteButton:Unlock()
expect(deleteButton:IsLocked(), "Unlock cannot bypass active mode lock")
deleteButton:Lock("Manual lock")
window:SetElementLockMode(1)
expect(deleteButton:IsLocked(), "mode decrease cannot clear manual lock")
deleteButton:Unlock()
expect(not deleteButton:IsLocked(), "Unlock clears manual when mode allows")
window:SetElementLockMode(5)
local lateToggle = tab:CreateToggle({ name = "Late control", value = true, lockLevel = 2 })
expect(lateToggle:IsLocked(), "late controls inherit active mode")
eq(lateToggle.value, true, "late registration preserves value")
window:SetElementLockMode(1)
TestPump(0.1)

-- ── H: input guards preserve state while locked ─────────────────────────
window:SetElementLockMode(2)
toggle:Set(true, true)
local toggleValue = toggle.value
local toggleCb = toggle.callback
window:SetElementLockMode(3)
expect(toggle:IsLocked(), "Mode 3 locks toggle")
eq(toggle.value, toggleValue, "locking retains toggle value")
eq(toggle.callback, toggleCb, "locking preserves toggle callback")
local beforeCalls = callbacks.toggle
toggle.interact.MouseButton1Click:Fire()
TestPump(0.1)
eq(toggle.value, toggleValue, "locked toggle ignores click")
eq(callbacks.toggle, beforeCalls, "locked toggle does not run callback")
window:SetElementLockMode(2)
toggle.interact.MouseButton1Click:Fire()
TestPump(0.1)
expect(toggle.value == false, "unlocked toggle still changes")
eq(callbacks.toggle, beforeCalls + 1, "unlocking restores callback")

print("GUARD INVARIANTS PASSED")
