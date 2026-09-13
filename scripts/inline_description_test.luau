-- ===== inline description assertions: descriptions live inside the card ====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Descriptions used to render as a standalone row *below* the element card
-- (the old `descriptor` element). They now render inside the element's own
-- card: a muted 14px line under the title region, the Collapsible Group
-- header recipe. The card grows by the measured height of the line
-- (one line: +20px, 41 -> 61) and the controls keep centring in the base
-- region, so nothing drifts into the description.
--
-- Expected behavior under test:
--   * I1 the label is a child of the element's main frame, the element has no
--        `descriptor`, and the tab page holds nothing but element cards,
--   * I2 a one-line description grows a 41px toggle to 61px with the label at
--        (20, 37), 14px and wrapped,
--   * I3 the title row still centres in the base region (20.5, not 30.5),
--   * I4 a wrapped description grows the card line by line (lines*17 + 3),
--   * I5 the slider's wide layout keeps its centred track in the base region,
--   * I6 the dropdown's closed and open heights both include the extra,
--   * I7 the line reveals with the element at 0.45 transparency,
--   * I8 locking swaps the line's text for the lock message and unlocking
--        restores the original description,
--   * I9 the progress track (bottom-anchored) rides up above the line,
--   * I10 the stat's bottom-anchored value labels ride up above the line.

local function expect(cond, message)
	if not cond then
		error("INLINE DESCRIPTION FAIL: " .. tostring(message), 0)
	end
end

local function near(actual, wanted, message)
	expect(
		math.abs(actual - wanted) < 0.01,
		message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")"
	)
end

