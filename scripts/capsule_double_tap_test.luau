--[[
===== Capsule double tap: the pill folds into the icon-only circle and =====
===== back, one tap still restores the window                        =====
Runs the real Astra bundle (loaded as global `Astra` above) against the mini
Roblox environment from sidebar_sizing_stubs.luau.

The gesture is driven through the stub's real input services: a tap is a
press on the capsule's hit target plus a service `InputEnded`, exactly the
pair `components/chrome.luau` listens for. The harness clock is virtual, so
the paused restore is observed by pumping: two taps in the same breath are a
double tap, and pumping past the window resolves a single tap.

Expected behavior under test:
  * T1 a single tap still restores the window, once the double-tap window
       has passed without a second tap,
  * T2 two taps inside that window are a double tap instead: the window stays
       hidden and the capsule becomes the icon-only circle,
  * T3 the shape changes right to left: the pill's left edge and its vertical
       centre are identical before and after the movement, and only the
       right edge travels,
  * T4 the face follows: the icon ends centred in the circle, the text frame
       is out of the way, and the labels keep a fixed column so the pill's
       own edge clips them instead of re-wrapping them,
  * T5 double-tapping again reverts to the full pill — the same left edge,
       the icon back at its inset, the labels back on screen,
  * T6 the capsule remembers the place it was left in, in either shape, so a
       later fold lands where the user put it,
  * T7 a press that turns into a drag drops the parked restore: the window
       stays hidden and the capsule does not morph,
  * T8 a parked restore never fights a window that showed itself in the
       meantime,
  * T9 a capsule built icon-only starts as the circle and double-taps up into
       the pill, painting the labels in as it widens,
  * T10 with motion off both shapes land on the spot, and the capsule is
       left interactable (no animation left in flight).
]]

