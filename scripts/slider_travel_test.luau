-- ===== slider travel assertions: the knob stays inside its track ==========
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The knob's centre is placed in track-local pixels (handle.Position.X's
-- offset, anchor half), so every measurement below is anchor-independent and
-- reads the same under the stubs and under Roblox.
--
-- Expected behavior under test:
--   * S1 at the top of the range the knob's capsule sits wholly inside the
--        track: its centre travels only within [halfWidth, travel -
--        halfWidth], so it can no longer overlap the track's end — and with
--        it the card's right edge and stroke — at max,
--   * S2 the same clamp holds at the bottom of the range,
--   * S3 the fill's right edge is the knob's centre at any value, so the bar
--        never peeks out from under the capsule,
--   * S4 holding the knob (the wider held size) keeps the clamp, because the
--        travel follows the held width.

local function expect(cond, message)
	if not cond then
		error("SLIDER TRAVEL FAIL: " .. tostring(message), 0)
	end
end

local function near(actual, wanted, message)
	expect(
		math.abs(actual - wanted) < 0.5,
		message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")"
	)
end

local window = Astra:CreateWindow({ name = "Slider Travel Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 100 })
TestPump(0.6)

local function travel()
	return slider.track.AbsoluteSize.X
end

local function centre()
	return slider.handle.Position.X.Offset
end

local function half()
	return slider.handle.AbsoluteSize.X / 2
end

local function checkClamped(where)
	local centreX, halfWidth, travelWidth = centre(), half(), travel()
	expect(
		centreX - halfWidth >= -0.01,
		"S1/S2 the knob stays inside the track at " .. where .. " (left, centre " .. tostring(centreX)
			.. " half " .. tostring(halfWidth) .. ")"
	)
	expect(
		centreX + halfWidth <= travelWidth + 0.01,
		"S1/S2 the knob stays inside the track at " .. where .. " (right, centre " .. tostring(centreX)
			.. " half " .. tostring(halfWidth) .. " travel " .. tostring(travelWidth) .. ")"
	)
end

local function checkFillUnderKnob(where)
	near(slider.progress.Size.X.Offset, centre(), "S3 the fill ends at the knob's centre at " .. where)
end

-- ===== S1: max value =======================================================

checkClamped("max")
checkFillUnderKnob("max")

-- ===== S2: min value =======================================================

slider:Set(0)
TestPump(0.6)
checkClamped("min")
checkFillUnderKnob("min")

-- ===== S3: a middle value ==================================================

slider:Set(50)
TestPump(0.6)
checkClamped("mid")
checkFillUnderKnob("mid")

-- ===== S4: the held (wider) knob keeps the clamp ===========================

slider:Set(100)
TestPump(0.6)
slider:_setHeld(true)
TestPump(0.5)
checkClamped("max while held")
slider:_setHeld(false)
TestPump(0.5)
checkClamped("max after release")

window:Unload()
TestPump(0.2)

print("SLIDER TRAVEL: all assertions passed")
