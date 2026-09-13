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
--   * topbar / collapsedSidebar layouts are untouched.

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

local switched = window:_setLayoutMode("sidebar")
expect(switched == true, "layout switch to the responsive sidebar")
TestPump(1.0)
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
assertRowsTrackRail("T6 collapsed rows track the collapsed rail")
for i, tab in groupTabs() do
	expect(tab.topbarItemTitle.Visible == false, "T6 row " .. i .. " hides its title when collapsed")
end

-- T7: wider window again -> the rail returns to the name-driven width.
TestViewport.set(1920, 1080)
TestPump(0.2)
assertGroupSized(shortRail, "T7 wide window -> name-driven rail restored")
for _, tab in groupTabs() do
	expect(tab.topbarItemTitle.Visible == true, "T7 titles visible again when expanded")
end

-- T8: the topbar layout keeps its existing per-pill sizing (untouched path).
switched = window:_setLayoutMode("top")
expect(switched == true, "T8 layout switch back to the topbar")
TestPump(1.0)
for i, tab in groupTabs() do
	local size = tab.topbarItem.Size
	if size.X.Offset ~= 0 or size.Y.Offset ~= 34 then
		error("SMOKE FAIL: T8 topbar row " .. i .. " keeps its original size", 0)
	end
	if tab.topbarItem.AutomaticSize ~= Enum.AutomaticSize.X then
		error("SMOKE FAIL: T8 topbar row " .. i .. " keeps AutomaticSize.X", 0)
	end
end

-- T9: the settings-mode rail group sizes from the settings tab names.
switched = window:_setLayoutMode("sidebar")
expect(switched == true, "T9 layout switch back to the responsive sidebar")
TestPump(1.0)

window:_buildSettingsUI() -- first settings access materialises its tab shells

