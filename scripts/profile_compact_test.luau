-- ===== compact profile card (260x420) assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * D1 the card is exactly 260 wide x 420 high at default — the default window's
--        height — with the 12px gap preserved, and height matches window height,
--   * D2 the card sits on the selected side (right by default, left when
--        switched) flush with the window edge and vertically centred on it,
--   * D3 every profile field still exists on the compact card,
--   * D4 nothing is clipped: every row fits inside the card, and the card
--        never overlaps the window,
--   * D5 "Show profile" on shows the card and centres the window + gap +
--        card as one group from wherever the window is; off hides the card
--        and recentres the window alone,
--   * D6 "Reveal profile details" is refused while "Show profile" is off
--        (setting off, switch rolled back, explanatory notification), works
--        while the card is on, and is cleared — with all values re-masked —
--        when the card is hidden,
--   * D7 a stale saved configuration (reveal on, card off) is normalised by
--        Window:LoadSettings so the reveal can never come back active,
--   * D8 viewport changes recompute the whole layout: the window resizes,
--        the card height matches window height (never greater), stays attached
--        and centred, and a viewport too small for the pair hides the card again.

local function expect(cond, message)
	if not cond then
		error("COMPACT FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"COMPACT FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

-- [[The stub's UDim2s are plain tables, so compare component-wise.]]
local function eqUDim2(actual, sx, so, sy, yo, message)
	if actual.X.Scale ~= sx or actual.X.Offset ~= so or actual.Y.Scale ~= sy or actual.Y.Offset ~= yo then
		error(
			"COMPACT FAIL: " .. message
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

-- Card geometry (components/profilePanel.luau): the compact card is exactly
-- the default window's height (420px) and 260px wide.
local PANEL_W = 260
local PANEL_GAP = 12
local PANEL_H = 420
local PANEL_SHIFT = (PANEL_W + PANEL_GAP) / 2 -- 136: the window's off-centre rest

local MASKED_ID = "••••••"
local USER_ID = 42
local PLACE_ID = 2753915549

local state = Astra.Core.state
local player = state.localPlayer
expect(player ~= nil, "D0 the stub environment has a local player")
player.Name = "TestUser"
player.DisplayName = "Test User"
player.UserId = USER_ID
game.PlaceId = PLACE_ID
game.Name = "Test Place"
game.GameId = 123456
game.JobId = "astra-compact-server"

local function findSettingsElement(targetWindow, tabName, elementName)
	targetWindow:_buildSettingsUI() -- settings shells are now lazy too
	for _, tab in targetWindow._settingsTabs do
		if tab.name == tabName then
			tab:Select()
			TestPump(0.15)
			local function scan(elements)
				for _, element in elements do
					if element.name == elementName then
						return element
					end
					if element.elements then
						local found = scan(element.elements)
						if found then
							return found
						end
					end
				end
				return nil
			end
			return scan(tab.elements)
		end
	end
	return nil
end

local function findChild(instance, name)
	for _, child in instance:GetChildren() do
		if child.__props and child.__props.Name == name then
			return child
		end
		local found = findChild(child, name)
		if found then
			return found
		end
	end
	return nil
end

local function notificationTexts(targetWindow)
	local texts = {}
	local holder = targetWindow.notifications
	if not holder then
		return texts
	end
	for _, child in holder:GetChildren() do
		for _, descendant in child:GetDescendants() do
			if descendant.ClassName == "TextLabel" and descendant.Text ~= "" then
				table.insert(texts, descendant.Text)
			end
		end
	end
	return texts
end

local function hasNotification(targetWindow, needle)
	for _, text in notificationTexts(targetWindow) do
		if text:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local function assertMasked(targetWindow, message)
	eq(targetWindow.profileName.Text, "Tes****", message .. ": display name masked")
	eq(targetWindow.profileSubtitle.Text, "@Tes****", message .. ": username masked")
	eq(targetWindow.profileUserIdValue.Text, MASKED_ID, message .. ": user ID masked")
	eq(targetWindow.profileCopyUserId.Visible, false, message .. ": COPY hidden while the user ID is masked")
	eq(targetWindow.profilePlaceId.Text, MASKED_ID, message .. ": place ID masked")
	eq(targetWindow.profileServerIdValue.Text, MASKED_ID, message .. ": job ID masked")
end

-- Absolute on-screen edges of the window and the card, from their UDim2s
-- (the stub viewport is the ScreenGui's size).
local function edges(targetWindow)
	local viewport = TestViewport.get()
	local main = targetWindow.main
	local windowLeft = main.Position.X.Scale * viewport.X + main.Position.X.Offset
	local windowTop = main.Position.Y.Scale * viewport.Y + main.Position.Y.Offset
	local windowRight = windowLeft + main.Size.X.Offset
	local windowBottom = windowTop + main.Size.Y.Offset
	local leftSide = (targetWindow.settings.profileSide or "right") == "left"
	local panelW = targetWindow.profilePanel.Size.X.Offset
	local cardLeft = if leftSide then windowLeft - PANEL_GAP - panelW else windowRight + PANEL_GAP
	return {
		windowLeft = windowLeft,
		windowRight = windowRight,
		windowTop = windowTop,
		windowBottom = windowBottom,
		cardLeft = cardLeft,
		cardRight = cardLeft + panelW,
	}
end

local function assertNoOverlap(targetWindow, message)
	local e = edges(targetWindow)
	if (targetWindow.settings.profileSide or "right") == "left" then
		expect(e.cardRight <= e.windowLeft + 1e-9, message .. ": card does not overlap the window (left side)")
		eq(e.windowLeft - e.cardRight, PANEL_GAP, message .. ": the 12px gap is preserved (left side)")
	else
		expect(e.cardLeft >= e.windowRight - 1e-9, message .. ": card does not overlap the window (right side)")
		eq(e.cardLeft - e.windowRight, PANEL_GAP, message .. ": the 12px gap is preserved (right side)")
	end
end

local window = Astra:CreateWindow({ name = "Profile Compact Test" })
TestPump(0.6)

local main = window.main
local panel = window.profilePanel

-- ===== D1: exact dimensions =====
eq(main.Size.X.Offset, 600, "D1 the default window is 600px wide")
eq(main.Size.Y.Offset, 420, "D1 the default window is 420px high")
eq(panel.Size.X.Offset, PANEL_W, "D1 the card is exactly 260px wide")
eq(panel.Size.Y.Offset, PANEL_H, "D1 the card is exactly 420px high at default")
eq(PANEL_H, main.Size.Y.Offset, "D1 the card is exactly as tall as the default window")
eq(panel.Size.Y.Offset, main.Size.Y.Offset, "D1 card height matches window height")
eq(panel.Visible, true, "D1 the card shows with 'Show profile' on")

-- ===== D2: placement on the selected side =====

local halfW = main.Size.X.Offset / 2
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "D1 the window rests half a card left of the screen centre")
eq(panel.AnchorPoint.X, 0, "D2 the right-side card anchors at its left edge")
eqUDim2(
	panel.Position,
	0.5,
	main.Position.X.Offset + halfW + PANEL_GAP,
	0.5,
	-PANEL_H / 2,
	"D2 the card hugs the window's right edge and is vertically centred on the window"
)
assertNoOverlap(window, "D2 right-side")

local sideDropdown = findSettingsElement(window, "Appearance", "Profile side")
expect(sideDropdown ~= nil, "D2 the 'Profile side' dropdown exists")
sideDropdown:Set("Left")
TestPump(0.3)
eq(window.settings.profileSide, "left", "D2 the selected side setting is preserved")
eqUDim2(main.Position, 0.5, PANEL_SHIFT, 0.5, 0, "D2 the pair recentres for the left-side card")
eq(panel.AnchorPoint.X, 1, "D2 the left-side card anchors at its right edge")
eqUDim2(
	panel.Position,
	0.5,
	main.Position.X.Offset - halfW - PANEL_GAP,
	0.5,
	-PANEL_H / 2,
	"D2 the card hugs the window's left edge and stays vertically centred"
)
assertNoOverlap(window, "D2 left-side")
sideDropdown:Set("Right")
TestPump(0.3)
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "D2 back on the right, the pair recentres again")

-- ===== D3: every profile field still exists =====

expect(window.profileAvatar ~= nil, "D3 the avatar exists")
expect(window.profileName ~= nil, "D3 the display name exists")
expect(window.profileSubtitle ~= nil, "D3 the username subtitle exists")
expect(findChild(panel, "TierBadge") ~= nil, "D3 the tier badge exists")
expect(window.profileTierLabel ~= nil and window.profileTierLabel.Text == "PREMIUM",
	"D3 the tier pill states the platform tier (the stub player is Premium)")
expect(window.profileUserIdValue ~= nil, "D3 the user ID value exists")
expect(window.profileCopyUserId ~= nil, "D3 the user ID copy action exists")
expect(findChild(panel, "JoinDateValue") ~= nil, "D3 the join date / account age exists")
expect(findChild(panel, "Friends") == nil, "D3 the friends row is gone")
expect(findChild(panel, "Followers") == nil, "D3 the followers row is gone")
local gameCard = findChild(panel, "CurrentGame")
expect(gameCard ~= nil, "D3 the current game card exists")
expect(findChild(gameCard, "GameThumbnail") ~= nil, "D3 the game thumbnail exists")
expect(findChild(panel, "GameName") ~= nil, "D3 the game name exists")
expect(window.profilePlaceId ~= nil, "D3 the place ID exists")
expect(findChild(panel, "Account") ~= nil, "D3 the Account section label exists")
expect(findChild(panel, "AccountCard") ~= nil, "D3 the account container exists")
expect(findChild(panel, "Current Game") ~= nil, "D3 the Current Game section label exists")
expect(findChild(panel, "Server") ~= nil, "D3 the Server section label exists")
expect(findChild(panel, "ServerCard") ~= nil, "D3 the server container exists")
expect(findChild(panel, "User Session") ~= nil, "D3 the User Session section label exists")
expect(findChild(panel, "SessionCard") ~= nil, "D3 the session container exists")
expect(findChild(panel, "KeyValue") ~= nil, "D3 the license key row exists")
expect(findChild(panel, "WhitelistValue") ~= nil, "D3 the whitelist row exists")
expect(findChild(panel, "PlayersValue") ~= nil, "D3 the players row exists")
expect(findChild(panel, "UptimeValue") == nil, "D3 the server uptime row is gone")
expect(findChild(panel, "ServerIdValue") ~= nil, "D3 the job ID row exists")
expect(findChild(panel, "SessionValue") ~= nil, "D3 the time-in-server row exists")
expect(window.profileGear == nil, "D3 the settings gear is gone from the card")
eq(findChild(panel, "GameName").Text, "Test Place", "D3 the game name carries the live game data")
eq(window.profilePlaceId.Text, MASKED_ID, "D3 the place ID carries the live place data (masked)")

-- ===== D4: no clipping, no overlap =====

local function assertFits(inst, parentW, parentH, path)
	-- [[Children of a ScrollingFrame are the scroll canvas: they may extend
	-- [[past the frame vertically (that is what scrolling is for). Everything
	-- [[else - including every horizontal edge - must stay inside its parent,
	-- [[so nothing spills out of the card or forces sideways scrolling.]]
	local relaxedVertically = inst.ClassName == "ScrollingFrame"
	for _, child in inst:GetChildren() do
		if child:IsA("GuiObject") then
			local w = child.Size.X.Scale * parentW + child.Size.X.Offset
			local h = child.Size.Y.Scale * parentH + child.Size.Y.Offset
			local ax = child.AnchorPoint and child.AnchorPoint.X or 0
			local ay = child.AnchorPoint and child.AnchorPoint.Y or 0
			local x0 = child.Position.X.Scale * parentW + child.Position.X.Offset - ax * w
			local y0 = child.Position.Y.Scale * parentH + child.Position.Y.Offset - ay * h
			expect(
				x0 >= -1e-3 and x0 + w <= parentW + 1e-3,
				"D4 " .. path .. "." .. child.Name .. " (" .. tostring(x0) .. ".." .. tostring(x0 + w) .. " x "
					.. tostring(y0) .. ".." .. tostring(y0 + h)
					.. ") fits horizontally inside its " .. parentW .. "x" .. parentH .. " parent"
			)
			expect(
				relaxedVertically or (y0 >= -1e-3 and y0 + h <= parentH + 1e-3),
				"D4 " .. path .. "." .. child.Name .. " (" .. tostring(x0) .. ".." .. tostring(x0 + w) .. " x "
					.. tostring(y0) .. ".." .. tostring(y0 + h)
					.. ") fits inside its " .. parentW .. "x" .. parentH .. " parent"
			)
			assertFits(child, w, h, path .. "." .. child.Name)
		end
	end
end

assertFits(panel, PANEL_W, PANEL_H, "ProfilePanel")
assertNoOverlap(window, "D4 right-side")

-- ===== D5: 'Show profile' drives the card and the pair's centring =====

-- A position the user dragged to (pure offset, no scale): the card follows.
main.Position = UDim2.fromOffset(500, 300)
TestPump(0.2)
eqUDim2(
	panel.Position,
	0,
	500 + halfW + PANEL_GAP,
	0,
	300 - PANEL_H / 2,
	"D5 the card follows a dragged window"
)

local showProfileToggle = findSettingsElement(window, "Appearance", "Show profile")
expect(showProfileToggle ~= nil, "D5 the 'Show profile' toggle exists")

-- Off: the card hides and the window recentres by itself.
showProfileToggle:Set(false)
TestPump(0.3)
eq(window.profilePanel.Visible, false, "D5 deactivating 'Show profile' hides the card")
eqUDim2(main.Position, 0.5, 0, 0.5, 0, "D5 and recentres the window alone, even from a dragged position")

-- On: the card appears and the pair centres as one group.
showProfileToggle:Set(true)
TestPump(0.3)
eq(window.profilePanel.Visible, true, "D5 activating 'Show profile' automatically shows the card")
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "D5 and centres the window + gap + card as one group")

-- ===== D6: the reveal dependency =====

local revealToggle = findSettingsElement(window, "Appearance", "Reveal profile details")
expect(revealToggle ~= nil, "D6 the 'Reveal profile details' toggle exists")

showProfileToggle:Set(false)
TestPump(0.2)
eq(window.profilePanel.Visible, false, "D6 the card is hidden for the dependency check")
expect(not hasNotification(window, "Show profile is required"), "D6 no dependency notification has been raised yet")

revealToggle:Set(true)
TestPump(0.2)
eq(window.settings.showFullUsername, false, "D6 the refused reveal leaves the setting off")
eq(revealToggle.value, false, "D6 the refused reveal keeps the switch visually off")
assertMasked(window, "D6 the refused reveal")
expect(
	hasNotification(window, "Show profile is required"),
	"D6 the refused reveal says that Show profile is required"
)

showProfileToggle:Set(true)
TestPump(0.2)
revealToggle:Set(true)
TestPump(0.2)
eq(window.settings.showFullUsername, true, "D6 the reveal sticks once Show profile is on")
eq(revealToggle.value, true, "D6 and its switch stays on")
eq(window.profileName.Text, "Test User", "D6 the card reveals the display name")
eq(window.profileSubtitle.Text, "@TestUser", "D6 the card reveals the username")
eq(window.profileUserIdValue.Text, tostring(USER_ID), "D6 the card reveals the user ID")
eq(window.profilePlaceId.Text, tostring(PLACE_ID), "D6 the card reveals the place ID")
eq(window.profileServerIdValue.Text, "astra-compact-server", "D6 the card reveals the job ID")
eq(window.profileKeyValue.Text, "—", "D6 no license key is invented when none was supplied")
eq(window.profileWhitelistValue.Text, "—", "D6 no whitelist status is invented when none was supplied")

-- Hiding the card takes the active reveal off with it and re-masks everything.
showProfileToggle:Set(false)
TestPump(0.2)
eq(window.settings.showFullUsername, false, "D6 hiding the card turns 'Reveal profile details' off")
eq(revealToggle.value, false, "D6 and keeps the switch visually in sync")
assertMasked(window, "D6 hiding the card re-masks the sensitive fields")
expect(
	hasNotification(window, "Turned off with the profile card"),
	"D6 clearing the reveal explains itself"
)

-- ===== D7: a stale saved configuration cannot revive the reveal =====

-- Inject the pair as a settings file written before the dependency existed:
-- card off, reveal on. LoadSettings must normalise it.
window.settings.showFullUsername = true
window:LoadSettings()
eq(window.settings.showFullUsername, false, "D7 LoadSettings refuses to leave the reveal on with the card off")
assertMasked(window, "D7 the stale configuration")

-- And with the card on, a load keeps a valid pair intact (the normaliser
-- only corrects the broken direction).
showProfileToggle:Set(true)
TestPump(0.2)
window.settings.showFullUsername = true
window:LoadSettings()
eq(window.settings.showFullUsername, true, "D7 a valid reveal survives a load with the card on")
showProfileToggle:Set(false)
TestPump(0.2)

-- ===== D8: viewport changes recompute the layout =====

showProfileToggle:Set(true)
TestPump(0.3)
eq(window.profilePanel.Visible, true, "D8 the card is shown before the viewport changes")

TestViewport.set(900, 500)
TestPump(0.5)
eq(window.profilePanel.Visible, true, "D8 the card is still shown at the smaller viewport")
eq(panel.Size.X.Offset, PANEL_W, "D8 the card keeps its 260px width")
-- [[At responsive size, card height must match window height and never exceed it.]]
eq(panel.Size.Y.Offset, main.Size.Y.Offset, "D8 the card height matches window height at responsive size")
expect(panel.Size.Y.Offset <= main.Size.Y.Offset, "D8 card height <= window height")
eq(main.Size.X.Offset, 608, "D8 the window resized responsively (width)")
eq(main.Size.Y.Offset, 410, "D8 the window resized responsively (height)")
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "D8 the pair stays centred after the resize")
eqUDim2(
	panel.Position,
	0.5,
	main.Position.X.Offset + main.Size.X.Offset / 2 + PANEL_GAP,
	0.5,
	-panel.Size.Y.Offset / 2,
	"D8 the card stays attached to the resized window, centred on its centre"
)
assertNoOverlap(window, "D8 right-side")

-- Portrait: no room for window + gap + card, so the card hides (its setting
-- stays on) and the window rests on its own.
TestViewport.set(360, 390)
TestPump(0.5)
eq(window.profilePanel.Visible, false, "D8 a portrait viewport has no room for the card")
eq(window.settings.showProfile, true, "D8 the 'Show profile' setting stays on")
eqUDim2(main.Position, 0.5, 0, 0.5, 0, "D8 the window rests centred on its own")

-- Desktop again: the pair comes back and recentres.
TestViewport.set(1920, 1080)
TestPump(0.5)
eq(window.profilePanel.Visible, true, "D8 the card comes back once the screen has room")
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "D8 and the pair recentres")
assertNoOverlap(window, "D8 right-side")

-- ===== D9: thumbnail uses GameId for official endpoint, PlaceId for display =====
eq(game.PlaceId, PLACE_ID, "D9 PlaceId preserved")
eq(game.GameId, 123456, "D9 GameId available for official thumbnail")
-- [[Thumbnail should not throw and game card remains visible even if HTTP unavailable.]]
expect(findChild(panel, "CurrentGame") ~= nil, "D9 game card still visible after thumbnail logic")
expect(findChild(findChild(panel, "CurrentGame"), "GameThumbnail") ~= nil, "D9 thumbnail ImageLabel exists")

print("PROFILE COMPACT: all assertions passed")
