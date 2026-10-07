--[[
===== Changelog entry surface: a nested level is a recess, not a second frame =====
Runs the real Astra bundle (loaded as global `Astra` above) against the mini
Roblox environment from sidebar_sizing_stubs.luau.

Before this the Changelog drew `StyleElementBody` on its own card and
`StyleElementPanel` on *every entry*: same `ElementGradient` fill, same lit
outline at the same strength, one inside the other. A changelog with N releases
drew N+1 outlines and the nesting said nothing. The element family's rule is
that the element wears one lit line and the levels inside it read as surface.

  * N1 an entry card carries no UIStroke, and the changelog's own card still
       carries the one lit line (`ElementStroke` at the element tier),
  * N2 the entry's fill is the window surface — a theme binding, like every
       other surface in the library, so a host palette re-derives it — revealed
       opaque so the recess reads even inside a Collapsible Group,
  * N3 the entry rounds with `ElementCornerRadius`, the same tier as the card
       it sits in, and reveal/hide still move the entry with the element,
  * N4 the scope stops here: a panel that floats over other content (a Dropdown
       list) keeps the edge `StyleElementPanel` gives it.
]]

local function expect(cond, message)
	if not cond then
		error("CHANGELOG ENTRY SURFACE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"CHANGELOG ENTRY SURFACE FAIL: "
				.. message
				.. " (got "
				.. tostring(actual)
				.. ", want "
				.. tostring(wanted)
				.. ")",
			0
		)
	end
end

local function childOfClassName(parent, className)
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

local function classNameCount(parent, className)
	local count = 0
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			count += 1
		end
	end
	return count
end

local window = Astra:CreateWindow({ name = "Changelog Entry Surface" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Notes" })

local changelog = tab:CreateChangelog({
	name = "What's new",
	entries = {
		{ version = "1.4.0", date = "2026-09-12", changes = {
			{ symbol = "+", text = "Links, changelogs and richer grouped controls." },
		} },
		{ version = "1.3.0", date = "2026-08-30", changes = {
			{ symbol = "~", text = "Quieter sidebar rows." },
		} },
	},
})
tab:Select()
TestPump(0.8)

local cards = {}
for _, child in changelog.main:GetChildren() do
	if child.ClassName == "Frame" and child.Name == "History" then
		for _, entry in child:GetChildren() do
			if entry.ClassName == "Frame" then
				table.insert(cards, entry)
			end
		end
	end
end
expect(#cards >= 2, "N1 the changelog rendered its entry cards")

-- ===== N1: no outline inside; one lit line on the card itself ===============

for _, card in cards do
	eq(classNameCount(card, "UIStroke"), 0, "N1 an entry card wears no outline of its own")
end
expect(changelog.stroke ~= nil and changelog.stroke.ClassName == "UIStroke", "N1 the changelog card keeps its stroke")
eq(
	changelog.stroke.Transparency,
	window:_elementStrokeTransparency(changelog, false),
	"N1 the changelog's own line stays at the element tier"
)

-- ===== N2: the recess is the window surface, and it is theme-bound ==========

for _, card in cards do
	local gradient = childOfClassName(card, "UIGradient")
	expect(gradient ~= nil, "N2 the entry card carries a gradient")
	eq(
		tostring(window.themeProperties[gradient] and window.themeProperties[gradient].Color),
		"WindowColor",
		"N2 the entry wears the window surface, as a theme binding"
	)
	eq(card.BackgroundTransparency, window.theme.ElementTransparency, "N2 the recess is revealed opaque")
end

local function firstKey(color)
	return color and color.Keypoints and color.Keypoints[1] and color.Keypoints[1].Value
end

local beforeSwap = firstKey(childOfClassName(cards[1], "UIGradient").Color)
local themeSwap = Color3.fromRGB(1, 2, 3)
window:ChangeTheme({ WindowColor = ColorSequence.new(themeSwap) })
TestPump(0.4)
local afterSwap = firstKey(childOfClassName(cards[1], "UIGradient").Color)
expect(afterSwap ~= beforeSwap, "N2 a theme change re-derives the entry surface")
eq(afterSwap.R, themeSwap.R, "N2 the entry surface follows the theme's window colour")

-- ===== N3: one corner family, and the reveal moves with the element =========

for _, card in cards do
	local corner = childOfClassName(card, "UICorner")
	expect(corner ~= nil, "N3 the entry card rounds")
	eq(
		tostring(corner.CornerRadius.Offset),
		tostring(window.theme.ElementCornerRadius.Offset),
		"N3 the entry wears the element corner, like the card it sits in"
	)
end

window:Hide()
TestPump(0.8)
eq(cards[1].BackgroundTransparency, 1, "N3 a hidden changelog takes its entries with it")
window:Show()
TestPump(0.8)
tab:Select()
TestPump(0.8)
eq(
	cards[1].BackgroundTransparency,
	window.theme.ElementTransparency,
	"N3 opening it again brings the entries back"
)

-- ===== N4: floating panels keep their edge ==================================

local dropdown = tab:CreateDropdown({ name = "Mode", options = { "Casual", "Ranked" }, value = "Casual" })
TestPump(0.4)
expect(dropdown.panelStroke ~= nil, "N4 a dropdown's floating panel still gets StyleElementPanel's edge")
local panelGradient = childOfClassName(dropdown.panelStroke, "UIGradient")
eq(
	tostring(window.themeProperties[panelGradient] and window.themeProperties[panelGradient].Color),
	"ElementStrokeGradient",
	"N4 the floating panel's lit lip is untouched"
)

print("CHANGELOG ENTRY SURFACE: all assertions passed")
