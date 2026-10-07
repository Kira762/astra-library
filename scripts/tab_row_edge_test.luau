--[[
===== Tab row outline shades =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau and pins the sidebar row's outline contract:

  * the selected row wears the theme's own TabStroke gradient — its lit top
    lip is what marks the open page — at its existing transparency,
  * hover and unselected rows wear a *flat* shade of it, stepped down from
    the stroke's lit end toward the rail's own surface, so the rail reads as
    a quiet list with one lit row instead of three outlines of equal weight,
  * hover is visibly firmer than unselected, and both keep their own
    transparencies,
  * a theme change re-resolves the shade instead of dropping every row back
    onto the lit gradient (the stroke binding goes through the row's state),
  * a locked row keeps the same shade as any other unpicked one.
]]

local function expect(cond, message)
	if not cond then
		error("TAB ROW EDGE FAIL: " .. tostring(message), 0)
	end
end

local function flat(sequence)
	expect(type(sequence) == "table" and type(sequence.Keypoints) == "table", "a color sequence is expected")
	local first = sequence.Keypoints[1].Value
	for _, keypoint in sequence.Keypoints do
		if keypoint.Value.R ~= first.R or keypoint.Value.G ~= first.G or keypoint.Value.B ~= first.B then
			return false
		end
	end
	return true
end

local function luminance(color)
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function keypointColor(sequence)
	return sequence.Keypoints[1].Value
end

--[[
Colour identity: the harness builds colours as plain tables, so `==` compares
references; compare channels instead.
]]
local function same(a, b)
	return math.abs(a.R - b.R) < 0.001 and math.abs(a.G - b.G) < 0.001 and math.abs(a.B - b.B) < 0.001
end

local window = Astra:CreateWindow({ name = "Tab Row Edge Test", configuration = { autoSave = false, autoLoad = false } })
TestPump(1.2)

local alpha = window:CreateTab({ name = "Alpha", icon = "house" })
local beta = window:CreateTab({ name = "Beta", icon = "gauge" })
local gamma = window:CreateTab({ name = "Gamma", icon = "layout-grid" })
beta:Select()
TestPump(0.6)

local function strokeOf(tab)
	local gradient = tab.topbarItemStrokeGradient
	expect(gradient ~= nil, "a row owns its stroke gradient")
	return gradient, gradient.Color
end

local theme = window.theme
local lit = theme.TabStroke.Keypoints[1].Value
local rail = theme.SidebarSurface

-- ===== the selected row keeps the theme's own gradient =====
local _, selectedColor = strokeOf(beta)
expect(not flat(selectedColor), "the selected row wears the TabStroke gradient, lip and all")
expect(same(keypointColor(selectedColor), lit), "and its lit end is the theme's own stroke colour")
expect(beta.topbarItemStroke.Transparency == 0.5, "the selected row keeps its outline transparency")

-- ===== the unselected row wears a flat, quieter shade =====
local _, unselectedColor = strokeOf(alpha)
expect(flat(unselectedColor), "the unselected row's outline is one even shade")
expect(not same(keypointColor(unselectedColor), lit), "and it is not the lit end the selected row wears")
expect(luminance(keypointColor(unselectedColor)) < luminance(lit), "the unselected shade sits below the lit end")
expect(
	luminance(keypointColor(unselectedColor)) > luminance(rail),
	"the unselected shade still clears the rail surface it sits on"
)
expect(alpha.topbarItemStroke.Transparency == 0.8, "the unselected row keeps its outline transparency")
expect(#unselectedColor.Keypoints == #theme.TabStroke.Keypoints, "the flat shade keeps the theme stroke's keypoint count")

-- ===== hover lifts the outline without copying the selected row =====
alpha.topbarItemInteract.MouseEnter:Fire()
TestPump(0.4)
local _, hoverColor = strokeOf(alpha)
expect(flat(hoverColor), "the hovered row's outline is still one even shade, not the selected lip")
expect(
	luminance(keypointColor(hoverColor)) > luminance(keypointColor(unselectedColor)),
	"hover reads firmer than unselected, got " .. tostring(keypointColor(hoverColor).R)
)
expect(luminance(keypointColor(hoverColor)) < luminance(lit), "and still short of the selected row's lit end")
expect(alpha.topbarItemStroke.Transparency < 0.8, "hover firms the outline up")

alpha.topbarItemInteract.MouseLeave:Fire()
TestPump(0.4)
local _, restedColor = strokeOf(alpha)
expect(flat(restedColor), "leaving the row rests the outline back to a flat shade")
expect(keypointColor(restedColor).R == keypointColor(unselectedColor).R, "and to the unselected shade exactly")
expect(alpha.topbarItemStroke.Transparency == 0.8, "and to the unselected transparency")

-- ===== selecting a different row re-shades the old one =====
alpha:Select()
TestPump(0.5)
local _, newlySelected = strokeOf(alpha)
local _, newlyUnselected = strokeOf(beta)
expect(not flat(newlySelected), "the newly selected row takes the gradient")
expect(flat(newlyUnselected), "and the row it left behind flattens to the quiet shade")
expect(same(keypointColor(newlyUnselected), keypointColor(restedColor)), "with the same shade as any other unselected row")

-- ===== a theme change keeps every row on its own shade =====
local newRail = Color3.fromRGB(40, 20, 60)
window:ChangeTheme({ SidebarSurface = newRail })
TestPump(0.6)
theme = window.theme
expect(theme.SidebarSurface == newRail, "the theme change landed")

local _, afterSelected = strokeOf(alpha)
local _, afterUnselected = strokeOf(beta)
expect(same(keypointColor(afterSelected), theme.TabStroke.Keypoints[1].Value), "the selected row keeps the lit gradient across a theme change")
expect(flat(afterUnselected), "an unselected row does not fall back onto the lit gradient")
local expectedShade = theme.TabStroke.Keypoints[1].Value:Lerp(newRail, 0.55)
expect(
	math.abs(afterUnselected.Keypoints[1].Value.R - expectedShade.R) < 0.001,
	"and its shade is re-derived against the new rail surface, got "
		.. tostring(afterUnselected.Keypoints[1].Value.R)
		.. " vs "
		.. tostring(expectedShade.R)
)

-- ===== a locked row reads as any other unpicked one =====
gamma:SetLocked(true)
TestPump(0.4)
local _, lockedColor = strokeOf(gamma)
expect(flat(lockedColor), "a locked row wears the flat unpicked shade")
expect(keypointColor(lockedColor).R == keypointColor(afterUnselected).R, "and the same shade as its neighbours")
expect(gamma.topbarItemStroke.Transparency == 0.8, "with the same outline transparency")

-- ===== a theme stroke of a different shape =====
--[[
A ColorSequence tween needs matching keypoint counts, and a host theme can
swap the stroke for one with a different shape. The row must land on the
new shade regardless (and keep the new stroke's keypoint count).
]]
local threePoint = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 90, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 70, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 40)),
})
window:ChangeTheme({ TabStroke = threePoint })
TestPump(0.6)
expect(#window.theme.TabStroke.Keypoints == 3, "the reshaped stroke landed")

beta.topbarItemInteract.MouseEnter:Fire()
TestPump(0.4)
local _, reshapedHover = strokeOf(beta)
expect(#reshapedHover.Keypoints == 3, "the hovered shade carries the new stroke's keypoint count")
expect(flat(reshapedHover), "and it is still one even shade")
beta.topbarItemInteract.MouseLeave:Fire()
TestPump(0.4)
local _, reshapedRest = strokeOf(beta)
expect(#reshapedRest.Keypoints == 3, "and resting keeps the new shape")

window:Unload()
TestPump(0.2)

print("TAB ROW EDGE: selected gradient, flat hover/unselected shades, theme change and lock all held")
