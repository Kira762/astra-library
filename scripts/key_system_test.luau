-- ===== key system assertions: the standalone key gate =======================
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau, plus the]]
-- [[in-memory executor filesystem from filesystem_stubs.luau.]]
--
-- Expected behavior under test:
--   * K1 the card is the popup-width short card (400px, ~150-165px tall) and
--        wears the corner scale: CornerRoundness on the shell,
--        ElementCornerRadius on the field and the Continue button,
--   * K2 a wrong key costs an attempt, clears the field and never fires
--        onSuccess,
--   * K3 a correct key (surrounding whitespace trimmed) passes, closes the
--        gate and saves the trimmed key to Astra/keys/<fileName>.txt,
--   * K4 a matching saved key skips the UI entirely (passthrough),
--   * K5 maxAttempts locks the gate and fires onMaxAttempts; further
--        submits are ignored,
--   * K6 a theme table overlays the baked palette (Continue wears it),
--   * K7 grabKeyFromSite fetches the expected key from the URL body,
--   * K8 dismissable=false builds no close button,
--   * K9 tapping the note with getKeyUrl copies the link and confirms,
--   * K10 no keys configured passes through with a warning,
--   * K11 a second gate retires the first (no stacking),
--   * K12 Escape closes a dismissable gate and fires onClose.

local function expect(cond, message)
	if not cond then
		error("KEY SYSTEM FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"KEY SYSTEM FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function cornerOf(frame)
	for _, child in frame:GetChildren() do
		if child.ClassName == "UICorner" then
			return child
		end
	end
	return nil
end

-- ===== K1: geometry and the corner scale ====================================

local gate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	onSuccess = function() end,
})
TestPump(0.6)

expect(gate._card ~= nil, "K1 the gate builds its card")
expect(gate._screenGui ~= nil and gate._screenGui.Parent ~= nil, "K1 the gate shows its root")
eq(gate._card.Size.X.Offset, 400, "K1 the card is the 400px popup-width card")
local height = gate._card.Size.Y.Offset
expect(height >= 140 and height <= 176, "K1 the card is the short card (got " .. tostring(height) .. "px)")
eq(gate._card.Position.X.Scale, 0.5, "K1 the card centres horizontally")
eq(gate._card.Position.Y.Scale, 0.5, "K1 the card centres vertically")

local cardCorner = cornerOf(gate._card)
expect(cardCorner ~= nil, "K1 the shell carries a corner")
eq(cardCorner.CornerRadius.Offset, 12, "K1 the shell wears CornerRoundness (12px)")
local fieldCorner = cornerOf(gate._fieldBox)
expect(fieldCorner ~= nil, "K1 the field carries a corner")
eq(fieldCorner.CornerRadius.Offset, 8, "K1 the field wears ElementCornerRadius (8px)")
local buttonCorner = cornerOf(gate._continue)
expect(buttonCorner ~= nil, "K1 Continue carries a corner")
eq(buttonCorner.CornerRadius.Offset, 8, "K1 Continue wears ElementCornerRadius (8px)")
expect(gate._input ~= nil, "K1 the field box holds its TextBox")
expect(gate._noteLabel ~= nil, "K1 the note line is built")

-- ===== K2: a wrong key costs an attempt, never a pass =======================

local fired = false
gate._input.Text = "nope"
gate:_submit(gate._input.Text)
TestPump(0.6)
eq(fired, false, "K2 a wrong key never fires onSuccess")
eq(gate.attempts, 1, "K2 a wrong key costs one attempt")
eq(gate.passed, false, "K2 a wrong key does not pass")
eq(gate.closed, false, "K2 a wrong key leaves the gate open")
eq(gate._input.Text, "", "K2 a wrong key clears the field")
gate:_submit("   ")
eq(gate.attempts, 1, "K2 an empty submit costs no attempt")

-- ===== K3: a correct key passes, closes and saves ===========================

local savedKey = nil
local passGate = Astra:CreateKeySystem({
	title = "Key System Test",
	fileName = "KeySystemTest",
	keys = { "SECRET" },
	saveKey = true,
	onSuccess = function(key)
		savedKey = key
	end,
})
TestPump(0.4)
eq(gate.closed, true, "K3 the new gate retires the previous one")
passGate._input.Text = "  SECRET  "
passGate._continueInteract.MouseButton1Click:Fire()
TestPump(0.6)
eq(savedKey, "SECRET", "K3 the padded key passes trimmed")
eq(passGate.passed, true, "K3 the gate records its pass")
eq(passGate.closed, true, "K3 the gate closes on success")
eq(passGate._screenGui, nil, "K3 the gate drops its root on success")
eq(isfile("Astra/keys/KeySystemTest.txt"), true, "K3 the key file is written")
eq(readfile("Astra/keys/KeySystemTest.txt"), "SECRET", "K3 the trimmed key is what is saved")

-- ===== K4: a saved key skips the UI =========================================

