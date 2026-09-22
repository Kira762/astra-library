--[[
===== switch (toggle) geometry assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

The element used to park its knob 3px from the end of a track twice as long
as it needed to be, leaving 22px of empty track on the other side — the
"gap" that reads as lopsided in both states. It also drew the track's sheen
overlay after the knob at the same ZIndex, so the sheen landed on top of the
knob and washed its lower half.

Expected behavior under test:
  * S1 the switch is driven by one set of metrics: the track is a pill and
  * S7 the indicator glow is built when the switch turns on (an off switch
    carries no shadow instance), while on/off states render as before.
       every clearance the knob shows is the same number (top/bottom and the
       parked end),
  * S2 the two resting states are exact mirrors of each other, and both
       states keep the knob inside the track,
  * S3 the knob's travel is the track minus the knob and both insets, so
       neither state can leave an oversized empty slab beside the knob,
  * S4 the sheen overlay sits under the knob (ZIndex order), so it tints the
       track instead of the knob,
  * S5 animating the switch lands on exactly the same positions the element
       was built with — pressing it cannot drift into its own uneven spot,
  * S6 the compact row's label budget follows the track width.
]]

local function expect(cond, message)
	if not cond then
		error("SWITCH FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"SWITCH FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local state = Astra.Core.state

local window = Astra:CreateWindow({ name = "Switch Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Switch" })
local offToggle = tab:CreateToggle({ name = "Off Switch", value = false })
local onToggle = tab:CreateToggle({ name = "On Switch", value = true })
TestPump(0.4)

--[[
The switch lives inside the element frame (full) or the clickable row
(compact); find it by shape rather than by path so both layouts work.
]]
local function findSwitch(element)
	--[[
	The knob is the frame anchored at (0, 0.5) inside its own track: find
	that pair, whatever element the switch is embedded in.
	]]
	local found
	local function walk(inst)
		if found then
			return
		end
		local props = inst.__props or {}
		local size = props.Size
		if size then
			for _, child in inst:GetChildren() do
				local childProps = child.__props or {}
				local childSize = childProps.Size
				local anchor = childProps.AnchorPoint
				if
					childProps.ClassName == "Frame"
					and childSize
					and anchor
					and anchor.X == 0
					and anchor.Y == 0.5
					and childSize.X.Scale == 0
					and size.X.Scale == 0
					and childSize.X.Offset > 0
					and childSize.X.Offset < size.X.Offset
					and childSize.Y.Offset < size.Y.Offset
				then
					found = { track = inst, knob = child }
					return
				end
			end
		end
		for _, child in inst:GetChildren() do
			walk(child)
		end
	end
	walk(element.main)
	return found
end

local function clearance(switch, stateName)
	local trackSize = switch.track.__props.Size
	local knobProps = switch.knob.__props
	local knobSize = knobProps.Size
	local position = knobProps.Position
	--[[
	The knob is anchored (0, 0.5) inside the track, so its left edge is
	scale * trackWidth + offset and its parked end decides which gap
	collapses.
	]]
	local left = position.X.Scale * trackSize.X.Offset + position.X.Offset
	local right = trackSize.X.Offset - (left + knobSize.X.Offset)
	return {
		name = stateName,
		trackWidth = trackSize.X.Offset,
		trackHeight = trackSize.Y.Offset,
		knobWidth = knobSize.X.Offset,
		knobHeight = knobSize.Y.Offset,
		left = left,
		right = right,
		top = (trackSize.Y.Offset - knobSize.Y.Offset) / 2,
		bottom = (trackSize.Y.Offset - knobSize.Y.Offset) / 2,
		position = position,
		zIndex = knobProps.ZIndex,
	}
end

local offSwitch = findSwitch(offToggle)
local onSwitch = findSwitch(onToggle)
expect(offSwitch and offSwitch.knob, "S1 the off element builds a track with a knob")
expect(onSwitch and onSwitch.knob, "S1 the on element builds a track with a knob")

local off = clearance(offSwitch, "off")
local on = clearance(onSwitch, "on")

-- ===== S1: metrics, and a track that is a pill =====

eq(off.trackWidth, on.trackWidth, "S1 both states use the same track width")
eq(off.trackHeight, on.trackHeight, "S1 ... and the same track height")
eq(off.knobWidth, on.knobWidth, "S1 ... and the same knob width")
eq(off.knobHeight, on.knobHeight, "S1 ... and the same knob height")

expect(off.trackHeight > off.knobHeight, "S1 the knob leaves a visible rim")
expect(off.knobWidth > off.knobHeight, "S1 the knob is a pill, not a circle")
expect(off.top == off.bottom, "S1 the knob is vertically centred (equal top and bottom clearance)")
expect(off.top > 0, "S1 the knob does not touch the track's stroke")
expect(off.top == 2, "S1 the rim is the 2px inset the switch is built with (got " .. tostring(off.top) .. ")")

-- ===== S2: the states mirror each other =====

eq(off.left, on.right, "S2 the off state's left gap equals the on state's right gap")
eq(on.left, off.right, "S2 ... and the other way round")
eq(off.left, 2, "S2 the parked knob sits off its end by the same 2px inset (got " .. tostring(off.left) .. ")")
eq(on.right, 2, "S2 ... in both states (got " .. tostring(on.right) .. ")")
expect(off.left >= 0 and off.right >= 0, "S2 no state pushes the knob out of the track")
expect(on.left >= 0 and on.right >= 0, "S2 ... in either direction")

-- ===== S3: travel and the empty slab beside the knob =====

local travel = off.trackWidth - off.knobWidth - off.left - on.right
eq(travel, on.left - off.left, "S3 the knob's travel is the difference between the two resting positions")
expect(travel >= 8, "S3 the two states are still visually distinct (got " .. tostring(travel) .. "px of travel)")

--[[
The old geometry left 22px of empty track beside a 25px knob (and only 3px
at the parked end). The empty side must stay a minority of the track — no
state is allowed to read as a knob floating in a mostly-empty pill again.
]]
local empty = math.max(off.left, off.right)
expect(
	empty < off.trackWidth * 0.5,
	"STHE empty side is less than half the track (got " .. tostring(empty) .. " of " .. tostring(off.trackWidth) .. ")"
)

-- ===== S4: the sheen paints the track, not the knob =====

local overlay
for _, child in offSwitch.track:GetChildren() do
	local props = child.__props or {}
	if props.ClassName == "Frame" and props.Size and props.Size.X.Scale == 1 and props.Size.Y.Scale == 1 then
		overlay = child
	end
end
expect(overlay ~= nil, "S4 the track keeps its sheen overlay")
if not overlay then
	window:Unload()
	TestPump(0.1)
	error("SWITCH FAIL: S4 the track keeps its sheen overlay", 0)
end
expect(overlay.__props.ZIndex ~= nil, "S4 the sheen declares a ZIndex")
expect(offSwitch.knob.__props.ZIndex ~= nil, "S4 the knob declares a ZIndex")
expect(
	offSwitch.knob.__props.ZIndex > overlay.__props.ZIndex,
	"STHE sheen draws under the knob (knob z="
		.. tostring(offSwitch.knob.__props.ZIndex)
		.. ", sheen z="
		.. tostring(overlay.__props.ZIndex)
		.. ")"
)

-- ===== S5: tapping the switch lands on the built positions =====

local function animatesTo(element, wanted)
	local switch = findSwitch(element)
	local seen
	local service = state.tweenService
	local original = service.Create
	service.Create = function(self, target, info, props)
		local tween = original(self, target, info, props)
		if target == switch.knob and props.Position then
			seen = props.Position
		end
		return tween
	end
	element:Set(wanted, true)
	TestPump(0.9)
	service.Create = original
	return seen
end

local toOn = animatesTo(offToggle, true)
expect(toOn ~= nil, "S5 switching on positions the knob")
eq(toOn.X.Scale, on.position.X.Scale, "S5 ... at the same scale the on state is built with")
eq(toOn.X.Offset, on.position.X.Offset, "S5 ... and the same offset (got " .. tostring(toOn.X.Offset) .. ")")

local toOff = animatesTo(onToggle, false)
expect(toOff ~= nil, "S5 switching off positions the knob")
eq(toOff.X.Scale, off.position.X.Scale, "S5 ... at the same scale the off state is built with")
eq(toOff.X.Offset, off.position.X.Offset, "S5 ... and the same offset (got " .. tostring(toOff.X.Offset) .. ")")

-- ===== S6: the compact row follows the track =====

--[[
The label budget is name-dependent, so the check is structural: the
minimum width has to leave room for the track the element actually draws.
]]
expect(
	offToggle:_minWidth() > off.trackWidth,
	"S6 the minimum width leaves room for the " .. tostring(off.trackWidth) .. "px track (got " .. tostring(offToggle:_minWidth()) .. ")"
)
local compactToggle = tab:CreateToggle({ name = "Compact Switch", value = false, compact = true })
TestPump(0.3)
local compactSwitch = findSwitch(compactToggle)
expect(compactSwitch ~= nil, "S6 the compact element builds a switch")
eq(compactSwitch.track.__props.Size.X.Offset, off.trackWidth,
	"S6 the compact row uses the same track (got " .. tostring(compactSwitch.track.__props.Size.X.Offset) .. ")")

-- ===== S7: the indicator glow follows the switch ==========================

--[[
A shadow instance that is invisible whenever the switch is off is not
worth carrying: it is built the first time the switch turns on.
]]
local function shadows(element)
	local found = {}
	local function walk(node)
		for _, child in node:GetChildren() do
			if (child.__props or {}).ClassName == "UIShadow" then
				found[#found + 1] = child
			end
			walk(child)
		end
	end
	walk(element.main)
	return found
end

local glowlessToggle = tab:CreateToggle({ name = "Glowless", value = false })
TestPump(0.4)
eq(#shadows(glowlessToggle), 0, "S7 an off switch carries no glow")

glowlessToggle:Set(true)
TestPump(0.6)
local litShadows = shadows(glowlessToggle)
eq(#litShadows, 1, "S7 turning the switch on builds its glow")
expect(
	litShadows[1].__props.Transparency ~= 1,
	"S7 the glow is visible while the switch is on (got " .. tostring(litShadows[1].__props.Transparency) .. ")"
)
eq(litShadows[1].__props.BlurRadius.Offset, 20, "S7 the glow keeps its blur radius")

glowlessToggle:Set(false)
TestPump(0.6)
eq(#shadows(glowlessToggle), 1, "S7 turning it off fades the same glow instead of rebuilding one")
eq(shadows(glowlessToggle)[1].__props.Transparency, 1, "S7 ... to invisible")

--[[
A switch that starts on builds it up front, exactly like the always-built
version did.
]]
local litFromStart = tab:CreateToggle({ name = "Lit from start", value = true })
TestPump(0.4)
eq(#shadows(litFromStart), 1, "S7 a switch that starts on has its glow")
expect(shadows(litFromStart)[1].__props.Transparency ~= 1, "S7 ... already visible")

window:Unload()
TestPump(0.1)

print("SWITCH: all assertions passed")
