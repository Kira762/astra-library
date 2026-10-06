--[[
===== flat page composition assertions =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau and pins the one-surface rules:

  * CreatePageHeader is a flat element: no gradient, no corner, no stroke,
    no padding box — a 20px title, a 12px muted metadata line (a table is
    joined with " · ") and an optional 14px paragraph, capped at the prose
    measure by a UISizeConstraint,
  * the metadata line and the paragraph settle at the muted alphas and a
    reveal/hide round trip restores them,
  * `plain = true` on Text drops the card and keeps the prose measure,
  * `plain = true` on Isolated drops the card, draws a 1px hairline above
    the row, and keeps the expansion contract intact,
  * the element list format is unchanged for carded elements (a carded Text
    still owns its stroke and its padding box).
]]

local function expect(cond, message)
	if not cond then
		error("PAGE HEADER FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"PAGE HEADER FAIL: "
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

local function findChild(parent, className)
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

local window = Astra:CreateWindow({ name = "Flat Page Test", configuration = { autoSave = false, autoLoad = false } })
TestPump(1.2)

local tab = window:CreateTab({ name = "Overview", icon = "house" })
tab:Select()
TestPump(0.3)

-- ===== P1: the header is flat =====
local header = tab:CreatePageHeader({
	name = "Overview",
	meta = { "v1.4.0", "13 tabs", "Astra Team" },
	body = "Every tab drives something real, and this paragraph is prose rather than another card.",
})
TestPump(0.2)

eq(header.__type, "PageHeader", "P1 the header reports its type")
eq(header.main.Size.X.Offset, -20, "P1 the header keeps the element gutter")
eq(header.main.BackgroundTransparency, 1, "P1 the header owns no surface")
expect(findChild(header.main, "UIGradient") == nil, "P1 no gradient is painted on the header")
expect(findChild(header.main, "UICorner") == nil, "P1 no corner is rounded on the header")
expect(findChild(header.main, "UIStroke") == nil, "P1 no outline is drawn on the header")
expect(findChild(header.main, "UIPadding") == nil, "P1 the header keeps no padding box")

eq(header.title.TextSize, 20, "P1 the title is the page-title size")
eq(tostring(header.title.FontFace.Weight), "SemiBold", "P1 the title carries the strong weight (600)")
eq(header.metaLabel.Text, "v1.4.0 · 13 tabs · Astra Team", "P1 the metadata table joins into one muted line")
eq(header.metaLabel.TextSize, 12, "P1 the metadata line is the caption size")
eq(header.bodyLabel.TextSize, 14, "P1 the paragraph is body size")

local measure = findChild(header.bodyLabel, "UISizeConstraint")
expect(measure ~= nil, "P1 the paragraph carries a size cap")
eq(measure.MaxSize.X, 468, "P1 the cap is the reading measure")

-- ===== P2: the reveal ladder =====
header:_setShown(true, false)
eq(header.title.TextTransparency, 0, "P2 the title lands at full strength")
eq(header.metaLabel.TextTransparency, 0.55, "P2 the metadata line rests muted")
eq(header.bodyLabel.TextTransparency, 0.45, "P2 the paragraph rests quieter still")
header:_setShown(false, false)
eq(header.title.TextTransparency, 1, "P2 hiding clears the title")
eq(header.metaLabel.TextTransparency, 1, "P2 hiding clears the metadata line")
header:_setShown(true, false)

-- ===== P3: setters keep the lines in step =====
header:SetMeta({ "v1.4.1" })
eq(header.metaLabel.Text, "v1.4.1", "P3 SetMeta retypes the line")
header:SetMeta(nil)
eq(header.metaLabel.Visible, false, "P3 an empty meta drops out of the layout")
header:SetBody(nil)
eq(header.bodyBlock.Visible, false, "P3 an empty body drops its block out of the layout")
header:SetTitle("Overview (updated)")
eq(header.title.Text, "Overview (updated)", "P3 SetTitle retypes the heading")

-- ===== P4: a plain Text drops the card, a carded one keeps it =====
local prose = tab:CreateText({
	name = "Start here",
	plain = true,
	text = "Plain prose sits on the page band instead of inside a card.",
})
TestPump(0.2)
expect(prose.stroke == nil, "P4 a plain Text owns no outline")
expect(findChild(prose.main, "UIPadding") == nil, "P4 a plain Text keeps no padding box")
expect(prose.main.BackgroundTransparency == 1, "P4 a plain Text paints no fill")
expect(findChild(prose.body, "UISizeConstraint") ~= nil, "P4 a plain Text still caps the reading measure")
prose:_setShown(true, false)
eq(prose.main.BackgroundTransparency, 1, "P4 the reveal cannot paint a surface on it")

local carded = tab:CreateText({ name = "Carded", text = "This one keeps its card." })
TestPump(0.2)
expect(carded.stroke ~= nil, "P4 a carded Text still owns its stroke")
expect(findChild(carded.main, "UIPadding") ~= nil, "P4 a carded Text still keeps its padding box")

-- ===== P5: a plain Isolated is a row with a hairline above it =====
local isolated = tab:CreateIsolated({
	name = "Release history",
	subtitle = "Library milestones",
	icon = "history",
	plain = true,
	elements = { { type = "Changelog", name = "Recent releases", entries = { { version = "1.4.0", date = "2026-09-12", changes = { { symbol = "+", text = "Flat pages." } } } } } },
})
TestPump(0.3)
eq(isolated.plain, true, "P5 the row reports its plain build")
expect(isolated.stroke == nil, "P5 a plain row owns no outline")
expect(isolated.headerCorner == nil, "P5 a plain row rounds no corner")
expect(findChild(isolated.main, "UIGradient") == nil, "P5 a plain row paints no gradient")
expect(isolated.rule ~= nil, "P5 a plain row draws its separating hairline")
eq(isolated.rule.Size.Y.Offset, 1, "P5 the hairline is one pixel")
eq(isolated.rule.Position.Y.Offset, 0, "P5 the hairline sits above the row")
eq(isolated.headerHeight, 36 + 20, "P5 the row uses the nav-row band plus its subtitle line")

isolated.contentLayout.AbsoluteContentSize = Vector2.new(400, 200)
isolated:Expand()
TestPump(0.4)
expect(isolated._expanded and isolated.body.Visible, "P5 the expansion contract still holds")
eq(isolated.main.Size.Y.Offset, 36 + 20 + 1 + isolated.bodyPad + 200 + isolated.bodyPad, "P5 the expanded height is header + hairline seam + padded content")

-- ===== P6: the sidebar rows are quiet rows =====
local rowTab = tab
expect(rowTab.topbarAccent ~= nil, "P6 the nav row owns its accent bar")
expect(findChild(rowTab.topbarItem, "UIStroke") == nil, "P6 the nav row carries no outline")
expect(findChild(rowTab.topbarItem, "UIShadow") == nil, "P6 the nav row carries no shadow")
eq(rowTab.topbarItem.Size.Y.Offset, 36, "P6 the nav row is the 36px row")
eq(window.layout.rowIconSize, 16, "P6 the nav icon is the 16px size")
eq(window.layout.rowLabelSize, 14, "P6 the nav label is body size")

print("PAGE HEADER: flat composition, plain rows and quiet nav rows passed")
