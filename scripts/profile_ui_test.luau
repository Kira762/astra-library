-- ===== profile card UI assertions: window-matched surface, copy feedback,
-- ===== Place/Job ID wording, tier pill icon =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * G1 the card's surface IS the window's background rather than a lookalike:
--        both come out of Window:StyleWindowSurface, so they share the base
--        colour, the WindowColor theme token and the gradient's rotation and
--        offset; both show at the window's own opacity; a theme change repaints
--        them together and a hide/show round trip fades the card's plate with
--        the window's,
--   * G2 a copy press writes the row's real value through the executor's
--        clipboard, swaps the copy glyph for the success check, states "Copied"
--        on the button's own label and restores it when the flash ends, and
--        repeated presses never leave two restores racing; hovering or holding
--        the button raises no tooltip surface of its own,
--   * G3 the server identifier row reads "Job ID" (it shows DataModel.JobId):
--        "Server ID" no longer appears anywhere on the card, while the
--        underlying field and the window handles are untouched,
--   * G4 the tier pill draws a real icon for both states (PREMIUM / FREEMIUM)
--        and in every icon pack, instead of a blank square wherever the active
--        pack has no icon under the lucide name the card asks for.

local function expect(cond, message)
	if not cond then
		error("PROFILE UI FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"PROFILE UI FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

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

-- [[Every piece of text the card draws, top to bottom, so a renaming assertion
-- [[cannot be fooled by a row that sits somewhere unexpected.]]
local function textOf(instance, out)
	out = out or {}
	for _, child in instance:GetChildren() do
		local props = child.__props or {}
		if (props.ClassName == "TextLabel" or props.ClassName == "TextButton") and type(props.Text) == "string" then
			table.insert(out, { text = props.Text, instance = child })
		end
		textOf(child, out)
	end
	return out
end

local function drawnTexts(panel)
	local result = {}
	for _, entry in textOf(panel) do
		table.insert(result, entry.text)
	end
	return result
end

-- [[The same three colour channels, keypoint for keypoint: the two gradients
-- [[must be the same sequence, not merely the same family.]]
local function assertSameColorSequence(actual, wanted, message)
	eq(#actual.Keypoints, #wanted.Keypoints, message .. ": keypoint count")
	for index, keypoint in wanted.Keypoints do
		local other = actual.Keypoints[index]
		eq(tostring(other.Time), tostring(keypoint.Time), message .. ": keypoint " .. index .. " time")
		for _, channel in { "R", "G", "B" } do
			eq(
				tostring(other.Value[channel]),
				tostring(keypoint.Value[channel]),
				message .. ": keypoint " .. index .. " " .. channel
			)
		end
	end
end

local player = state.localPlayer
expect(player ~= nil, "G0 the stub environment has a local player")
player.Name = "TestUser"
player.DisplayName = "Test User"
player.UserId = 42
game.PlaceId = 2753915549
game.Name = "Test Place"
game.GameId = 123456
game.JobId = "astra-ui-server"

local window = Astra:CreateWindow({ name = "Profile UI Test" })
TestPump(1.2)
theme = window.theme
expect(theme ~= nil, "G0 the window exposes its resolved theme")

local panel = window.profilePanel
expect(panel ~= nil, "G1 the profile card exists")

-- ===== G1: the card's background IS the window's background =====

local surface = findChild(panel, "Surface")
expect(surface ~= nil, "G1 the card surface exists")

-- [[Base colour and opacity: the card states the window's own values, not a
-- [[styling of its own.]]
for _, channel in { "R", "G", "B" } do
	eq(
		tostring(surface.BackgroundColor3[channel]),
		tostring(window.main.BackgroundColor3[channel]),
		"G1 the card's base colour matches the window frame's " .. channel
	)
end
eq(
	surface.BackgroundTransparency,
	window:WindowSurfaceTransparency(),
	"G1 the card shows at the window's own surface opacity"
)
eq(
	surface.BackgroundTransparency,
	window.main.BackgroundTransparency,
	"G1 the card and the shown window frame are equally opaque"
)
eq(window.main.BackgroundTransparency, 0, "G1 the shown window frame is fully opaque")

-- [[Gradient: same theme token, same rotation, same offset - the three things
-- [[that decide what shade the surface actually renders.]]
local cardGradient = window.profilePanelGradient
local mainGradient = window.windowGradient
expect(cardGradient ~= nil, "G1 the card's gradient is exposed on the window")
eq(cardGradient.Parent, surface, "G1 the card's gradient sits on the card surface")
eq(cardGradient.Rotation, mainGradient.Rotation, "G1 the card's gradient rotation matches the window's")
eq(cardGradient.Offset.X, mainGradient.Offset.X, "G1 the card's gradient offset matches the window's (X)")
eq(cardGradient.Offset.Y, mainGradient.Offset.Y, "G1 the card's gradient offset matches the window's (Y)")
assertSameColorSequence(cardGradient.Color, mainGradient.Color, "G1 the card's gradient is the window's gradient")
assertSameColorSequence(cardGradient.Color, theme.WindowColor, "G1 both gradients are the theme's WindowColor token")

-- [[One styling source: a surface built through the window's own entry point
-- [[comes out identical to both, so the card cannot be a private copy of the
-- [[numbers.]]
local probe = window:Create("Frame", { Name = "SurfaceProbe", Parent = window.screenGui })
local probeGradient = window:StyleWindowSurface(probe)
eq(probeGradient.Rotation, cardGradient.Rotation, "G1 one gradient definition for the window and the card")
eq(probeGradient.Offset.Y, cardGradient.Offset.Y, "G1 one gradient offset for the window and the card")
eq(
	tostring(probe.BackgroundColor3.R),
	tostring(surface.BackgroundColor3.R),
	"G1 one base colour for the window and the card"
)
probe:Destroy()

-- [[A theme change reaches both surfaces, because both gradients are the same
-- [[theme binding.]]
window:ChangeTheme("frost")
TestPump(0.3)
assertSameColorSequence(cardGradient.Color, window.theme.WindowColor, "G1 the card follows the new theme")
assertSameColorSequence(mainGradient.Color, window.theme.WindowColor, "G1 ... and so does the window frame")
window:ChangeTheme("default")
TestPump(0.3)
assertSameColorSequence(cardGradient.Color, theme.WindowColor, "G1 switching back repaints both surfaces")

-- [[A host's own theme table is a supported theme too: both surfaces read the
-- [[same custom WindowColor through the same binding (the table's bare Color3
-- [[reaches them as the sequence the gradient requires).]]
window:ChangeTheme({ WindowColor = Color3.fromRGB(40, 44, 50) })
TestPump(0.3)
assertSameColorSequence(cardGradient.Color, mainGradient.Color, "G1 a custom theme paints both surfaces alike")
local custom = Color3.fromRGB(40, 44, 50)
for _, channel in { "R", "G", "B" } do
	eq(
		tostring(cardGradient.Color.Keypoints[1].Value[channel]),
		tostring(custom[channel]),
		"G1 the card takes the host's WindowColor (" .. channel .. ")"
	)
	eq(
		tostring(mainGradient.Color.Keypoints[#mainGradient.Color.Keypoints].Value[channel]),
		tostring(custom[channel]),
		"G1 ... and so does the window frame (" .. channel .. ")"
	)
end
window:ChangeTheme("default")
TestPump(0.3)
assertSameColorSequence(cardGradient.Color, mainGradient.Color, "G1 the default theme paints both surfaces alike")

-- [[Show/hide is a state too: the card's plate may not stay solid while the
-- [[window it belongs to is fading.]
window:Hide()
TestPump(0.6)
eq(panel.Visible, false, "G1 the card hides with the window")
eq(surface.BackgroundTransparency, 1, "G1 the card's plate fades out with the window's")
window:Show()
TestPump(0.8)
eq(panel.Visible, true, "G1 the card returns with the window")
eq(
	surface.BackgroundTransparency,
	window.main.BackgroundTransparency,
	"G1 the card returns at the window's own opacity"
)
eq(surface.BackgroundTransparency, 0, "G1 ... which is the window's surface opacity")

-- ===== G2: copy feedback =====

local copied = {}
setclipboard = function(text)
	table.insert(copied, text)
	return true
end

window.settings.showFullUsername = true
window:SetProfile({})
TestPump(0.2)

local placeEntry = window.profileCopyButtons.PlaceId
expect(placeEntry ~= nil, "G2 the Place ID row carries its copy action")
local jobEntry = window.profileCopyButtons.ServerId
expect(jobEntry ~= nil, "G2 the job ID row carries its copy action")

-- [[Idle wording: the button's own label says what the press will copy. The
-- [[line is never drawn (its transparency stays 1); it is the accessible name
-- [[of the glyph-only button.]]
eq(placeEntry.button.Text, "Copy Place ID", "G2 the Place ID button announces what it copies")
eq(jobEntry.button.Text, "Copy Job ID", "G2 the job ID button announces what it copies")

-- [[No hover surface rides on the copy button: holding the pointer over the
-- [[glyph must not raise the card's tooltip — the rows' truncation hover-help
-- [[is the only tooltip the card shows.]]
placeEntry.button.MouseEnter:Fire()
TestPump(0.1)
eq(window.profileTooltip.Visible, false, "G2 hovering a copy button raises no tooltip")

-- [[The press copies the real identifier, swaps in the green check and states
-- [[the success on the button's own label — still with no tooltip.]]
placeEntry.button.Activated:Fire()
TestPump(0.1)
eq(#copied, 1, "G2 one press copies once")
eq(copied[1], tostring(game.PlaceId), "G2 the Place ID button copies the place ID")
eq(placeEntry.icon.Image, TestImageUri(window:ResolveIcon("check")), "G2 a successful copy swaps in the check icon")
eq(placeEntry.icon.ImageColor3, theme.Success, "G2 the check is drawn in the success green")
eq(placeEntry.button.Text, "Copied", "G2 the button states the success")
eq(window.profileTooltip.Visible, false, "G2 ... and the press itself raises no tooltip")
expect(placeEntry.icon.Image ~= TestImageUri(window:ResolveIcon("copy")), "G2 the copy glyph is gone while the check is up")

-- [[The job ID row copies its own value, not the place ID.]]
jobEntry.button.Activated:Fire()
TestPump(0.1)
eq(copied[#copied], game.JobId, "G2 the job ID button copies the server's job ID")
eq(jobEntry.icon.Image, TestImageUri(window:ResolveIcon("check")), "G2 the job ID button flashes its own check")

-- [[Repeated presses: the flash restarts rather than stacking, so no earlier
-- [[timer may restore the icon while a newer one is still running.]]
placeEntry.button.Activated:Fire()
TestPump(0.6)
placeEntry.button.Activated:Fire()
TestPump(0.5)
eq(
	placeEntry.icon.Image,
	TestImageUri(window:ResolveIcon("check")),
	"G2 a superseded timer never restores the icon early"
)
TestPump(1.0)
eq(placeEntry.icon.Image, TestImageUri(window:ResolveIcon("copy")), "G2 the copy glyph returns after the last flash")
eq(placeEntry.icon.ImageColor3, theme.ActionColor, "G2 ... in the action colour")
eq(placeEntry.button.Text, "Copy Place ID", "G2 the button goes back to naming the action")

placeEntry.button.MouseLeave:Fire()
TestPump(0.3)
eq(window.profileTooltip.Visible, false, "G2 leaving the button keeps the tooltip down")

-- [[The wording is locale-bound: a host's translation table re-states the
-- [[label in the locale's own words, in whichever state the button is in.]]
window:RegisterTranslations({
	es = { ["Copy Place ID"] = "Copiar ID del lugar", ["Copied"] = "Copiado" },
})
window:SetLocale("es")
TestPump(0.2)
eq(placeEntry.button.Text, "Copiar ID del lugar", "G2 the copy label follows the locale")
placeEntry.button.Activated:Fire()
TestPump(0.1)
eq(placeEntry.button.Text, "Copiado", "G2 the success word follows the locale too")
eq(window.profileCopyButtons.PlaceId.icon.Image, TestImageUri(window:ResolveIcon("check")), "G2 the flash still runs under a locale")
TestPump(1.4)
eq(placeEntry.button.Text, "Copiar ID del lugar", "G2 the idle word returns in the locale")
window:SetLocale("en")
TestPump(0.2)
eq(placeEntry.button.Text, "Copy Place ID", "G2 switching back restates the English wording")

-- [[A press with the reveal toggle off copies nothing: the buttons are hidden
-- [[for exactly that reason.]]
window.settings.showFullUsername = false
window:SetProfile({})
TestPump(0.2)
local before = #copied
placeEntry.button.Activated:Fire()
TestPump(0.2)
eq(#copied, before, "G2 a masked card copies nothing")

-- ===== G3: the server identifier row reads "Job ID" =====

window.settings.showFullUsername = true
window:SetProfile({})
TestPump(0.2)

local texts = drawnTexts(panel)
for _, text in texts do
	expect(text ~= "Server ID", "G3 'Server ID' no longer appears on the card")
	expect(string.find(text, "Server ID") == nil, "G3 no line on the card mentions a Server ID (got '" .. text .. "')")
end

local jobLabel = findChild(panel, "ServerIdLabel")
expect(jobLabel ~= nil, "G3 the job ID row still exists")
eq(jobLabel.Text, "Job ID", "G3 the row labels DataModel.JobId as a job ID")
eq(window.profileServerIdValue.Text, game.JobId, "G3 the underlying value is untouched")
eq(jobEntry.label, "Job ID", "G3 the copy action is labelled for it too")

-- [[The place row keeps its own wording: the two identifiers are not allowed
-- [[to trade names.]]
local placeLabel = findChild(panel, "PlaceIdLabel")
expect(placeLabel ~= nil, "G3 the place ID row still exists")
eq(placeLabel.Text, "Place ID", "G3 the place ID row keeps its label")

-- ===== G4: all-pack lookup keeps native profile badges and real asset URIs =====
local membership = player.MembershipType
player.MembershipType = Enum.MembershipType.Premium
local packed = Astra:CreateWindow({ name = "All-pack profile" })
TestPump(0.6)
eq(packed.profileTierLabel.Text, "PREMIUM", "G4 paid tier label")
eq(packed.profileTierIcon.Image, TestImageUri(packed:ResolveIcon("crown")), "G4 crown uses image loader")
local premiumIcon = packed.profileTierIcon.Image
player.MembershipType = Enum.MembershipType.None
packed:SetProfile({})
TestPump(0.3)
eq(packed.profileTierLabel.Text, "FREEMIUM", "G4 free tier label")
eq(packed.profileTierIcon.Image, TestImageUri(packed:ResolveIcon("badge-check")), "G4 badge uses image loader")
local freeIcon = packed.profileTierIcon.Image
expect(freeIcon ~= premiumIcon, "G4 free and premium icons differ")
eq(packed.profileTierIcon.ImageColor3, packed.theme.PlaceholderColor, "G4 free badge colour")
packed:SetProfile({ tier = "VIP" })
TestPump(0.3)
eq(packed.profileTierIcon.Image, freeIcon, "G4 custom tier retains its badge")
eq(packed.profileTierLabel.Text, "VIP", "G4 custom label")
packed:Unload()
player.MembershipType = membership
print("PROFILE UI: all assertions passed")
