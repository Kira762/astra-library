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

-- Mirrors Window:_buildLockScrim's flow-layout probe: a GuiObject child of
-- any of these joins the layout as an item, so a lock surface that hosts one
-- would adopt the scrim and reflow its own content on every lock.
local function flowLayoutChild(frame)
	for _, child in frame:GetChildren() do
		if
			child:IsA("UIListLayout")
			or child:IsA("UIGridLayout")
			or child:IsA("UITableLayout")
			or child:IsA("UIPageLayout")
		then
			return child
		end
	end
	return nil
end

-- ── bootstrap window + tab ──────────────────────────────────────────────
local window = Astra:CreateWindow({ name = "Guard Invariants" })
TestPump(0.5)
window:Show()
TestPump(0.5)
local tab = window:CreateTab({ name = "Guard" })

local callbacks = { button = 0, toggle = 0, input = 0, dropdown = 0 }

-- 9 lockable + explicit Level 1 probe
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
local group = tab:CreateCollapsibleGroup({
	name = "Expandable Group",
	description = "Guard harness group.",
	elements = {},
})
-- explicit Level 1 probe — only thing that should lock at Mode 1
local minorToggle = tab:CreateToggle({
	name = "Minor Toggle",
	id = "minorToggle",
	lockLevel = 1,
	value = false,
	callback = function() end,
})

-- non-lockable: 7
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
	deleteButton, advancedSlider,
	group, minorToggle,
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
eq(group.lockLevel, 5, "CollapsibleGroups default to remaining tier (5)")
eq(minorToggle.lockLevel, 1, "explicit lockLevel=1 honored")
expect(containsUsage(link.usage, "host:documentation"), "existing usage preserved (host:documentation)")
expect(containsUsage(link.usage, "analytics:read"), "existing usage preserved (analytics:read)")
expect(containsUsage(input.usage, "host:profile"), "scalar usage preserved")

-- ── B: non-lockable excluded ────────────────────────────────────────────
for _, element in { text, divider, stat, inertButton, section, footer } do
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
for _, element in { link, input, dropdown, keybind, toggle, saveButton } do
	expect(not element:IsLocked(), element.elementId .. " must stay unlocked at Mode 1 (auto tier) — got locked")
end
for _, element in { deleteButton, advancedSlider, group } do
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
	linkEl = link,
	groupEl = group, statEl = stat,
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
		-- Overlay, not a layout item: the surface the scrim parents to must
		-- host no flow layout, or the scrim joins it and shoves the surface's
		-- own content on every lock (the compact-row regression).
		local surface = element.lockSurface or element.main
		eq(element.lockScrim.Parent, surface, key .. " scrim parents to the lock surface")
		expect(
			flowLayoutChild(surface) == nil,
			key .. " lock surface hosts no flow layout (the scrim must stay an overlay)"
		)
	end
end
-- reset for later sections
window:SetElementLockMode(1)
TestPump(0.2)

-- ── D2: compact rows — the scrim must not join the row's content flow ───
-- Regression: the scrim parented onto the compact row joined its
-- UIListLayout as an item beside the row's own button, so at Mode 3+ the
-- icon/label squeezed into half the pill and clipped past the row edge.
local rowActions = tab:CreateGroup({ direction = "row" })
local rowButton = rowActions:CreateButton({
	name = "Refresh roster",
	id = "rowButton",
	icon = "refresh-cw",
	callback = function() end,
})
local rowToggle = rowActions:CreateToggle({
	name = "Row toggle",
	id = "rowToggle",
	value = true,
	callback = function() end,
})
local rowLink = rowActions:CreateLink({
	name = "Row link",
	id = "rowLink",
	link = "https://example.com",
})
TestPump(0.2)

local compactRows = {
	rowButton = rowButton,
	rowToggle = rowToggle,
	rowLink = rowLink,
}
for key, element in pairs(compactRows) do
	local row = element.main
	local content = row:FindFirstChild("Content")
	expect(content ~= nil, key .. " compact row keeps an inner content frame")
	eq(content.Size.X.Scale, 1, key .. " content frame spans the row width")
	eq(content.Size.Y.Scale, 1, key .. " content frame spans the row height")
	eq(element.interact.Parent, content, key .. " row surface flows inside the content frame")
	expect(flowLayoutChild(content) ~= nil, key .. " content frame hosts the row's UIListLayout")
	expect(flowLayoutChild(row) == nil, key .. " row itself stays layout-free for overlays")
