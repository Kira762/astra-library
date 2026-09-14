-- ===== in-card description assertions: the line never covers the element ====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- An element created with a `description` renders it inside its own card: a
-- muted 14px line under the title band (the Collapsible Group header recipe,
-- one line: 41 -> 61). The card grows by the measured wrapped-line height and
-- the element's own UI keeps the space it always had, so the line can never
-- cover the title row, the control or the card's edge — the overlap this
-- suite exists to pin.
--
-- Expected behavior under test:
--   * D1 the label is a child of the element's own card and the tab page
--        holds nothing but element cards (no standalone row under the card),
--   * D2 the one-line recipe: a 41px card grows to 61px with a 14px, wrapped
--        label at (20, 37), 17px tall,
--   * D3 the title row keeps centring in the base region (20.5, not 30.5),
--   * D4 a wrapped description grows the card line by line (lines*17 + 3),
--   * D5 no described element's line intersects its own title row, control
--        surface or any bottom-anchored track/readout, and every line stays
--        inside its card,
--   * D6 the slider re-seats the line for each layout mode (wide, narrow,
--        minimal) and keeps its track centred in the base region,
--   * D7 the dropdown's closed and open heights both carry the extra, so its
--        option panel opens below the line,
--   * D8 the line reveals with its element at 0.45 transparency,
--   * D9 locking swaps the line for the lock message, unlocking restores the
--        original description,
--   * D10 the progress bar and the stat readouts ride up above the line,
--   * D11 an element without a description keeps its card height and carries
--        no label,
--   * D12 the Collapsible Group header grows to 61px with its own line,
--   * D13 and that header's body starts below that line, so the group's own
--        children never sit on top of the copy.

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

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"INLINE DESCRIPTION FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

