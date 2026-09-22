--[[
===== Footer (CreateFooter) assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

The Footer is the centred inline text-and-icon strip — the
"Built with ⚡ Astra ♡" credit line. Its whole contract is order and
centring: the run renders exactly in the order it was given, every
segment auto-sizes, the icons scale to the text size, and the row
re-centres itself as one unit whenever the content changes.

Expected behavior under test:
  * F1 the run renders in order — text, icon, text, icon — as one
       TextLabel / ImageLabel per segment under a centring layout,
  * F2 the labels auto-size on X, the icons ride at textSize + 3, and the
       container auto-heights and centres on both axes,
  * F3 a footer on the selected tab is revealed to the muted resting
       transparency; a footer built on an unselected tab stays hidden until
       its tab is selected,
  * F4 Set() replaces the whole run: old segments are destroyed, the new
       order renders, unresolved pack names drop instead of leaving gaps,
       and explicit asset references survive,
  * F5 the shorthand forms work — plain strings and mixed
       `{ text = ..., icon = ... }` entries,
  * F6 the footer builds inside an ordinary Group and declaratively inside
       a Collapsible Group (`type = "Footer"`),
  * F7 an empty run renders nothing (the row hides instead of showing a
       blank band),
  * F8 the move API works like on every other element,
  * F9 neither a theme pass nor a bar-layout switch ever paints the
       container: the transparent host stays transparent and the run keeps
       its muted resting transparency (the "white bar" regression),
  * F10 teardown.
]]

