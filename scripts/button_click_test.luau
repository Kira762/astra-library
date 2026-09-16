-- ===== button click assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The Button element drove its whole press choreography through the motion
-- service (`motion.spec(...)`) but never required it, so every click died on
-- `attempt to index nil with 'spec'` before the user's callback could run —
-- the element built fine and only exploded on the first tap. No suite ever
-- fired a click on a Button, which is how it shipped.
--
-- The harness invokes the click handler on the CLI main thread, where
-- `task.wait` cannot yield, so the press and the release both land inside the
-- one `Fire()` call. The choreography is therefore pinned by the *sequence*
-- of values written to the animated instances, not by a mid-press snapshot.
--
-- Expected behavior under test:
--   * B1 the built-in tap affordance exists, so the press animation really is
--     on the path being exercised (a missing glyph would skip it silently),
--   * B2 clicking the card runs the user's callback without erroring,
--   * B3 the press lands then springs back: the tap glyph dips to 0.78 and
--     returns to 1, the card nudges to -26 and settles at -20, the stroke
--     opens fully and closes on its resting token — every one of those is a
--     separate `motion.spec` call,
--   * B4 a second click repeats the whole cycle,
--   * B5 the compact row's button (the Group layout) clicks the same way — it
--     has its own click handler with its own `motion.spec` calls,
--   * B6 the settings surface exposes the persistence module it required,
--   * B7 grouped buttons sort custom icon, title, then tap glyph explicitly.

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

-- [[Every write the tweens make to an animated property, in order.]]
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
expect(button.tapScale ~= nil, "B1 the tap glyph and its scale exist, so the press animation is exercised")

local scaleLog = record(button.tapScale, "Scale", function(inst)
	return inst.Scale
end)
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

expectSequence(scaleLog, { 0.78, 1 }, "B3 the tap glyph dipped and sprang back")
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
expectSequence(scaleLog, { 0.78, 1, 0.78, 1 }, "B4 the second click pressed and released again")
eq(button.tapScale.Scale, 1, "B4 the glyph rests at full scale")

-- ===== B5: the compact row's button =======================================
-- [[A row Group lays its children out as compact rows, which is the]]
-- [[element's second click handler — it has its own `motion.spec` calls.]]

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
expect(compactButton.tapScale ~= nil, "B5 the compact row carries the tap glyph too")

local compactScaleLog = record(compactButton.tapScale, "Scale", function(inst)
	return inst.Scale
end)
local compactStrokeLog = record(compactButton.stroke, "Transparency", function(inst)
	return inst.Transparency
end)

local ok3, err3 = pcall(function()
	compactButton.interact.MouseButton1Click:Fire()
end)
expect(ok3, "B5 clicking the compact row must not error (got " .. tostring(err3) .. ")")
eq(compactClicks, 1, "B5 the compact callback ran once")
expectSequence(compactScaleLog, { 0.78, 1 }, "B5 the compact row pressed and released")
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

-- ===== B7: grouped tap glyph trails the title =============================
-- The stubs do not run Roblox's layout engine. Pin its sorting input as well
-- as the sibling orders: LayoutOrder values alone do nothing under Name sort.
local function expectTrailingTap(element)
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
	if element.tapIcon then
		eq(element.tapIcon.Parent, element.interact, "B7 tap glyph participates in the layout")
		expect(element.title.LayoutOrder < element.tapIcon.LayoutOrder, "B7 built-in glyph is right of title")
	end
	if element.iconLabel then
		expect(element.iconLabel.LayoutOrder < element.title.LayoutOrder, "B7 custom icon remains left of title")
	end
end

expectTrailingTap(compactButton)
expectTrailingTap(group:CreateButton({ name = "With icon", icon = "house" }))
local withoutTap = group:CreateButton({ name = "No tap", tapIcon = false })
expectTrailingTap(withoutTap)
expect(withoutTap.tapIcon == nil, "B7 tapIcon=false still opts out")
eq(button.tapIcon.Parent, button.main, "B7 full-card glyph stays outside the compact layout")
eq(button.tapIcon.Position.X.Scale, 1, "B7 full-card glyph remains at the right edge")

print("B1-B7 OK")
