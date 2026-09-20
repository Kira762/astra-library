-- Locked tabs: `CreateTab({ locked = true })` marks a tab visible-but-gated.
-- The lock badge is temporarily hidden with no reserved rail width; the row
-- dims like a disabled control, never selects (row tap, `tab:Select`,
-- `window:Navigate` all bail), and keeps its elements out of the search
-- index. Only host code unlocks it, through `tab:SetLocked(false)`; locking
-- a tab that is currently open moves the selection to another unlocked tab.
--
-- The assertions below pin the states a regression would break:
--
--   L1 the flag, the badge (always hidden during the UI pause) and the
--      auto-select skipping a locked first tab,
--   L2 a row tap on a locked tab: no selection, one notification,
--   L3 hover leaves a locked row dimmed (an unlocked row still hovers),
--   L4 `window:Navigate` (name and object) does not open a locked tab,
--   L5 a direct `tab:Select` does not open a locked tab,
--   L6 `SetLocked(false)` re-enables the row and it can be selected,
--   L7 `SetLocked(true)` on the open tab moves the selection off it,
--   L8 the search index excludes locked tabs' elements but keeps the
--      unlocked ones,
--   L9 locking every remaining tab clears the selection and hides the
--      content; unlocking and opening it again restores it,
--   L10 the hidden badge retains its geometry for re-enabling, but takes no
--      layout space and stays hidden after lock flips, collapse and rebuild.

local function expect(cond, message)
	if not cond then
		error("TAB LOCK FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"TAB LOCK FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function near(actual, wanted, tolerance, message)
	if actual == nil or math.abs(actual - wanted) > tolerance then
		error(
			"TAB LOCK FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. " ±" .. tostring(tolerance) .. ")",
			0
		)
	end
end

local function findNotificationCard(window)
	for _, child in window.notifications:GetChildren() do
		if child.Name == "Notification" then
			return child
		end
	end
	return nil
end

-- The card nests its labels two levels down (main -> body -> container), so
-- the scan is recursive over whatever the stub models as children.
local function cardContainsText(instance, text)
	for _, child in instance:GetChildren() do
		if child:IsA("TextLabel") then
			if child.Text == text then
				return true
			end
		elseif cardContainsText(child, text) then
			return true
		end
	end
	return false
end

local function cardContainsClass(instance, className)
	for _, child in instance:GetChildren() do
		if child:IsA(className) then
			return true
		elseif cardContainsClass(child, className) then
			return true
		end
	end
	return false
end

local window = Astra:CreateWindow({ name = "Tab Lock Test" })
TestPump(0.5)

-- L1: the flag, the badge, and auto-select skipping a locked first tab.
local lockedTab = window:CreateTab({ name = "Locked", icon = "star", locked = true })
local openTab = window:CreateTab({ name = "Open", icon = "house" })
local otherTab = window:CreateTab({ name = "Other", icon = "gauge" })
TestPump(0.3)

eq(lockedTab.locked, true, "L1 locked prop is stored")
eq(openTab.locked, false, "L1 unlocked by default")
expect(lockedTab.topbarItemLock, "L1 locked tab builds a lock badge")
eq(lockedTab.topbarItemLock.Visible, false, "L1 badge stays hidden while locked")
expect(openTab.topbarItemLock, "L1 badge instance exists on an unlocked tab")
eq(openTab.topbarItemLock.Visible, false, "L1 no lock icon is drawn while unlocked")
eq(window.selectedTab, openTab, "L1 auto-select skips the locked first tab")

-- L2: a row tap on a locked tab selects nothing and raises one notification.
lockedTab.topbarItemInteract.MouseButton1Click:Fire()
TestPump(0.4)
eq(window.selectedTab, openTab, "L2 tapping a locked tab does not select it")
local card = findNotificationCard(window)
expect(card, "L2 tapping a locked tab raises a notification")
expect(cardContainsText(card, "Locked"), "L2 notification title is 'Locked'")
expect(cardContainsText(card, "This tab is locked."), "L2 notification explains the lock")
expect(cardContainsClass(card, "ImageLabel"), "L2 notification carries the lock icon")

-- L3: hover never lifts a locked row; an unlocked row still hovers.
near(lockedTab.topbarItemIcon.ImageTransparency, 0.7, 0.05, "L3 locked row starts dimmed")
otherTab.topbarItemInteract.MouseEnter:Fire()
TestPump(0.3)
near(otherTab.topbarItemIcon.ImageTransparency, 0.3, 0.05, "L3 control: unlocked row hovers")
lockedTab.topbarItemInteract.MouseEnter:Fire()
TestPump(0.3)
near(lockedTab.topbarItemIcon.ImageTransparency, 0.7, 0.05, "L3 locked row ignores hover")
near(lockedTab.topbarItemLock.ImageTransparency, 0.7, 0.05, "L3 badge dims with the row")

