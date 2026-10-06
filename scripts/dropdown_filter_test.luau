--[[
===== dropdown filter assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

Typing in a dropdown's search used to cost four walks of every option row per
keystroke -- one to filter, one to round the surviving rows' corners, two
more for the select-all checkbox (one to collect names, one to test them) --
plus a fifth to count the rows the panel height needs, and a lowercased copy
of every row's name allocated each time. The filter now walks the rows once,
caches each row's lowercase name when the row is built, and hands the
surviving set to everything that needs it.

That is a refactor of hot code, so this suite pins the behaviour the
shortcuts could break:

  * F1 the filter is still case-insensitive in both directions,
  * F2 a row renamed by Refresh filters on its NEW name (a stale cached
    lowercase form would keep matching the old one),
  * F3 the select-all checkbox answers for the filtered set, not the whole
    option list,
  * F4 Clear removes what the filter shows and leaves the rest,
  * F5 the open panel's height tracks the number of visible rows, and
    grows back when the query is cleared,
  * F6 a query that matches nothing leaves no row visible and shows the
    empty label,
  * F7 clearing the query brings every row back, in option order.
]]

local function expect(cond, message)
	if not cond then
		error("DROPDOWN FILTER FAIL: " .. message, 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"DROPDOWN FILTER FAIL: "
				.. message
				.. " (got "
				.. tostring(actual)
				.. ", want "
				.. tostring(wanted)
				.. ")",
			0
		)
	end
end

local function visibleNames(dropdown)
	local names = {}
	for _, option in dropdown._optionFrames do
		if option.frame.Visible then
			table.insert(names, option.name)
		end
	end
	return names
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

local window = Astra:CreateWindow({ name = "Dropdown filter" })
TestPump(0.6)
window:Show()
TestPump(0.6)
local tab = window:CreateTab({ name = "Dropdown filter" })

local function openDropdown(dropdown)
	dropdown.interact.MouseButton1Click:Fire()
	TestPump(0.4)
end

local function setFilter(dropdown, text)
	if not dropdown._searchOpen then
		dropdown.searchToggle.MouseButton1Click:Fire()
		TestPump(0.3)
	end
	dropdown.searchInput.Text = text
	TestPump(0.3)
end

-- ===== F1: case-insensitive matching in both directions =====

local mixed = tab:CreateDropdown({
	name = "Mixed",
	options = { "Alpha", "beta", "GAMMA" },
	value = "Alpha",
})
openDropdown(mixed)
setFilter(mixed, "beta")
eq(sameSet(visibleNames(mixed), { "beta" }), true, "F1 a lowercase query matches the mixed-case row")
setFilter(mixed, "GAMMA")
eq(sameSet(visibleNames(mixed), { "GAMMA" }), true, "F1 ... and an uppercase query matches it too")
setFilter(mixed, "a")
eq(
	sameSet(visibleNames(mixed), { "Alpha", "beta", "GAMMA" }),
	true,
	"F1 ... against every row's lowercased name, so all three contain the letter"
)
setFilter(mixed, "lph")
eq(sameSet(visibleNames(mixed), { "Alpha" }), true, "F1 ... and a longer query narrows to one row")

-- ===== F2: a renamed row filters on its new name =====

mixed:Refresh({ "Alpha", "beta", "Renamed" })
TestPump(0.4)
eq(#mixed._optionFrames, 3, "F2 Refresh keeps one row per option")
setFilter(mixed, "renamed")
eq(sameSet(visibleNames(mixed), { "Renamed" }), true, "F2 the renamed row matches its new name")
setFilter(mixed, "gamma")
eq(
	#visibleNames(mixed),
	0,
	"F2 ... and the name it replaced no longer matches (the cached lowercase form follows the rename)"
)

-- ===== F3/F4: the action row answers for the filtered set =====

--[=[
"Two" starts selected and is about to be hidden by the filter, so the two
bulk actions can be shown to act on the filtered set and nothing else.
]=]
local multi = tab:CreateDropdown({
	name = "Multi",
	options = { "One", "Two", "Three" },
	value = { "One", "Two" },
	multiSelect = true,
})
TestPump(0.3)
openDropdown(multi)

eq(multi.selectAllCheck.ImageTransparency, 1, "F3 the box is off while a visible row is unselected")

-- "e" matches One and Three; Two is hidden.
setFilter(multi, "e")
eq(sameSet(visibleNames(multi), { "One", "Three" }), true, "F3 the filter narrows the list to two rows")
eq(multi.selectAllCheck.ImageTransparency, 1, "F3 ... and the box stays off because Three is not selected")

multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(
	sameSet(multi.value, { "One", "Two", "Three" }),
	true,
	"F4 a filtered Select all adds the visible rows to the selection"
)
eq(multi.selectAllCheck.ImageTransparency, 0, "F4 ... and the box turns on")

multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
eq(
	sameSet(multi.value, { "Two" }),
	true,
	"F4 ... and clicking it again clears the visible rows, leaving the hidden one selected"
)
eq(multi.selectAllCheck.ImageTransparency, 1, "F4 ... with the box back off")

multi.selectAll.MouseButton1Click:Fire()
TestPump(0.3)
multi.clear.MouseButton1Click:Fire()
TestPump(0.3)
eq(
	sameSet(multi.value, { "Two" }),
	true,
	"F4 Clear removes what the filter shows and leaves the hidden selection alone"
)

-- ===== F5: the panel height tracks the visible rows =====

local height = tab:CreateDropdown({
	name = "Height",
	options = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" },
	value = "One",
})
openDropdown(height)
--[=[
Opening the search adds the field to the panel, so the baseline is measured
with the search open and empty. The list is capped at four rows, so the
narrowing query has to leave fewer than four behind to move the height.
]=]
setFilter(height, "")
local fullHeight = height.main.Size.Y.Offset
expect(fullHeight > 0, "F5 an open dropdown has a measured panel height")
setFilter(height, "igh")
local filteredHeight = height.main.Size.Y.Offset
expect(
	filteredHeight < fullHeight,
	"F5 narrowing the filter shrinks the panel (got "
		.. tostring(filteredHeight)
		.. " from "
		.. tostring(fullHeight)
		.. ")"
)
setFilter(height, "zzz")
local emptyHeight = height.main.Size.Y.Offset
expect(
	emptyHeight <= filteredHeight,
	"F5 ... and a filter that matches nothing is no taller than one that matches a row"
)

-- ===== F6: a query that matches nothing =====

eq(#visibleNames(height), 0, "F6 no row is visible when nothing matches")
eq(height.emptyLabel.Visible, true, "F6 ... and the empty label says so")

-- ===== F7: clearing the query brings every row back =====

setFilter(height, "")
eq(#visibleNames(height), 8, "F7 every row returns when the query is cleared")
eq(height.emptyLabel.Visible, false, "F7 ... and the empty label goes away")
TestPump(0.4)
eq(
	height.main.Size.Y.Offset,
	fullHeight,
	"F7 ... with the panel back at the height it had before the filter"
)
eq(
	sameSet(visibleNames(height), { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" }),
	true,
	"F7 ... still in option order"
)

window:Unload()
TestPump(0.1)

print("DROPDOWN FILTER: all assertions passed")
