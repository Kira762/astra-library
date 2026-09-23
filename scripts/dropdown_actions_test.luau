--[[
===== dropdown bulk-action row assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

A multi-select dropdown's Select all / Clear line used to be two bare text
buttons with no state of their own, sitting at the left of a 22px strip. It
is now a checkbox and a bin: the box answers for the options the list is
showing, Select all toggles that set, and Clear still removes only what the
filter shows.

Expected behavior under test:
  * A1 only a multi-select dropdown carries the row, and the row holds the
    checkbox + "Select all" at its left edge and "Clear" + its bin at the
    right,
  * A2 the box is on when every visible option is selected and off
    otherwise: the drawn outline shows when it is off, the check glyph the
    rows use when it is on,
  * A3 Select all fills the visible set from whatever the selection was,
  * A4 clicking it again - with everything visible already selected -
    clears that same set instead,
  * A5 Clear removes what is visible and leaves the options the filter
    hides alone,
  * A6 the box follows individual picks and a changed filter,
  * A7 the taller row is what the open panel pays for, between the search
    bar and the list,
  * A8 an unchecked box keeps its hover brightness when a click empties it
    under the pointer,
  * A9 the bin resolves to a real pack icon.
]]

local function expect(cond, message)
	if not cond then
		error("DROPDOWN ACTIONS FAIL: " .. message, 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"DROPDOWN ACTIONS FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function count(inst)
	local n = 1
	for _, child in inst:GetChildren() do
		n += count(child)
	end
	return n
end

--[[
The checkbox's two visible halves: the glyph the rows use and the outline
the unchecked box draws. Exactly one of them is showing.
]]
local function boxState(dropdown)
	return {
		glyph = dropdown.selectAllCheck.ImageTransparency,
		outline = dropdown.selectAllStroke.Transparency,
	}
end

local function sameSet(actual, wanted)
	if #actual ~= #wanted then
		return false
	end
	for _, value in actual do
		if not table.find(wanted, value) then
			return false
		end
	end
	return true
end

local window = Astra:CreateWindow({ name = "Dropdown actions" })
TestPump(0.6)
window:Show()
TestPump(0.6)
local tab = window:CreateTab({ name = "Dropdown actions" })

local function openDropdown(dropdown)
	dropdown.interact.MouseButton1Click:Fire()
	TestPump(0.4)
end

local function closeDropdown(dropdown)
	dropdown:_close()
	TestPump(0.3)
end

local function pickRow(dropdown, index)
	dropdown._optionFrames[index].interact.MouseButton1Click:Fire()
	TestPump(0.3)
end

local function setFilter(dropdown, text)
	if not dropdown._searchOpen then
		dropdown.searchToggle.MouseButton1Click:Fire()
		TestPump(0.3)
	end
	dropdown.searchInput.Text = text
	TestPump(0.3)
end

local function clearFilter(dropdown)
	if dropdown._searchOpen then
		dropdown.searchIcon.MouseButton1Click:Fire()
		TestPump(0.3)
	end
end

-- ===== A1: only a multi-select dropdown has the row =====

local single = tab:CreateDropdown({ name = "Single", options = { "One", "Two" }, value = "One" })
local picked = {}
local multi = tab:CreateDropdown({
	name = "Multi",
	options = { "One", "Two", "Three" },
	value = { "One" },
	multiSelect = true,
	callback = function(value)
		picked = value
	end,
})
TestPump(0.3)

eq(single.actions, nil, "A1 a single-select dropdown has no action row")
eq(single.selectAll, nil, "A1 ... and no Select all control")
expect(multi.actions ~= nil, "A1 a multi-select dropdown has the row")
eq(multi.actions.Parent, multi.panel, "A1 ... inside the option panel")
eq(multi.actions.Name, "Actions", "A1 ... still called Actions")

expect(multi.selectAll ~= nil and multi.clear ~= nil, "A1 the row holds Select all and Clear")
eq(multi.selectAll.Parent, multi.actions, "A1 Select all is one of its two controls")
eq(multi.clear.Parent, multi.actions, "A1 ... and Clear is the other")
eq(multi.selectAll.Position.X.Scale, 0, "A1 Select all is anchored to the left edge")
eq(multi.clear.Position.X.Scale, 1, "A1 ... and Clear to the right one")
expect(multi.selectAllBox ~= nil, "A1 Select all carries a checkbox")
expect(multi.selectAllCheck ~= nil, "A1 ... with the row glyph inside it")
eq(multi.selectAllBox.Size.X.Offset, 12, "A1 the drawn outline is the width of a row glyph")
eq(multi.selectAllBox.Size.Y.Offset, 12, "A1 ... square")
eq(multi.selectAllCheck.Size.X.Offset, 16, "A1 ... inside the 16px slot a row gives its glyph")
eq(multi.selectAll.Position.X.Offset, 8, "A1 Select all is inset from the row's left edge")
eq(multi.clear.Position.X.Offset, -10, "A1 ... and Clear from its right one")
eq(multi.clearIcon.Parent, multi.clear, "A1 Clear carries its bin")
expect(multi.clearLabel ~= nil, "A1 ... next to its label")

-- ===== A2: the box answers for the visible options =====

eq(boxState(multi).outline, 0.45, "A2 a partly selected dropdown draws the empty box")
eq(boxState(multi).glyph, 1, "A2 ... and not the check glyph")
multi:Set({ "One", "Two", "Three" })
TestPump(0.3)
eq(boxState(multi).glyph, 0, "A2 selecting every option fills the box in")
eq(boxState(multi).outline, 1, "A2 ... and takes the outline away")
multi:Set({ "One", "Three" })
TestPump(0.3)
eq(boxState(multi).glyph, 1, "A2 taking one back empties it again")
eq(boxState(multi).outline, 0.45, "A2 ... with the outline back")

-- ===== A3: Select all fills the visible set =====

openDropdown(multi)
eq(multi.value[1], "One", "A3 the dropdown starts on the value it was given")
eq(
	multi.selectAllCheck.Image,
	multi._optionFrames[1].checkIcon.Image,
	"A3 the checked box is the glyph a selected row shows"
)
expect(
	multi._optionFrames[1].checkIcon.Image ~= multi._optionFrames[2].checkIcon.Image,
	"A3 ... not the empty box the unselected rows carry"
)
multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(#multi.value, 3, "A3 Select all takes every option")
expect(sameSet(multi.value, { "One", "Two", "Three" }), "A3 ... the whole list of them")
eq(multi.selectedLabel.Text, "Various", "A3 ... and the header follows the value")
expect(sameSet(picked, { "One", "Two", "Three" }), "A3 ... and so does the callback")
eq(boxState(multi).glyph, 0, "A3 ... with the box reporting it")

-- ===== A4: it toggles back off =====

picked = {}
multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(#multi.value, 0, "A4 clicking it with everything visible selected clears them")
eq(multi.selectedLabel.Text, "None", "A4 ... the header falls back to the placeholder")
eq(#picked, 0, "A4 ... the callback is told about the empty value")
eq(boxState(multi).glyph, 1, "A4 ... and the box empties with it")
expect(multi._isOpen, "A4 the bulk actions leave a multi-select dropdown open")

-- ===== A5: Clear removes only what the filter shows =====

multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(#multi.value, 3, "A5 everything is selected again")
setFilter(multi, "Two")
eq(multi._optionFrames[1].frame.Visible, false, "A5 the filter hides the other rows")
eq(multi._optionFrames[2].frame.Visible, true, "A5 ... and shows the one it matches")
multi.clear.MouseButton1Click:Fire()
TestPump(0.3)
eq(#multi.value, 2, "A5 Clear removes only the options on screen")
expect(not table.find(multi.value, "Two"), "A5 ... which is the one that was showing")
expect(table.find(multi.value, "One") and table.find(multi.value, "Three"), "A5 ... and leaves the hidden ones alone")
eq(boxState(multi).glyph, 1, "A5 the box answers for the visible set, not the whole list")
clearFilter(multi)
eq(boxState(multi).glyph, 1, "A5 ... and a widened filter still finds an option unselected")

-- ===== A6: the box follows picks and the filter =====

setFilter(multi, "Two")
eq(boxState(multi).glyph, 1, "A6 a visible option that is not selected leaves the box off")
pickRow(multi, 2)
eq(boxState(multi).glyph, 0, "A6 picking it fills the box")
eq(#multi.value, 3, "A6 ... and the value holds all three")
pickRow(multi, 2)
eq(boxState(multi).glyph, 1, "A6 unpicking it empties the box")
clearFilter(multi)
eq(boxState(multi).glyph, 1, "A6 ... even though the rest of the list is still selected")
pickRow(multi, 2)
eq(boxState(multi).glyph, 0, "A6 selecting the last missing option fills it")

-- ===== A7: the row is what the open panel pays for =====

closeDropdown(multi)
--[[
Both dropdowns are compared with their rows materialised: a never-opened
one measures as a single row, which is a different sum entirely.
]]
local rowsOnly = tab:CreateDropdown({ name = "Rows only", options = { "One", "Two", "Three" }, value = "One" })
openDropdown(rowsOnly)
closeDropdown(rowsOnly)
eq(multi.actions.Size.Y.Offset, 32, "A7 the row is 32px tall")
eq(multi.actions.LayoutOrder, 2, "A7 ... and sits between the search bar (1) and the list (3)")
eq(
	multi:_openHeight() - rowsOnly:_openHeight(),
	37,
	"A7 the open dropdown pays 32px for the row plus the 5px gap above it"
)

-- ===== A8: the box keeps its hover brightness =====

--[[
Unchecking the box with the pointer still on it must not drop the outline
to the idle dim: the click that empties it leaves the pointer hovering.
]]
local hover = tab:CreateDropdown({
	name = "Hover",
	options = { "One", "Two" },
	value = { "One" },
	multiSelect = true,
})
openDropdown(hover)
eq(boxState(hover).outline, 0.45, "A8 an untouched box draws the idle outline")
hover.selectAll.MouseEnter:Fire()
TestPump(0.2)
eq(boxState(hover).outline, 0.2, "A8 hovering it brightens the outline")
hover.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(boxState(hover).glyph, 0, "A8 clicking it fills every option in")
eq(boxState(hover).outline, 1, "A8 ... and the outline goes with the empty box")
hover.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(boxState(hover).glyph, 1, "A8 clicking it again empties them")
eq(boxState(hover).outline, 0.2, "A8 ... and the outline is still the hovered one")
hover.selectAll.MouseLeave:Fire()
TestPump(0.2)
eq(boxState(hover).outline, 0.45, "A8 leaving the box settles it back to the idle outline")
closeDropdown(hover)

-- ===== A9: the bin is a real icon =====

local bin = Astra.Icons.resolve("trash")
expect(type(bin) == "string" and bin ~= "trash", "A9 the bin resolves to an icon")
expect(
	string.find(bin, "lucide-pack/lucideTrash.png", 1, true) ~= nil,
	"A9 ... the pack's trash glyph (got " .. tostring(bin) .. ")"
)

window:Unload()
TestPump(0.1)

print("DROPDOWN ACTIONS: all assertions passed")
