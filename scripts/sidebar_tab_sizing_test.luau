-- ===== responsive sidebar sizing assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau. The stub]]
-- [[TextService measures text at 0.6 * size per character, so expected]]
-- [[widths are computed here from that same deterministic formula.]]
--
-- Expected behavior under test:
--   * the rail hugs the widest visible tab row (names drive its width,
--     no hardcoded rail width),
--   * rows stay full-rail (the pre-existing look), so every tab matches
--     the longest one and nothing floats mid-air,
--   * the window's available space caps the rail, so the elements area
--     always keeps at least half the window and takes back freed space,
--   * capped long names wrap in place instead of overflowing,
--   * collapsedSidebar layout is untouched.

local function expect(cond, message)
	if not cond then
		error("SMOKE FAIL: " .. message, 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"SMOKE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function eqVector2(actual, x, y, message)
	if actual.X ~= x or actual.Y ~= y then
		error(
			"SMOKE FAIL: " .. message .. " (got " .. tostring(actual.X) .. ", " .. tostring(actual.Y) .. ", want " .. tostring(x) .. ", " .. tostring(y) .. ")",
			0
		)
	end
end

-- [[The stub's UDim2s are plain tables, so compare component-wise.]]
local function eqUDim2(actual, sx, so, sy, yo, message)
	if actual.X.Scale ~= sx or actual.X.Offset ~= so or actual.Y.Scale ~= sy or actual.Y.Offset ~= yo then
		error(
			"SMOKE FAIL: " .. message
				.. " (got "
				.. tostring(actual.X.Scale) .. ", "
				.. tostring(actual.X.Offset) .. " / "
				.. tostring(actual.Y.Scale) .. ", "
				.. tostring(actual.Y.Offset)
				.. ", want "
				.. tostring(sx) .. ", "
				.. tostring(so) .. " / "
				.. tostring(sy) .. ", "
				.. tostring(yo) .. ")",
			0
		)
	end
end

-- Layout constants (utilities/layouts.luau, mode "sidebar")
local RAIL_COLLAPSED = 64
local ROW_INSET2 = 30 -- rowInset * 2
local ROW_PADDING2 = 20 -- rowPadding * 2
local ROW_ICON = 20
local ROW_SPACING = 6
local ROW_HEIGHT = 38

-- Window is 600 wide at the 1920x1080 test viewport (windowSizing fit).
local WINDOW_WIDE = 600
local RAIL_CAP = math.floor(WINDOW_WIDE * 0.5) -- the window's available-space cap

local function textW(text)
	return math.ceil(#text * 16 * 0.6)
end

local function naturalRow(name, hasIcon)
	local width = ROW_PADDING2
	if hasIcon then
		width += ROW_ICON
		if name ~= nil then
			width += ROW_SPACING
		end
	end
	if name ~= nil then
		width += textW(name)
	end
	return width
end

local function naturalRail(name, hasIcon)
	return naturalRow(name, hasIcon) + ROW_INSET2
end

local window = Astra:CreateWindow({ name = "Sidebar Sizing Test" })
print("stage: window created")
TestPump(0.5)
print("stage: initial pump done")

local function groupTabs()
	local out = {}
	for _, tab in window.tabs do
		if
			not tab.neglectSelector
			and tab.topbarItem
			and (tab._isSettingsTab == true) == (window._settingsMode == true)
		then
			table.insert(out, tab)
		end
	end
	return out
end

local function assertRailWidth(width, message)
	local sidebar = window.sidebar
	expect(sidebar ~= nil, message .. " (no sidebar rail)")
	eq(sidebar.Size.X.Offset, width, message .. " rail width")
	-- [[The elements area must take back whatever the rail frees up.]]
	eq(window.elements.Size.X.Offset, -width, message .. " elements take the freed space")
end

local function assertRowsTrackRail(message)
	local tabs = groupTabs()
	expect(#tabs > 0, message .. " (no rows in the current rail group)")
	for i, tab in tabs do
		local size = tab.topbarItem.Size
		if size.X.Scale ~= 1 or size.X.Offset ~= -ROW_INSET2 then
			error("SMOKE FAIL: " .. message .. " row " .. i .. " must stay full-rail (inset on both sides)", 0)
		end
	end
end

local function assertGroupSized(wantedRail, message)
	assertRailWidth(wantedRail, message)
	assertRowsTrackRail(message)
end

-- [[Icon-only rows are square tiles the height of the row (a 34x38 full-rail
-- [[row left the icon 7px from its sides but 9px from its top and bottom), and
-- [[the row's content is centred with no expanded padding.]]
local function assertRowsCollapsed(message)
	local tabs = groupTabs()
	expect(#tabs > 0, message .. " (no rows in the current rail group)")
	for i, tab in tabs do
		eq(tab.topbarItem.Size.X.Scale, 0, message .. " row " .. i .. " is a fixed-width icon tile")
		eq(tab.topbarItem.Size.X.Offset, ROW_HEIGHT, message .. " row " .. i .. " tile is square")
		eq(tab.topbarItem.Size.Y.Offset, ROW_HEIGHT, message .. " row " .. i .. " tile matches the row height")
		eq(tab.topbarItemContainer.Size.X.Scale, 1, message .. " row " .. i .. " content spans the tile")
		eq(tab.topbarItemContainer.Size.X.Offset, 0, message .. " row " .. i .. " content keeps no expanded padding")
		eq(tab.topbarItemContainer.Position.X.Offset, 0, message .. " row " .. i .. " content is not pushed inward")
		eq(tab.topbarItemLayout.HorizontalAlignment, Enum.HorizontalAlignment.Center, message .. " row " .. i .. " content is centred")
		expect(tab.topbarItemTitle.Visible == false, message .. " row " .. i .. " shows no title")
	end
end

expect(window.layout.mode == "sidebar", "window opens in responsive sidebar mode")
expect(window.sidebar ~= nil, "responsive sidebar rail exists")

-- T1: several tabs with identical short names.
local t1 = window:CreateTab({ name = "AAA", icon = "house" })
local t2 = window:CreateTab({ name = "AAA", icon = "house" })
local t3 = window:CreateTab({ name = "AAA", icon = "house" })
TestPump(0.2)
local shortRail = naturalRail("AAA", true)
assertGroupSized(shortRail, "T1 identical short names -> rail hugs the shared natural width")
expect(shortRail < 219, "T1 the rail is NOT a fixed 219px; it follows the names")

-- T2: a mixture of short and long names; the longest drives everything.
local medium = window:CreateTab({ name = "AAAAAAAAAAAA", icon = "gauge" }) -- 12 chars
TestPump(0.2)
local mediumRail = naturalRail("AAAAAAAAAAAA", true)
expect(mediumRail > shortRail, "T2 precondition: long name measures wider")
assertGroupSized(mediumRail, "T2 mixed names -> every row (incl. short ones) matches the longest")

-- T3: one significantly longer name; the window's available space is the cap.
local long1 = window:CreateTab({ name = "ThisTabNameIsReallyQuiteLong", icon = "sliders-horizontal" })
TestPump(0.2)
local long1Natural = naturalRail("ThisTabNameIsReallyQuiteLong", true)
expect(long1Natural > RAIL_CAP, "T3 precondition: name is wider than the available rail space")
assertGroupSized(RAIL_CAP, "T3 very long name -> rail caps at the available window space")
local long1Title = long1.topbarItemTitle
local cappedSlot = (RAIL_CAP - ROW_INSET2) - ROW_PADDING2 - ROW_ICON - ROW_SPACING
eq(long1Title.AutomaticSize, Enum.AutomaticSize.Y, "T3 capped title is width-constrained (wraps)")
eq(long1Title.Size.X.Offset, cappedSlot, "T3 capped title holds exactly the available slot")
expect(long1Title.TextWrapped == true, "T3 title keeps its existing TextWrapped style")
eq(t1.topbarItemTitle.AutomaticSize, Enum.AutomaticSize.XY, "T3 uncapped titles keep automatic sizing")
eq(t1.topbarItemTitle.Size.X.Offset, 0, "T3 uncapped titles keep their original size")
eq(window.elements.Size.X.Offset, -RAIL_CAP, "T3 elements keep at least half the window")

-- T4: multiple long names; no tab resizes independently.
local long2 = window:CreateTab({ name = "AnotherExtremelyLongTabName", icon = "palette" })
TestPump(0.2)
assertGroupSized(RAIL_CAP, "T4 several long names -> rail stays capped, all rows equal")

-- T5: removing the long rows re-derives the width from what remains (no latching).
long1:Remove()
long2:Remove()
TestPump(0.2)
assertGroupSized(mediumRail, "T5 after removing the long rows -> rail follows the new longest")
medium:Remove()
TestPump(0.2)
assertGroupSized(shortRail, "T5 after removing the medium row -> rail shrinks again")
eq(window.elements.Size.X.Offset, -shortRail, "T5 elements took back the freed space")

-- T6: narrow window -> the rail collapses to the icon-only width.
TestViewport.set(500, 700)
TestPump(0.2)
assertRailWidth(RAIL_COLLAPSED, "T6 narrow window -> rail uses the collapsed width")
assertRowsCollapsed("T6 narrow window -> rows become icon tiles")

-- T7: wider window again -> the rail returns to the name-driven width.
TestViewport.set(1920, 1080)
TestPump(0.2)
assertGroupSized(shortRail, "T7 wide window -> name-driven rail restored")
for _, tab in groupTabs() do
	expect(tab.topbarItemTitle.Visible == true, "T7 titles visible again when expanded")
end

-- T9: the settings-mode rail group sizes from the settings tab names.
window:_buildSettingsUI() -- first settings access materialises its tab shells

-- T9a: the gear opens the information-first Overview, followed by purpose-based controls.
do
	local rows = {}
	for _, tab in window._settingsTabs do
		if tab.topbarItem then
			table.insert(rows, { order = tab.topbarItem.LayoutOrder, name = tab.name })
		end
	end
	table.sort(rows, function(a, b)
		return a.order < b.order
	end)
	local names = { rows[1] and rows[1].name, rows[2] and rows[2].name, rows[3] and rows[3].name, rows[4] and rows[4].name }
	if #rows ~= 4 or names[1] ~= "Overview" or names[2] ~= "Controls" or names[3] ~= "Appearance" or names[4] ~= "Persistence" then
		error("SMOKE FAIL: T9a settings rail order (got " .. table.concat(names, ", ") .. ")", 0)
	end
end

-- T9b: the Persistence tab must build its content on first open even when
-- the window was created without a `configuration` prop (no saved configs
-- anywhere) - and it must build it exactly once.
local persistenceTab
for _, tab in window._settingsTabs do
	if tab.name == "Persistence" then
		persistenceTab = tab
	end
end
expect(persistenceTab ~= nil, "T9b the Persistence settings tab exists")
eq(#persistenceTab.elements, 0, "T9b settings content is lazy before first open")
persistenceTab:Select()
TestPump(0.2)
expect(
	#persistenceTab.elements >= 2,
	"T9b Persistence tab builds its content without a configuration prop (got " .. tostring(#persistenceTab.elements) .. " elements)"
)
local builtOnce = #persistenceTab.elements
persistenceTab:Select()
TestPump(0.2)
eq(#persistenceTab.elements, builtOnce, "T9b settings content is built exactly once")

window.rfSettings:Select()
TestPump(0.2)
local settingsRail = math.max(
	naturalRail("Overview", true),
	naturalRail("Appearance", true),
	naturalRail("Persistence", true),
	naturalRail("Controls", true)
)
assertGroupSized(settingsRail, "T9 settings-mode rail group uses its own longest name")

-- T9c: opening settings via the gear path lands on the FIRST settings tab
-- (Overview), the page the content area shows is Overview's page, and the
-- lazy content for Overview is built on that first open.
window.selectedTab = t1
window._previousTab = t1
window._settingsMode = false
window.rfSettings:Select()
TestPump(0.2)
eq(window.selectedTab, window.rfSettings, "T9c opening settings selects Overview")
local currentPage = window.elementsLayout.__currentPage
expect(
	currentPage == window.rfSettings.tabPage,
	"T9c the content area shows Overview's page when settings opens"
)
expect(
	#window.rfSettings.elements >= 3,
	"T9c opening settings builds Overview's lazy content (got " .. tostring(#window.rfSettings.elements) .. " elements)"
)

-- T9d: every settings tab opens with its full content on its own page.
local expectedSettingsContent = {
    Overview = 6,
    Controls = 5,
    -- [[Appearance has no Theme picker: Layout section, Bar Layout, Motion & Feedback.]]
    Appearance = 3,
    Persistence = 2,
}
for name, wanted in expectedSettingsContent do
	for _, tab in window._settingsTabs do
		if tab.name == name then
			tab:Select()
			TestPump(0.15)
			eq(#tab.elements, wanted, "T9d " .. name .. " tab opens with its full content")
			expect(
				window.elementsLayout.__currentPage == tab.tabPage,
				"T9d " .. name .. " opens on its own page"
			)
			break
		end
	end
end

t1:Select()
TestPump(0.2)
assertGroupSized(shortRail, "T9 leaving settings restores the normal group width")

-- T10: neglectSelector tabs have no row and must not influence sizing.
local hidden = window:CreateTab({ name = "ShouldNotAffectSizing", neglectSelector = true })
expect(hidden.topbarItem == nil, "T10 neglectSelector tab has no row")
assertGroupSized(shortRail, "T10 neglectSelector tab does not change the rail")
hidden:Remove()

-- T11: a tab without an icon measures without icon/spacing, and reverts on remove.
local noIcon = window:CreateTab({ name = "NoIconTab" })
TestPump(0.2)
assertGroupSized(naturalRail("NoIconTab", false), "T11 icon-less tab measured without icon and spacing")
eq(noIcon.topbarItemTitle.AutomaticSize, Enum.AutomaticSize.XY, "T11 icon-less title stays automatic")
noIcon:Remove()
TestPump(0.2)
assertGroupSized(shortRail, "T11 rail reverts after the icon-less tab is removed")

-- T12: locale changes re-measure the rail.
window:RegisterTranslations({ ["en"] = { ["AAA"] = "MuchLongerTranslatedName" } })
TestPump(0.2)
local translatedRail = naturalRail("MuchLongerTranslatedName", true)
if translatedRail > RAIL_CAP then
	assertGroupSized(RAIL_CAP, "T12 translated long name caps at the available width")
else
	assertGroupSized(translatedRail, "T12 translated name widens the rail for every row")
end
window:RegisterTranslations({ ["en"] = { ["AAA"] = "AAA" } })
TestPump(0.2)
assertGroupSized(shortRail, "T12 restoring the locale restores the original rail")

-- T13: the separate collapsedSidebar layout keeps its icon-only rail
-- (name-driven sizing must not leak into it).
switched = window:_setLayoutMode("collapsedSidebar")
expect(switched == true, "T13 layout switch to the collapsed sidebar")
TestPump(1.0)
assertRailWidth(RAIL_COLLAPSED, "T13 collapsed sidebar uses its fixed compact rail")
assertRowsCollapsed("T13 collapsed sidebar rows are icon tiles")
for i, tab in groupTabs() do

	expect(tab.topbarItemTitle ~= nil, "T13 row " .. i .. " keeps its title node for restore")
	expect(tab.topbarItemIcon ~= nil or tab.topbarItemInitial ~= nil, "T13 row " .. i .. " keeps an icon or initial")
end

-- T13b: rows are rebuilt by a layout switch (and by CreateTab) after the rail
-- has already been sized, so a row has to be born in the rail's current state.
-- Built as an expanded row, it kept its title and its 10px content padding, and
-- a 64px rail rendered "El…" of the tab name beside the icon instead of an
-- icon-only row centred in its tile.
local collapsedExtra = window:CreateTab({ name = "CollapsedExtra", icon = "gauge" })
TestPump(0.3)
assertRowsCollapsed("T13b a row created while collapsed is born icon-only")
collapsedExtra:Remove()
TestPump(0.3)
assertRailWidth(RAIL_COLLAPSED, "T13b removing the row keeps the collapsed rail")

-- T14: returning to the responsive sidebar restores name-driven sizing.
switched = window:_setLayoutMode("sidebar")
expect(switched == true, "T14 layout switch back to the responsive sidebar")
TestPump(1.0)
assertGroupSized(shortRail, "T14 responsive sidebar rail is name-sized again")

-- T14b: the same rebuild path has to re-apply the rail's title wrapping. A
-- capped long name had its width constraint reset by the rebuild, so the row
-- came back at its natural width and overflowed the rail it was capped for.
local longAgain = window:CreateTab({ name = "ThisTabNameIsReallyQuiteLong", icon = "sliders-horizontal" })
TestPump(0.3)
window:_setLayoutMode("collapsedSidebar")
TestPump(1.0)
window:_setLayoutMode("sidebar")
TestPump(1.0)
assertGroupSized(RAIL_CAP, "T14b rebuilt rows keep the capped rail")
local cappedTitle = longAgain.topbarItemTitle
eq(cappedTitle.AutomaticSize, Enum.AutomaticSize.Y, "T14b rebuilt capped title is width-constrained again")
eq(cappedTitle.Size.X.Offset, cappedSlot, "T14b rebuilt capped title holds the available slot")
longAgain:Remove()
TestPump(0.3)
assertGroupSized(shortRail, "T14b removing the long row restores the name-driven rail")

print("SIDEBAR TAB SIZING: all assertions passed")