local function expect(cond, message)
	if not cond then
		error("FOOTER FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"FOOTER FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

--[[
Collect an element's runs in layout order: every direct child of the
footer body that carries a LayoutOrder is a run. Sorted densely — a
dropped segment leaves a hole in the order, not in this list.
]]
local function runsOf(footer)
	local runs = {}
	for _, child in footer.main:GetChildren() do
		local props = child.__props or {}
		if props.LayoutOrder and props.LayoutOrder > 0 then
			runs[#runs + 1] = {
				order = props.LayoutOrder,
				instance = child,
				className = props.ClassName,
				text = props.Text,
				image = props.Image,
			}
		end
	end
	table.sort(runs, function(a, b)
		return a.order < b.order
	end)
	return runs
end

local window = Astra:CreateWindow({ name = "Footer Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Home" })
TestPump(0.4)

-- ===== F1 + F2: the centred run ============================================

local footer = tab:CreateFooter({
	parts = {
		{ text = "Built with" },
		{ icon = "zap" },
		{ text = "Astra" },
		{ icon = "heart" },
	},
})
TestPump(0.4)

expect(footer ~= nil, "F1 CreateFooter returned an element")
eq(footer.__type, "Footer", "F1 the element reports its type")

local runs = runsOf(footer)
eq(#runs, 4, "F1 the run renders one segment per entry")

eq(runs[1].className, "TextLabel", "F1 segment 1 is text")
eq(runs[1].text, "Built with", "F1 ... carrying the first text")
eq(runs[2].className, "ImageLabel", "F1 segment 2 is an icon")
expect(runs[2].image ~= nil and runs[2].image ~= "zap", "F1 ... resolved through the icon catalog")
eq(runs[3].className, "TextLabel", "F1 segment 3 is text")
eq(runs[3].text, "Astra", "F1 ... carrying the second text")
eq(runs[4].className, "ImageLabel", "F1 segment 4 is an icon")
expect(runs[4].image ~= nil and runs[4].image ~= "heart", "F1 ... resolved through the icon catalog")

--[[
Remote glyph URLs go through the shared image cache and read as a pending
placeholder until the download lands, so distinctness is asserted at the
resolver: two different pack names resolve to two different glyphs.
]]
expect(
	footer.window:ResolveIcon("zap") ~= footer.window:ResolveIcon("heart"),
	"F1 the two glyphs are different icons"
)

-- F2: the layout that keeps the line centred as one unit.
local layouts = {}
for _, child in footer.main:GetChildren() do
	if (child.__props or {}).ClassName == "UIListLayout" then
		layouts[#layouts + 1] = child
	end
end
eq(#layouts, 1, "F2 the body carries exactly one list layout")
eq(layouts[1].__props.FillDirection, Enum.FillDirection.Horizontal, "F2 the run flows horizontally")
eq(layouts[1].__props.HorizontalAlignment, Enum.HorizontalAlignment.Center, "F2 the run stays centred")
eq(layouts[1].__props.VerticalAlignment, Enum.VerticalAlignment.Center, "F2 icons centre against the text")
eq(layouts[1].__props.Padding.Offset, footer.spacing, "F2 the gap follows the spacing prop")

eq(footer.main.__props.AutomaticSize, Enum.AutomaticSize.Y, "F2 the row auto-heights")

local firstLabel = runs[1].instance
eq(firstLabel.__props.AutomaticSize, Enum.AutomaticSize.X, "F2 labels auto-size to their text")
eq(firstLabel.__props.RichText, true, "F2 labels accept inline markup")
eq(firstLabel.__props.TextSize, footer.textSize, "F2 labels use the element's text size")

local iconSize = footer.textSize + 3
eq(runs[2].instance.__props.Size.X.Offset, iconSize, "F2 icons scale with the text size")
eq(runs[2].instance.__props.Size.Y.Offset, iconSize, "F2 ... square, at the same size")

-- ===== F3: reveal follows the tab ==========================================

--[[
The footer was built on the selected tab, so it is already revealed to the
muted resting transparency.
]]
eq(firstLabel.__props.TextTransparency, 0.5, "F3 revealed text rests muted")
eq(runs[2].instance.__props.ImageTransparency, 0.5, "F3 revealed icons rest muted")

local hiddenTab = window:CreateTab({ name = "Away" })
local hiddenFooter = hiddenTab:CreateFooter({ parts = { "Coming soon" } })
TestPump(0.4)

local hiddenRuns = runsOf(hiddenFooter)
eq(hiddenRuns[1].className, "TextLabel", "F3 the away tab built its run")
eq(hiddenRuns[1].instance.__props.TextTransparency, 1, "F3 ... and it stays hidden while the tab is not selected")

hiddenTab:Select()
TestPump(0.6)
eq(hiddenRuns[1].instance.__props.TextTransparency, 0.5, "F3 selecting the tab reveals the line")

-- Back to the home tab so the rest of the run registers on a live page.
tab:Select()
TestPump(0.6)

-- ===== F4: Set() replaces the run ==========================================

footer:Set({
	{ text = "Made" },
	{ icon = "heart" },
})
TestPump(0.4)

local replaced = runsOf(footer)
eq(#replaced, 2, "F4 Set() replaces the whole run")
eq(replaced[1].text, "Made", "F4 ... with the new text first")
eq(replaced[2].className, "ImageLabel", "F4 ... then the new icon")
expect(replaced[1].instance ~= firstLabel, "F4 the old label is gone")
expect(replaced[1].instance.__props.TextTransparency == 0.5, "F4 the rebuilt line is revealed again")

--[[
Unresolved pack names drop instead of leaving a dead gap; explicit asset
references survive untouched.
]]
footer:Set({
	{ text = "keep" },
	{ icon = "definitely-not-a-real-icon-name" },
	{ icon = "rbxassetid://1234567890" },
})
TestPump(0.4)

local dropped = runsOf(footer)
eq(#dropped, 2, "F4 an unresolved pack name drops out of the run")
eq(dropped[1].text, "keep", "F4 ... keeping the text before it")
eq(dropped[2].image, "rbxassetid://1234567890", "F4 ... and keeping the explicit asset reference")

-- ===== F5: shorthand forms ==================================================

local shorthand = tab:CreateFooter({ parts = { "Powered", { text = "by", icon = "zap" } } })
TestPump(0.4)

local shorthandRuns = runsOf(shorthand)
eq(#shorthandRuns, 3, "F5 a plain string is a text segment")
eq(shorthandRuns[1].text, "Powered", "F5 ... rendered first")
eq(shorthandRuns[2].text, "by", "F5 a mixed entry renders its text")
eq(shorthandRuns[3].className, "ImageLabel", "F5 ... then its icon")

-- ===== F6: containers =======================================================

local group = tab:CreateGroup({ direction = "column" })
local groupFooter = group:CreateFooter({ parts = { "inside a group" } })
TestPump(0.4)

expect(groupFooter ~= nil, "F6 a Group builds a footer")
eq(groupFooter.__type, "Footer", "F6 ... reporting its type")
eq(#runsOf(groupFooter), 1, "F6 ... rendering its run")

local collapsible = tab:CreateCollapsibleGroup({
	name = "About",
	elements = {
		{ type = "Footer", parts = { "declarative footer" } },
	},
})
TestPump(0.6)

local declarative = nil
for _, element in collapsible.elements do
	if element.__type == "Footer" then
		declarative = element
		break
	end
end
expect(declarative ~= nil, "F6 a Collapsible Group builds a declarative footer")
eq(declarative.parts[1].value, "declarative footer", "F6 ... carrying its run")

--[[
The stub does not simulate UIListLayout measurement; drive its engine
signal, then tap the header to expand like the collapsible test does.
]]
collapsible.contentLayout.AbsoluteContentSize = Vector2.new(400, 120)
collapsible.interact.Activated:Fire()
TestPump(0.6)
eq(runsOf(declarative)[1].instance.__props.TextTransparency, 0.5, "F6 expanding the container reveals the line")

-- ===== F7: an empty run renders nothing =====================================

local empty = tab:CreateFooter({ parts = {} })
TestPump(0.4)

expect(empty ~= nil, "F7 an empty footer still constructs")
eq(empty.main.Visible, false, "F7 the row hides instead of showing a blank band")

empty:Set({ "now populated" })
TestPump(0.4)
eq(empty.main.Visible, true, "F7 populating the run shows the row again")

-- ===== F8: the move API =====================================================

footer:MoveToBottom()
footer:MoveToTop()
footer:MoveDown()
footer:MoveUp()
TestPump(0.2)

-- ===== F9: theme pass and layout switches never paint the container =========

--[[
Regression: the container used to register BackgroundTransparency against
the theme's ElementTransparency. Element cards can afford that binding —
their StyleElementBody/StyleElementPanel gradient tints the white base —
but the footer's host is never tinted, so the next theme pass tweened it
to opaque and the strip read as a solid white bar. The container carries
no binding any more; these assertions lock that in.
]]
eq(footer.main.BackgroundTransparency, 1, "F9 the container starts transparent")

window:ChangeTheme("default")
TestPump(0.6)
eq(footer.main.BackgroundTransparency, 1, "F9 a theme pass never paints the container")

local liveRuns = runsOf(footer)
eq(liveRuns[1].instance.__props.TextTransparency, 0.5, "F9 ... and the run keeps resting transparency")

local switched = window:_setLayoutMode("collapsedSidebar")
eq(switched, true, "F9 the collapsed-sidebar switch applies")
TestPump(0.8)
eq(footer.main.BackgroundTransparency, 1, "F9 ... leaving the container unpainted")
eq(liveRuns[1].instance.__props.TextTransparency, 0.5, "F9 ... with the run still revealed")

switched = window:_setLayoutMode("sidebar")
eq(switched, true, "F9 the sidebar switch applies")
TestPump(0.8)
eq(footer.main.BackgroundTransparency, 1, "F9 ... and back again, still transparent")
eq(liveRuns[1].instance.__props.TextTransparency, 0.5, "F9 ... with the run still revealed")

--[[
A theme pass after the round trip as well: the container must stay
transparent however the two gestures are interleaved.
]]
window:ChangeTheme({ Accent = Color3.fromRGB(255, 0, 0) })
TestPump(0.6)
eq(footer.main.BackgroundTransparency, 1, "F9 a later theme edit still never paints the container")

-- ===== F10: teardown ========================================================

window:Unload()
TestPump(0.6)

print("FOOTER: all assertions passed")
