--[[ 
===== Title-bar search reveal: the field grows out of the search action's =====
===== side and folds back into it                                         =====
Runs the real Astra bundle (loaded as global `Astra` above) against the mini
Roblox environment from sidebar_sizing_stubs.luau.

Harness tweens play to their end inside `Play`, so a reveal is invisible to
an assertion that reads the pill afterwards. This suite holds the pill's own
tween instead (the same trick the capsule suite uses for the window's fold):
`Play` is swapped for a no-op, which leaves the field on the first frame of
its movement with the target still readable off the tween.

Expected behavior under test:
  * R1 the field is built flat and hidden, so its first open animates like
       every other one instead of appearing at a resting width,
  * R2 opening shows it collapsed against the action side and starts one
       movement that targets the free space between the title and the
       toolbar actions,
  * R3 that growth is one-way: the field's right edge is identical in the
       start geometry and in the tween's target, so only its left edge
       moves — it expands right to left,
  * R4 the surface's own fill rides the same tween, so the pill and its
       glass arrive as one piece,
  * R5 the movement landing puts the field at its resting geometry and
       clears the direction flag,
  * R6 closing folds it back the same way and leaves the field on screen
       until the fold ends — the pill hides on the completion, never
       before the movement finishes,
  * R7 a reopen while the field is still folding continues from the width
       showing rather than jumping flat and growing again,
  * R8 with motion off nothing tweens: the field lands at rest on the spot
       and hides on the spot when it closes,
  * R9 the text box is sized from the field's resting width, so it scales
       with the pill instead of being re-cut on every frame.
]]

local function expect(cond, message)
	if not cond then
		error("SEARCH REVEAL FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"SEARCH REVEAL FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function near(actual, wanted, message)
	if type(actual) ~= "number" or math.abs(actual - wanted) > 1e-6 then
		error(
			"SEARCH REVEAL FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Search reveal" })
local tab = window:CreateTab({ name = "Home" })
tab:CreateButton({ name = "Action" })
TestPump(1)

--[[
The search action's side and the free space the field may occupy, measured
the way `components/search.luau` measures it: from the rendered title and
action bounds, with the same 16px title gap, 12px action gap and 260px cap.
]]
local function geometry()
	local topbar = window.topbar
	local titleRight = window.titleContainer.AbsolutePosition.X
		+ window.titleContainer.AbsoluteSize.X
		- topbar.AbsolutePosition.X
	local rightLimit = window.searchAction.action.AbsolutePosition.X - topbar.AbsolutePosition.X - 12
	local restWidth = math.min(260, math.max(0, rightLimit - (titleRight + 16)))
	return rightLimit, restWidth
end

-- The pill's movement is held, never played: the assertions read the frame a
-- real open would show before its tween advances.
local tweenService = Astra.Core.state.tweenService
local createTween = tweenService.Create
local held
local function holdSearchTween()
	tweenService.Create = function(service, target, info, props)
		local tween = createTween(service, target, info, props)
		if target == window.searchPill and props.Size then
			local play = tween.Play
			tween.Play = function() end
			held = { tween = tween, info = info, props = props, play = play }
		end
		return tween
	end
end
local function releaseSearchTween()
	local entry = held
	held = nil
	expect(entry ~= nil, "a held movement should be in flight")
	entry.play()
	return entry
end

-- R1: nothing of the field exists before search is opened, and no movement
-- is in flight.
eq(window.searchPill, nil, "R1 the field is only built when search opens")
eq(window._searchReveal, nil, "R1 no movement is in flight before search opens")

local rightLimit, restWidth = geometry()
expect(restWidth > 0, "R0 the harness leaves the field room to expand into")

-- R2/R3/R4: the open.
holdSearchTween()
window.searchAction.callback()
TestPump(0.05)

expect(window._searching, "R2 the search action opens the field")
eq(window.searchPill.Visible, true, "R2 the field is shown while it opens")
eq(window.searchPill.Size.X.Offset, 0, "R2 the open starts folded flat against the action side")
eq(window.searchPill.Position.X.Offset, rightLimit, "R2 ... whose left edge sits on the field's right edge")
eq(window.searchPill.Size.Y.Offset, 35, "R2 the field keeps its compact height")
eq(window._searchReveal, "open", "R2 the field records the movement it is in")
expect(held ~= nil, "R2 the open starts a movement")
eq(held.props.Size.X.Offset, restWidth, "R2 ... that grows the field into the free space")
eq(held.props.Size.Y.Offset, 35, "R2 ... without changing its height")
eq(held.props.Position.X.Offset, rightLimit - restWidth, "R2 ... landing on the free space's left edge")
near(held.info.Time, Astra.Motion.spec("smooth").Time, "R2 the reveal plays the surface-move spec")

-- R3: one-way growth -- the right edge is the same at the start and at the end.
eq(
	held.props.Position.X.Offset + held.props.Size.X.Offset,
	window.searchPill.Position.X.Offset + window.searchPill.Size.X.Offset,
	"R3 only the left edge moves: the field's right edge is pinned, so it expands right to left"
)

-- R4: the surface's fill arrives with the movement, not before it.
eq(held.props.BackgroundTransparency, 0.9, "R4 the surface fill rides the reveal")
eq(window.searchPill.BackgroundTransparency, 1, "R4 ... and is not switched on before the movement starts")

-- R9: the text box is sized from the resting width while the pill is still
-- flat, so it scales with the pill instead of being re-cut every frame.
eq(window.searchInput.Position.X.Offset, 36, "R9 the text box keeps its leading inset")
eq(
	window.searchInput.Size.X.Offset,
	-math.min(48, restWidth),
	"R9 the text box is sized from the field's resting width"
)

-- R5: the movement lands.
releaseSearchTween()
TestPump(0.05)
eq(window.searchPill.Size.X.Offset, restWidth, "R5 the landed reveal leaves the field at its resting width")
eq(window.searchPill.Position.X.Offset, rightLimit - restWidth, "R5 ... at its resting left edge")
eq(window.searchPill.BackgroundTransparency, 0.9, "R5 ... with its fill in")
eq(window._searchReveal, nil, "R5 the landed movement clears the direction flag")

-- R6: the close folds it back, on screen until the movement ends.
holdSearchTween()
window.searchAction.callback()
TestPump(0.05)
expect(window.searchPill.Visible, "R6 the field stays on screen while it folds")
eq(window._searchReveal, "close", "R6 the close records the movement it is in")
expect(held ~= nil, "R6 the close starts a movement")
eq(held.props.Size.X.Offset, 0, "R6 ... that folds the field flat")
eq(held.props.Position.X.Offset, rightLimit, "R6 ... back onto the action side")
eq(held.props.BackgroundTransparency, 1, "R6 ... the surface fill leaving with it")
near(held.info.Time, Astra.Motion.spec("exit").Time, "R6 the fold plays the dismissal spec")
releaseSearchTween()
TestPump(0.05)
eq(window.searchPill.Visible, false, "R6 the field hides when the fold ends")
eq(window._searchReveal, nil, "R6 the landed fold clears the direction flag")

-- R7: a reveal that reverses mid-flight continues from the width showing.
holdSearchTween()
window.searchAction.callback()
TestPump(0.05)
window.searchPill.Size = UDim2.fromOffset(90, 35) -- one frame of the reveal
window.searchAction.callback() -- close while it is still opening
TestPump(0.05)
eq(window._searchReveal, "close", "R7 closing mid-reveal takes over the movement")
window.searchPill.Size = UDim2.fromOffset(40, 35) -- the fold has progressed
window.searchPill.Position = UDim2.new(0, rightLimit - 40, 0.5, 0)
window.searchAction.callback() -- reopen while it is still folding
TestPump(0.05)
eq(window.searchPill.Size.X.Offset, 40, "R7 the field reopens from the width it was showing")
eq(window.searchPill.Position.X.Offset, rightLimit - 40, "R7 ... with its right edge where it belongs")
eq(held.props.Size.X.Offset, restWidth, "R7 ... and grows back into the free space")
eq(window.searchPill.Visible, true, "R7 the field is on screen for the new reveal")

-- R8: motion off -- no tweens, so both directions land on the spot.
Astra.Motion.setProfile("instant")
window.searchAction.callback()
TestPump(0.05)
eq(window.searchPill.Visible, false, "R8 with motion off the field hides the moment it closes")
eq(window.searchPill.Size.X.Offset, 0, "R8 ... folded flat in one step")
eq(window._searchReveal, nil, "R8 ... with nothing left in flight")
window.searchAction.callback()
TestPump(0.05)
eq(window.searchPill.Size.X.Offset, restWidth, "R8 with motion off the field opens in one step")
eq(window.searchPill.Position.X.Offset, rightLimit - restWidth, "R8 ... at its resting geometry")
eq(window.searchPill.BackgroundTransparency, 0.9, "R8 ... with its fill already in")
eq(window._searchReveal, nil, "R8 nothing stays in flight when nothing tweens")

-- Back to the library's own profile: the fold still settles and hides.
Astra.Motion.setProfile("snappy")
tweenService.Create = createTween
window.searchAction.callback()
TestPump(0.4)
eq(window.searchPill.Visible, false, "R8 the field folds and hides again once motion returns")
eq(window._searchReveal, nil, "R8 the settled fold leaves no movement behind")

print("SEARCH REVEAL: the title-bar field expands right to left, folds back and hides when it lands")
