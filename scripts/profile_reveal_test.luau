-- ===== profile card reveal assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * P1 with "Reveal profile details" off (the default) the card still
--        shows, and every identifying value on it is masked: the display
--        name (headline), the @username (subtitle), the user ID (with its
--        COPY action hidden) and the place ID (current-game card),
--   * P2 the toggle reveals all four at once,
--   * P3 toggling back off re-masks all four,
--   * P4 an explicit Window:SetProfile subtitle is developer copy, not
--        identity data, so the toggle leaves it alone,
--   * P5 regression: a window built before Players.LocalPlayer exists still
--        shows its card once the player turns up. The identity refresh used
--        to call a nil `sidebar.mask_username`, which threw inside the
--        RenderStepped waiter and left the panel invisible even though
--        "Show profile" was on,
--   * P6 the card also needs room on screen: turning it on in a viewport too
--        small for it keeps it hidden but says why (notification),
--   * P7 "Reveal profile details" depends on "Show profile": flipping it on
--        while the card is off is refused (the setting stays off, the switch
--        rolls back and a notification says what is required), it works once
--        the card is on, and hiding the card takes an active reveal off with
--        it.

local function expect(cond, message)
	if not cond then
		error("PROFILE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"PROFILE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local MASKED_ID = "••••••"
local USER_ID = 42
local PLACE_ID = 2753915549

-- [[The stub player/game carry no identity of their own: give them distinct]]
-- [[values so a masked display name can never be confused with the username.]]
local state = Astra.Core.state
local player = state.localPlayer
expect(player ~= nil, "P0 the stub environment has a local player")
player.Name = "TestUser"
player.DisplayName = "Test User"
player.UserId = USER_ID
game.PlaceId = PLACE_ID
game.Name = "Test Place"
game.JobId = "astra-reveal-server"

local window = Astra:CreateWindow({ name = "Profile Reveal Test" })
TestPump(0.6)

local function findSettingsElement(targetWindow, tabName, elementName)
	for _, tab in targetWindow._settingsTabs do
		if tab.name == tabName then
			tab:Select()
			TestPump(0.15)
			for _, element in tab.elements do
				if element.name == elementName then
					return element
				end
			end
		end
	end
	return nil
end

local function assertMasked(message)
	eq(window.profileName.Text, "Tes****", message .. ": display name masked")
	eq(window.profileSubtitle.Text, "@Tes****", message .. ": username masked")
	eq(window.profileSubtitle.Visible, true, message .. ": username row visible")
	eq(window.profileUserIdValue.Text, MASKED_ID, message .. ": user ID masked")
	eq(window.profileCopyUserId.Visible, false, message .. ": COPY hidden while the user ID is masked")
	eq(window.profilePlaceId.Text, MASKED_ID, message .. ": place ID masked")
	eq(window.profileServerIdValue.Text, MASKED_ID, message .. ": job ID masked")
end

local function assertRevealed(message)
	eq(window.profileName.Text, "Test User", message .. ": display name revealed")
	eq(window.profileSubtitle.Text, "@TestUser", message .. ": username revealed")
	eq(window.profileUserIdValue.Text, tostring(USER_ID), message .. ": user ID revealed")
	eq(window.profileCopyUserId.Visible, true, message .. ": COPY available once the user ID is revealed")
	eq(window.profilePlaceId.Text, tostring(PLACE_ID), message .. ": place ID revealed")
	eq(window.profileServerIdValue.Text, "astra-reveal-server", message .. ": job ID revealed")
end

-- P1: the card is on screen by default, with everything masked.
expect(window.profilePanel ~= nil, "P1 the profile panel exists beside the window")
eq(window.profilePanel.Visible, true, "P1 the card shows with 'Show profile' on")
eq(window.settings.showFullUsername, false, "P1 the reveal toggle defaults to off")
assertMasked("P1")

-- P2: the reveal toggle drives all four identity fields at once.
local revealToggle = findSettingsElement(window, "Appearance", "Reveal profile details")
expect(revealToggle ~= nil, "P2 the 'Reveal profile details' toggle exists")
expect(
	findSettingsElement(window, "Appearance", "Reveal full username") == nil,
	"P2 the old 'Reveal full username' toggle is gone"
)
revealToggle:Set(true)
TestPump(0.2)
eq(window.settings.showFullUsername, true, "P2 the toggle writes its setting")
assertRevealed("P2")

-- P3: back off, everything re-masks (nothing latches the revealed values).
revealToggle:Set(false)
TestPump(0.2)
eq(window.settings.showFullUsername, false, "P3 the toggle writes its setting back")
assertMasked("P3")

-- P4: SetProfile copy is the developer's own text, so the toggle skips it.
window:SetProfile("Panel subtitle")
TestPump(0.1)
eq(window.profileSubtitle.Text, "Panel subtitle", "P4 a custom subtitle replaces the @username")
revealToggle:Set(true)
TestPump(0.2)
eq(window.profileSubtitle.Text, "Panel subtitle", "P4 the reveal toggle leaves custom copy alone")
eq(window.profileName.Text, "Test User", "P4 the headline still follows the toggle")
revealToggle:Set(false)
TestPump(0.2)
window:SetProfile(nil)
TestPump(0.1)
eq(window.profileSubtitle.Text, "@Tes****", "P4 clearing the custom subtitle restores the masked @username")

-- P8: the card's host-supplied rows (license key, whitelist) follow the same
-- masking rule as the platform identities and never show invented data. Run on
-- the first window (P4 just put its subtitle back) because CreateWindow would
-- replace the active window while `lateWindow` is still under test.
eq(window.profileKeyValue.Text, "—", "P8 no key is shown before the host supplies one")
eq(window.profileWhitelistValue.Text, "—", "P8 no whitelist status is shown before the host supplies one")
local expiresAt = os.time() + 5 * 86400
window:SetProfile({
	key = "ASTRA-LICENSE-KEY",
	whitelist = { status = "Active", expiresAt = expiresAt },
})
TestPump(0.2)
eq(window.profileSubtitle.Text, "@Tes****", "P8 SetProfile without a subtitle keeps the masked @username")
eq(window.profileKeyValue.Text, "••••••••", "P8 the license key is masked while reveal is off")
eq(window.profileWhitelistValue.Text, "5 days left", "P8 the whitelist row counts down from its expiry")
revealToggle:Set(true)
TestPump(0.2)
eq(window.profileKeyValue.Text, "ASTRA-LICENSE-KEY", "P8 the reveal unmasks the license key")
revealToggle:Set(false)
TestPump(0.2)
eq(window.profileKeyValue.Text, "••••••••", "P8 turning the reveal off masks the key again")
window:SetProfile({ whitelist = { status = "Expired", daysLeft = -1 } })
TestPump(0.2)
eq(window.profileKeyValue.Text, "—", "P8 clearing the key row falls back to the neutral placeholder")
eq(window.profileWhitelistValue.Text, "Expired", "P8 an elapsed whitelist reads as expired")
window:SetProfile({})
TestPump(0.2)


-- P5: regression - the card must appear when the local player turns up after
-- construction (the path that used to throw on the nil mask helper).
window:Unload()
TestPump(0.2)
state.localPlayer = nil
local lateWindow = Astra:CreateWindow({ name = "Profile Reveal Test (late player)" })
TestPump(0.6)
expect(lateWindow.profilePanel ~= nil, "P5 the panel is built even without a local player")
eq(lateWindow.profilePanel.Visible, false, "P5 the card stays hidden while the player is unknown")
eq(lateWindow.profileName.Text, "", "P5 no identity is rendered before the player exists")

state.localPlayer = player
TestPump(0.6)
eq(lateWindow.profilePanel.Visible, true, "P5 the card shows once the local player turns up")
eq(lateWindow.profileName.Text, "Tes****", "P5 the late identity refresh masks the display name")
eq(lateWindow.profileSubtitle.Text, "@Tes****", "P5 the late identity refresh masks the username")
eq(lateWindow.profileUserIdValue.Text, MASKED_ID, "P5 the late identity refresh masks the user ID")
eq(lateWindow.profilePlaceId.Text, MASKED_ID, "P5 the late identity refresh masks the place ID")

local lateReveal = findSettingsElement(lateWindow, "Appearance", "Reveal profile details")
expect(lateReveal ~= nil, "P5 the late window has its own reveal toggle")
lateReveal:Set(true)
TestPump(0.2)
eq(lateWindow.profileName.Text, "Test User", "P5 the late window reveals the display name")
eq(lateWindow.profileSubtitle.Text, "@TestUser", "P5 the late window reveals the username")
eq(lateWindow.profileUserIdValue.Text, tostring(USER_ID), "P5 the late window reveals the user ID")
eq(lateWindow.profilePlaceId.Text, tostring(PLACE_ID), "P5 the late window reveals the place ID")

-- P6: the card also needs room; an active toggle on a cramped viewport says
-- so instead of silently leaving the user without a card.
expect(lateWindow.notifications == nil, "P6 no notification has been raised yet")
TestViewport.set(360, 390)
TestPump(0.4)
local showProfileToggle = findSettingsElement(lateWindow, "Appearance", "Show profile")
expect(showProfileToggle ~= nil, "P6 the 'Show profile' toggle exists")
showProfileToggle:Set(false)
TestPump(0.2)
showProfileToggle:Set(true)
TestPump(0.2)
eq(lateWindow.profilePanel.Visible, false, "P6 a portrait viewport has no room for the card")
expect(
	lateWindow.notifications ~= nil,
	"P6 turning the card on without room explains why it is hidden"
)
TestViewport.set(1920, 1080)
TestPump(0.4)
eq(lateWindow.profilePanel.Visible, true, "P6 the card comes back once the screen has room")

-- P7: "Reveal profile details" only means something while the card is on
-- screen, so the switch is refused without it -- and turning the card off
-- takes an active reveal off with it.
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

eq(lateWindow.settings.showProfile, true, "P7 the card is back on after P6")
eq(lateWindow.settings.showFullUsername, false, "P7 P6 hiding the card already cleared the reveal")
eq(lateReveal.value, false, "P7 and rolled the reveal switch back with it")

showProfileToggle:Set(false)
TestPump(0.2)
eq(lateWindow.profilePanel.Visible, false, "P7 the card is hidden for the dependency check")
expect(
	not hasNotification(lateWindow, "Show profile is required"),
	"P7 no dependency notification has been raised yet"
)
lateReveal:Set(true)
TestPump(0.2)
eq(lateWindow.settings.showFullUsername, false, "P7 the refused reveal leaves the setting off")
eq(lateReveal.value, false, "P7 the refused reveal rolls its switch back")
eq(lateWindow.profileUserIdValue.Text, MASKED_ID, "P7 the refused reveal leaves the user ID masked")
eq(lateWindow.profilePlaceId.Text, MASKED_ID, "P7 the refused reveal leaves the place ID masked")
expect(
	hasNotification(lateWindow, "Show profile is required"),
	"P7 the refused reveal says that Show profile is required"
)

-- With the card back on, the same switch is accepted.
showProfileToggle:Set(true)
TestPump(0.2)
lateReveal:Set(true)
TestPump(0.2)
eq(lateWindow.settings.showFullUsername, true, "P7 the reveal sticks once Show profile is on")
eq(lateReveal.value, true, "P7 and its switch stays on")
eq(lateWindow.profileUserIdValue.Text, tostring(USER_ID), "P7 the card reveals the user ID")

-- Hiding the card again takes the active reveal off with it, so the reveal
-- can never sit on while there is nothing on screen to reveal.
showProfileToggle:Set(false)
TestPump(0.2)
eq(lateWindow.settings.showFullUsername, false, "P7 hiding the card clears the reveal")
eq(lateReveal.value, false, "P7 hiding the card rolls the reveal switch back")
expect(
	hasNotification(lateWindow, "Turned off with the profile card"),
	"P7 clearing the reveal explains itself"
)

print("PROFILE REVEAL: all assertions passed")