-- L4: programmatic navigation respects the gate.
window:Navigate("Locked")
TestPump(0.1)
eq(window.selectedTab, openTab, "L4 Navigate by name does not open a locked tab")
window:Navigate(lockedTab)
TestPump(0.1)
eq(window.selectedTab, openTab, "L4 Navigate by object does not open a locked tab")

-- L5: a direct Select respects the gate.
lockedTab:Select()
TestPump(0.1)
eq(window.selectedTab, openTab, "L5 direct Select does not open a locked tab")

-- L6: SetLocked(false) re-enables the row.
lockedTab:SetLocked(false)
TestPump(0.3)
eq(lockedTab.locked, false, "L6 SetLocked(false) clears the flag")
eq(lockedTab.topbarItemLock.Visible, false, "L6 badge hidden after unlock")
lockedTab:Select()
TestPump(0.3)
eq(window.selectedTab, lockedTab, "L6 unlocked tab can be selected")
near(lockedTab.topbarItemIcon.ImageTransparency, 0, 0.05, "L6 selected row is bright again")

-- L7: SetLocked(true) on the open tab moves the selection off it.
lockedTab:SetLocked(true)
TestPump(0.3)
eq(lockedTab.locked, true, "L7 flag set again")
expect(window.selectedTab ~= lockedTab, "L7 selection moved off the locked tab")
eq(window.selectedTab, openTab, "L7 fallback is an unlocked tab from the same rail")
eq(lockedTab.topbarItemLock.Visible, false, "L7 badge stays hidden after relocking")
near(lockedTab.topbarItemIcon.ImageTransparency, 0.7, 0.05, "L7 locked row dimmed again")

-- L8: search never leaks a locked tab's contents.
local secret = lockedTab:CreateButton({ name = "SuperSecretThing" })
local visibleButton = openTab:CreateButton({ name = "VisibleThing" })
TestPump(0.2)
window.searchAction.interact.MouseButton1Click:Fire()
TestPump(0.5)
expect(window._searching, "L8 search opened")
local leaked = false
local foundVisible = false
for _, unit in window._searchUnits do
	if string.find(unit.text, "supersecretthing", 1, true) then
		leaked = true
	end
	if string.find(unit.text, "visiblething", 1, true) then
		foundVisible = true
	end
end
eq(leaked, false, "L8 search index excludes the locked tab's elements")
eq(foundVisible, true, "L8 search still indexes the unlocked tabs' elements")
window.searchAction.interact.MouseButton1Click:Fire()
TestPump(0.3)
eq(window._searching, false, "L8 search closed again")
eq(secret.__type, "Button", "L8 the locked tab's element still exists for the host")
eq(visibleButton.__type, "Button", "L8 control element still exists")

-- L9: locking every remaining tab hides the content; unlocking restores it.
window:Unload()
TestPump(0.3)
local w2 = Astra:CreateWindow({ name = "Tab Lock Edge" })
TestPump(0.5)
local tabA = w2:CreateTab({ name = "A", icon = "house" })
local tabB = w2:CreateTab({ name = "B", icon = "star" })
TestPump(0.3)
eq(w2.selectedTab, tabA, "L9 first unlocked tab auto-selected")

tabB:SetLocked(true)
w2.rfSettings:SetLocked(true)
TestPump(0.2)
tabA:SetLocked(true)
TestPump(0.3)
eq(w2.selectedTab, nil, "L9 everything locked: no tab can hold the selection")
eq(tabA._elementsPending, true, "L9 the locked open tab's content is marked pending")

local hiddenWhileLocked = tabA:CreateButton({ name = "HiddenWhileLocked" })
TestPump(0.3)
eq(
	hiddenWhileLocked.title.TextTransparency,
	1,
	"L9 content added to a locked tab stays hidden (elements hide by transparency)"
)

tabA:SetLocked(false)
TestPump(0.2)
tabA:Select()
TestPump(0.3)
eq(w2.selectedTab, tabA, "L9 unlocking restores the selection")
near(hiddenWhileLocked.title.TextTransparency, 0, 0.05, "L9 content revealed when the tab opens")
eq(tabA.topbarItemLock.Visible, false, "L9 badge hidden after the final unlock")

w2:Unload()

-- L10: the badge is integrated into the row, and the rail fits it.
local w3 = Astra:CreateWindow({ name = "Tab Lock Geometry" })
TestPump(0.5)
local alphaTab = w3:CreateTab({ name = "Alpha", icon = "house" })
local betaTab = w3:CreateTab({ name = "Beta", icon = "gauge" })
local premiumTab = w3:CreateTab({ name = "Premium", icon = "star", locked = true })
TestPump(0.3)

