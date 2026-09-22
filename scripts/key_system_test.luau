--[[
===== key system assertions: the standalone key gate =======================
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau, plus the
in-memory executor filesystem from filesystem_stubs.luau.

Expected behavior under test:
  * K1 the card is the popup-width short card (400px, ~150-165px tall) and
       wears the corner scale: CornerRoundness on the shell,
       ElementCornerRadius on the field and the Continue button,
  * K2 a wrong key costs an attempt, clears the field and never fires
       onSuccess,
  * K3 a correct key (surrounding whitespace trimmed) passes, closes the
       gate and saves the trimmed key to Astra/keys/<fileName>.txt,
  * K4 a matching saved key skips the UI entirely (passthrough),
  * K5 maxAttempts locks the gate and fires onMaxAttempts; further
       submits are ignored,
  * K6 a theme table overlays the baked palette (Continue wears it),
  * K7 grabKeyFromSite fetches the expected key from the URL body,
  * K8 dismissable=false builds no close button,
  * K9 getKeyUrl promotes to a "Get Key" link button: pressing copies its
       hidden link into a notification (title "Link copied", content =
       the URL, exact duplicates replace), the note stays plain text and
       never changes,
  * K10 no keys configured passes through with a warning,
  * K11 a second gate retires the first (no stacking),
  * K12 Escape closes a dismissable gate and fires onClose,
  * K13 the links prop builds 0-3 equal buttons whose faces show name
       (never the URL) plus a glyph rendered through the executor image
       pipeline, each copies its own link, past three drops with
       a warning, and the row grows the card,
  * K14 props.icon is ignored: the header always wears Sirius, rendered
       through the same pipeline (a second gate with no icon prop shows
       the identical mark).
]]

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

-- ===== K9: getKeyUrl promotes to a link button; the note stays plain =======

local copied = nil
setclipboard = function(text)
	copied = text