end

local compactSnapshots = {}
for key, element in pairs(compactRows) do
	local pos = element.interact.Position
	local size = element.interact.Size
	compactSnapshots[key] = {
		pos = { X = pos.X.Offset, Y = pos.Y.Offset },
		size = { X = size.X.Offset, Y = size.Y.Offset },
	}
end
window:SetElementLockMode(5)
TestPump(0.2)
for key, element in pairs(compactRows) do
	expect(element:IsLocked(), key .. " locks at Mode 5")
	expect(element.lockScrim ~= nil, key .. " scrim built")
	expect(element.lockScrim.__props.Visible == true, key .. " scrim visible at Mode 5")
	eq(element.lockScrim.Parent, element.main, key .. " scrim overlays the row instead of flowing beside the button")
	expect(element.lockScrim ~= element.interact, key .. " scrim never replaces the interact surface")
	local before = compactSnapshots[key]
	local pos = element.interact.Position
	local size = element.interact.Size
	eq(pos.X.Offset, before.pos.X, key .. " interact X offset stable across lock")
	eq(pos.Y.Offset, before.pos.Y, key .. " interact Y offset stable across lock")
	eq(size.X.Offset, before.size.X, key .. " interact width stable across lock")
	eq(size.Y.Offset, before.size.Y, key .. " interact height stable across lock")
end
window:SetElementLockMode(1)
TestPump(0.2)
for key, element in pairs(compactRows) do
	expect(not element:IsLocked(), key .. " unlocks back at Mode 1")
end

-- ── E: corner sync — header vs scrim (CollapsibleGroup) ─────────────────
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
-- leave collapsed
group:_setExpanded(false, false)
TestPump(0.1)
window:SetElementLockMode(1)
TestPump(0.1)

-- ── F: controller exempt + locale-bound title ───────────────────────────
window:_buildSettingsUI()
local controlsTab
for _, t in ipairs(window._settingsTabs) do if t.name == "Controls" then controlsTab = t break end end
expect(controlsTab ~= nil, "Controls settings tab exists")
controlsTab:Select()
TestPump(0.6)
local controller = window._elementLockAllToggle
expect(controller ~= nil and controller.__type == "Toggle", "built-in lock uses a Toggle")
eq(controller.usageTag, nil, "controller exempt from lockable usage")
eq(controller.usage, nil, "controller cannot be in Mode 5 lock-all")
eq(controller.flag, nil, "the switch owns no flag — the tier is window state")
eq(window.controls["astra.elementLockMode"], nil, "no control registers the tier's flag")
-- controller must stay usable even at Mode 5
controller:Set(true)
TestPump(0.2)
eq(window:GetElementLockMode(), 5, "switching the controller on selects Mode 5")
expect(not controller:IsLocked(), "controller remains unlocked at Mode 5")
eq(controller._isLockable, false, "controller _isLockable false")
controller:Lock("must remain usable")
expect(not controller:IsLocked(), "manual Lock cannot disable controller")
-- off returns the page to Mode 1
controller:Set(false)
TestPump(0.2)
eq(window:GetElementLockMode(), 1, "switching the controller off selects Mode 1")
eq(controller.value, false, "controller UI stays synchronized")
-- external mode changes drive the switch: on at 5, off below it
window:SetElementLockMode(5)
TestPump(0.2)
eq(controller.value, true, "a host-driven Mode 5 turns the switch on")
window:SetElementLockMode(2)
TestPump(0.2)
eq(controller.value, false, "a host-driven mode below 5 parks the switch off")
window:SetElementLockMode(5)
TestPump(0.2)
expect(not controller:IsLocked(), "Mode 5 cannot lock its own controller")

-- locale binding (the bug class): a token table must never reach TextLabel.Text
expect(type(controller.title.Text) == "string", "controller title Text is a string (not a token table)")
window:RegisterTranslations({ fr = { ["Lock all controls"] = "Tout verrouiller" } })
window:SetLocale("fr")
TestPump(0.2)
eq(controller.title.Text, "Tout verrouiller", "controller title re-resolves on locale change via _bindLocale")
expect(type(controller.title.Text) == "string", "controller title stays a string after the locale switch")
window:SetLocale("en")
TestPump(0.2)

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
