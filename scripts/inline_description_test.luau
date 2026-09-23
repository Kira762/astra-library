--[[
===== in-card description assertions: stat and group lines only ============
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

The in-card description line is a Stat recipe now: a muted 14px line under
the card's controls (the Collapsible Group header carries its own variant
of it, one line: 41 -> 61). The card grows by the measured wrapped-line
height and the element's own UI keeps the space it always had, so the line
can never cover the controls or the card's edge.

Button, Toggle, Slider, Dropdown, Input, Mode Picker, About Card and Link
no longer accept the prop: a `description` passed to one of them is
ignored — no line, no growth, base geometry exactly as if the prop had
never been there.

Expected behavior under test:
  * D1 the tab page holds nothing but element cards (no standalone row
       under any card),
  * D2 the one-line recipe on the Stat: a 70px card grows to 90px with a
       14px, wrapped label at (20, 66), 17px tall,
  * D3 a control built with a `description` prop keeps its base geometry:
       same card height, title and controls centred as ever, no label,
  * D4 a wrapped description grows the Stat card line by line
       (lines*17 + 3),
  * D5 no Stat line intersects the Stat's own readouts, and every line
       stays inside its card,
  * D6 the described and plain dropdowns open to the same height,
  * D7 the line reveals with its element at 0.45 transparency,
  * D8 locking a described Collapsible Group swaps its line for the lock
       message, unlocking restores the description,
  * D9 the Stat's bottom-anchored readouts ride up above the line,
  * D10 an element without a description keeps its card height and
       carries no label,
  * D11 the Collapsible Group header grows to 61px with its own line,
  * D12 and that header's body starts below that line, so the group's own
       children never sit on top of the copy,
  * D13 a declarative child's `description` prop is ignored too: the
       grouped control keeps its base card and carries no label.
]]

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

--[[
Rects in the element card's own coordinates, computed the way the engine
lays them out: every hop resolves Position against the parent's size and
subtracts the child's anchor. The stub reports AbsoluteSize (scale chains
resolved) but places anchored children at their raw offset, so the rects
are walked here rather than read from AbsolutePosition.
]]
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

--[[
The line must clear the element's own UI: whatever control surface the
element draws and the parts that anchor to the card's bottom (a progress
bar, a stat readout). Frames that only paint the card behind the text
(backgrounds, hover overlays, click targets) are not content and are
deliberately not listed.
]]
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

local stat = tab:CreateStat({ name = "Frames", value = 240, description = "Per second." })
local wrapped = tab:CreateStat({
	name = "Wrapped",
	value = 240,
	description = "A longer helper line that runs long enough to wrap onto a second line inside the card.",
})
local plainStat = more:CreateStat({ name = "Plain stat", value = 1 })
local toggle = tab:CreateToggle({ name = "Notifications", description = "Ping me." })
local button = tab:CreateButton({ name = "Run routine", description = "Starts the routine." })
local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, description = "Master level." })
local minimal = tab:CreateSlider({
	name = "Sensitivity",
	range = { 0, 100 },
	value = 40,
	minimal = true,
	description = "Ignored on a minimal slider.",
})
local dropdown = tab:CreateDropdown({
	name = "Quality",
	description = "Applies instantly.",
	options = { "Low", "High" },
	value = "Low",
})
local input = tab:CreateInput({ name = "Display name", placeholder = "Enter a name", description = "Shown to friends." })
local picker = more:CreateModePicker({
	title = "Modes",
	description = "A static picker line the picker no longer renders.",
	modes = {
		{ label = "Normal", type = "default", description = "Default mode." },
		{ label = "Fast", type = "dot", description = "Second mode." },
		{ label = "Balanced", type = "dot", description = "Third mode." },
	},
})
local about = more:CreateAboutCard({
	name = "About",
	subtitle = "The card",
	description = "A paragraph the card no longer renders.",
})
local link = more:CreateLink({ name = "Docs", link = "https://example.com", description = "Ignored helper line." })
local undescribed = tab:CreateToggle({ name = "No description" })
local group = more:CreateCollapsibleGroup({
	name = "Player Preferences",
	description = "Click to expand. Closing keeps the values active.",
	elements = {},
})
TestPump(0.6)

