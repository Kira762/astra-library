-- ===== profile details card assertions (redesigned panel) =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * E1 the card is built from the window's own visual language: the themed
--        plate/stroke/corner tokens, one uppercase section label per section
--        (ACCOUNT, CURRENT GAME, SERVER, USER SESSION) and a rounded dark
--        container per section holding compact label/value rows,
--   * E2 the header is pinned: avatar, name, subtitle and the tier pill sit
--        outside the scrolling details region, which scrolls vertically
--        only, keeps bottom padding on its canvas and shows its scrollbar only
--        when the sections are taller than the window allows,
--   * E3 the SERVER and USER SESSION values come from the live environment
--        (Players:GetPlayers()/MaxPlayers, DataModel.JobId, the client's own
--        clock) and fall back to "—" when a source is unavailable - never to
--        an invented number,
--   * E4 the license/whitelist rows are host-owned (Window:SetProfile) and
--        read "—" until the host supplies real data,
--   * E5 long values truncate with an ellipsis and reveal the full text in the
--        themed hover tooltip; short values do not raise a tooltip,
--   * E6 a missing local player leaves neutral placeholders instead of
--        identity data or fabricated values,
--   * E7 the tier pill always states a real tier: PREMIUM / FREEMIUM from the
--        platform membership, or the host's own word from Window:SetProfile;
--        it rides the handle row next to the subtitle,
--   * E8 the copy actions write through the executor's clipboard (setclipboard)
--        and answer with a green check that returns to the copy icon,
--   * E9 the game name follows the official two-step API (place id ->
--        universe id -> the games list's "name") whenever the executor
--        exposes a request function, replacing the DataModel's place title.

local function expect(cond, message)
	if not cond then
		error("DETAILS FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"DETAILS FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local DASH = "—"

local state = Astra.Core.state
local theme = nil

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

local function isDescendantOf(instance, ancestor)
	local cursor = instance.Parent
	while cursor do
		if cursor == ancestor then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local player = state.localPlayer
expect(player ~= nil, "E0 the stub environment has a local player")
player.Name = "TestUser"
player.DisplayName = "Test User"
player.UserId = 42
game.PlaceId = 2753915549
game.Name = "Test Place"
game.GameId = 123456
game.JobId = "astra-details-server"

local window = Astra:CreateWindow({ name = "Profile Details Test" })
EnableProfileCard(window) -- lazy profile card
TestPump(1.2)
theme = window.theme
expect(theme ~= nil, "E0 the window exposes its resolved theme")

local panel = window.profilePanel
expect(panel ~= nil, "E1 the profile card exists")

-- ===== E1: the card reuses the window's design tokens =====

local surface = findChild(panel, "Surface")
expect(surface ~= nil, "E1 the card surface exists")
-- [[The panel's UICorner is a child of the surface frame.]]
local surfaceCornerInstance = nil
for _, child in surface:GetChildren() do
	if child.ClassName == "UICorner" then
		surfaceCornerInstance = child
	end
end
expect(surfaceCornerInstance ~= nil, "E1 the surface carries its UICorner")
eq(tostring(surfaceCornerInstance.CornerRadius.Offset), tostring(theme.CornerRoundness.Offset), "E1 the card reuses the window's corner radius")

-- [[Every section plate is styled exactly like a window element body:]]
-- [[Window:StyleElementBody's gradient, corner and stroke, at the theme's]]
-- [[own transparencies - so the card's containers and the window's elements]]
-- [[are visually the same object.]]
local accountCard = findChild(panel, "AccountCard")
expect(accountCard ~= nil, "E1 the account container exists")
local cardCorner = nil
local cardStroke = nil
local cardGradient = nil
for _, child in accountCard:GetChildren() do
	if child.ClassName == "UICorner" then
		cardCorner = child
	elseif child.ClassName == "UIStroke" then
		cardStroke = child
	elseif child.ClassName == "UIGradient" then
		cardGradient = child
	end
end
expect(cardGradient ~= nil, "E1 the containers carry the element gradient")
eq(tostring(cardGradient.Color.Keypoints[1].Value.R), tostring(theme.ElementGradient.Keypoints[1].Value.R),
	"E1 the container gradient is the theme's ElementGradient")
expect(cardCorner ~= nil and cardStroke ~= nil, "E1 the containers carry a corner and a stroke")
eq(tostring(cardCorner.CornerRadius.Offset), tostring(theme.ElementCornerRadius.Offset), "E1 containers use the element corner radius")
eq(tostring(cardStroke.Color.R), tostring(theme.ElementStroke.R), "E1 containers use the themed element stroke")
eq(tostring(cardStroke.Transparency), tostring(theme.ElementStrokeTransparency),
	"E1 the container stroke shows at the element stroke transparency")

-- [[Headings reuse the Section element's own look: ContentColor icon and]]
-- [[15px ContentColor title at the section transparencies.]]
for _, sectionLabel in { "Account", "Current Game", "Server", "User Session" } do
	local label = findChild(panel, sectionLabel)
	expect(label ~= nil, "E1 the " .. sectionLabel .. " section label exists")
	eq(tostring(label.TextColor3.R), tostring(theme.ContentColor.R), "E1 headings use the section title colour")
	eq(label.TextSize, 15, "E1 headings use the section title size")
	local icon = findChild(panel, sectionLabel .. "Icon")
	expect(icon ~= nil, "E1 the " .. sectionLabel .. " heading carries an icon")
	eq(tostring(icon.ImageColor3.R), tostring(theme.ContentColor.R), "E1 heading icons use the section icon colour")
end
for _, container in { "AccountCard", "CurrentGame", "ServerCard", "SessionCard" } do
	expect(findChild(panel, container) ~= nil, "E1 the " .. container .. " container exists")
end

-- [[Rows are compact label/value pairs in the window's element colours: the
-- [[label is a muted ContentColor line (the window's secondary-text
-- [[treatment), the value a full-strength ContentColor line, and both
-- [[truncate rather than overflow.]]
local userIdLabel = findChild(panel, "UserIdLabel")
local userIdValue = window.profileUserIdValue
expect(userIdLabel ~= nil and userIdValue ~= nil, "E1 the user ID row exists")
eq(tostring(userIdLabel.TextColor3.R), tostring(theme.ContentColor.R), "E1 row labels use the element text colour")
eq(tostring(userIdValue.TextColor3.R), tostring(theme.ContentColor.R), "E1 row values use the element text colour")
local userIdIcon = findChild(panel, "UserIdIcon")
expect(userIdIcon ~= nil, "E1 the user ID row carries an icon")
eq(tostring(userIdIcon.ImageColor3.R), tostring(theme.ContentColor.R), "E1 row icons use the element icon colour")
eq(userIdValue.TextTruncate, Enum.TextTruncate.AtEnd, "E1 long values truncate with an ellipsis")
eq(userIdLabel.TextXAlignment, Enum.TextXAlignment.Left, "E1 labels are left aligned")
eq(userIdValue.TextXAlignment, Enum.TextXAlignment.Right, "E1 values are right aligned")

-- ===== E2: pinned header + vertical-only scrolling =====

local details = findChild(panel, "Details")
local content = findChild(panel, "Content")
expect(details ~= nil and content ~= nil, "E2 the details scroller exists")
expect(details.ClassName == "ScrollingFrame", "E2 the details region is a ScrollingFrame")
eq(details.ScrollingDirection, Enum.ScrollingDirection.Y, "E2 the details region scrolls vertically only")
expect(isDescendantOf(content, details), "E2 the sections live inside the scroller")

for _, headerPart in { window.profileAvatar, window.profileName, window.profileSubtitle, window.profilePremium } do
	expect(not isDescendantOf(headerPart, details), "E2 the header stays pinned above the scroller")
end
expect(window.profileGear == nil, "E2 the card no longer carries a settings gear")
expect(isDescendantOf(window.profileSessionValue, details), "E2 the session row scrolls with the details")

-- [[The canvas keeps the bottom padding, so the last row is never flush against
-- [[the card edge.]]
expect(details.CanvasSize.Y.Offset > content.Size.Y.Offset, "E2 the canvas reserves padding around the content")
eq(details.CanvasSize.X.Offset, 0, "E2 the canvas never scrolls sideways")
eq(content.Size.X.Scale, 1, "E2 the content spans the scroller")
expect(content.Size.X.Offset <= 0, "E2 the content never exceeds the scroller width")

-- [[At the default window height the sections are taller than the region, so
-- [[the themed scrollbar is present.]]
expect(details.ScrollBarThickness > 0, "E2 the scrollbar appears while the sections overflow")
eq(details.ScrollBarImageColor3.R, 1, "E2 the scrollbar uses the dark theme's thumbnail colour")
expect(details.ClipsDescendants, "E2 the scroller clips its content")

-- [[A window tall enough for everything hides the scrollbar again and hands
-- [[the reserved width back to the content (simulated by resizing the frame,
-- [[which is what a viewport change does).]]
local originalSize = window.main.Size
local tallSize = UDim2.fromOffset(originalSize.X.Offset, 900)
window.size = tallSize
window.main.Size = tallSize
TestPump(0.2)
eq(details.ScrollBarThickness, 0, "E2 a tall enough card shows no scrollbar")
eq(content.Size.X.Offset, 0, "E2 the content reclaims the scrollbar width when nothing scrolls")
window.size = originalSize
window.main.Size = originalSize
TestPump(0.2)
expect(details.ScrollBarThickness > 0, "E2 the scrollbar comes back when the card shrinks again")

-- ===== E3: live server + session values =====

local players = game:GetService("Players")
expect(players ~= nil, "E3 the stub exposes the Players service")

players.MaxPlayers = 50
TestPump(1.2)
eq(window.profilePlayersValue.Text, "1 / 50", "E3 the players row shows current players / max players")
expect(
	window.profileSessionValue.Text:match("^%d+[smhd]") ~= nil
		or window.profileSessionValue.Text:match("^%d+d %d+h$") ~= nil,
	"E3 the session row shows a real duration (got " .. tostring(window.profileSessionValue.Text) .. ")"
)
eq(window.profileServerIdValue.Text, "••••••", "E3 the job ID is masked while reveal is off")

-- [[A missing source is a neutral placeholder, not a zero.]]
players.MaxPlayers = nil
players.GetPlayers = nil
TestPump(1.2)
eq(window.profilePlayersValue.Text, DASH, "E3 an unavailable player source reads as the neutral placeholder")

players.MaxPlayers = 50
players.GetPlayers = function()
	return { player }
end
TestPump(1.2)
eq(window.profilePlayersValue.Text, "1 / 50", "E3 the rows recover as soon as the source answers again")

-- ===== E4: host-owned license rows =====

eq(window.profileKeyValue.Text, DASH, "E4 the key row reads the placeholder until the host supplies one")
eq(window.profileWhitelistValue.Text, DASH, "E4 the whitelist row reads the placeholder until the host supplies one")
window:SetProfile({ key = "ASTRA-KEY-123", whitelist = { status = "Active", daysLeft = 14 } })
TestPump(0.2)
eq(window.profileKeyValue.Text, "••••••••", "E4 the key stays masked while reveal is off")
eq(window.profileWhitelistValue.Text, "14 days left", "E4 the whitelist row shows the host's status and days")
-- [[The legacy string/nil shape only swaps the subtitle: a host toggling
-- [[their own copy must not lose the license rows.]]
window:SetProfile(nil)
TestPump(0.2)
eq(window.profileSubtitle.Text, "@Tes****", "E4 clearing the subtitle restores the masked @username")
eq(window.profileKeyValue.Text, "••••••••", "E4 the legacy shape leaves the host's key row in place")
-- [[The table shape is a full payload: anything omitted is cleared.]]
window:SetProfile({})
TestPump(0.2)
eq(window.profileKeyValue.Text, DASH, "E4 an empty payload clears the key row")
eq(window.profileWhitelistValue.Text, DASH, "E4 an empty payload clears the whitelist row")

-- ===== E7: the tier pill always states a real tier =====

local premium = window.profilePremium
expect(premium ~= nil, "E7 the tier pill exists")
local player = state.localPlayer
local membership = player.MembershipType
eq(premium.Visible, true, "E7 the pill is shown")
eq(window.profileTierLabel.Text, "PREMIUM", "E7 a paid membership reads PREMIUM")
eq(premium.Position.Y.Offset, window.profileSubtitle.Position.Y.Offset - 0.5,
	"E7 the pill rides the @username row, matching the design")
expect(premium.Position.X.Offset > window.profileSubtitle.Position.X.Offset,
	"E7 the pill sits after the handle text")
expect(premium.Position.X.Offset + premium.Size.X.Offset <= panel.Size.X.Offset - 8,
	"E7 the pill never runs out of the card")
expect(isDescendantOf(premium, window.profilePanelSurface), "E7 the pill lives in the pinned header")

-- [[A free account is labelled rather than decorated: the pill switches to]]
-- [[FREEMIUM instead of disappearing.]]
player.MembershipType = Enum.MembershipType.None
window:SetProfile({ subtitle = "Still here" })
TestPump(0.2)
eq(premium.Visible, true, "E7 the pill stays for a free account")
eq(window.profileTierLabel.Text, "FREEMIUM", "E7 a free account reads FREEMIUM")

-- [[The host's own tier word wins, uppercased on the card.]]
window:SetProfile({ tier = "vip" })
TestPump(0.2)
eq(window.profileTierLabel.Text, "VIP", "E7 a host tier overrides the platform tier")
player.MembershipType = membership
window:SetProfile({})
TestPump(0.2)
eq(window.profileTierLabel.Text, "PREMIUM", "E7 clearing the payload restores the platform tier")

-- ===== E8: copy actions use the executor clipboard and flash a green check =====

local copied = {}
setclipboard = function(text)
	table.insert(copied, text)
	return true
end

window.settings.showFullUsername = true
window:SetProfile({})
TestPump(0.2)

local userIdEntry = window.profileCopyButtons.UserId
expect(userIdEntry ~= nil, "E8 the user ID copy action is registered")
eq(userIdEntry.button.Visible, true, "E8 the copy button shows once the value is revealed")
userIdEntry.button.Activated:Fire()
TestPump(0.1)
eq(copied[1], tostring(player.UserId), "E8 the copy wrote the user ID through setclipboard")
eq(userIdEntry.icon.Image, TestImageUri(window:ResolveIcon("check")), "E8 a successful copy swaps in the check icon")
eq(tostring(userIdEntry.icon.ImageColor3.R), tostring(theme.Success.R), "E8 the check reads in the success green")
eq(tostring(userIdEntry.icon.ImageColor3.G), tostring(theme.Success.G), "E8 the check reads in the success green")

TestPump(1.4)
eq(userIdEntry.icon.Image, TestImageUri(window:ResolveIcon("copy")), "E8 the copy icon returns after the flash")
eq(tostring(userIdEntry.icon.ImageColor3.R), tostring(theme.ActionColor.R), "E8 and so does its colour")

-- [[Every identifier row carries its own copy action.]]
for _, name in { "PlaceId", "ServerId", "Key" } do
	expect(window.profileCopyButtons[name] ~= nil, "E8 the " .. name .. " row carries a copy action")
end
window.settings.showFullUsername = false
window:SetProfile({})
TestPump(0.2)
eq(userIdEntry.button.Visible, false, "E8 masking the card hides the copy buttons again")

-- ===== E5: truncation + hover tooltip =====

local longName = string.rep("Extremely Long Game Title ", 6)
game.Name = longName
local longWindow = Astra:CreateWindow({ name = "Profile Details Test (long values)" })
EnableProfileCard(longWindow)
TestPump(0.6)
local longPanel = longWindow.profilePanel
expect(longPanel ~= nil, "E5 the long-value card exists")
local longGameName = findChild(longPanel, "GameName")
expect(longGameName ~= nil, "E5 the game name exists")
eq(longGameName.Text, longName, "E5 the game name is never truncated in the data, only in the label")
eq(longGameName.TextTruncate, Enum.TextTruncate.AtEnd, "E5 the game name truncates with an ellipsis")
expect(not longWindow.profileTooltip.Visible, "E5 the tooltip starts hidden")

longGameName.MouseEnter:Fire()
TestPump(0.1)
expect(longWindow.profileTooltip.Visible, "E5 hovering a truncated value raises the tooltip")
eq(longWindow.profileTooltipLabel.Text, longName, "E5 the tooltip shows the full value")

-- [[The window's ScreenGui stacks by global z-index, so a parent draws over
-- [[any lower-ranked child: unless the label outranks the surface it sits on,
-- [[the tooltip renders as an empty box with its text buried underneath.]]
eq(longWindow.screenGui.ZIndexBehavior, Enum.ZIndexBehavior.Global, "E5 the window stacks by global z-index")
expect(
	longWindow.profileTooltipLabel.ZIndex > longWindow.profileTooltip.ZIndex,
	"E5 ... so the tooltip label outranks its own surface"
)

longGameName.MouseLeave:Fire()
TestPump(0.4)
expect(not longWindow.profileTooltip.Visible, "E5 the tooltip hides again on mouse leave")

-- [[A short value that fits raises nothing.]]
longWindow.profilePlayersValue.MouseEnter:Fire()
TestPump(0.1)
expect(not longWindow.profileTooltip.Visible, "E5 a value that fits does not raise a tooltip")
longWindow:Unload()
TestPump(0.2)
game.Name = "Test Place"

-- ===== E6: no player, no invented identity =====

local absentPlayer = state.localPlayer
state.localPlayer = nil
local absentWindow = Astra:CreateWindow({ name = "Profile Details Test (no player)" })
EnableProfileCard(absentWindow)
TestPump(0.6)
eq(absentWindow.profilePanel.Visible, false, "E6 the card stays hidden while the local player is unknown")
eq(absentWindow.profileName.Text, "", "E6 no display name is invented")
eq(absentWindow.profileUserIdValue.Text, DASH, "E6 no user ID is invented")
eq(absentWindow.profileKeyValue.Text, DASH, "E6 no license key is invented")
state.localPlayer = absentPlayer
TestPump(0.6)
eq(absentWindow.profileUserIdValue.Text, "••••••", "E6 the real identity lands (masked) once the player is known")
absentWindow:Unload()
TestPump(0.2)

-- ===== E9: the official two-step game-name flow =====

-- [[With the executor's request function stubbed, the card must follow the]]
-- [[documented flow - place id -> universe id -> the games list's "name" -]]
-- [[and prefer that answer over the DataModel's own place title.]]
local requestedUrls = {}
request = function(opts)
	table.insert(requestedUrls, tostring(opts.Url))
	if opts.Url:find("/universes/v1/places/", 1, true) then
		return { StatusCode = 200, Body = '{"universeId":459933}' }
	end
	if opts.Url:find("/v1/games?universeIds=", 1, true) then
		return { StatusCode = 200, Body = '{"data":[{"id":459933,"name":"Blox Fruits"}]}' }
	end
	return { StatusCode = 404, Body = "" }
end

game.GameId = nil -- force the official place -> universe lookup
game.Name = "Some Place Title"
local nameWindow = Astra:CreateWindow({ name = "Profile Details Test (game name)" })
EnableProfileCard(nameWindow)
TestPump(1.0)
local nameGameName = findChild(nameWindow.profilePanel, "GameName")
expect(nameGameName ~= nil, "E9 the game name row exists")
eq(nameGameName.Text, "Blox Fruits", "E9 the official game name replaces the DataModel's place title")
local sawUniverseStep, sawGamesStep = false, false
for _, url in requestedUrls do
	if url:find("/universes/v1/places/2753915549/universe", 1, true) then
		sawUniverseStep = true
	end
	if url:find("/v1/games?universeIds=459933", 1, true) then
		sawGamesStep = true
	end
end
expect(sawUniverseStep, "E9 step 1 hits the universes endpoint with the place id")
expect(sawGamesStep, "E9 step 2 hits the games endpoint with the universe id")
nameWindow:Unload()
TestPump(0.2)
request = nil
game.GameId = 123456
game.Name = "Test Place"

print("PROFILE DETAILS: all assertions passed")