-- Stub text metrics: ceil(#text * 16 * 0.6), so "Premium" is 68px wide and
-- the row measures 20 (padding) + 26 (icon + gap) + 68 = 114,
-- i.e. a 144px rail with the row insets. Hidden badges reserve nothing.
local badge = premiumTab.topbarItemLock
expect(badge, "L10 locked tab builds a lock badge")
eq(badge.Visible, false, "L10 badge stays hidden while locked")
eq(badge.AnchorPoint.X, 1, "L10 badge anchors to the trailing edge")
eq(badge.AnchorPoint.Y, 0.5, "L10 badge centres vertically")
eq(badge.Position.X.Scale, 1, "L10 badge position is row-relative (X)")
eq(badge.Position.X.Offset, -w3.layout.rowPadding, "L10 badge insets by the row padding")
eq(badge.Position.Y.Scale, 0.5, "L10 badge position is row-relative (Y)")
eq(badge.Position.Y.Offset, 0, "L10 badge carries no vertical offset")
eq(badge.Size.X.Offset, 13, "L10 badge is small (13px wide)")
eq(badge.Size.Y.Offset, 13, "L10 badge is small (13px tall)")
eq(w3.sidebar.Size.X.Offset, 144, "L10 rail reserves no space for the hidden badge")
near(premiumTab.topbarItemTitle.TextTransparency, 0.7, 0.05, "L10 locked title holds the gated floor")
near(betaTab.topbarItemTitle.TextTransparency, 0.5, 0.05, "L10 adding a locked tab does not brighten the other rows")

-- Lock flips must not resize the rail while the badge is hidden.
premiumTab:SetLocked(false)
TestPump(0.3)
eq(premiumTab.topbarItemLock.Visible, false, "L10 badge hidden after unlock")
eq(w3.sidebar.Size.X.Offset, 144, "L10 unlocking keeps the same rail width")
premiumTab:SetLocked(true)
TestPump(0.3)
eq(w3.sidebar.Size.X.Offset, 144, "L10 locking keeps the same rail width")
near(premiumTab.topbarItemTitle.TextTransparency, 0.7, 0.05, "L10 the re-locked row keeps the gated floor")

-- A long locked name wraps clear of the badge: at the 300px cap the slot is
-- 270 - 20 - 26 - 19 = 224, while the short rows stay unconstrained.
local longLocked = w3:CreateTab({ name = "ThisLockedNameIsLongEnoughToCapTheRail", icon = "star", locked = true })
TestPump(0.3)
eq(w3.sidebar.Size.X.Offset, 300, "L10 very long locked name caps the rail")
eq(longLocked.topbarItemTitle.AutomaticSize, Enum.AutomaticSize.Y, "L10 capped locked title wraps")
eq(longLocked.topbarItemTitle.Size.X.Offset, 224, "L10 capped locked title holds the full title slot")
eq(premiumTab.topbarItemTitle.AutomaticSize, Enum.AutomaticSize.XY, "L10 short locked title stays unconstrained")
longLocked:Remove()
TestPump(0.2)
eq(w3.sidebar.Size.X.Offset, 144, "L10 removing the long row restores the content-fitted rail")

-- The collapsed tile has no trailing room: the badge keeps the corner seat.
TestViewport.set(500, 700)
TestPump(0.2)
eq(w3.sidebar.Size.X.Offset, 64, "L10 narrow viewport collapses the rail")
eq(badge.Visible, false, "L10 badge stays hidden on the collapsed tile")
eq(badge.AnchorPoint.X, 0, "L10 collapsed badge anchors top-left (X)")
eq(badge.AnchorPoint.Y, 0, "L10 collapsed badge anchors top-left (Y)")
eq(badge.Position.X.Scale, 1, "L10 collapsed badge keeps the corner seat (X scale)")
eq(badge.Position.X.Offset, -20, "L10 collapsed badge keeps the corner seat (X offset)")
eq(badge.Position.Y.Scale, 0, "L10 collapsed badge keeps the corner seat (Y scale)")
eq(badge.Position.Y.Offset, 11, "L10 collapsed badge keeps the corner seat (Y offset)")
TestViewport.set(1920, 1080)
TestPump(0.2)
eq(w3.sidebar.Size.X.Offset, 144, "L10 wide viewport restores the content-fitted rail")
eq(badge.AnchorPoint.X, 1, "L10 badge returns to the trailing seat")
eq(badge.Position.X.Offset, -w3.layout.rowPadding, "L10 badge returns to the row padding")
near(betaTab.topbarItemTitle.TextTransparency, 0.5, 0.05, "L10 restore keeps the unselected wash")
near(alphaTab.topbarItemTitle.TextTransparency, 0, 0.05, "L10 restore keeps the selected row bright")

premiumTab:_rebuildSelector()
eq(premiumTab.topbarItemLock.Visible, false, "L10 rebuilding cannot restore the paused lock UI")
premiumTab:SetLocked(false)
premiumTab:SetLocked(true)
eq(premiumTab.topbarItemLock.Visible, false, "L10 lock flips after rebuild keep the badge hidden")

w3:Unload()

print("TAB LOCK: all assertions passed")
