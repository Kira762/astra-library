--[[
Drag handle: the detached pill under the window (`components/drag.luau`).

The handle is created `Visible = false` and the window owns the moment it
becomes reachable. Before this suite's fix the window only ever turned it
*on* in one place (the minimise settle, 0.5s after folding), so in the
normal expanded state the hitbox was invisible, MouseEnter/MouseLeave could
never fire and the pill never showed — not on a hover, not when the window
was moved. The assertions below pin the states that were missing:

  H1 the first show's settle makes the handle reachable, pill unseen,
  H2 hovering the handle reveals it (and leaving returns it to the idle hint),
  H3 moving the window by its topbar brings the pill out for the move and
     leaves it resting at the idle look when the move ends,
  H4 the resting pill stays centred, 22px below the window's bottom edge,
  H5 a press that never crosses the drag threshold is a click: no pill,
  H6 the handle can itself drag the window (grab look, window follows),
  H7 hide parks the handle and the next show hands it back unseen,
  H8 minimise and expand both leave the handle reachable,
  H9 close takes it off the screen for good.

The stub's input services are driven directly: `InputBegan`/`InputEnded`
are fired on the frames the window listens to, and `GetMouseLocation` is
patched so the pointer can actually travel (the stub answers the viewport
centre otherwise, and a drag that never leaves its 4px threshold is never
a drag). The stub cannot model "an invisible GUI receives no input", so
the reachability assertions read `Visible` — that is the flag the engine
gates the input on, and the flag that used to be false for the life of an
expanded window.

The stub's inert layout engine does not handle AnchorPoint, so the drag
offset the window computes is not the engine's; the assertions therefore
check that the window travelled *by the pointer's delta* and that the pill
stayed 22px under it, both of which hold whatever the offset is.
]]

local function expect(cond, message)
	if not cond then
		error("DRAG HANDLE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"DRAG HANDLE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function near(actual, wanted, tolerance, message)
	if math.abs(actual - wanted) > tolerance then
		error(
			"DRAG HANDLE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. " ±" .. tostring(tolerance) .. ")",
			0
		)
	end
end

local function samePosition(actual, expected, message)
	if actual.X.Scale ~= expected.X.Scale or actual.X.Offset ~= expected.X.Offset
		or actual.Y.Scale ~= expected.Y.Scale or actual.Y.Offset ~= expected.Y.Offset then
		error("DRAG HANDLE FAIL: " .. message .. " (position mismatch)", 0)
	end
end

local function mouseButton()
	return { UserInputType = { Name = "MouseButton1" } }
end

local window = Astra:CreateWindow({
	name = "Drag handle",
	configuration = { autoSave = false, autoLoad = false },
})
window:CreateTab({ name = "Home" })
TestPump(0.2)
window:Show()
TestPump(1.2)

local handle = window.drag.drag
local pill = window.drag.dragCosmetic

--[[
The stub's services are read through the library's own state so the test
drives exactly the instances the window bound to. `services` is a local
in the stubs, so the public handle is `Astra.Core.state`.
]]
local state = Astra.Core.state
local inputService = state.userInputService
local realGetMouseLocation = inputService.GetMouseLocation
local pointer = Vector2.new(960, 540)
--[[
A fresh vector per read, the way the engine answers: handing out one
shared table would make the window's `startMousePos` and its current
pointer the same table, so the gesture's travel would read as zero and
no press would ever cross the drag threshold.
]]
inputService.GetMouseLocation = function()
	return Vector2.new(pointer.X, pointer.Y)
end

local function movePointer(x, y)
	pointer.X = x
	pointer.Y = y
end

-- H1: the expanded window offers its handle, and the pill itself is unseen.
expect(window.hidden == false and window.animating == false, "H1 the window is shown and settled")
eq(handle.Visible, true, "H1 the handle is reachable in the normal expanded state")
eq(pill.BackgroundTransparency, 1, "H1 the untouched pill is still invisible")
eq(pill.Size.X.Offset, 0, "H1 the untouched pill has no width to show")

-- H2: hover reveal — the state the missing `Visible` used to make unreachable.
handle.MouseEnter:Fire()
TestPump(0.3)
eq(pill.BackgroundTransparency, 0.5, "H2 hovering shows the pill")
eq(pill.Size.X.Offset, 64, "H2 the hovered pill grows to 64px")
handle.MouseLeave:Fire()
TestPump(0.3)
eq(pill.BackgroundTransparency, 0.7, "H2 leaving returns the pill to its idle hint")
eq(pill.Size.X.Offset, 48, "H2 the idle pill rests at 48px")

--[[
H3: a topbar move brings the pill out for the length of the move.

The window's target is the pointer plus the offset the press grabbed it
by, read from the public geometry (the grip formula the topbar drag
documents). Reaching it exactly is what proves the move ran to its
settled position rather than the pill merely twitching.
]]
local function grabOffset(mouseX, mouseY)
	return Vector2.new(
		window.main.AbsolutePosition.X + window.main.AbsoluteSize.X * window.main.AnchorPoint.X - mouseX,
		window.main.AbsolutePosition.Y + window.main.AbsoluteSize.Y * window.main.AnchorPoint.Y - mouseY
	)
end

local topbarGrab = grabOffset(700, 500)
movePointer(700, 500)
window.topbar.InputBegan:Fire({
	UserInputType = { Name = "MouseButton1" },
	Position = { X = 700, Y = 500 },
}, false)
TestPump(0.1)
eq(pill.BackgroundTransparency, 0.7, "H3 the press alone leaves the pill at its resting look")
eq(pill.Size.X.Offset, 48, "H3 the press alone does not grow the pill")

