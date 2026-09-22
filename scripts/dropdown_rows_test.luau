--[[
===== dropdown lazy-row assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

A dropdown used to build its search bar and every option row (frame, corner,
stroke, click button, icon+title container, layout, icon and title = eight
instances each) while it was being constructed, even though a closed
dropdown shows only its header and the rows and the bar live behind a panel
with the same colour as the background. Both are now materialised on the
first open, which is the first moment either can be seen.

Expected behavior under test:
  * D1 a closed dropdown has no rows and no search bar, whatever its option
    list - two options and twelve options cost the same,
  * D2 opening it builds exactly one row per option, in option order, plus
    the search bar once,
  * D3 those rows are in the state the always-built version left them in
    (selected/unselected transparencies, first/last corner tiers),
  * D4 closing and reopening reuses them - nothing is rebuilt or duplicated,
  * D5 Add/Remove/Refresh while closed are reflected the next time it opens,
  * D6 picking a row still updates the value, the header and the list state,
  * D7 the search bar still filters the rows, and collapsing it brings them
    all back,
  * D8 a dropdown inside a Collapsible Group opens cleanly: its open-time
    scroll resolves the owner chain up to the tab's ScrollingFrame instead
    of reading scroll members off the group's plain body frame.
]]

local function expect(cond, message)
	if not cond then
		error("DROPDOWN FAIL: " .. message, 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"DROPDOWN FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
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

local function childOfClass(inst, className)
	for _, child in inst:GetChildren() do
		if ((child.__props or {}).ClassName) == className then
			return child
		end
	end
	return nil
end

local function rowState(row)
	return {
		frame = row.frame.BackgroundTransparency,
		title = row.title.TextTransparency,
		icon = row.checkIcon.ImageTransparency,
		stroke = row.stroke.Transparency,
	}
end

local window = Astra:CreateWindow({ name = "Dropdown rows" })
TestPump(0.6)
window:Show()
TestPump(0.6)
local tab = window:CreateTab({ name = "Dropdown rows" })

local function openDropdown(dropdown)
	dropdown.interact.MouseButton1Click:Fire()
	TestPump(0.4)
end

local function closeDropdown(dropdown)
	dropdown:_close()
	TestPump(0.3)
end

-- ===== D1: a closed dropdown is only its header =====

local function closedCost(build)
	local before = count(tab.tabPage)
	local dropdown = build()
	TestPump(0.3)
	return count(tab.tabPage) - before, dropdown
end

local shortCost, short = closedCost(function()
	return tab:CreateDropdown({ name = "Short", options = { "Alpha", "Beta" }, value = "Alpha" })
end)

local longOptions = {}
for index = 1, 12 do
	longOptions[index] = "Option " .. tostring(index)
end

local longCost, long = closedCost(function()
	return tab:CreateDropdown({ name = "Long", options = longOptions, value = "Option 1" })
end)

eq(#short._optionFrames, 0, "D1 a closed dropdown has no rows")
eq(#long._optionFrames, 0, "D1 ... however long its option list is")
eq(short.searchbar, nil, "D1 a closed dropdown has no search bar either")
eq(shortCost, longCost, "D1 a closed dropdown costs the same with 12 options as with 2")
expect(shortCost <= 30, "D1 a closed dropdown stays under 30 instances (used " .. tostring(shortCost) .. ")")

for _, child in long.list:GetChildren() do
	local className = (child.__props or {}).ClassName
	local name = (child.__props or {}).Name
	local allowed = className == "UIFlexItem"
		or className == "UIListLayout"
		or className == "UIPadding"
		or (className == "TextLabel" and name == "Empty")
	expect(allowed, "D1 the closed list holds nothing but its empty label (found " .. tostring(className) .. ")")
end

-- ===== D2: opening materialises the list once =====

local beforeOpen = count(tab.tabPage)
openDropdown(long)
eq(#long._optionFrames, 12, "D2 opening builds one row per option")
expect(long.searchbar ~= nil, "D2 ... and the search bar with them")
for index, row in long._optionFrames do
	eq(row.name, long.options[index], "D2 row " .. tostring(index) .. " is the option at that index")
	eq(row.frame.LayoutOrder, index, "D2 ... laid out in option order")
	eq(row.frame.Parent, long.list, "D2 ... inside the list")
end
eq(
	count(tab.tabPage) - beforeOpen,
	12 * 8 + 7,
	"D2 the open dropdown is exactly its 12 rows (8 instances each) plus the bar (7)"
)

-- ===== D3: the rows render exactly like the always-built ones =====

local selected = rowState(long._optionFrames[1])
eq(selected.frame, 0.9, "D3 the selected row keeps the open dropdown's fill")
eq(selected.title, 0, "D3 ... its title")
eq(selected.icon, 0, "D3 ... and its check icon")
eq(selected.stroke, 0.85, "D3 ... and its stroke")

local unselected = rowState(long._optionFrames[2])
eq(unselected.frame, 0.95, "D3 an unselected row keeps its fill")
eq(unselected.title, 0.3, "D3 ... its title")
eq(unselected.icon, 0.7, "D3 ... and its check icon")
eq(unselected.stroke, 0.93, "D3 ... and its stroke")

--[[
The stub leaves Visible unset (the engine default is true), so the corner
tiers are asked for the same way the open path asks for them: every row on
screen. The rows sit 6px inside the panel that clips them, so the outer
tier is that panel's own `ElementCornerRadius` -- a row's arc then lands
inside the clip instead of being cut by it -- and the seam where two rows
meet sits the element's 4px `rowSeam` below it. Read from the theme, so
the assertion follows a radius change instead of pinning one number.
]]
local outerTier = window.theme.ElementCornerRadius.Offset
local innerTier = outerTier - 4

for _, row in long._optionFrames do
	row.frame.Visible = true
end
long:_updateCorners()
local firstCorner = long._optionFrames[1].corner
local lastCorner = long._optionFrames[12].corner
eq(firstCorner.TopLeftRadius.Offset, outerTier, "D3 the first row rounds its top")
eq(firstCorner.BottomLeftRadius.Offset, innerTier, "D3 ... and meets the next row at the list radius")
eq(lastCorner.BottomLeftRadius.Offset, outerTier, "D3 the last row rounds its bottom")
eq(lastCorner.TopLeftRadius.Offset, innerTier, "D3 ... and meets the one above at the list radius")

-- ===== D4: reopening reuses the same rows =====

local keptRow = long._optionFrames[3]
local keptBar = long.searchbar
local openCost = count(tab.tabPage)
closeDropdown(long)
eq(long._isOpen, false, "D4 the list closed")
openDropdown(long)
eq(long._isOpen, true, "D4 ... and reopened")
eq(#long._optionFrames, 12, "D4 reopening keeps one row per option")
expect(long._optionFrames[3] == keptRow, "D4 ... the same row objects")
expect(long.searchbar == keptBar, "D4 ... and the same search bar")
eq(count(tab.tabPage), openCost, "D4 reopening builds nothing new")
closeDropdown(long)

-- ===== D5: edits made while closed are reflected on open =====

local edited = tab:CreateDropdown({ name = "Edited", options = { "A", "B", "C" }, value = "A" })
TestPump(0.3)
edited:Add("D")
edited:Remove("B")
edited:Refresh({ "A", "D", "E" })
TestPump(0.3)
eq(#edited._optionFrames, 0, "D5 editing a closed dropdown does not build rows")
openDropdown(edited)
eq(#edited._optionFrames, 3, "D5 the next open builds exactly the refreshed list")
local wanted = { "A", "D", "E" }
for index, row in edited._optionFrames do
	eq(row.name, wanted[index], "D5 row " .. tostring(index) .. " follows the refreshed list")
	eq(row.frame.LayoutOrder, index, "D5 ... in order")
end
eq(edited.value[1], "A", "D5 a selection the new list still has survives")
eq(rowState(edited._optionFrames[1]).frame, 0.9, "D5 ... and its row opens highlighted")
closeDropdown(edited)

--[[
A refreshed list that no longer holds the selection clears it and the
header falls back to the placeholder - the behaviour the always-built
version had, now reached without a single row existing first.
]]
local cleared = tab:CreateDropdown({ name = "Cleared", options = { "A" }, value = "A" })
TestPump(0.2)
cleared:Refresh({ "Q" })
TestPump(0.2)
eq(cleared.value[1], nil, "D5 a new list that drops the selection clears it")
expect(cleared.selectedLabel.Text ~= "", "D5 ... and the header falls back to its placeholder")
openDropdown(cleared)
eq(#cleared._optionFrames, 1, "D5 ... and the next open builds the new list")
eq(cleared._optionFrames[1].name, "Q", "D5 ... from the options it was given")
closeDropdown(cleared)

-- ===== D6: picking a row still works =====

local pick = tab:CreateDropdown({ name = "Pick", options = { "One", "Two", "Three" }, value = "One" })
openDropdown(pick)
eq(pick.selectedLabel.Text, "One", "D6 the header shows the current value")
eq(rowState(pick._optionFrames[1]).frame, 0.9, "D6 ... and its row is the highlighted one")
pick._optionFrames[3].interact.MouseButton1Click:Fire()
TestPump(0.3)
eq(pick.value[1], "Three", "D6 clicking a row selects it")
eq(pick.selectedLabel.Text, "Three", "D6 ... and the header follows")
eq(pick._isOpen, false, "D6 a single-select pick closes the list")
openDropdown(pick)
eq(rowState(pick._optionFrames[3]).frame, 0.9, "D6 ... the picked row is highlighted next time")
eq(rowState(pick._optionFrames[1]).frame, 0.95, "D6 ... and the row it replaced is not")
closeDropdown(pick)

-- ===== D7: the search bar filters the rows it was built with =====

local search = tab:CreateDropdown({ name = "Search", options = { "Alpha", "Beta", "Gamma" }, value = "Alpha" })
openDropdown(search)
search.searchToggle.MouseButton1Click:Fire()
TestPump(0.3)
eq(search._searchOpen, true, "D7 opening the search leaves every row alone until something is typed")
eq(#search._optionFrames, 3, "D7 ... with the rows it was built with")
search.searchInput.Text = "ga"
TestPump(0.3)
eq(search._optionFrames[1].frame.Visible, false, "D7 a row that does not match is hidden")
eq(search._optionFrames[2].frame.Visible, false, "D7 ... every one of them")
eq(search._optionFrames[3].frame.Visible, true, "D7 ... and the matching row stays")
search.searchIcon.MouseButton1Click:Fire()
TestPump(0.3)
eq(search._searchOpen, false, "D7 collapsing the search clears the filter")
eq(search._optionFrames[1].frame.Visible, true, "D7 every row is back")

--[[
===== D8: a dropdown inside a Collapsible Group scrolls the tab page =====
Grouped controls receive the group as their `tab` (that is what parents
them into the group body), and the group body is a plain Frame. The
open-time scroll used to read ScrollingFrame-only members off whatever
`tabPage` it found, which the engine rejects ("AbsoluteWindowSize is not
a valid member of Frame") the first time a grouped dropdown opens; the
stub models that strictness, so this pin fails on the old code path.
]]

local groupedTab = window:CreateTab({ name = "Grouped" })
local group = groupedTab:CreateCollapsibleGroup({
    name = "Nested controls",
    elements = {
        { type = "Dropdown", name = "Inner", options = { "One", "Two", "Three" }, value = "One" },
    },
})
groupedTab:Select()
TestPump(0.3)
group.interact.Activated:Fire()
TestPump(0.4)
eq(group._expanded, true, "D8 the group expands")
local inner = group.elements[1]
eq(inner.tab, group, "D8 a grouped control's owner is the group")
openDropdown(inner)
eq(inner._isOpen, true, "D8 a grouped dropdown opens without reading scroll members off the group body")
local host = inner.tab
while host and host.__type ~= "Tab" do
    host = host.tab
end
eq(host, groupedTab, "D8 ... and its owner chain ends at the tab that owns the scroll page")
closeDropdown(inner)

window:Unload()
TestPump(0.1)

print("DROPDOWN ROWS: all assertions passed")