-- ===== D1: element cards only, nothing below them ==========================
expect(stat.descriptor == nil, "D1 there is no standalone descriptor row any more")
expect(stat.descriptionLabel ~= nil, "D1 the Stat carries an in-card description label")
expect(
	stat.descriptionLabel.Parent == stat.main,
	"D1 the label is a child of the element's own card"
)
local cards = {
	[stat.main] = true,
	[wrapped.main] = true,
	[plainStat.main] = true,
	[toggle.main] = true,
	[button.main] = true,
	[slider.main] = true,
	[minimal.main] = true,
	[dropdown.main] = true,
	[input.main] = true,
	[picker.main] = true,
	[about.main] = true,
	[link.main] = true,
	[undescribed.main] = true,
	[group.main] = true,
}
for _, child in tab.tabPage:GetChildren() do
	if child:IsA("Frame") then
		expect(cards[child] == true, "D1 the tab page holds nothing but element cards, found " .. tostring(child.Name))
	end
end

-- ===== D2: the one-line recipe on the Stat =================================
near(stat.main.Size.Y.Offset, 90, "D2 a one-line description grows the 70px stat card to 90px")
near(stat.descriptionLabel.Position.X.Offset, 20, "D2 the line sits on the card's left inset")
near(stat.descriptionLabel.Position.Y.Offset, 66, "D2 the line sits under the 70px control region")
near(stat.descriptionLabel.Size.Y.Offset, 17, "D2 one line is 17px tall")
eq(stat.descriptionLabel.Text, "Per second.", "D2 the line shows the description")
eq(stat.descriptionLabel.TextSize, 14, "D2 the line uses the 14px in-UI description size")
eq(stat.descriptionLabel.TextWrapped, true, "D2 the line wraps")

-- ===== D3: a passed description prop is inert on the eight elements ========
eq(toggle.descriptionLabel, nil, "D3 a described toggle carries no label")
near(toggle.main.Size.Y.Offset, 41, "D3 a described toggle keeps its 41px card")
local toggleTitle = rectOf(toggle.container, toggle.main.AbsoluteSize)
near(toggleTitle.y + toggleTitle.h / 2, 20.5, "D3 the toggle's title row keeps centring in the 41px card")
near(button.main.Size.Y.Offset, 43, "D3 a described button keeps its 43px card")
eq(button.descriptionLabel, nil, "D3 a described button carries no label")
near(slider.main.Size.Y.Offset, 65, "D3 a described slider keeps its 65px wide card")
eq(slider.descriptionLabel, nil, "D3 a described slider carries no label")
local sliderTrack = rectOf(slider.track, slider.main.AbsoluteSize)
near(sliderTrack.y + sliderTrack.h / 2, 32.5, "D3 the wide track keeps its base-region centre")
near(minimal.main.Size.Y.Offset, 41, "D3 a described minimal slider keeps its 41px card")
local minimalTrack = rectOf(minimal.track, minimal.main.AbsoluteSize)
near(minimalTrack.y + minimalTrack.h / 2, 20.5, "D3 the minimal track keeps its base-region centre")
near(input.main.Size.Y.Offset, 41, "D3 a described input keeps its 41px card")
eq(input.descriptionLabel, nil, "D3 a described input carries no label")
local inputTitle = rectOf(input.container, input.main.AbsoluteSize)
near(inputTitle.y + inputTitle.h / 2, 20.5, "D3 the input's title row keeps the base region")
local inputField = rectOf(input.box, input.main.AbsoluteSize)
near(inputField.y + inputField.h / 2, 20.5, "D3 the input's field box keeps the base region")
near(picker.main.Size.Y.Offset, 84, "D3 a described picker keeps its 84px card")
eq(picker.descriptionLabel, nil, "D3 a described picker carries no label")
eq(about.descriptionLabel, nil, "D3 a described About card carries no paragraph label")
expect(about.SetDescription == nil, "D3 the About card exposes no SetDescription any more")
near(link.main.Size.Y.Offset, 43, "D3 a described link keeps its single-line 43px card")
eq(link.descriptionLabel, nil, "D3 a described link carries no label")

-- ===== D4: wrapped descriptions grow the Stat line by line =================
eq(wrapped._descriptionLines, 2, "D4 the long description measures as two lines")
near(wrapped.main.Size.Y.Offset, 70 + 2 * 17 + 3, "D4 the card grows by lines*17 + 3 (107px)")
near(wrapped.descriptionLabel.Size.Y.Offset, 34, "D4 the label reserves two line heights")