local skippedKey = nil
local skipGate = Astra:CreateKeySystem({
	fileName = "KeySystemTest",
	keys = { "SECRET" },
	saveKey = true,
	onSuccess = function(key)
		skippedKey = key
	end,
})
TestPump(0.4)
eq(skipGate.passed, true, "K4 the saved key passes")
eq(skipGate.closed, true, "K4 the passthrough builds no card to close")
eq(skipGate._screenGui, nil, "K4 the passthrough builds no UI at all")
eq(skippedKey, "SECRET", "K4 onSuccess still fires with the saved key")

-- ===== K5: the attempt budget locks the gate =================================

local exhausted = false
local budgetGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	maxAttempts = 2,
	saveKey = false,
	onSuccess = function()
		fired = true
	end,
	onMaxAttempts = function()
		exhausted = true
	end,
})
TestPump(0.4)
budgetGate:_submit("wrong-one")
budgetGate:_submit("wrong-two")
TestPump(0.4)
eq(exhausted, true, "K5 exhausting the budget fires onMaxAttempts")
eq(budgetGate.locked, true, "K5 the gate locks at the budget")
eq(budgetGate._noteLabel.Text, "No attempts remaining.", "K5 the note says why")
budgetGate:_submit("SECRET")
TestPump(0.2)
eq(fired, false, "K5 a locked gate ignores even the right key")
eq(budgetGate.passed, false, "K5 a locked gate never passes")

-- ===== K6: a theme table overlays the baked palette =========================

local themedAccent = Color3.fromRGB(120, 90, 220)
local themeGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	theme = { AccentColor = themedAccent },
	onSuccess = function() end,
})
TestPump(0.4)
eq(budgetGate.closed, true, "K6 the new gate retires the locked one")
local continueBg = themeGate._continue.BackgroundColor3
eq(
	tostring(continueBg),
	tostring(themedAccent),
	"K6 Continue wears the overlay accent"
)

-- ===== K7: remote keys come from the URL body ================================

game.HttpGet = function(_, _)
	return "REMOTE-KEY\n"
end
local remoteKey = nil
local remoteGate = Astra:CreateKeySystem({
	keys = { "https://keys.example.com/a" },
	grabKeyFromSite = true,
	saveKey = false,
	onSuccess = function(key)
		remoteKey = key
	end,
})
TestPump(0.4)
remoteGate:_submit("REMOTE-KEY")
TestPump(0.4)
eq(remoteKey, "REMOTE-KEY", "K7 the fetched body is the expected key")
eq(remoteGate.passed, true, "K7 the remote key passes")
game.HttpGet = nil

-- ===== K8: a non-dismissable gate has no close ===============================

local pinnedGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	dismissable = false,
	onSuccess = function() end,
})
TestPump(0.4)
eq(pinnedGate._closeButton, nil, "K8 dismissable=false builds no close button")

-- ===== K9: the get-key note copies its link ==================================

local copied = nil
setclipboard = function(text)
	copied = text
end
local linkGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	note = "No key yet? Tap here to copy the link.",
	getKeyUrl = "https://keys.example.com/get",
	onSuccess = function() end,
})
TestPump(0.4)
eq(linkGate._noteLabel.ClassName, "TextButton", "K9 the note is a tap target with getKeyUrl")
linkGate._noteLabel.MouseButton1Click:Fire()
TestPump(0.2)
eq(copied, "https://keys.example.com/get", "K9 tapping the note copies the get-key link")
eq(
	linkGate._noteLabel.Text,
	"Link copied — paste it in your browser to get a key.",
	"K9 the note confirms the copy"
)
TestPump(2.2)
eq(
	linkGate._noteLabel.Text,
	"No key yet? Tap here to copy the link.",
	"K9 the note restores itself"
)
setclipboard = nil

-- ===== K10: no keys passes through ===========================================

local openKey = nil
local openGate = Astra:CreateKeySystem({
	saveKey = false,
	onSuccess = function(key)
		openKey = key
	end,
})
TestPump(0.3)
eq(openGate.passed, true, "K10 the keyless gate passes")
eq(openGate._screenGui, nil, "K10 the keyless gate builds no UI")
eq(openKey, "", "K10 onSuccess fires with an empty key")

-- ===== K11: gates never stack ================================================

local firstGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	onSuccess = function() end,
})
TestPump(0.3)
local secondGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	onSuccess = function() end,
})
TestPump(0.3)
eq(firstGate.closed, true, "K11 the second gate retires the first")
eq(secondGate.closed, false, "K11 the second gate stays open")

-- ===== K12: Escape closes a dismissable gate =================================

local closedByUser = false
secondGate.onClose = function()
	closedByUser = true
end
local userInput = game:GetService("UserInputService")
userInput.InputBegan:Fire({ KeyCode = Enum.KeyCode.Escape }, false)
TestPump(0.4)
eq(secondGate.closed, true, "K12 Escape closes the gate")
eq(closedByUser, true, "K12 closing fires onClose")
eq(secondGate._screenGui, nil, "K12 the closed gate drops its root")

print("KEY SYSTEM: all assertions passed")