local function expect(cond, message)
	if not cond then
		error("CAPSULE DOUBLE TAP FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"CAPSULE DOUBLE TAP FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function near(actual, wanted, message)
	if type(actual) ~= "number" or math.abs(actual - wanted) > 1e-6 then
		error(
			"CAPSULE DOUBLE TAP FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local inputService = game:GetService("UserInputService")
local function mouseButton()
	return { UserInputType = { Name = "MouseButton1" } }
end

--[[
A pointer the test drives. A fresh vector per read, the way the engine
answers: one shared table would make the press's start point and its current
position the same value, so no press would ever cross the drag threshold.
]]
local pointer = { X = 700, Y = 500 }
inputService.GetMouseLocation = function()
	return Vector2.new(pointer.X, pointer.Y)
end

local function movePointer(x, y)
	pointer.X = x
	pointer.Y = y
end

--[[
One tap: press on the capsule's hit target, then release. Both halves are the
service events the component binds, so the drag guard, the gesture window and
the parked restore all run for real.
]]
local function tap(window)
	window.collapsedInteract.InputBegan:Fire(mouseButton(), false)
	inputService.InputEnded:Fire(mouseButton())
end

--[[
The capsule's rectangle, read the way a player sees it: the left edge and the
vertical centre are what a right-to-left shape change has to leave alone.
]]
local function rect(window)
	local main = window.main
	--[[
	The window is anchored at its centre, so the position's offsets are the
	rect's middle and the left edge is half a width back. The scale part of
	the position does not move during a shape change, so comparing these
	offset-space edges compares the rect itself.
	]]
	return {
		left = main.Position.X.Offset - main.Size.X.Offset * main.AnchorPoint.X,
		centerY = main.Position.Y.Offset,
		width = main.Size.X.Offset,
		height = main.Size.Y.Offset,
	}
end

local wideSize = 185
local circleSize = 50

local window = Astra:CreateWindow({
	name = "Capsule double tap",
	configuration = { autoSave = false, autoLoad = false },
})
local tab = window:CreateTab({ name = "Home" })
tab:CreateButton({ name = "Action" })
TestPump(1)

-- T1: a single tap restores, once the window for a second tap has passed.
window:Hide()
TestPump(1.0)
expect(window.hidden and window._collapsedShown, "T1 the window folds to its capsule")
expect(window.showIconOnly == false, "T1 the capsule starts as the full pill")
eq(window.main.Size.X.Offset, wideSize, "T1 ... at the wide capsule's width")

tap(window)
TestPump(0.1)
expect(window.hidden, "T1 one tap does not restore before the gesture window closes")
eq(window.main.Size.X.Offset, wideSize, "T1 ... and does not change the capsule's shape")
TestPump(0.5)
expect(not window.hidden, "T1 the parked restore runs when no second tap claims it")

-- T2/T3/T4: a double tap folds the pill into the circle.
window:Hide()
TestPump(1.0)
local before = rect(window)
tap(window)
tap(window)
TestPump(0.05)
expect(window.hidden, "T2 a double tap changes the capsule instead of restoring")
eq(window.showIconOnly, true, "T2 ... leaving the capsule icon-only")
eq(window.main.Size.X.Offset, circleSize, "T2 ... at the circle's width")
eq(window.main.Size.Y.Offset, 50, "T2 ... and its height")
local after = rect(window)
near(after.left, before.left, "T3 the shape change keeps the pill's left edge")
near(after.centerY, before.centerY, "T3 ... and its vertical centre, so the right edge did the travelling")
near(after.width, circleSize, "T3 ... into the icon-only circle")
eq(window.collapsedIcon.Visible, true, "T4 the circle's face is the icon alone")
near(window.collapsedIcon.AnchorPoint.X, 0.5, "T4 the icon is centred in the circle")
near(window.collapsedIcon.Position.X.Scale, 0.5, "T4 ... by the scale the circle's centre is read from")
eq(window.collapsedTextFrame.Visible, false, "T4 the text frame is out of the way")
eq(
	window.collapsedTitle.Size.X.Offset,
	wideSize - 60,
	"T4 the labels keep the wide capsule's fixed column"
)
eq(
	window.collapsedSubtitle.Size.X.Offset,
	wideSize - 60,
	"T4 ... so the pill's own edge clips them instead of re-wrapping them"
)

-- T5: a second double tap reverts to the full pill.
tap(window)
tap(window)
TestPump(0.05)
expect(window.hidden, "T5 reverting does not restore the window")
eq(window.showIconOnly, false, "T5 the capsule is the full pill again")
eq(window.main.Size.X.Offset, wideSize, "T5 ... at the wide width")
local reverted = rect(window)
near(reverted.left, before.left, "T5 the revert keeps the same left edge")
near(reverted.centerY, before.centerY, "T5 ... and the same vertical centre")
near(window.collapsedIcon.Position.X.Offset, 16, "T5 the icon is back at its inset")
near(window.collapsedIcon.AnchorPoint.X, 0, "T5 ... anchored to its inset again")
eq(window.collapsedTextFrame.Visible, true, "T5 the labels are back on screen")
eq(window.collapsedTitle.TextTransparency, 0, "T5 ... painted in")
eq(window.collapsedSubtitle.TextTransparency, 0.5, "T5 ... at the face's own strengths")

-- T6: the place the capsule was left in is the place it comes back to.
local parked = window.main.Position
window:Show()
TestPump(1.0)
window:Hide()
TestPump(1.0)
near(window.main.Position.X.Offset, parked.X.Offset, "T6 the fold returns the capsule to where the player left it")

-- T7: a press that turns into a drag drops the parked restore.
movePointer(700, 500)
tap(window)
expect(window._capsuleTapToken ~= nil, "T7 the first tap parks a restore")
window.collapsedInteract.InputBegan:Fire(mouseButton(), false)
movePointer(740, 540)
TestPump(0.1)
inputService.InputEnded:Fire(mouseButton())
TestPump(0.5)
expect(window.hidden, "T7 a drag drops the parked restore")
eq(window.main.Size.X.Offset, wideSize, "T7 ... and leaves the capsule's shape alone")

-- T8: a parked restore never fights a window that already showed itself.
tap(window)
window:Show()
TestPump(1.0)
TestPump(0.5)
expect(not window.hidden, "T8 a window that showed itself keeps its state")

-- T9: a host that starts icon-only begins as the circle and taps up to the pill.
window.settings.antiWindowDuplicate = false
local circleWindow = Astra:CreateWindow({
	name = "Icon only capsule",
	showIconOnly = true,
	configuration = { autoSave = false, autoLoad = false },
})
circleWindow:CreateTab({ name = "Home" })
TestPump(1.0)
circleWindow:Hide()
TestPump(1.0)
eq(circleWindow.main.Size.X.Offset, circleSize, "T9 a host's icon-only capsule is the circle")
eq(circleWindow.collapsedTextFrame.Visible, false, "T9 ... with no text on it")
local circleBefore = rect(circleWindow)
tap(circleWindow)
tap(circleWindow)
TestPump(0.05)
eq(circleWindow.main.Size.X.Offset, wideSize, "T9 a double tap opens it into the pill")
near(rect(circleWindow).left, circleBefore.left, "T9 ... keeping its left edge")
eq(circleWindow.collapsedTextFrame.Visible, true, "T9 ... and painting the labels in")
eq(circleWindow.collapsedTitle.TextTransparency, 0, "T9 ... for the widening pill to reveal")
eq(circleWindow.showIconOnly, false, "T9 ... so the flag follows the shape")
circleWindow:Unload()
TestPump(0.3)

-- T10: with motion off both shapes land on the spot, still interactable.
window:Hide()
TestPump(1.0)
Astra.Motion.setProfile("instant")
local instant = rect(window)
tap(window)
tap(window)
TestPump(0.05)
eq(window.main.Size.X.Offset, circleSize, "T10 with motion off the circle lands in one step")
eq(window.showIconOnly, true, "T10 ... with the flag following")
near(rect(window).left, instant.left, "T10 ... and the left edge kept")
expect(not window.animating, "T10 nothing is left in flight")
tap(window)
tap(window)
TestPump(0.05)
eq(window.main.Size.X.Offset, wideSize, "T10 and the pill comes back in one step")
expect(not window.animating, "T10 with nothing left in flight either way")

-- A held morph: the second double tap cannot land mid-movement, so the
-- capsule is never left half-shaped and half-settled.
Astra.Motion.setProfile("normal")
local tweenService = Astra.Core.state.tweenService
local createTween = tweenService.Create
local held
tweenService.Create = function(service, target, info, props)
	local tween = createTween(service, target, info, props)
	if target == window.main and props.Size then
		local play = tween.Play
		tween.Play = function()
			held = { finish = play, tween = tween }
		end
	end
	return tween
end
tap(window)
tap(window)
TestPump(0.05)
expect(held ~= nil and window.animating, "T10 a movement in flight holds the capsule")
eq(window.main.Size.X.Offset, wideSize, "T10 ... on the shape it is leaving")
tap(window)
tap(window)
TestPump(0.05)
eq(window.main.Size.X.Offset, wideSize, "T10 a tap mid-movement changes nothing")
expect(window.hidden, "T10 ... and cannot restore the window either")
held.finish()
tweenService.Create = createTween
TestPump(0.05)
expect(not window.animating, "T10 the movement settles once it lands")
eq(window.main.Size.X.Offset, circleSize, "T10 ... on the new shape")

print("CAPSULE DOUBLE TAP: the pill folds into the icon-only circle and back, one tap still restores")