-- T9a: the settings rail order - General must be the first row (the tab the
-- gear action opens), About the last; the old About customOrder (1000)
-- sorted it before General, so opening settings highlighted the SECOND row.
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
	local names = { rows[1] and rows[1].name, rows[2] and rows[2].name, rows[3] and rows[3].name, rows[4] and rows[4].name, rows[5] and rows[5].name, rows[6] and rows[6].name }
	if #rows ~= 6 or names[1] ~= "General" or names[2] ~= "Appearance" or names[3] ~= "Behavior" or names[4] ~= "Performance" or names[5] ~= "Persistence" or names[6] ~= "About" then
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
	#persistenceTab.elements >= 4,
	"T9b Persistence tab builds its content without a configuration prop (got " .. tostring(#persistenceTab.elements) .. " elements)"
)
local builtOnce = #persistenceTab.elements
persistenceTab:Select()
TestPump(0.2)
eq(#persistenceTab.elements, builtOnce, "T9b settings content is built exactly once")

window.rfSettings:Select()
TestPump(0.2)
local settingsRail = math.max(
	naturalRail("General", true),
	naturalRail("Appearance", true),
	naturalRail("Behavior", true),
	naturalRail("Performance", true),
	naturalRail("Persistence", true),
	naturalRail("About", true)
)
assertGroupSized(settingsRail, "T9 settings-mode rail group uses its own longest name")

-- T9c: opening settings via the gear path lands on the FIRST settings tab
-- (General), the page the content area shows is General's page, and the
-- lazy content for General is built on that first open.
window.selectedTab = t1
window._previousTab = t1
window._settingsMode = false
window.rfSettings:Select()
TestPump(0.2)
eq(window.selectedTab, window.rfSettings, "T9c opening settings selects General")
local currentPage = window.elementsLayout.__currentPage
expect(
	currentPage == window.rfSettings.tabPage,
	"T9c the content area shows General's page when settings opens"
)
expect(
	#window.rfSettings.elements >= 4,
	"T9c opening settings builds General's lazy content (got " .. tostring(#window.rfSettings.elements) .. " elements)"
)

-- T9d: every settings tab opens with its full content on its own page.
-- Performance gained its "Motion" section and the "Animation speed" dropdown
-- (the control that drives utilities/motion.luau), hence 4 rather than 2.
local expectedSettingsContent = {
    General = 4,
    Appearance = 14,
    Behavior = 2,
    Performance = 4,
    Persistence = 4,
    About = 9,
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
-- (name-driven sizing must not leak into it; title visibility there is
-- pre-existing baseline behavior and is intentionally not asserted).
switched = window:_setLayoutMode("collapsedSidebar")
expect(switched == true, "T13 layout switch to the collapsed sidebar")
TestPump(1.0)
assertRailWidth(RAIL_COLLAPSED, "T13 collapsed sidebar uses its fixed compact rail")
assertRowsTrackRail("T13 collapsed sidebar rows stay icon-only/full-rail")

-- T14: returning to the responsive sidebar restores name-driven sizing.
switched = window:_setLayoutMode("sidebar")
expect(switched == true, "T14 layout switch back to the responsive sidebar")
TestPump(1.0)
assertGroupSized(shortRail, "T14 responsive sidebar rail is name-sized again")

-- T15: the profile panel beside the window (it replaces the in-window
-- profile). The window + gap + panel rest centred on screen as one unit:
-- the window itself sits half a panel away from the screen centre, on the
-- opposite side of the panel.
local PANEL_W = 260
local PANEL_GAP = 12
local PANEL_H = 420 -- profilePanel.height: at default window height, matches window
local PANEL_SHIFT = (PANEL_W + PANEL_GAP) / 2
local main = window.main
local halfW = main.Size.X.Offset / 2
local halfPanelH = PANEL_H / 2

expect(window.profilePanel ~= nil, "T15 the profile panel exists beside the window")
eq(window.profilePanel.Visible, true, "T15 panel is visible while the window is shown")
expect(window.profilePanel.Parent == window.screenGui, "T15 panel is a sibling of the window frame")

eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "T15 window shifted away from the default right-side panel")
eq(main.Size.X.Offset, 600, "T15 desktop window width at the 1920x1080 viewport")
eq(main.Size.Y.Offset, 420, "T15 desktop window height at the 1920x1080 viewport")

eqVector2(window.profilePanel.AnchorPoint, 0, 0, "T15 right-side panel anchors at its left edge")
eqUDim2(
	window.profilePanel.Position,
	0.5,
	main.Position.X.Offset + halfW + PANEL_GAP,
	0.5,
	-halfPanelH,
	"T15 panel flush with the window's right edge, centred on the window"
)
eq(window.profilePanel.Size.X.Offset, PANEL_W, "T15 panel width")
eq(window.profilePanel.Size.Y.Offset, PANEL_H, "T15 panel uses its intrinsic content height")

eq(window.profileName.Text, "Tes****", "T15 display name masked by default")
eq(window.profileSubtitle.Text, "@Tes****", "T15 username masked by default")
expect(window.profileAvatar ~= nil, "T15 avatar exists")
expect(window.profileGear == nil, "T15 the card carries no settings gear")
expect(window.profileTierLabel ~= nil, "T15 the tier pill exists")
window:SetProfile("Panel subtitle")
TestPump(0.1)
eq(window.profileSubtitle.Text, "Panel subtitle", "T15 SetProfile drives the panel subtitle")
eq(window.profileSubtitle.Visible, true, "T15 subtitle visible once set")

eqUDim2(window.tabList.Size, 1, 0, 1, 0, "T15 the rail no longer reserves in-window profile footer space")

local appearanceTab, sideDropdown, showProfileToggle
for _, tab in window._settingsTabs do
    if tab.name == "Appearance" then
        appearanceTab = tab
    end
end
expect(appearanceTab ~= nil, "T15 the Appearance settings tab exists")
for _, el in appearanceTab.elements do
    if el.name == "Profile side" then
        sideDropdown = el
    elseif el.name == "Show profile" then
        showProfileToggle = el
    end
end
expect(sideDropdown ~= nil, "T15 the Profile side option exists")
expect(showProfileToggle ~= nil, "T15 the Show profile toggle exists")

-- Flipping the side moves the panel and shifts the window the other way.
sideDropdown:Set("Left")
TestPump(0.2)
eqUDim2(main.Position, 0.5, PANEL_SHIFT, 0.5, 0, "T15 left-side panel shifts the window right")
eqVector2(window.profilePanel.AnchorPoint, 1, 0, "T15 left-side panel anchors at its right edge")
eqUDim2(
	window.profilePanel.Position,
	0.5,
	main.Position.X.Offset - halfW - PANEL_GAP,
	0.5,
	-halfPanelH,
	"T15 panel flush with the window's left edge, centred on the window"
)
sideDropdown:Set("Right")
TestPump(0.2)
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "T15 back to the right side re-centres the window")

-- Toggling the panel off re-centres the window on its own.
showProfileToggle:Set(false)
TestPump(0.2)
eqUDim2(main.Position, 0.5, 0, 0.5, 0, "T15 hiding the panel re-centres the window")
eq(window.profilePanel.Visible, false, "T15 panel hidden with the toggle")
showProfileToggle:Set(true)
TestPump(0.2)
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "T15 showing the panel shifts the window again")
eq(window.profilePanel.Visible, true, "T15 panel visible again")

-- The panel is gated by horizontal room, not by device type: a portrait
-- phone (window + gap + panel would not fit) hides it and uses the fixed
-- mobile window size; a wide landscape phone (plenty of room) still shows
-- the panel and recentres the window; the desktop viewport restores both.
local inputService = game:GetService("UserInputService")
inputService.TouchEnabled = true
inputService.KeyboardEnabled = false
TestViewport.set(360, 390)
TestPump(0.4)
eq(window.profilePanel.Visible, false, "T15 portrait phone has no room for the panel")
eq(main.Size.X.Offset, 560, "T15 phone viewport uses the fixed mobile window width")
eq(main.Size.Y.Offset, 380, "T15 phone viewport uses the fixed mobile window height")
eqUDim2(main.Position, 0.5, 0, 0.5, 0, "T15 portrait phone window sits centred (no shift)")
TestViewport.set(1320, 600)
TestPump(0.4)
eq(window.profilePanel.Visible, true, "T15 wide landscape phone has room, panel shows")
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "T15 landscape phone window recentres for the panel")
TestViewport.set(1920, 1080)
TestPump(0.4)
inputService.TouchEnabled = false
inputService.KeyboardEnabled = true
eq(window.profilePanel.Visible, true, "T15 desktop viewport restores the panel")
eq(main.Size.X.Offset, 600, "T15 desktop window width restored")
eq(main.Size.Y.Offset, 420, "T15 desktop window height restored")

print("SIDEBAR TAB SIZING: all assertions passed")
