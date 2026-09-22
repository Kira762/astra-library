-- Button callbacks and press motion survive permanent removal of the trailing cursor.
local function expect(cond, message)
	if not cond then
		error("BUTTON FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"BUTTON FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

-- Every write the tweens make to an animated property, in order.
local function record(instance, propName, read)
	local log = {}
	instance:GetPropertyChangedSignal(propName):Connect(function()
		table.insert(log, read(instance))
	end)
	return log
end

local function joined(log)
	local parts = {}
	for _, value in ipairs(log) do
		table.insert(parts, tostring(value))
	end
	return table.concat(parts, " -> ")
end

local function expectSequence(log, wanted, message)
	local parts = {}
	for _, value in ipairs(wanted) do
		table.insert(parts, tostring(value))
	end
	if joined(log) ~= table.concat(parts, " -> ") then
		error("BUTTON FAIL: " .. message .. " (got " .. joined(log) .. ", want " .. table.concat(parts, " -> ") .. ")", 0)
	end
end

local window = Astra:CreateWindow({ name = "Button Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Buttons" })

local clicks = 0
local button = tab:CreateButton({
	name = "Card Button",
	icon = "hand-tap",
	callback = function()
		clicks = clicks + 1
	end,
})
TestPump(0.4)

-- ===== B1: the tap affordance is really there ==============================

expect(button ~= nil, "B1 CreateButton returned an element")
expect(button.interact ~= nil, "B1 the card exposes its click surface")
expect(button.tapScale == nil and button.tapIcon == nil, "B1 no trailing cursor or scale is built")

local widthLog = record(button.main, "Size", function(inst)
	return inst.Size.X.Offset
end)
local strokeLog = record(button.stroke, "Transparency", function(inst)
	return inst.Transparency
end)

-- ===== B2: the click runs the callback =====================================

local ok, err = pcall(function()
	button.interact.MouseButton1Click:Fire()
end)
expect(ok, "B2 clicking the card must not error (got " .. tostring(err) .. ")")
eq(clicks, 1, "B2 the callback ran once")

-- ===== B3: the press landed and sprang back ================================

expectSequence(widthLog, { -26, -20 }, "B3 the card nudged in and settled back")
expectSequence(
	strokeLog,
	{ 1, window.theme.ElementStrokeTransparency },
	"B3 the stroke opened and closed on its resting token"
)

-- ===== B4: a second click repeats the cycle ================================

local ok2, err2 = pcall(function()
	button.interact.MouseButton1Click:Fire()
end)
expect(ok2, "B4 a second click must not error (got " .. tostring(err2) .. ")")
eq(clicks, 2, "B4 the callback ran twice")

--[[
===== B5: the compact row's button =======================================
A row Group lays its children out as compact rows, which is the
element's second click handler — it has its own `motion.spec` calls.
]]

local group = tab:CreateGroup({ direction = "row" })
local compactClicks = 0
local compactButton = group:CreateButton({
	name = "Compact Button",
	callback = function()
		compactClicks = compactClicks + 1
	end,
})
TestPump(0.4)

expect(compactButton.compact == true, "B5 the grouped button uses the compact row")
expect(compactButton.tapScale == nil and compactButton.tapIcon == nil, "B5 no compact cursor is built")

local compactStrokeLog = record(compactButton.stroke, "Transparency", function(inst)
	return inst.Transparency
end)

local ok3, err3 = pcall(function()
	compactButton.interact.MouseButton1Click:Fire()
end)
expect(ok3, "B5 clicking the compact row must not error (got " .. tostring(err3) .. ")")
eq(compactClicks, 1, "B5 the compact callback ran once")
expectSequence(
	compactStrokeLog,
	{ 1, window.theme.ElementStrokeTransparency },
	"B5 the compact stroke opened and closed"
)

-- ===== B6: the settings surface wires its persistence module ==============

local settings = Astra.Settings
expect(type(settings) == "table", "B6 Astra.Settings exists")
expect(
	type(settings.persistence) == "table",
	"B6 Astra.Settings.persistence is the module it required, got " .. type(settings.persistence)
)
expect(type(settings.persistence.read) == "function", "B6 the persistence module exposes read")

--[[
===== B7: optional leading icons still precede the title =================
The stubs do not run Roblox's layout engine. Pin its sorting input as well
as the sibling orders: LayoutOrder values alone do nothing under Name sort.
]]
local function expectLeadingIcon(element)
	local layout
	for _, child in ipairs(element.interact:GetChildren()) do
		if child.ClassName == "UIListLayout" then
			layout = child
			break
		end
	end
	expect(layout ~= nil, "B7 compact button has a horizontal layout")
	eq(layout.SortOrder, Enum.SortOrder.LayoutOrder, "B7 layout honors explicit sibling order")
	eq(layout.FillDirection, Enum.FillDirection.Horizontal, "B7 content runs left to right")
	eq(element.title.Parent, element.interact, "B7 title participates in the layout")
	expect(element.tapIcon == nil, "B7 trailing icons cannot be restored")
	if element.iconLabel then
		expect(element.iconLabel.LayoutOrder < element.title.LayoutOrder, "B7 custom icon remains left of title")
	end
end

expectLeadingIcon(compactButton)
expectLeadingIcon(group:CreateButton({ name = "With icon", icon = "house" }))
local legacyOverride = group:CreateButton({ name = "Legacy override", tapIcon = "mouse-pointer-click" })
expectLeadingIcon(legacyOverride)
local fullOverride = tab:CreateButton({ name = "Legacy full", tapIcon = true })
expect(fullOverride.tapIcon == nil and fullOverride.tapScale == nil, "Legacy props cannot bring back the cursor")
print("B1-B7 OK")
