--[[
===== corner scale assertions: three nested tiers, plus the derived pills =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

Astra shipped with every radius at zero: the three theme tokens were
`UDim.new(0, 0)` and eleven more surfaces baked a zero of their own, so 34 of
the tree's 35 corners drew a hard edge. The scale that replaced them is three
tiers nested one step inside each other — 12px shell, 8px elements, 32px
folds — with the controls that are round by nature (the switch, the slider,
the drag pill, the unread dot) taking half their own height instead of
reading a token. These assertions pin both halves of that, so the square
corners cannot creep back one baked literal at a time.

Expected behavior under test:
  * K1 the shell tier is a non-zero pixel radius and the window frame wears
       it,
  * K2 every element card, the input's field box and the rail's rows round at
       the element tier,
  * K3 the round-by-nature controls are pills of their own metrics — the
       switch track/knob/sheen, the slider track/fill/handle, the drag pill —
       and none of them reads a theme token,
  * K4 the dropdown's row tiers follow the panel that clips them: the outer
       tier is the panel's own radius, the seam 4px below it, and its search
       field rounds a tier under the rows,
  * K5 a `ChangeTheme` reaches every bound surface, so nothing is baked, and
       switching back restores the scale,
  * K6 the corners that are square on purpose stay square (the elements
       band's top edge, flush against the topbar),
  * K7 no painted surface anywhere in the tree carries an all-zero corner.
]]

local function expect(cond, message)
	if not cond then
		error("CORNER SCALE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"CORNER SCALE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local cornerKeys = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" }

local function cornerOf(inst)
	if not inst then
		return nil
	end
	for _, child in inst:GetChildren() do
		if (child.__props or {}).ClassName == "UICorner" then
			return child
		end
	end
	return nil
end

--[[
A corner rounds if its own radius is non-zero or any explicitly written
per-corner radius is. Read from `__props` so an engine that never wrote a
per-corner value does not read as a square corner through a stub default.
]]
local function rounds(corner)
	local main = corner.CornerRadius
	if main and (main.Scale ~= 0 or main.Offset ~= 0) then
		return true
	end
	for _, key in cornerKeys do
		local value = (corner.__props or {})[key]
		if value and (value.Scale ~= 0 or value.Offset ~= 0) then
			return true
		end
	end
	return false
end

local window = Astra:CreateWindow({ name = "Corner scale" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Scale" })
local button = tab:CreateButton({ name = "Button", callback = function() end })
local toggle = tab:CreateToggle({ name = "Switch", value = true })
local slider = tab:CreateSlider({ name = "Slider", min = 0, max = 100, value = 40 })
local dropdown = tab:CreateDropdown({ name = "Options", options = { "One", "Two", "Three" } })
local input = tab:CreateInput({ name = "Field", value = "value" })
local stat = tab:CreateStat({ name = "Kills", value = 128 })
TestPump(0.6)

-- ===== K1: the shell tier ====================================================

local shell = window.theme.CornerRoundness
expect(shell ~= nil, "K1 the theme carries CornerRoundness")
eq(shell.Scale, 0, "K1 the shell radius is a pixel radius, not a scale")
expect(shell.Offset > 0, "K1 the shell actually rounds (" .. tostring(shell.Offset) .. "px)")
eq(window.windowCorner.CornerRadius, shell, "K1 the window frame wears it")

-- ===== K2: the element tier ==================================================

local element = window.theme.ElementCornerRadius
eq(element.Scale, 0, "K2 the element radius is a pixel radius")
expect(element.Offset > 0, "K2 elements actually round (" .. tostring(element.Offset) .. "px)")
expect(
	element.Offset < shell.Offset,
	"K2 the element tier sits inside the shell's (" .. tostring(element.Offset) .. " < " .. tostring(shell.Offset) .. ")"
)

--[[
The dropdown's card is its `top` frame (the closed button row); its `main`
is the wrapper that also holds the open panel, so it carries no corner of
its own.
]]
local function cardCorner(card)
	local surface = if card.__type == "Dropdown" then card.top else card.main
	expect(surface ~= nil, "K2 the " .. tostring(card.__type) .. " has a card surface")
	local corner = cornerOf(surface)
	expect(corner ~= nil, "K2 the " .. tostring(card.__type) .. " card carries a corner")
	return corner
end

for _, card in { button, toggle, slider, dropdown, input, stat } do
	eq(
		cardCorner(card).CornerRadius.Offset,
		element.Offset,
		"K2 the " .. tostring(card.__type) .. " card rounds at the element tier"
	)
end

eq(
	cornerOf(input.box).CornerRadius.Offset,
	element.Offset,
	"K2 the input's field box shares the card's tier"
)

local row = cornerOf(tab.topbarItem)
expect(row ~= nil, "K2 the rail's row carries a corner")
expect(row.CornerRadius.Offset > 0, "K2 the rail's row is a chip, not a square band")

-- ===== K3: the round-by-nature controls ======================================

local trackCorner = cornerOf(toggle.functionContainer)
local knobCorner = cornerOf(toggle.indicator)
expect(trackCorner ~= nil and knobCorner ~= nil, "K3 the switch track and knob carry corners")
eq(
	trackCorner.CornerRadius.Offset,
	toggle.functionContainer.Size.Y.Offset / 2,
	"K3 the switch track is a pill of its own height"
)
eq(
	knobCorner.CornerRadius.Offset,
	toggle.indicator.Size.Y.Offset / 2,
	"K3 ... and so is the knob"
)
eq(
	cornerOf(toggle.overlay).CornerRadius.Offset,
	trackCorner.CornerRadius.Offset,
	"K3 the sheen wears the track's arc"
)

eq(
	cornerOf(slider.track).CornerRadius.Offset,
	slider.track.Size.Y.Offset / 2,
	"K3 the slider track is a pill of its own height"
)
eq(
	cornerOf(slider.progress).CornerRadius.Offset,
	slider.track.Size.Y.Offset / 2,
	"K3 the fill follows the track, not its own zero-height scale"
)
eq(
	cornerOf(slider.handle).CornerRadius.Offset,
	slider.handle.Size.Y.Offset / 2,
	"K3 the handle is a pill of its own height"
)

local pill = cornerOf(window.drag.dragCosmetic)
expect(pill ~= nil, "K3 the drag pill carries a corner")
eq(
	pill.CornerRadius.Offset,
	window.drag.dragCosmetic.Size.Y.Offset / 2,
	"K3 the drag pill's ends are domed at half its thickness"
)

--[[
None of the four reads a token: a theme that squares the cards off must
leave the switch, the slider and the drag pill round.
]]

-- ===== K4: the dropdown's row tiers ==========================================

pcall(function() dropdown:_open() end)
TestPump(0.6)
for _, optionRow in dropdown._optionFrames do
	optionRow.frame.Visible = true
end
dropdown:_updateCorners()

local firstRow = dropdown._optionFrames[1].corner
local lastRow = dropdown._optionFrames[#dropdown._optionFrames].corner
expect(firstRow ~= nil and lastRow ~= nil, "K4 the rows carry corners")
eq(firstRow.TopLeftRadius.Offset, element.Offset, "K4 the first row's arc is the panel's own radius")
eq(
	firstRow.BottomLeftRadius.Offset,
	math.max(0, element.Offset - 4),
	"K4 ... and meets the next row 4px below it"
)
eq(lastRow.BottomLeftRadius.Offset, element.Offset, "K4 the last row rounds its bottom the same way")

local searchCorner = cornerOf(dropdown.searchbar)
expect(searchCorner ~= nil, "K4 the dropdown's search field carries a corner")
expect(searchCorner.CornerRadius.Offset > 0, "K4 the search field rounds")
expect(
	searchCorner.CornerRadius.Offset < element.Offset,
	"K4 ... a tier under the rows, so it reads as a field"
)

-- ===== K5: a theme change reaches every bound surface ========================

--[[
The search bar is built the first time search opens, so open it through the
toolbar action the window owns instead of assuming the frame exists.
]]
if not window.searchPill and window.searchAction and window.searchAction.callback then
	window.searchAction.callback()
	TestPump(0.8)
end
expect(window.searchPill ~= nil, "K5 the search bar exists once search has been opened")

window:ChangeTheme({ CornerRoundness = UDim.new(0, 4), ElementCornerRadius = UDim.new(0, 2) })
TestPump(0.6)
eq(window.windowCorner.CornerRadius.Offset, 4, "K5 the shell follows a theme change")
eq(cardCorner(button).CornerRadius.Offset, 2, "K5 ... and so does a card")
eq(cornerOf(input.box).CornerRadius.Offset, 2, "K5 ... the field box")
eq(cornerOf(window.searchPill).CornerRadius.Offset, 2, "K5 ... the search bar")
eq(
	cornerOf(toggle.functionContainer).CornerRadius.Offset,
	toggle.functionContainer.Size.Y.Offset / 2,
	"K5 ... while the switch stays a pill of its own height"
)

--[[
Search filters and hides elements while it is open; close it before the
sweep below audits the tree.
]]
if window._searching and window.searchAction and window.searchAction.callback then
	window.searchAction.callback()
	TestPump(0.8)
end

window:ChangeTheme("default")
TestPump(0.6)
eq(
	cardCorner(button).CornerRadius.Offset,
	window.theme.ElementCornerRadius.Offset,
	"K5 switching back restores the element tier"
)
eq(
	window.windowCorner.CornerRadius.Offset,
	window.theme.CornerRoundness.Offset,
	"K5 ... and the shell's"
)

-- ===== K6: square on purpose, still square ===================================

local band = cornerOf(window.elements)
expect(band ~= nil, "K6 the elements band carries a corner")
eq(band.TopLeftRadius.Offset, 0, "K6 the band's top-left stays square against the topbar")
eq(band.TopRightRadius.Offset, 0, "K6 ... and its top-right too")
eq(
	band.BottomRightRadius.Offset,
	window.theme.CornerRoundness.Offset,
	"K6 the band's bottom-right mirrors the shell's silhouette"
)

-- ===== K7: nothing painted is left square ====================================

local PAINTABLE = {
	Frame = true,
	ScrollingFrame = true,
	ImageLabel = true,
	ImageButton = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
}

local offenders = {}
for _, inst in window.screenGui:GetDescendants() do
	local props = inst.__props or {}
	if PAINTABLE[props.ClassName] and (inst.BackgroundTransparency or 1) < 1 then
		local corner = cornerOf(inst)
		if corner and not rounds(corner) then
			table.insert(offenders, tostring(props.ClassName) .. "/" .. tostring(props.Name))
		end
	end
end
expect(
	#offenders == 0,
	"K7 every painted surface with a corner rounds (" .. table.concat(offenders, ", ") .. ")"
)

window:Unload()
TestPump(0.4)

print("CORNER SCALE: all assertions passed")
