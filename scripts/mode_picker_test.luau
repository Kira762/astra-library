--[[
===== Mode Picker assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

Expected behavior under test:
  * M1 the mode window is enforced at construction: fewer than min_modes
       (floor 3) or more than max_modes (ceiling 5) errors in the house
       message style,
  * M2 a five-mode picker starts on Mode 1 and Get reports index+label,
  * M3 Set snaps to the stop, fires the mode's onEnable then the picker
       callback with (index, label), and clamps out-of-range values,
  * M4 the dot row matches the mode count and rebuilds on add/remove,
  * M5 the knob parks on the first dot's scale at Mode 1 and the last
       dot's scale at the final mode,
  * M6 Reset returns to Mode 1, rolls runtime add/remove back to the
       configured set and fires onReset,
  * M7 AddMode/RemoveMode respect max/min and the optional flag, and
       allow_mode_add_remove = false closes both,
  * M8 with no picker-level description the line follows the selected
       mode's description,
  * M9 the title wears the left icon's RGB while the subtitle keeps the
       default content color.
]]

local function expect(cond, message)
	if not cond then
		error("MODEPICKER FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"MODEPICKER FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

--[[
The stub's Color3 values are plain {R,G,B} tables, so colors compare by
component, never by reference.
]]
local function rgb(color)
	return math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
end

local function eqColor(actual, r, g, b, message)
	local ar, ag, ab = rgb(actual)
	if ar ~= r or ag ~= g or ab ~= b then
		error(
			("MODEPICKER FAIL: %s (got %d,%d,%d, want %d,%d,%d)"):format(message, ar, ag, ab, r, g, b),
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Mode Picker Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Modes" })
TestPump(0.4)

-- M1: the 3..5 window is absolute.
local tooFew = pcall(function()
	tab:CreateModePicker({
		title = "Too few",
		modes = { { label = "A" }, { label = "B" } },
	})
end)
expect(not tooFew, "M1 two modes must error")

local tooMany = pcall(function()
	tab:CreateModePicker({
		title = "Too many",
		modes = {
			{ label = "A" }, { label = "B" }, { label = "C" },
			{ label = "D" }, { label = "E" }, { label = "F" },
		},
	})
end)
expect(not tooMany, "M1 six modes must error")

local clamped = pcall(function()
	tab:CreateModePicker({
		title = "Clamped window",
		min_modes = 1,
		max_modes = 9,
		modes = { { label = "A" }, { label = "B" } },
	})
end)
expect(not clamped, "M1 min_modes/max_modes clamp into 3..5, two modes still error")

-- M2/M3/M5/M8/M9: the working picker.
local enabled = {}
local calls = {}
local picker = tab:CreateModePicker({
	title = "Mode Picker",
	subtitle = "GPT-5.6 Sol",
	left_icon = "zap",
	right_icon = "rotate-ccw",
	left_icon_color = { r = 77, g = 163, b = 255, a = 255 },
	flag = "test.modePicker",
	modes = {
		{ label = "Normal", type = "default", description = "Default mode." },
		{ label = "Fast", type = "dot", description = "Second mode." },
		{ label = "Balanced", type = "dot", description = "Third mode." },
		{
			label = "Advanced",
			type = "dot",
			optional = true,
			description = "Fourth mode.",
		},
		{
			label = "Max",
			type = "dot",
			optional = true,
			description = "Fifth and maximum mode.",
			onEnable = function(index, label)
				table.insert(enabled, { index, label })
			end,
		},
	},
	callback = function(index, label)
		table.insert(calls, { index, label })
	end,
	onReset = function()
		table.insert(calls, { "reset" })
	end,
})
TestPump(0.6)

eq(picker.mode, 1, "M2 initial mode")
local index, label = picker:Get()
eq(index, 1, "M2 Get index")
eq(label, "Normal", "M2 Get label")

-- M4: one dot per stop.
local function dotCount(element)
	local count = 0
	local function walk(inst)
		local props = inst.__props or {}
		local size = props.Size
		if
			props.ClassName == "Frame"
			and size
			and size.X.Offset == 4
			and size.Y.Offset == 4
		then
			count += 1
		end
		for _, child in ipairs(inst:GetChildren()) do
			walk(child)
		end
	end
	walk(element.track)
	return count
end
eq(dotCount(picker), 5, "M4 five dots for five modes")

-- M9: icon RGB drives the title; subtitle keeps the default color.
eqColor(picker.title.TextColor3, 77, 163, 255, "M9 title wears the icon RGB")
eqColor(picker.iconLabel.ImageColor3, 77, 163, 255, "M9 icon wears its configured RGB")
local sr, sg, sb = rgb(picker.subtitleLabel.TextColor3)
expect(not (sr == 77 and sg == 163 and sb == 255), "M9 subtitle keeps default color")

-- M8: the description line follows the selected mode.
eq(picker.descriptionLabel.Text, "Default mode.", "M8 initial description is mode 1's line")

-- M3: Set snaps, fires onEnable then callback, and clamps.
picker:Set(5)
TestPump(0.8)
eq(picker.mode, 5, "M3 Set(5)")
eq(#enabled, 1, "M3 onEnable fired once")
eq(enabled[1][1], 5, "M3 onEnable index")
eq(enabled[1][2], "Max", "M3 onEnable label")
eq(calls[#calls][1], 5, "M3 callback index")
eq(calls[#calls][2], "Max", "M3 callback label")
eq(picker.descriptionLabel.Text, "Fifth and maximum mode.", "M8 description follows the mode")

picker:Set(99)
TestPump(0.8)
eq(picker.mode, 5, "M3 Set clamps above the range")
picker:Set(0)
TestPump(0.8)
eq(picker.mode, 1, "M3 Set clamps below the range")

-- M5: the knob parks on the end dots' scales.
local knobScale = picker.knob.__props.Position.X.Scale
eq(knobScale, 0, "M5 knob at the first dot's scale on Mode 1")
picker:Set(5, true)
TestPump(0.2)
knobScale = picker.knob.__props.Position.X.Scale
eq(knobScale, 1, "M5 knob at the last dot's scale on the final mode")
picker:Set(1, true)
TestPump(0.2)

-- M7: add/remove bounds, optional flag and the kill switch.
local okAdd = picker:AddMode({ label = "Overflow" })
expect(not okAdd, "M7 AddMode at max_modes fails")
local okCore = picker:RemoveMode(1)
expect(not okCore, "M7 non-optional modes cannot be removed")
local okOptional = picker:RemoveMode(5)
expect(okOptional, "M7 optional modes remove")
TestPump(0.4)
eq(#picker.modes, 4, "M7 mode list shrank")
eq(dotCount(picker), 4, "M4 dots rebuild after remove")
local okSecond = picker:RemoveMode(4)
expect(okSecond, "M7 remove down to the floor")
local okFloor = picker:RemoveMode(3)
expect(not okFloor, "M7 RemoveMode at min_modes fails")
eq(#picker.modes, 3, "M7 floor holds at three")
local okBack = picker:AddMode({ label = "Returned", optional = true })
expect(okBack, "M7 AddMode inside the window")
TestPump(0.4)
eq(#picker.modes, 4, "M7 mode list grew")

-- M6: Reset rolls the runtime set back and returns to Mode 1.
picker:Set(3, true)
TestPump(0.4)
picker:Reset()
TestPump(0.8)
eq(picker.mode, 1, "M6 reset returns to Mode 1")
eq(#picker.modes, 5, "M6 reset restores the configured mode set")
eq(dotCount(picker), 5, "M4 dots rebuild after reset")
eq(calls[#calls][1], "reset", "M6 onReset fired")

-- M7: the kill switch closes both directions.
local frozen = tab:CreateModePicker({
	title = "Frozen",
	allow_mode_add_remove = false,
	modes = { { label = "A" }, { label = "B" }, { label = "C" } },
})
TestPump(0.4)
local frozenAdd = frozen:AddMode({ label = "D", optional = true })
expect(not frozenAdd, "M7 AddMode closed by allow_mode_add_remove")
local frozenRemove = frozen:RemoveMode(3)
expect(not frozenRemove, "M7 RemoveMode closed by allow_mode_add_remove")

print("mode picker assertions complete")
