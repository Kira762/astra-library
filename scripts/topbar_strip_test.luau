-- ===== top-layout tab strip spacing assertions =====
-- [[Runs the real Astra bundle (global `Astra`) against the mini Roblox]]
-- [[environment from sidebar_sizing_stubs.luau. The stub's layout engine is]]
-- [[inert, so canvas geometry that Roblox derives from UIPadding /]]
-- [[AutomaticCanvasSize is emulated by writing CanvasSize/CanvasPosition and]]
-- [[the pill Position/Size directly, exactly like the pre-clamp geometry]]
-- [[the engine would produce.]]

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"SMOKE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function expect(cond, message)
	if not cond then
		error("SMOKE FAIL: " .. message, 0)
	end
end

local function childOfClass(inst, className)
	for _, ch in inst:GetChildren() do
		if ch.ClassName == className then
			return ch
		end
	end
end

local window = Astra:CreateWindow({ name = "Topbar Strip Test" })
TestPump(0.3)

local layout = window.layout
local strip = window.tabList

-- T1: the top layout owns the new spacing tokens.
eq(layout.mode, "top", "T1 window opens in topbar mode")
eq(layout.tabStripInset, 30, "T1 strip frame stays inset 30px from the window edge")
eq(layout.tabStripEdgePadding, 14, "T1 end gutter inside the strip is 14px")
eq(layout.tabStripFadeWidth, 30, "T1 edge fade is 30px wide")
eq(layout.tabStripTop, layout.topbarHeight + 6, "T1 strip keeps a 6px gap under the topbar")
eq(
	layout.chromeHeight,
	layout.tabStripTop + layout.tabStripHeight + 6,
	"T1 chrome reserves a matching 6px gap below the strip"
)

-- T2: the strip frame is inset on both sides; the gutters live in canvas
-- padding (which scrolls with the content), and the pills are spaced out.
eq(strip.Position.X.Offset, layout.tabStripInset, "T2 strip frame starts at the side inset")
eq(strip.Size.X.Offset, -layout.tabStripInset * 2, "T2 strip frame ends at the opposite inset")
eq(strip.Position.Y.Offset, layout.tabStripTop, "T2 strip frame starts on the strip top")

local padding = childOfClass(strip, "UIPadding")
expect(padding ~= nil, "T2 strip carries a canvas UIPadding")
eq(padding.PaddingLeft.Offset, layout.tabStripEdgePadding, "T2 leading end gutter")
eq(padding.PaddingRight.Offset, layout.tabStripEdgePadding, "T2 trailing end gutter")
local padTop = padding.PaddingTop and padding.PaddingTop.Offset or 0
local padBottom = padding.PaddingBottom and padding.PaddingBottom.Offset or 0
eq(padTop, 0, "T2 no vertical gutter on the horizontal strip")
eq(padBottom, 0, "T2 no vertical gutter on the horizontal strip")

local listLayout = childOfClass(strip, "UIListLayout")
eq(listLayout.Padding.Offset, 8, "T2 pills keep an 8px gap from each other")
eq(listLayout.FillDirection, Enum.FillDirection.Horizontal, "T2 strip lays pills out horizontally")

-- T3: the edge fades sit on the strip edges and use the layout fade width.
eq(window.tabFadeLeft.Size.X.Offset, layout.tabStripFadeWidth, "T3 left fade width follows the layout")
eq(window.tabFadeRight.Size.X.Offset, layout.tabStripFadeWidth, "T3 right fade width follows the layout")
eq(window.tabFadeLeft.Position.X.Offset, layout.tabStripInset, "T3 left fade starts on the strip edge")
eq(
	window.tabFadeRight.Position.X.Offset,
	-(layout.tabStripInset + layout.tabStripFadeWidth),
	"T3 right fade ends on the strip edge"
)

-- T4: the content area and search pill inherit the taller, balanced chrome.
eq(window.elements.Size.Y.Offset, -layout.chromeHeight, "T4 elements area clears the chrome band")

-- T5: the Tag element and every trace of its container/API are gone.
expect(window.CreateTag == nil, "T5 Window:CreateTag is removed")
expect(window.tags == nil, "T5 window no longer keeps a tags list")
expect(window.tagContainer == nil, "T5 the topbar no longer builds a tag container")

-- T6: fades light only for real clipping, gutter-aware (the trailing 14px
-- gutter must not count as clipped content).
local frameWidth = strip.AbsoluteSize.X
eq(frameWidth, window.main.Size.X.Offset - layout.tabStripInset * 2, "T6 precondition: strip frame width")

local function fades()
	return window.tabFadeRight.Visible, window.tabFadeLeft.Visible
end

strip.CanvasPosition = Vector2.new(0, 0)
strip.CanvasSize = UDim2.new(0, 400, 0, 0)
window:_refreshTabStripChrome()
do
	local right, left = fades()
	expect(right == false and left == false, "T6 no fades when the pills fit")
end

strip.CanvasSize = UDim2.new(0, frameWidth + layout.tabStripEdgePadding - 10, 0, 0)
window:_refreshTabStripChrome()
do
	local right, left = fades()
	expect(right == false, "T6 the trailing gutter alone does not light the right fade")
end

strip.CanvasSize = UDim2.new(0, 800, 0, 0)
window:_refreshTabStripChrome()
do
	local right, left = fades()
	expect(right == true and left == false, "T6 overflow at scroll 0 lights only the right fade")
end

strip.CanvasPosition = Vector2.new(40, 0)
window:_refreshTabStripChrome()
do
	local right, left = fades()
	expect(right == true and left == true, "T6 scrolling in lights the left fade too")
end
strip.CanvasPosition = Vector2.new(0, 0)

-- T7: scroll-into-view lands the selected pill clear of a fade / inside the
-- trailing gutter, and never scrolls a comfortably visible pill.
local a = window:CreateTab({ name = "AAAAAAA", icon = "house" })
local b = window:CreateTab({ name = "BBBBBBB", icon = "house" })
local c = window:CreateTab({ name = "CCCCCCC", icon = "house" })
TestPump(0.2)

local function emulate(tab, canvasX, width)
	tab.topbarItem.Position = UDim2.fromOffset(canvasX, 0)
	tab.topbarItem.Size = UDim2.fromOffset(width, 34)
end

local maxScroll = 800 - frameWidth

window.selectedTab = c
emulate(c, 600, 100) -- right edge at canvas 700, past the 526px visible bound
strip.CanvasPosition = Vector2.new(0, 0)
window:_scrollSelectedTabIntoView(false)
do
	-- target = right(700) + edgePadding(14) - frameWidth(540) = 174
	eq(strip.CanvasPosition.X, 700 + layout.tabStripEdgePadding - frameWidth, "T7 off-right pill scrolls to its gutter")
end

window.selectedTab = a
emulate(a, layout.tabStripEdgePadding, 100) -- first pill starts in the leading gutter
window:_scrollSelectedTabIntoView(false)
eq(strip.CanvasPosition.X, 0, "T7 first pill scrolls back to the rest position")

window.selectedTab = b
emulate(b, 210, 90) -- comfortably inside a 174..714 viewport
window:_scrollSelectedTabIntoView(false)
eq(strip.CanvasPosition.X, 0, "T7 an already-visible pill does not scroll")

window.selectedTab = c
emulate(c, 760, 100) -- would ask to scroll past maxScroll
strip.CanvasPosition = Vector2.new(0, 0)
window:_scrollSelectedTabIntoView(false)
eq(strip.CanvasPosition.X, maxScroll, "T7 scroll target clamps to the canvas maximum")

window:Unload()
print("TOPBAR STRIP: all assertions passed")
