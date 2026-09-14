-- ===== window + profile card centring assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * C1 a shown window rests with window + gap + card centred as ONE unit:
--        the window sits half a card away from the screen centre on the
--        opposite side of the card, and the card is vertically centred on the
--        window (so both are fully on screen),
--   * C2 the pair is centred on the first show even when the local player
--        turns up between the build and that show — the frame is built with
--        the card disabled, so the build-time centring cannot know about it,
--   * C3 hide/show comes back to the pair's centre, while a position the user
--        dragged to is restored instead of being re-centred,
--   * C4 the keep-on-screen clamp measures the pair, so a drag can push
--        neither the window nor the card off the edge — on either side,
--   * C5 with the card off, the resting centre and the clamp fall back to the
--        plain window,
--   * C6 expanding a minimised window re-clamps for the card that comes back
--        with it (the capsule's own clamp only knew the capsule).

local function expect(cond, message)
	if not cond then
		error("CENTRING FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"CENTRING FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

-- [[The stub's UDim2s are plain tables, so compare component-wise.]]
local function eqUDim2(actual, sx, so, sy, yo, message)
	if actual.X.Scale ~= sx or actual.X.Offset ~= so or actual.Y.Scale ~= sy or actual.Y.Offset ~= yo then
		error(
			"CENTRING FAIL: " .. message
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
-- the default window's height (420px) and 260px wide, gap 12.
local PANEL_W = 260
local PANEL_GAP = 12
local PANEL_H = 420
local PANEL_SHIFT = (PANEL_W + PANEL_GAP) / 2 -- 136: the window's off-centre rest
local EDGE_MARGIN = 8 -- the keep-on-screen margin

local state = Astra.Core.state
local player = state.localPlayer
expect(player ~= nil, "C0 the stub environment has a local player")
player.Name = "TestUser"
player.DisplayName = "Test User"
player.UserId = 42

local viewport = TestViewport.get()
eq(viewport.X, 1920, "C0 the stub viewport is the desktop width")
eq(viewport.Y, 1080, "C0 the stub viewport is the desktop height")
local centreX = viewport.X / 2
local centreY = viewport.Y / 2

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

-- ===== C1: a fresh window rests with the pair centred =====

local window = Astra:CreateWindow({ name = "Profile Centring Test" })
TestPump(0.6)

local main = window.main
local panel = window.profilePanel
expect(panel ~= nil, "C1 the profile card exists beside the window")
eq(panel.Visible, true, "C1 the card is shown ('Show profile' defaults to on)")
eq(panel.Size.X.Offset, PANEL_W, "C1 card width")
-- [[At default window height 420, card height must be exactly 420.]]
eq(panel.Size.Y.Offset, PANEL_H, "C1 card height at default")
eq(window.size.Y.Offset, PANEL_H, "C1 window height is default 420")
eq(panel.Size.Y.Offset, window.size.Y.Offset, "C1 card height matches window height")

local halfW = window.size.X.Offset / 2
local halfH = window.size.Y.Offset / 2
-- [[From the *pair's* centre: window + gap + card, halved. The window rests]]
-- [[one card-half (PANEL_SHIFT) off the screen centre, which is exactly what]]
-- [[makes the two edges symmetric.]]
local pairHalfW = (window.size.X.Offset + PANEL_GAP + PANEL_W) / 2
-- [[Card height equals window height, so vertical half is window half.]]
local clampNear = halfW
local clampFar = halfW + PANEL_GAP + PANEL_W
local pairHalfH = halfH
eqUDim2(main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "C1 the window rests half a card left of the screen centre")

local windowLeft = centreX - PANEL_SHIFT - halfW
local windowRight = windowLeft + window.size.X.Offset
local cardLeft = windowRight + PANEL_GAP
local cardRight = cardLeft + PANEL_W
eq(centreX - windowLeft, pairHalfW, "C1 the pair's left edge is one pair-half from the screen centre")
eq(cardRight - centreX, pairHalfW, "C1 and so is the pair's right edge, card included")
expect(windowLeft >= 0 and cardRight <= viewport.X, "C1 the whole pair is on screen horizontally")

eqUDim2(
	panel.Position,
	0.5,
	main.Position.X.Offset + halfW + PANEL_GAP,
	0.5,
	-PANEL_H / 2,
	"C1 the card hugs the window's right edge, vertically centred on the window"
)
local cardTop = centreY - PANEL_H / 2
expect(cardTop >= 0 and cardTop + PANEL_H <= viewport.Y, "C1 the centred card is fully on screen vertically")
-- [[Top and bottom align with window at default 420 height.]]
eq(panel.Position.Y.Offset, -PANEL_H / 2, "C1 card top aligns with window top at default")
eq(panel.Size.Y.Offset, PANEL_H, "C1 card bottom aligns with window bottom at default (height 420)")

-- ===== C2: the first show centres the pair for a player that turned up late =====

window:Unload()
TestPump(0.2)
state.localPlayer = nil
local lateWindow = Astra:CreateWindow({ name = "Profile Centring Test (late player)" })
-- [[The player arrives after the frame was built (so the build-time centring]]
-- [[saw a disabled card) but before the deferred first show runs.]]
state.localPlayer = player
-- [[The first show now also builds the initial settings page, and that build]]
-- [[is batched over a couple of extra frames by the construction pacing, so]]
-- [[give the reveal the frames it legitimately costs (was 0.15 when a shown]]
-- [[window had no settings content to build).]]
TestPump(0.35)
eq(lateWindow.profilePanel.Visible, true, "C2 the card shows on the first show")
eqUDim2(
	lateWindow.main.Position,
	0.5,
	-PANEL_SHIFT,
	0.5,
	0,
	"C2 the first show centres the window + card pair, not the window alone"
)

-- ===== C3: hide/show round trips =====

lateWindow:Hide()
TestPump(0.8)
eq(lateWindow.profilePanel.Visible, false, "C3 the card hides with the window")
lateWindow:Show()
TestPump(0.8)
eq(lateWindow.profilePanel.Visible, true, "C3 the card comes back with the window")
eqUDim2(lateWindow.main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "C3 the restore lands on the pair's centre")

-- [[A position the user dragged to (pure offset, no scale) is theirs: the]]
-- [[restore brings it back clamped, it does not re-centre over it.]]
lateWindow.main.Position = UDim2.fromOffset(500, 400)
TestPump(0.2)
lateWindow:Hide()
TestPump(0.8)
lateWindow:Show()
TestPump(0.8)
eqUDim2(
	lateWindow.main.Position,
	0,
	500,
	0,
	400,
	"C3 a dragged window is restored where it was left instead of being re-centred"
)
eq(
	lateWindow.profilePanel.Position.X.Offset,
	500 + halfW + PANEL_GAP,
	"C3 the card follows the dragged window"
)

-- ===== C4: the keep-on-screen clamp measures the pair =====

local clamped = lateWindow:_clampedPosition(UDim2.fromOffset(viewport.X, viewport.Y))
eq(
	clamped.X.Offset,
	viewport.X - clampFar - EDGE_MARGIN,
	"C4 dragging right stops when the card reaches the edge, not when the window does"
)
eq(
	clamped.Y.Offset,
	viewport.Y - pairHalfH - EDGE_MARGIN,
	"C4 dragging down stops when the pair reaches the edge"
)

local clampedOrigin = lateWindow:_clampedPosition(UDim2.fromOffset(0, 0))
eq(clampedOrigin.X.Offset, clampNear + EDGE_MARGIN, "C4 the window's own left edge still limits the left side")
eq(clampedOrigin.Y.Offset, pairHalfH + EDGE_MARGIN, "C4 the card's height limits the top (same as window)")

-- Flipping the card to the left mirrors both the resting centre and the clamp.
local sideDropdown = findSettingsElement(lateWindow, "Appearance", "Profile side")
expect(sideDropdown ~= nil, "C4 the 'Profile side' dropdown exists")
sideDropdown:Set("Left")
TestPump(0.3)
eqUDim2(lateWindow.main.Position, 0.5, PANEL_SHIFT, 0.5, 0, "C4 a left-side card mirrors the resting centre")
eqUDim2(
	lateWindow.profilePanel.Position,
	0.5,
	lateWindow.main.Position.X.Offset - halfW - PANEL_GAP,
	0.5,
	-PANEL_H / 2,
	"C4 the card hugs the window's left edge"
)
local clampedLeft = lateWindow:_clampedPosition(UDim2.fromOffset(0, 0))
eq(
	clampedLeft.X.Offset,
	clampFar + EDGE_MARGIN,
	"C4 with the card on the left, the pair's left edge limits the drag"
)
eq(clampedLeft.Y.Offset, pairHalfH + EDGE_MARGIN, "C4 the vertical limit is the same on both sides")
sideDropdown:Set("Right")
TestPump(0.3)
eqUDim2(lateWindow.main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "C4 back on the right, the pair recentres again")

-- ===== C5: with the card off, everything falls back to the plain window =====

local showProfileToggle = findSettingsElement(lateWindow, "Appearance", "Show profile")
expect(showProfileToggle ~= nil, "C5 the 'Show profile' toggle exists")
showProfileToggle:Set(false)
TestPump(0.3)
eq(lateWindow.profilePanel.Visible, false, "C5 the card is off")
eqUDim2(lateWindow.main.Position, 0.5, 0, 0.5, 0, "C5 the window recentres on its own")
local clampedOff = lateWindow:_clampedPosition(UDim2.fromOffset(viewport.X, viewport.Y))
eq(clampedOff.X.Offset, viewport.X - clampNear - EDGE_MARGIN, "C5 the clamp is the plain window clamp again")
eq(clampedOff.Y.Offset, viewport.Y - halfH - EDGE_MARGIN, "C5 vertically too")

-- ===== C6: expanding a minimised window re-clamps for the returning card =====

showProfileToggle:Set(true)
TestPump(0.3)
eq(lateWindow.profilePanel.Visible, true, "C6 the card is back")
eqUDim2(lateWindow.main.Position, 0.5, -PANEL_SHIFT, 0.5, 0, "C6 and the pair recentres with it")

-- [[Park the window where only the window itself fits: the capsule is happy]]
-- [[there, but the card would hang off the right edge once it comes back.]]
lateWindow.main.Position = UDim2.fromOffset(viewport.X - clampNear - EDGE_MARGIN, 400)
TestPump(0.2)
lateWindow:ToggleMinimise()
TestPump(0.8)
eq(lateWindow.profilePanel.Visible, false, "C6 the card hides while minimised")
lateWindow:ToggleMinimise()
TestPump(0.8)
eq(lateWindow.profilePanel.Visible, true, "C6 the card comes back with the expanded window")
eq(
	lateWindow.main.Position.X.Offset,
	viewport.X - clampFar - EDGE_MARGIN,
	"C6 expanding pulls the pair back into view instead of leaving the card off screen"
)

-- ===== Additional: height matches window at responsive sizes =====
TestViewport.set(900, 500)
TestPump(0.5)
local responsiveH = lateWindow.size.Y.Offset
eq(lateWindow.profilePanel.Size.Y.Offset, responsiveH, "Responsive: card height equals window height")
expect(lateWindow.profilePanel.Size.Y.Offset <= responsiveH, "Responsive: card height <= window height")
TestViewport.set(1920, 1080)
TestPump(0.5)
eq(lateWindow.profilePanel.Size.Y.Offset, lateWindow.size.Y.Offset, "Back to default: card height equals window height again")

print("PROFILE CENTRING: all assertions passed")