-- ===== D5: the line never covers the Stat's own UI =========================
local function lineOf(element)
	return rectIn(element.descriptionLabel, element.main)
end

for _, case in {
	{ element = stat, parts = { stat.titleContainer, stat.valueHost, stat.changeHost } },
	{ element = wrapped, parts = { wrapped.titleContainer, wrapped.valueHost, wrapped.changeHost } },
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

-- ===== D6: the dropdown opens to the same height with or without a line ===
local dropdownPlain = more:CreateDropdown({ name = "Plain", options = { "A", "B" }, value = "A" })
TestPump(0.3)
near(
	dropdown:_openHeight() - dropdownPlain:_openHeight(),
	0,
	"D6 a passed description no longer adds anything to the dropdown's open height"
)
dropdown:_open()
TestPump(0.8)
near(dropdown.main.Size.Y.Offset, dropdown:_openHeight(), "D6 the open card reaches the open height")
dropdown:_close()
TestPump(0.8)
near(dropdown.main.Size.Y.Offset, 41, "D6 closing returns the card to the 41px closed height")

-- ===== D7: the line reveals with its element ===============================
eq(stat.descriptionLabel.TextTransparency, 0.45, "D7 the line reveals with its element at 0.45")
window:Show()
TestPump(0.8)
eq(stat.descriptionLabel.TextTransparency, 0.45, "D7 the line stays at 0.45 once the window is shown")

-- ===== D8: the lock message rides the group's own line =====================
group:Lock("Locked by the host.")
TestPump(0.4)
eq(group.descriptionLabel.Text, "Locked by the host.", "D8 locking swaps the line for the lock message")
group:Unlock()
TestPump(0.4)
eq(group.descriptionLabel.Text, "Click to expand. Closing keeps the values active.", "D8 unlocking restores the description")

-- ===== D9: bottom-anchored readouts ride above the line ====================
local statValue = rectOf(stat.valueHost, stat.main.AbsoluteSize)
near(statValue.y + statValue.h, 90 - 12 - 20, "D9 the stat's value host rides up above the line")
near(stat.main.Size.Y.Offset, 90, "D9 the described stat card grows by the line (70 + 20)")

-- ===== D10: no description, no line, no growth =============================
eq(plainStat.descriptionLabel, nil, "D10 an undescribed element carries no label")
near(plainStat.main.Size.Y.Offset, 70, "D10 an undescribed element keeps its base card")
eq(undescribed.descriptionLabel, nil, "D10 an undescribed toggle carries no label")
near(undescribed.main.Size.Y.Offset, 41, "D10 an undescribed toggle keeps its 41px card")

-- ===== D11: the Collapsible Group header carries its own line ==============
near(group.headerHeight, 61, "D11 a described group header grows to 61px")
expect(group.descriptionLabel ~= nil, "D11 the group carries a header line")
near(group.descriptionLabel.Position.Y.Offset, 37, "D11 the group's line sits under the title band")
eq(group.descriptionLabel.TextSize, 14, "D11 the group's line matches the element description size")
near(group.main.Size.Y.Offset, 61, "D11 the collapsed container matches the header")

-- ===== D12: the group's body starts below its line =========================
local groupLine = rectIn(group.descriptionLabel, group.main)
local groupClip = rectIn(group.bodyClip, group.main)
expect(
	groupClip.y >= groupLine.y + groupLine.h,
	"D12 the group's contents clip " .. describe(groupClip) .. " starts below its line " .. describe(groupLine)
)
near(groupClip.y, 62, "D12 the described group's body starts under the divider at 61px")
local plainGroup = more:CreateCollapsibleGroup({ name = "Plain group", elements = {} })
TestPump(0.3)
near(plainGroup.headerHeight, 41, "D12 an undescribed group header stays 41px")
near(rectIn(plainGroup.bodyClip, plainGroup.main).y, 42, "D12 an undescribed group's body starts under the divider at 41px")

-- ===== D13: declarative children ignore the prop too =======================
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
eq(groupedToggle.descriptionLabel, nil, "D13 a described grouped toggle carries no label")
near(groupedToggle.main.Size.Y.Offset, 41, "D13 a described grouped toggle keeps its 41px card")
near(groupedButton.main.Size.Y.Offset, 43, "D13 an undescribed sibling keeps its base 43px card")

window:Unload()
TestPump(0.2)

print("INLINE DESCRIPTION: all assertions passed")