movePointer(760, 540)
TestPump(1.2)
eq(handle.Visible, true, "H3 the handle stays reachable during the move")
eq(pill.BackgroundTransparency, 0.5, "H3 moving the window brings the pill out")
eq(pill.Size.X.Offset, 64, "H3 the pill brightens to the move look")
near(window.main.Position.X.Offset, 760 + topbarGrab.X, 2, "H3 the window lands where the press grabbed it (X)")
near(window.main.Position.Y.Offset, 540 + topbarGrab.Y, 2, "H3 the window lands where the press grabbed it (Y)")

-- H4: the pill stays centred under the window, 22px below its bottom edge.
samePosition(
	handle.Position,
	UDim2.new(
		window.main.Position.X.Scale,
		window.main.Position.X.Offset,
		window.main.Position.Y.Scale,
		window.main.Position.Y.Offset + window.main.Size.Y.Offset / 2 + 22
	),
	"H4 the pill rides 22px below the window's bottom edge"
)

inputService.InputEnded:Fire(mouseButton())
TestPump(0.5)
eq(pill.BackgroundTransparency, 0.7, "H3 the pill settles to its idle hint when the move ends")
eq(pill.Size.X.Offset, 48, "H3 the resting pill is the 48px idle hint")
eq(handle.Visible, true, "H3 the handle is still reachable after the move")
eq(window.main.Position.X.Offset, window.drag.drag.Position.X.Offset, "H4 the two are still in step")

-- H5: a press that never moves is a click, not a move — no pill, no travel.
local resting = window.main.Position
window.topbar.InputBegan:Fire({
	UserInputType = { Name = "MouseButton1" },
	Position = { X = 760, Y = 540 },
}, false)
TestPump(0.2)
inputService.InputEnded:Fire(mouseButton())
TestPump(0.5)
eq(pill.BackgroundTransparency, 0.7, "H5 a click leaves the resting look alone")
samePosition(window.main.Position, resting, "H5 a click does not move the window")

-- H6: the handle itself drags the window (the grab path).
local handleGrab = grabOffset(760, 540)
window.drag.dragInteract.InputBegan:Fire(mouseButton(), false)
TestPump(0.2)
eq(pill.BackgroundTransparency, 0, "H6 grabbing the handle shows the grab look")
eq(pill.Size.X.Offset, 56, "H6 the grabbed pill is the 56px grab size")
--[[
A hand-placed target well inside the window's clamp range: the point is
to see the handle drive the window, not to test "Keep window on screen"
(that clamping has its own coverage elsewhere).
]]
movePointer(500, 300)
TestPump(1.2)
near(window.main.Position.X.Offset, 500 + handleGrab.X, 2, "H6 the window follows the handle's drag")
near(window.main.Position.Y.Offset, 300 + handleGrab.Y, 2, "H6 the follow holds on Y too")
inputService.InputEnded:Fire(mouseButton())
TestPump(0.5)
eq(pill.BackgroundTransparency, 0.7, "H6 releasing the handle settles the pill")
expect(handle.Visible == true, "H6 the handle stays reachable after its own drag")

-- H7: a hide parks the handle; the next show hands it back unseen.
window:Hide()
TestPump(1.0)
eq(window.hidden, true, "H7 hide reaches its resting state")
eq(handle.Visible, false, "H7 hiding takes the handle off the screen")
eq(pill.BackgroundTransparency, 1, "H7 the pill is parked, not left at its last look")
eq(pill.Size.X.Offset, 0, "H7 the parked pill has no width")

window:Show()
TestPump(1.2)
eq(window.hidden, false, "H7 show restores the window")
eq(handle.Visible, true, "H7 the restored window hands the handle back")
eq(pill.BackgroundTransparency, 1, "H7 the restored handle waits unseen for the pointer")
handle.MouseEnter:Fire()
TestPump(0.3)
eq(pill.BackgroundTransparency, 0.5, "H7 the restored handle still reveals on hover")
handle.MouseLeave:Fire()
TestPump(0.3)

-- H8: both directions of the minimise keep the handle reachable.
window:ToggleMinimise()
TestPump(1.2)
eq(window.minimised, true, "H8 the window folds to its bar")
eq(handle.Visible, true, "H8 the folded window keeps its handle reachable")
samePosition(
	handle.Position,
	UDim2.new(
		window.main.Position.X.Scale,
		window.main.Position.X.Offset,
		window.main.Position.Y.Scale,
		window.main.Position.Y.Offset + window.layout.topbarHeight / 2 + 22
	),
	"H8 the folded handle sits under the bar"
)
window:ToggleMinimise()
TestPump(1.2)
eq(window.minimised, false, "H8 the window expands again")
eq(handle.Visible, true, "H8 the expanded window offers the handle again")
samePosition(
	handle.Position,
	UDim2.new(
		window.main.Position.X.Scale,
		window.main.Position.X.Offset,
		window.main.Position.Y.Scale,
		window.main.Position.Y.Offset + window.main.Size.Y.Offset / 2 + 22
	),
	"H8 the expanded handle is back under the full window"
)

-- H9: close takes it off the screen with the window.
window:Close()
TestPump(1.0)
eq(window.unloaded, true, "H9 close tears the window down")
eq(handle.Visible, false, "H9 the handle leaves with the window")
eq(pill.BackgroundTransparency, 1, "H9 the closed window's pill is parked")

inputService.GetMouseLocation = realGetMouseLocation
print("DRAG HANDLE: reachability, hover reveal, move reveal and every exit passed")