-- [[Rects in the element card's own coordinates, computed the way the engine
-- [[lays them out: every hop resolves Position against the parent's size and
-- [[subtracts the child's anchor. The stub reports AbsoluteSize (scale chains
-- [[resolved) but places anchored children at their raw offset, so the rects
-- [[are walked here rather than read from AbsolutePosition.]]
local function rectIn(instance, ancestor)
	local x, y = 0, 0
	local width, height = 0, 0
	local node = instance
	while node do
		local parent = node.Parent
		if not parent then
			break
		end
		local size = parent.AbsoluteSize
		local position, nodeSize, anchor = node.Position, node.Size, node.AnchorPoint
		local nodeWidth = nodeSize.X.Scale * size.X + nodeSize.X.Offset
		local nodeHeight = nodeSize.Y.Scale * size.Y + nodeSize.Y.Offset
		if node == instance then
			width, height = nodeWidth, nodeHeight
		end
		x = x + position.X.Scale * size.X + position.X.Offset - anchor.X * nodeWidth
		y = y + position.Y.Scale * size.Y + position.Y.Offset - anchor.Y * nodeHeight
		if parent == ancestor then
			break
		end
		node = parent
	end
	return { x = x, y = y, w = width, h = height }
end

local function rectOf(instance, parentSize)
	local position, size, anchor = instance.Position, instance.Size, instance.AnchorPoint
	local width = size.X.Scale * parentSize.X + size.X.Offset
	local height = size.Y.Scale * parentSize.Y + size.Y.Offset
	return {
		x = position.X.Scale * parentSize.X + position.X.Offset - anchor.X * width,
		y = position.Y.Scale * parentSize.Y + position.Y.Offset - anchor.Y * height,
		w = width,
		h = height,
	}
end

local function overlaps(a, b): boolean
	return not (a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y)
end

local function describe(text): string
	return string.format(
		"%.1f..%.1f x %.1f..%.1f",
		text.y, text.y + text.h, text.x, text.x + text.w
	)
end

-- [[The line must clear the element's own UI: the title row, whatever control
-- [[surface the element draws, and the parts that anchor to the card's bottom
-- [[(a slider track, a progress bar, a stat readout). Frames that only paint
-- [[the card behind the text (backgrounds, hover overlays, click targets) are
-- [[not content and are deliberately not listed.]]
local function assertClearOfContent(element, line, parts)
	for _, part in parts do
		if part then
			local rect = rectIn(part, element.main)
			expect(
				not overlaps(line, rect),
				element.name .. " description line " .. describe(line) .. " overlaps " .. describe(rect)
			)
		end
	end
end

local window = Astra:CreateWindow({ name = "Inline Description Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
local more = window:CreateTab({ name = "More" })

local toggle = tab:CreateToggle({ name = "Notifications", description = "Ping me." })
local button = tab:CreateButton({ name = "Run routine", description = "Starts the routine." })
local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, description = "Master level." })
local minimal = tab:CreateSlider({
	name = "Sensitivity",
	range = { 0, 100 },
	value = 40,
	minimal = true,
	description = "Narrow cards keep the line too.",
})
local dropdown = tab:CreateDropdown({
	name = "Quality",
	description = "Applies instantly.",
	options = { "Low", "High" },
	value = "Low",
})
local input = tab:CreateInput({ name = "Display name", placeholder = "Enter a name", description = "Shown to friends." })
local keybind = tab:CreateKeybind({ name = "Push to talk", value = Enum.KeyCode.T, description = "One letter only." })
local progress = tab:CreateProgress({ name = "Download", value = 50, description = "Hang tight." })
local stat = tab:CreateStat({ name = "Frames", value = 240, description = "Per second." })
local undescribed = tab:CreateToggle({ name = "No description" })
local wrapped = more:CreateKeybind({
	name = "Wrapped",
	value = Enum.KeyCode.Y,
	description = "Type one letter. Extra characters are removed automatically, which makes this line wrap.",
})
local group = more:CreateCollapsibleGroup({
	name = "Player Preferences",
	description = "Click to expand. Closing keeps the values active.",
	elements = {},
})
TestPump(0.6)

-- ===== D1: inside the card, nothing below it ===============================
expect(toggle.descriptor == nil, "D1 there is no standalone descriptor row any more")
expect(toggle.descriptionLabel ~= nil, "D1 the element carries an in-card description label")
expect(
	toggle.descriptionLabel.Parent == toggle.main,
	"D1 the label is a child of the element's own card"
)
local cards = {
	[toggle.main] = true,
	[button.main] = true,
	[slider.main] = true,
	[minimal.main] = true,
	[dropdown.main] = true,
	[input.main] = true,
	[keybind.main] = true,
	[progress.main] = true,
	[stat.main] = true,
	[undescribed.main] = true,
}
for _, child in tab.tabPage:GetChildren() do
	if child:IsA("Frame") then
		expect(cards[child] == true, "D1 the tab page holds nothing but element cards, found " .. tostring(child.Name))
	end
end

-- ===== D2: the one-line recipe ============================================
near(toggle.main.Size.Y.Offset, 61, "D2 a one-line description grows the 41px card to 61px")
near(toggle.descriptionLabel.Position.X.Offset, 20, "D2 the line sits on the card's left inset")
near(toggle.descriptionLabel.Position.Y.Offset, 37, "D2 the line sits under the 41px title band")
near(toggle.descriptionLabel.Size.Y.Offset, 17, "D2 one line is 17px tall")
eq(toggle.descriptionLabel.Text, "Ping me.", "D2 the line shows the description")
eq(toggle.descriptionLabel.TextSize, 14, "D2 the line uses the 14px in-UI description size")
eq(toggle.descriptionLabel.TextWrapped, true, "D2 the line wraps")
near(button.main.Size.Y.Offset, 63, "D2 a described 43px button card grows to 63px")
near(input.main.Size.Y.Offset, 61, "D2 a described input card grows to 61px")
near(keybind.main.Size.Y.Offset, 61, "D2 a described keybind card grows to 61px")
near(dropdown.main.Size.Y.Offset, 61, "D2 a described dropdown card grows to 61px")

-- ===== D3: controls keep the base region ==================================
local toggleTitle = rectOf(toggle.container, toggle.main.AbsoluteSize)
near(toggleTitle.y + toggleTitle.h / 2, 20.5, "D3 the title row centres in the 41px base region, not the grown card")
local inputTitle = rectOf(input.container, input.main.AbsoluteSize)
near(inputTitle.y + inputTitle.h / 2, 20.5, "D3 the input's title row keeps the base region")
local inputField = rectOf(input.box, input.main.AbsoluteSize)
near(inputField.y + inputField.h / 2, 20.5, "D3 the input's field box keeps the base region")
local keybindCap = rectOf(keybind.box, keybind.main.AbsoluteSize)
near(keybindCap.y + keybindCap.h / 2, 20.5, "D3 the keybind cap keeps the base region")
local dropdownTitle = rectOf(dropdown.container, dropdown.main.AbsoluteSize)
near(dropdownTitle.y + dropdownTitle.h / 2, 20.5, "D3 the dropdown's title row keeps the base region")

-- ===== D4: wrapped descriptions grow line by line =========================
eq(wrapped._descriptionLines, 2, "D4 the long description measures as two lines")
near(wrapped.main.Size.Y.Offset, 41 + 2 * 17 + 3, "D4 the card grows by lines*17 + 3 (78px)")
near(wrapped.descriptionLabel.Size.Y.Offset, 34, "D4 the label reserves two line heights")

-- ===== D5: the line never covers the element's own UI =====================
local function lineOf(element)
	return rectIn(element.descriptionLabel, element.main)
end

for _, case in {
	{ element = toggle, parts = { toggle.container, toggle.functionContainer } },
	{ element = button, parts = { button.container } },
	{ element = slider, parts = { slider.container, slider.track } },
	{ element = minimal, parts = { minimal.track } },
	{ element = dropdown, parts = { dropdown.container, dropdown.selectedLabel, dropdown.chevron } },
	{ element = input, parts = { input.container, input.box } },
	{ element = keybind, parts = { keybind.container, keybind.box } },
	{ element = progress, parts = { progress.container, progress.readout, progress.track } },
	{ element = stat, parts = { stat.titleContainer, stat.valueHost, stat.changeHost } },
	{ element = wrapped, parts = { wrapped.container, wrapped.box } },
} do
	local element = case.element
	local line = lineOf(element)
	local card = { x = 0, y = 0, w = element.main.AbsoluteSize.X, h = element.main.AbsoluteSize.Y }
	expect(
		line.y >= 0 and line.y + line.h <= card.h,
		"D5 " .. element.name .. " line " .. describe(line) .. " stays inside its card " .. describe(card)
	)
	assertClearOfContent(element, line, case.parts)
end

-- ===== D6: the slider re-seats the line per layout mode ===================
local sliderCard = rectOf(slider.track, slider.main.AbsoluteSize)
near(slider.main.Size.Y.Offset, 85, "D6 the wide slider card carries the line (65 + 20)")
near(sliderCard.y + sliderCard.h / 2, 32.5, "D6 the wide track centres in the 65px base region")
near(slider.descriptionLabel.Position.Y.Offset, 61, "D6 the line sits under the wide base region")
near(minimal.main.Size.Y.Offset, 61, "D6 the minimal slider card carries the line (41 + 20)")
near(minimal.descriptionLabel.Position.Y.Offset, 37, "D6 the minimal slider re-seats the line at 37")
local minimalTrack = rectOf(minimal.track, minimal.main.AbsoluteSize)
near(minimalTrack.y + minimalTrack.h / 2, 20.5, "D6 the minimal track centres in the base region")

-- ===== D7: the dropdown's open height carries the extra ===================
local dropdownPlain = more:CreateDropdown({ name = "Plain", options = { "A", "B" }, value = "A" })
TestPump(0.3)
near(
	dropdown:_openHeight() - dropdownPlain:_openHeight(),
	20,
	"D7 the described dropdown's open height carries the same 20px the closed card does"
)
dropdown:_open()
TestPump(0.8)
near(dropdown.main.Size.Y.Offset, dropdown:_openHeight(), "D7 the open card reaches the open height")
local openLine = lineOf(dropdown)
local panel = rectIn(dropdown.panel, dropdown.main)
expect(
	not overlaps(panel, openLine),
	"D7 the option panel " .. describe(panel) .. " stays below the line " .. describe(openLine)
)
local firstRow = dropdown._optionFrames[1].frame
if firstRow then
	local row = rectIn(firstRow, dropdown.main)
	expect(
		not overlaps(row, openLine),
		"D7 the first option row " .. describe(row) .. " stays below the line " .. describe(openLine)
	)
end
dropdown:_close()
TestPump(0.8)
near(dropdown.main.Size.Y.Offset, 61, "D7 closing returns the card to the described closed height")

-- ===== D8: the line reveals with its element ==============================
eq(toggle.descriptionLabel.TextTransparency, 0.45, "D8 the line reveals with its element at 0.45")
window:Show()
TestPump(0.8)
eq(toggle.descriptionLabel.TextTransparency, 0.45, "D8 the line stays at 0.45 once the window is shown")

-- ===== D9: the lock message rides the same line ===========================
toggle:Lock("Locked by the host.")
TestPump(0.4)
eq(toggle.descriptionLabel.Text, "Locked by the host.", "D9 locking swaps the line for the lock message")
toggle:Unlock()
TestPump(0.4)
eq(toggle.descriptionLabel.Text, "Ping me.", "D9 unlocking restores the description")

-- ===== D10: bottom-anchored bars ride above the line ======================
near(progress.main.Size.Y.Offset, 80, "D10 the described progress card grows by the line (60 + 20)")
local progressTrack = rectOf(progress.track, progress.main.AbsoluteSize)
near(progressTrack.y + progressTrack.h, 44, "D10 the progress bar keeps its 44px seat 20px above the card's floor")
local statValue = rectOf(stat.valueHost, stat.main.AbsoluteSize)
near(statValue.y + statValue.h, 90 - 12 - 20, "D10 the stat's value host rides up above the line")
near(stat.main.Size.Y.Offset, 90, "D10 the described stat card grows by the line (70 + 20)")

-- ===== D11: no description, no line, no growth ============================
eq(undescribed.descriptionLabel, nil, "D11 an undescribed element carries no label")
near(undescribed.main.Size.Y.Offset, 41, "D11 an undescribed element keeps its 41px card")

-- ===== D12: the Collapsible Group header carries its own line =============
near(group.headerHeight, 61, "D12 a described group header grows to 61px")
expect(group.descriptionLabel ~= nil, "D12 the group carries a header line")
near(group.descriptionLabel.Position.Y.Offset, 37, "D12 the group's line sits under the title band")
eq(group.descriptionLabel.TextSize, 14, "D12 the group's line matches the element description size")
near(group.main.Size.Y.Offset, 61, "D12 the collapsed container matches the header")

-- ===== D13: the group's body starts below its line ======================
local groupLine = rectIn(group.descriptionLabel, group.main)
local groupClip = rectIn(group.bodyClip, group.main)
expect(
	groupClip.y >= groupLine.y + groupLine.h,
	"D13 the group's contents clip " .. describe(groupClip) .. " starts below its line " .. describe(groupLine)
)
near(groupClip.y, 67, "D13 the described group's body starts 6px under the 61px header")
local plainGroup = more:CreateCollapsibleGroup({ name = "Plain group", elements = {} })
TestPump(0.3)
near(plainGroup.headerHeight, 41, "D13 an undescribed group header stays 41px")
near(rectIn(plainGroup.bodyClip, plainGroup.main).y, 47, "D13 an undescribed group's body starts 6px under its 41px header")

-- [[A described control inside a group carries the same line: the declarative
-- [[child receives the prop and grows its own card, so the group's measured
-- [[content includes the extra.]]
local groupedGroup = more:CreateCollapsibleGroup({
	name = "Grouped children",
	elements = {
		{ type = "Toggle", name = "Grouped toggle", description = "Grouped line.", value = false },
		{ type = "Button", name = "Grouped button", callback = function() end },
	},
})
TestPump(0.4)
local groupedToggle = groupedGroup.elements[1]
local groupedButton = groupedGroup.elements[2]
near(groupedToggle.main.Size.Y.Offset, 61, "D13 a described control inside a group grows to 61px")
expect(groupedToggle.descriptionLabel.Parent == groupedToggle.main, "D13 the grouped line is inside the control's card")
local groupedLine = rectIn(groupedToggle.descriptionLabel, groupedToggle.main)
local groupedTitle = rectIn(groupedToggle.container, groupedToggle.main)
expect(
	not overlaps(groupedLine, groupedTitle),
	"D13 the grouped line " .. describe(groupedLine) .. " clears the control's title row " .. describe(groupedTitle)
)
near(groupedButton.main.Size.Y.Offset, 43, "D13 an undescribed sibling keeps its base 43px card")

window:Unload()
TestPump(0.2)

print("INLINE DESCRIPTION: all assertions passed")