end
local linkGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	note = "No key yet? The button below copies the link.",
	getKeyUrl = "https://keys.example.com/get",
	onSuccess = function() end,
})
TestPump(0.4)
eq(linkGate._noteLabel.ClassName, "TextLabel", "K9 the note is plain text even with getKeyUrl")
eq(#linkGate._links, 1, "K9 getKeyUrl promotes to one entry")
eq(#linkGate._linkButtons, 1, "K9 getKeyUrl builds one link button")
eq(linkGate._links[1].name, "Get Key", "K9 the promoted entry is named Get Key")
eq(linkGate._links[1].link, "https://keys.example.com/get", "K9 the promoted entry carries the URL")
local getKeyFace = nil
for _, child in linkGate._linkButtons[1]:GetChildren() do
	if child.ClassName == "TextLabel" then
		getKeyFace = child
	end
end
expect(getKeyFace ~= nil, "K9 the button face carries a label")
eq(getKeyFace.Text, "Get Key", "K9 the face shows the name")
local noteBefore = linkGate._noteLabel.Text

linkGate._linkInteracts[1].MouseButton1Click:Fire()
TestPump(0.2)
eq(copied, "https://keys.example.com/get", "K9 pressing the button copies the hidden link")
eq(linkGate._noteLabel.Text, noteBefore, "K9 the note never changes")
local host = linkGate._notifyHost
expect(host ~= nil, "K9 the copy builds a notification host")
expect(host.notifications.Parent == linkGate._screenGui, "K9 the notification lane lives in the gate's root")
eq(#host._liveNotifications, 1, "K9 a notification goes live")
eq(host._liveNotifications[1].title, "Link copied", "K9 the notification title says so")
eq(
	host._liveNotifications[1].content,
	"https://keys.example.com/get",
	"K9 the notification reveals the copied link"
)

-- An exact duplicate replaces its card instead of stacking.
linkGate._linkInteracts[1].MouseButton1Click:Fire()
TestPump(0.1)
eq(#linkGate._notifyHost._liveNotifications, 1, "K9 an exact duplicate replaces its card")
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

-- ===== K13: 0-3 link buttons, each copying its own hidden link ==============

setclipboard = function(text)
	copied = text
end
copied = nil

--[[
The executor image pipeline the gate's glyphs render through: catalog URLs
are https, so `image.assign` downloads each PNG via `request` and rewrites
the Image property to a `getcustomasset` URI. Without these two globals the
labels stay blank — the regression this block pins.
]]
request = function(_payload)
	return { Body = "\137PNG\r\n\26\nfake-icon-bytes", StatusCode = 200 }
end
getcustomasset = function(path)
	return "rbxasset://mock/" .. tostring(path):gsub("[^%w]+", "_")
end

local manyGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	links = {
		{ name = "Docs", icon = "book-open", link = "https://example.com/docs" },
		{ name = "Repo", icon = "external-link", link = "https://example.com/repo" },
		{ name = "Support", link = "https://example.com/support" },
		{ name = "Overflow", link = "https://example.com/overflow" },
	},
	onSuccess = function() end,
})
TestPump(0.4)
eq(#manyGate._links, 3, "K13 at most three entries survive the cap")
eq(#manyGate._linkButtons, 3, "K13 three buttons are built")
eq(#manyGate._linkInteracts, 3, "K13 every button gets its hit target")
local manyHeight = manyGate._card.Size.Y.Offset
expect(manyHeight > 176, "K13 the links row grows the card (got " .. tostring(manyHeight) .. "px)")

local function faceOf(button)
	for _, child in button:GetChildren() do
		if child.ClassName == "TextLabel" then
			return child
		end
	end
	return nil
end

local faceDocs = faceOf(manyGate._linkButtons[1])
expect(faceDocs ~= nil, "K13 the first face carries a label")
eq(faceDocs.Text, "Docs", "K13 the face shows the name")
expect(string.find(faceDocs.Text, "https://", 1, true) == nil, "K13 the face never shows the URL")
local faceIcon = nil
for _, child in manyGate._linkButtons[1]:GetChildren() do
	if child.ClassName == "ImageLabel" then
		faceIcon = child
	end
end
expect(faceIcon ~= nil, "K13 an entry icon builds a glyph")
expect(
	type(manyGate._links[1].iconResolved) == "string"
		and manyGate._links[1].iconResolved:find("^https?://") ~= nil,
	"K13 the entry icon resolves to a loadable catalog source"
)
expect(
	type(faceIcon.Image) == "string" and faceIcon.Image:find("^rbxasset://mock/") ~= nil,
	"K13 the glyph renders through the image pipeline, not the bare name"
)

manyGate._linkInteracts[2].MouseButton1Click:Fire()
TestPump(0.1)
eq(copied, "https://example.com/repo", "K13 each button copies its own link")
expect(manyGate._notifyHost ~= nil, "K13 the press builds a notification host")
eq(
	manyGate._notifyHost._liveNotifications[1].content,
	"https://example.com/repo",
	"K13 the notification carries that link"
)
setclipboard = nil

-- A gate with no links builds no row and never touches the notification lane.
local bareGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	onSuccess = function() end,
})
TestPump(0.4)
eq(manyGate.closed, true, "K13 the bare gate retires the previous one")
eq(#bareGate._links, 0, "K13 no links means no entries")
eq(#bareGate._linkButtons, 0, "K13 no links means no buttons")
eq(bareGate._notifyHost, nil, "K13 nothing built a notification host")
local bareHeight = bareGate._card.Size.Y.Offset
expect(
	bareHeight >= 140 and bareHeight <= 176,
	"K13 a bare gate keeps the short-card height (got " .. tostring(bareHeight) .. "px)"
)

-- ===== K14: the header icon is forced to Sirius ==============================

local Icons = Astra.Icons
expect(
	type(Icons.resolve("sirius")) == "string" and Icons.resolve("sirius"):find("^https?://") ~= nil,
	"K14 sirius resolves to a loadable source"
)
local iconGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	icon = "house", -- older scripts pass this; it must be ignored
	onSuccess = function() end,
})
TestPump(0.4)
expect(iconGate._headerIcon ~= nil, "K14 the header always carries its mark")
expect(
	type(iconGate._headerIcon.Image) == "string"
		and iconGate._headerIcon.Image:find("^rbxasset://mock/") ~= nil,
	"K14 the header mark renders through the image pipeline"
)
eq(iconGate._headerIcon.Size.X.Offset, iconGate._headerIcon.Size.Y.Offset, "K14 the mark is square")

-- A gate with no icon prop wears the identical mark: props.icon is ignored.
local plainGate = Astra:CreateKeySystem({
	keys = { "SECRET" },
	saveKey = false,
	onSuccess = function() end,
})
TestPump(0.4)
expect(plainGate._headerIcon ~= nil, "K14 the plain gate carries the mark too")
eq(plainGate._headerIcon.Image, iconGate._headerIcon.Image, "K14 props.icon is ignored — both headers wear Sirius")

request = nil
getcustomasset = nil

print("KEY SYSTEM: all assertions passed")
