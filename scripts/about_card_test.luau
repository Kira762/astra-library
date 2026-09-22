-- ===== About card (CreateAboutCard) assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The About card is one container with four blocks: a brand header, a row of
-- at most three data tiles, a description paragraph and an optional trailing
-- action band. Expected behavior under test:
--   * A1 the header renders the leading icon, the title and the subtitle, and
--        the band is as tall as the copy it carries,
--   * A2 one, two or three compact tiles always share a single row evenly and
--        each carries its badge icon and its own label and value,
--   * A3 the description is one wrapped paragraph,
--   * A4 the action band is the card's tap target: it renders its copy, its
--        trailing chevron and fires its callback,
--   * A5 a fourth data row is refused with an exact message,
--   * A6 the setters rewrite the header, one row and the paragraph in place,
--   * A7 the card rests revealed, disappears with the window and comes back,
--        and a theme change re-reads every resting value,
--   * A8 a locked card fires nothing.

local function expect(cond, message)
	if not cond then
		error("ABOUT CARD FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"ABOUT CARD FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function close(actual, wanted, message)
	if math.abs(actual - wanted) > 1e-9 then
		error(
			"ABOUT CARD FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function texts(inst, out)
	out = out or {}
	local props = inst.__props or {}
	if props.ClassName == "TextLabel" or props.ClassName == "TextButton" then
		out[#out + 1] = tostring(props.Text or "")
	end
	for _, child in inst:GetChildren() do
		texts(child, out)
	end
	return out
end

local function contains(values, wanted)
	for _, value in ipairs(values) do
		if value == wanted then
			return true
		end
	end
	return false
end

local description = "Astra is a modern and flexible UI library designed to make your experience smoother, cleaner, and more customizable. Built for developers, by developers."

local window = Astra:CreateWindow({
	name = "About Test",
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "About" })

-- ===== A1: the header ======================================================

local taps = 0
local card = tab:CreateAboutCard({
	name = "Astra",
	subtitle = "UI Library for a better experience.",
	icon = 80387863064905,
	rows = {
		{ icon = "code", label = "Version", value = "1.4.0" },
		{ icon = "package", label = "Build", value = "2026.09.12" },
		{ icon = "user", label = "Author", value = "Astra Team" },
	},
	description = description,
	action = {
		icon = "file-text",
		name = "View Changelog",
		subtitle = "See what's new in this version",
		callback = function()
			taps += 1
		end,
	},
})
TestPump(0.4)

expect(card ~= nil, "A1 CreateAboutCard returned an element")
eq(card.__type, "AboutCard", "A1 the element reports its type")
eq(tab.elements[1], card, "A1 the card is registered on its tab")
eq(card.title.Text, "Astra", "A1 the header title renders the name")
eq(card.subtitleLabel.Text, "UI Library for a better experience.", "A1 the subtitle renders under it")
eq(card.subtitleLabel.Visible, true, "A1 ... and the second line is on")
eq(card.header.Size.Y.Offset, 46, "A1 the two-line header band is 26 + 2 + 18")
eq(card.iconLabel.Visible, true, "A1 the leading slot is drawn")
expect(string.find(tostring(card.iconLabel.Image), "80387863064905", 1, true) ~= nil, "A1 the Astra asset id is kept")
eq(card.main.Size.X.Offset, -20, "A1 the card keeps the element gutter")
eq(card.main.AutomaticSize, Enum.AutomaticSize.Y, "A1 the card grows with its copy")

-- ===== A2: the data rows ====================================================

eq(#card.rows, 3, "A2 three rows build three tiles")
eq(card.rowsHost.Visible, true, "A2 the rows section is on")
eq(card.rowsHost.Size.Y.Offset, 48, "A2 the compact rows band is one tile tall")
eq(#card._rowLines, 1, "A2 all three tiles stay on one line")
eq(#card._rowLines[1], 3, "A2 that line contains all three rows")

local labels = { "Version", "Build", "Author" }
local values = { "1.4.0", "2026.09.12", "Astra Team" }
local icons = { "code", "package", "user" }
for index, entry in ipairs(card.rows) do
	eq(entry.main.Size.Y.Offset, 48, "A2 row " .. index .. " wears the compact tile height")
	eq(entry.main.Position.Y.Offset, 0, "A2 row " .. index .. " never wraps below the line")
	close(entry.main.Size.X.Scale, 1 / 3, "A2 row " .. index .. " takes an equal third")
	close(entry.main.Size.X.Offset, -16 / 3, "A2 row " .. index .. " pays its share of both 8px gaps")
	close(entry.main.Position.X.Scale, (index - 1) / 3, "A2 row " .. index .. " is ordered left to right")
	close(entry.main.Position.X.Offset, 8 * (index - 1) / 3, "A2 row " .. index .. " keeps the compact gap")
	eq(entry.labelLabel.Text, labels[index], "A2 row " .. index .. " renders its label")
	eq(entry.valueLabel.Text, values[index], "A2 ... and its value")
	eq(entry.labelLabel.TextSize, 11, "A2 the label is the compact small line")
	eq(entry.valueLabel.TextSize, 14, "A2 the value is the compact strong line")
	eq(entry.badge.Size.X.Offset, 28, "A2 the badge is compact")
	eq(entry.badgeIcon.Size.X.Offset, 14, "A2 ... with a compact glyph")
	eq(entry.badge.Visible, true, "A2 row " .. index .. " draws its badge")
	eq(entry.badgeIcon.Visible, true, "A2 ... with the row icon in it")
	eq(entry.icon, window:ResolveIcon(icons[index]), "A2 ... resolved through the icon catalog")
	expect(entry.icon ~= nil and entry.icon ~= "", "A2 row " .. index .. " resolved a real icon")
	expect(type(entry.badgeIcon.Image) == "string", "A2 ... and the badge carries the image slot")
	eq(entry.textColumn.Size.X.Offset, -36, "A2 the text column reserves only the compact badge and gap")
end

expect(card.rows[1].icon ~= card.rows[2].icon, "A2 the rows carry their own icons")
close(card.main.Size.X.Offset, -20, "A2 the card keeps the element gutter")

-- [[One row fills the band on its own; two split it between them.]]
local single = tab:CreateAboutCard({ name = "One", rows = { { icon = "code", label = "Only", value = "1" } } })
TestPump(0.3)
eq(#single._rowLines, 1, "A2 a single row is its own line")
eq(single.rows[1].main.Size.X.Scale, 1, "A2 ... filling the whole band")
eq(single.rows[1].main.Size.X.Offset, 0, "A2 ... without a reserved gap")
eq(single.rows[1].main.Position.X.Offset, 0, "A2 ... from the left edge")
eq(single.header.Size.Y.Offset, 26, "A2 a header without a subtitle is the single-line band")
eq(single.subtitleLabel.Visible, false, "A2 ... and its subtitle slot is off")
eq(single.actionBand, nil, "A2 a card without an action has no band")
eq(single.descriptionLabel.Visible, false, "A2 ... and an empty paragraph is out of the layout")

local pair = tab:CreateAboutCard({
	name = "Two",
	rows = {
		{ icon = "code", label = "Left", value = "L" },
		{ icon = "user", label = "Right", value = "R" },
	},
})
TestPump(0.3)
eq(#pair._rowLines, 1, "A2 two rows share one line")
close(pair.rows[1].main.Size.X.Scale, 0.5, "A2 the first of two takes half the band")
close(pair.rows[2].main.Size.X.Scale, 0.5, "A2 the second takes the other half")
close(pair.rows[1].main.Size.X.Offset, -4, "A2 each half pays half the 8px gap")
close(pair.rows[2].main.Position.X.Scale, 0.5, "A2 the second starts after half the band")
close(pair.rows[2].main.Position.X.Offset, 4, "A2 ... and half the gap")

local noRows = tab:CreateAboutCard({ name = "Bare", description = "Copy only." })
TestPump(0.3)
eq(#noRows.rows, 0, "A2 a card can carry no rows at all")
eq(noRows.rowsHost.Visible, false, "A2 ... leaving the rows section out of the layout")

local iconless = tab:CreateAboutCard({ name = "Plain", rows = { { label = "No icon", value = "1" } } })
TestPump(0.3)
eq(iconless.rows[1].badge.Visible, false, "A2 a row without an icon drops the badge")
eq(iconless.rows[1].textColumn.Size.X.Offset, 0, "A2 ... and hands the whole tile to its text")

-- ===== A3: the description ==================================================

eq(card.descriptionLabel.Visible, true, "A3 the paragraph is drawn")
eq(card.descriptionLabel.Text, description, "A3 the copy is the paragraph")
eq(card.descriptionLabel.TextWrapped, true, "A3 ... and it wraps")
eq(card.descriptionLabel.AutomaticSize, Enum.AutomaticSize.Y, "A3 ... reserving its own wrapped height")

-- ===== A4: the action band ==================================================

expect(card.actionBand ~= nil, "A4 the action band is built")
eq(card.actionBand.Size.Y.Offset, 56, "A4 the two-line band is 19 + 1 + 16 tall")
eq(card.actionLabel.Text, "View Changelog", "A4 the band renders its label")
eq(card.actionSubtitle.Text, "See what's new in this version", "A4 ... and its subtitle")
eq(card.action.icon, window:ResolveIcon("file-text"), "A4 the leading icon resolved from the repo packs")
eq(card.actionIcon.Visible, true, "A4 ... and the slot is drawn")
expect(
	window:ResolveIcon("chevron-right") ~= "chevron-right",
	"A4 the trailing chevron name resolves in the packs"
)
expect(type(card.actionChevron.Image) == "string", "A4 ... and the glyph slot is filled")
eq(card.actionChevron.Parent, card.actionBand, "A4 the chevron belongs to the band")
eq(card.actionButton.Size.X.Scale, 1, "A4 the tap target is the whole band")
eq(card.actionButton.Text, "", "A4 ... and carries no text")
expect(card.actionButton.ZIndex > card.actionBand.ZIndex, "A4 the tap target sits over the band")

card.actionButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(taps, 1, "A4 the band tap fired the callback")

-- [[A card built without an action keeps its header, rows and paragraph.]]
local quiet = tab:CreateAboutCard({ name = "Quiet", rows = { { label = "Only", value = "1" } } })
TestPump(0.3)
eq(quiet.actionButton, nil, "A4 a card without an action has nothing to tap")

-- ===== A5: the row cap ======================================================

local okGuard, message = pcall(function()
	return tab:CreateAboutCard({
		name = "Too many",
		rows = { { label = "1" }, { label = "2" }, { label = "3" }, { label = "4" } },
	})
end)
expect(not okGuard, "A5 a fourth data row is refused")
eq(
	tostring(message),
	"Astra:CreateAboutCard — at most 3 data rows are supported, got 4",
	"A5 the guard message is exact"
)

local okShape = pcall(function()
	return tab:CreateAboutCard({ name = "Bad rows", rows = "nope" })
end)
expect(not okShape, "A5 a non-array rows value is refused")

-- ===== A6: the setters ======================================================

card:SetTitle("Release")
TestPump(0.2)
eq(card.title.Text, "Release", "A6 SetTitle rewrites the header title")

card:SetSubtitle(nil)
TestPump(0.2)
eq(card.header.Size.Y.Offset, 26, "A6 dropping the subtitle closes the band")
eq(card.subtitleLabel.Visible, false, "A6 ... and takes the line out of the layout")

card:SetSubtitle("Back again")
TestPump(0.2)
eq(card.header.Size.Y.Offset, 46, "A6 restoring it reopens the band")
eq(card.subtitleLabel.Text, "Back again", "A6 ... with the new copy")

card:SetIcon("sparkles")
TestPump(0.2)
expect(card.icon == window:ResolveIcon("sparkles"), "A6 SetIcon resolves the new icon")
eq(card.iconLabel.Visible, true, "A6 ... and keeps the slot drawn")

card:SetIcon(nil)
TestPump(0.2)
eq(card.iconLabel.Visible, false, "A6 SetIcon(nil) takes the slot out")

card:SetRow(1, { icon = "box", label = "Version", value = "1.5.0" })
TestPump(0.2)
eq(card.rows[1].labelLabel.Text, "Version", "A6 SetRow rewrites the label")
eq(card._rowLines and #card._rowLines == 1, true, "A6 ... and the compact row stays on one line")
eq(card.rows[1].valueLabel.Text, "1.5.0", "A6 ... and the value")
eq(card.rows[1].icon, window:ResolveIcon("box"), "A6 ... and re-resolves the row icon")
eq(card.rows[2].valueLabel.Text, "2026.09.12", "A6 ... leaving the other rows alone")

local okRow = pcall(function()
	card:SetRow(9, { value = "nope" })
end)
expect(not okRow, "A6 SetRow refuses an index the card does not have")

card:SetDescription("Shorter copy.")
TestPump(0.2)
eq(card.descriptionLabel.Text, "Shorter copy.", "A6 SetDescription rewrites the paragraph")
eq(card.descriptionLabel.Visible, true, "A6 ... keeping it drawn")

card:SetDescription(nil)
TestPump(0.2)
eq(card.descriptionLabel.Visible, false, "A6 SetDescription(nil) takes it out of the layout")

-- [[The rendered copy is host copy: every string the props carried is on the
-- [[card, and nothing else was invented.]]
local rendered = texts(card.main)
for _, wanted in ipairs({ "Release", "Back again", "Version", "1.5.0", "Build", "2026.09.12", "Author", "Astra Team" }) do
	expect(contains(rendered, wanted), "A6 the card renders '" .. wanted .. "'")
end
expect(contains(rendered, "View Changelog"), "A4 the action copy is on the card")

-- ===== A7: reveal and theme =================================================

TestPump(0.6)
local theme = window.theme
eq(card.main.BackgroundTransparency, theme.ElementTransparency, "A7 the card rests on the element surface")
eq(card.stroke.Transparency, theme.ElementStrokeTransparency, "A7 ... with its stroke drawn")
eq(card.rows[1].main.BackgroundTransparency, theme.ElementTransparency, "A7 a tile rests on its own surface")
eq(card.rows[1].main.BackgroundColor3, theme.ElementSurface, "A7 the tile uses the regular element fill, not the dark window surface")
eq(card.actionBand.BackgroundColor3, theme.ElementSurface, "A7 the action band uses that same UI surface")
eq(card.rows[1].stroke.Transparency, theme.ElementStrokeTransparency, "A7 ... with its own stroke")
eq(card.rows[1].badge.BackgroundTransparency, theme.ElementTransparency, "A7 the badge is drawn")
eq(card.rows[1].valueLabel.TextTransparency, 0, "A7 values rest solid")
eq(card.rows[1].labelLabel.TextTransparency, 0.45, "A7 labels rest muted")
eq(card.subtitleLabel.TextTransparency, 0.45, "A7 so does the header subtitle")
eq(card.descriptionLabel.TextTransparency, 0.45, "A7 and the paragraph")
eq(card.actionChevron.ImageTransparency, 0.4, "A7 the chevron rests on the baked transparency")
eq(card.rows[1].badgeIcon.ImageTransparency, 0, "A7 the badge icon is fully drawn")

window:Hide()
TestPump(0.8)
eq(card.main.BackgroundTransparency, 1, "A7 hiding the window hides the card")
eq(card.rows[1].valueLabel.TextTransparency, 1, "A7 ... including every label")
eq(card.actionChevron.ImageTransparency, 1, "A7 ... and the chevron")

window:Show()
TestPump(0.8)
eq(card.main.BackgroundTransparency, theme.ElementTransparency, "A7 showing again restores the surface")
eq(card.rows[1].valueLabel.TextTransparency, 0, "A7 ... and the values")
eq(card.rows[1].labelLabel.TextTransparency, 0.45, "A7 ... and the muted lines")
eq(card.actionChevron.ImageTransparency, 0.4, "A7 ... and the chevron")

local overrideSurface = Color3.fromRGB(48, 48, 62)
window:ChangeTheme({ ElementSurface = overrideSurface })
TestPump(0.4)
local themed = window.theme
eq(card.main.BackgroundTransparency, themed.ElementTransparency, "A7 a theme change re-reads the card surface")
eq(card.rows[1].stroke.Transparency, themed.ElementStrokeTransparency, "A7 ... and the tile stroke")
eq(card.rows[1].main.BackgroundColor3, overrideSurface, "A7 ... including the lighter tile fill")
eq(card.actionBand.BackgroundColor3, overrideSurface, "A7 ... and the matching action fill")
eq(card.rows[1].labelLabel.TextTransparency, 0.45, "A7 ... keeping the muted lines muted")
eq(card.rows[1].valueLabel.TextTransparency, 0, "A7 ... and the values solid")
eq(card.rows[1].badge.BackgroundColor3, overrideSurface, "A7 the badge follows the content surface token")

-- ===== A8: the lock =========================================================

card:SetDescription("Locked copy goes here.")
TestPump(0.2)
eq(card.descriptionLabel.Visible, true, "A8 the paragraph is back before the lock")

card:Lock()
TestPump(0.2)
expect(card:IsLocked(), "A8 Lock marks the card")
expect(card.lockScrim ~= nil, "A8 ... and builds the lock scrim over it")

local before = taps
card.actionButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(taps, before, "A8 a locked card fires nothing")

-- [[While it is locked the card's paragraph is the shared lock message; the
-- [[description it had comes back on unlock.
eq(card.descriptionLabel.Text, "This element is locked.", "A8 the paragraph carries the lock message")

card:Unlock()
TestPump(0.3)
expect(not card:IsLocked(), "A8 Unlock releases the card")
eq(card.descriptionLabel.Text, "Locked copy goes here.", "A8 ... and the paragraph comes back")

card.actionButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(taps, before + 1, "A8 ... and the band taps again")