-- [[The stubs measure text at 0.6 * size per character; mirror the helper's
-- [[greedy word wrap so the expected line count is computed, not guessed.]]
local function stubWidth(text)
	return math.ceil(#text * 14 * 0.6)
end

local function expectedLines(text, width)
	local count = 1
	local current = 0
	for word in text:gmatch("%S+") do
		local piece = if current == 0 then word else " " .. word
		local grown = current + stubWidth(piece)
		if current > 0 and grown > width then
			count += 1
			current = stubWidth(word)
		else
			current = grown
		end
	end
	return count
end

local window = Astra:CreateWindow({ name = "Inline Description Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })

local toggle = tab:CreateToggle({ name = "Notifications", description = "Ping me." })
local keybind = tab:CreateKeybind({
	name = "Push to talk",
	description = "Type one letter. Extra characters are removed automatically.",
})
local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, description = "Master level." })
local dropdown = tab:CreateDropdown({
	name = "Quality",
	description = "Applies instantly.",
	options = { "Low", "High" },
	value = "Low",
})
local plainDropdown = tab:CreateDropdown({ name = "Mode", options = { "A", "B" }, value = "A" })
local progress = tab:CreateProgress({ name = "Download", value = 50, description = "Hang tight." })
local stat = tab:CreateStat({ name = "Frames", value = 240, description = "Per second." })
TestPump(0.6)

-- ===== I1: inside the card, nothing below it ==============================
expect(toggle.descriptor == nil, "I1 the element carries no standalone descriptor")
expect(toggle.descriptionLabel ~= nil, "I1 the element carries an in-card descriptionLabel")
expect(
	toggle.descriptionLabel.Parent == toggle.main,
	"I1 the description label is a child of the element's own main frame"
)

local mains = {
	[toggle.main] = true,
	[keybind.main] = true,
	[slider.main] = true,
	[dropdown.main] = true,
	[plainDropdown.main] = true,
	[progress.main] = true,
	[stat.main] = true,
}
for _, child in tab.tabPage:GetChildren() do
	if child:IsA("Frame") then
		expect(mains[child] == true, "I1 the tab page holds nothing but element cards, found " .. tostring(child.Name))
	end
end

-- ===== I2: the one-line recipe ============================================
near(toggle.main.Size.Y.Offset, 61, "I2 a one-line description grows the 41px card to 61px")
near(toggle.descriptionLabel.Position.X.Offset, 20, "I2 the label sits at the card's left inset")
near(toggle.descriptionLabel.Position.Y.Offset, 37, "I2 the label sits under the 41px base region")
near(toggle.descriptionLabel.Size.Y.Offset, 17, "I2 one line is 17px tall")
expect(toggle.descriptionLabel.Text == "Ping me.", "I2 the label shows the description")
expect(toggle.descriptionLabel.TextSize == 14, "I2 the label uses the 14px in-UI description size")
expect(toggle.descriptionLabel.TextWrapped == true, "I2 the label wraps")

-- ===== I3: controls keep centring in the base region ======================
near(toggle.container.Position.Y.Scale, 0, "I3 the title row no longer centres on scale")
near(toggle.container.Position.Y.Offset, 20.5, "I3 the title row centres in the 41px base region")

-- ===== I4: wrapped descriptions grow line by line =========================
local keybindWidth = keybind.main.AbsoluteSize.X - 40
local keybindLines = expectedLines("Type one letter. Extra characters are removed automatically.", keybindWidth)
expect(keybindLines >= 1, "I4 sanity: at least one line")
near(
	keybind.main.Size.Y.Offset,
	41 + keybindLines * 17 + 3,
	"I4 the keybind card grows by lines*17 + 3 (" .. keybindLines .. " lines)"
)
near(keybind.descriptionLabel.Size.Y.Offset, keybindLines * 17, "I4 the label holds every wrapped line")
near(keybind.box.Position.Y.Offset, 20.5, "I4 the key box stays centred in the base region")

-- ===== I5: the slider's wide layout =======================================
near(slider.main.Size.Y.Offset, 85, "I5 the wide slider card is 65 + 20 with a description")
near(slider.track.Position.Y.Scale, 0, "I5 the track centres in the base region, not the grown card")
near(slider.track.Position.Y.Offset, 32.5, "I5 the track sits at the 65px base region's centre")

-- ===== I6: the dropdown's closed and open heights =========================
near(dropdown.main.Size.Y.Offset, 61, "I6 the closed dropdown card includes the description extra")
dropdown.interact.MouseButton1Click:Fire()
plainDropdown.interact.MouseButton1Click:Fire()
TestPump(0.6)
near(
	dropdown.main.Size.Y.Offset - plainDropdown.main.Size.Y.Offset,
	dropdown._descriptionExtra,
	"I6 the open dropdown card includes the description extra"
)
expect(dropdown._descriptionExtra == 20, "I6 the dropdown's extra is the one-line 20px")
dropdown:_close()
plainDropdown:_close()
TestPump(0.6)
near(dropdown.main.Size.Y.Offset, 61, "I6 closing returns to base + extra, not base")

-- ===== I7: the line reveals with the element ==============================
near(toggle.descriptionLabel.TextTransparency, 0.45, "I7 the description reveals at 0.45 with the element")

-- ===== I8: the lock message rides the in-card line ========================
toggle:Lock("Locked for testing.")
TestPump(0.6)
expect(toggle.descriptionLabel.Text == "Locked for testing.", "I8 locking swaps the line's text")
toggle:Unlock()
TestPump(0.6)
expect(toggle.descriptionLabel.Text == "Ping me.", "I8 unlocking restores the description")
near(toggle.descriptionLabel.TextTransparency, 0.45, "I8 unlocking restores the revealed transparency")

-- ===== I9: the progress track rides up above the line =====================
near(progress.main.Size.Y.Offset, 80, "I9 the progress card is 60 + 20 with a description")
near(progress.track.Position.Y.Scale, 1, "I9 the track stays bottom-anchored")
near(progress.track.Position.Y.Offset, -36, "I9 the track's bottom offset clears the description line")

-- ===== I10: the stat's value labels ride up above the line ================
near(stat.main.Size.Y.Offset, 90, "I10 the stat card is 70 + 20 with a description")

-- ===== I11: the line is locale-bound and the card re-measures =============
window:RegisterTranslations({ fr = { ["Ping me."] = "Tenez-moi au courant des notifications." } })
window:SetLocale("fr")
TestPump(0.6)
expect(
	toggle.descriptionLabel.Text == "Tenez-moi au courant des notifications.",
	"I11 SetLocale retypes the in-card line"
)
local frLines = expectedLines("Tenez-moi au courant des notifications.", toggle.main.AbsoluteSize.X - 40)
near(
	toggle.main.Size.Y.Offset,
	41 + frLines * 17 + 3,
	"I11 the card re-measures for the translated line (" .. frLines .. " lines)"
)
window:SetLocale("en")
TestPump(0.6)
expect(toggle.descriptionLabel.Text == "Ping me.", "I11 switching back restores the description")
near(toggle.main.Size.Y.Offset, 61, "I11 and the card shrinks back to one line")

window:Unload()
TestPump(0.2)

print("INLINE DESCRIPTION: all assertions passed")
