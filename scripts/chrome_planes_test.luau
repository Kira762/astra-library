-- ===== Chrome plane assertions =====
-- The window's chrome is three painted planes: the topbar band (darkest), the
-- tab rail, and the elements pane (lightest). They are flat surfaces that
-- meet edge to edge, so a region's colour is the colour of the band it sits
-- on wherever it sits on the screen, instead of one WindowColor gradient
-- showing through thin overlays.
--
--   P1  one flat plane per region, darkest at the top, with the three
--       regions meeting edge to edge (no gutter between the rail and the
--       pane, or between the topbar and either),
--   P2  the planes are flat and opaque: no gradient over the topbar band or
--       the elements pane, and the bottom fade dissolves rows into the pane
--       colour it sits on rather than into a different shade,
--   P3  each band owns the window-silhouette corner its edge touches and
--       none of the corners it shares with another band — including under a
--       theme that actually rounds (CornerRoundness 20), where a square
--       corner behind the rounded silhouette would show,
--   P4  the bands fold with the shell: nothing solid is left standing where
--       the window shrank into its capsule, and every band is back when the
--       window is.

local function expect(cond, message)
	if not cond then
		error("CHROME FAIL: " .. tostring(message), 0)
	end
end

local function rgb(color)
	return string.format(
		"%d,%d,%d",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function luminance(color)
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function cornerRadius(corner, key)
	local value = corner and corner[key]
	if type(value) == "table" then
		return value.Offset
	end
	return nil
end

local window = Astra:CreateWindow({
	name = "Chrome planes",
	configuration = { autoSave = false, autoLoad = false },
})
local tab = window:CreateTab({ name = "Home", icon = "house" })
tab:CreateButton({ name = "One", callback = function() end })
TestPump(0.8)
window:Show()
TestPump(1.2)

local railCorner = window.sidebar:FindFirstChild("UICorner")

-- ===== P1: three planes, one per region, darkest at the top =====

local topbarColor = window.topbar.BackgroundColor3
local railColor = window.sidebar.BackgroundColor3
local paneColor = window.elements.BackgroundColor3

expect(
	rgb(topbarColor) == rgb(window.theme.TopbarSurface),
	"P1 the topbar band is painted TopbarSurface (" .. rgb(topbarColor) .. ")"
)
expect(
	rgb(railColor) == rgb(window.theme.SidebarSurface),
	"P1 the rail band is painted SidebarSurface (" .. rgb(railColor) .. ")"
)
expect(
	rgb(paneColor) == rgb(window.theme.WindowSurface),
	"P1 the elements pane is painted WindowSurface (" .. rgb(paneColor) .. ")"
)
expect(
	luminance(topbarColor) < luminance(railColor) and luminance(railColor) < luminance(paneColor),
	"P1 the planes step darkest at the top ("
		.. rgb(topbarColor) .. " < " .. rgb(railColor) .. " < " .. rgb(paneColor) .. ")"
)
expect(
	luminance(paneColor) - luminance(topbarColor) > 0.04,
	"P1 the topbar is a clear step darker than the pane"
)

-- The card surface stays a shade above the pane it sits on, or the elements
-- area would read as one flat plane with holes in it.
local elementFill = window.theme.ElementGradient.Keypoints[1].Value
local elementFillEnd = window.theme.ElementGradient.Keypoints[#window.theme.ElementGradient.Keypoints].Value
expect(
	luminance(elementFill) > luminance(paneColor)
		and luminance(elementFillEnd) > luminance(paneColor),
	"P1 the element cards stay above the pane (" .. rgb(elementFill) .. " / " .. rgb(elementFillEnd) .. ")"
)

-- Edge to edge: the pane begins exactly where the topbar band ends and exactly
-- where the rail band ends, so neither boundary is a gutter.
-- The pane is inset from the bottom-right corner by exactly the bands' own
-- extents: its top edge is the topbar band's bottom edge, and its left edge is
-- the rail band's right edge. Neither boundary is a gutter.
expect(
	-window.elements.Size.Y.Offset == window.topbar.Size.Y.Offset,
	"P1 the pane's top edge is the topbar band's bottom edge ("
		.. tostring(-window.elements.Size.Y.Offset) .. " vs " .. tostring(window.topbar.Size.Y.Offset) .. ")"
)
expect(
	-window.elements.Size.X.Offset == window.sidebar.Size.X.Offset,
	"P1 the pane's left edge is the rail band's right edge ("
		.. tostring(-window.elements.Size.X.Offset) .. " vs " .. tostring(window.sidebar.Size.X.Offset) .. ")"
)
expect(
	window.topbar.Size.X.Scale == 1 and window.topbar.Size.X.Offset == 0,
	"P1 the topbar band spans the window's full width"
)
local paneAnchor, panePosition = window.elements.AnchorPoint, window.elements.Position
expect(
	paneAnchor.X == 1 and paneAnchor.Y == 1 and panePosition.X.Scale == 1 and panePosition.Y.Scale == 1,
	"P1 the pane is anchored into the window's bottom-right corner"
)
local railAnchor = window.sidebar.AnchorPoint
expect(
	railAnchor.X == 0 and railAnchor.Y == 1 and window.sidebar.Position.Y.Scale == 1,
	"P1 the rail band is anchored to the window's bottom edge"
)

-- ===== P2: flat planes, and a fade in the plane's own colour =====

expect(
	window.elements:FindFirstChild("UIGradient") == nil,
	"P2 the elements pane is a flat fill, not a gradient over the window surface"
)
expect(window.topbar:FindFirstChild("UIGradient") == nil, "P2 the topbar band is a flat fill")

expect(window.topbar.BackgroundTransparency == 0, "P2 the topbar band is opaque once the window is shown")
expect(window.sidebar.BackgroundTransparency == 0, "P2 the rail band is opaque once the window is shown")
expect(window.elements.BackgroundTransparency == 0, "P2 the elements pane is opaque once the window is shown")

expect(
	rgb(window.bottomFade.BackgroundColor3) == rgb(paneColor),
	"P2 the bottom fade is painted the pane's own colour ("
		.. rgb(window.bottomFade.BackgroundColor3) .. ")"
)
local fadeGradient = window.bottomFade:FindFirstChild("UIGradient")
expect(
	fadeGradient ~= nil and fadeGradient.__props.Color == nil,
	"P2 the bottom fade only ramps opacity (no colour override)"
)

-- The pane's edge stroke is what draws the seam against the rail band, and it
-- has to follow the pane's arc rather than cutting a square corner across it.
expect(
	window.elementsStroke ~= nil
		and window.elementsStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border,
	"P2 the pane's edge stroke follows the pane's corners (Border mode)"
)

-- ===== P3: silhouette corners =====

local roundness = window.theme.CornerRoundness.Offset
expect(
	cornerRadius(window.topbarCorner, "TopLeftRadius") == roundness
		and cornerRadius(window.topbarCorner, "TopRightRadius") == roundness,
	"P3 the topbar band owns the window's top corner arcs"
)
expect(
	cornerRadius(window.topbarCorner, "BottomLeftRadius") == 0
		and cornerRadius(window.topbarCorner, "BottomRightRadius") == 0,
	"P3 the topbar band keeps the corners it shares with the bands below it square"
)
expect(
	cornerRadius(railCorner, "BottomLeftRadius") == roundness,
	"P3 the rail band owns the window's bottom-left arc"
)
expect(
	cornerRadius(railCorner, "TopLeftRadius") == 0 and cornerRadius(railCorner, "TopRightRadius") == 0,
	"P3 the rail band keeps its top corners square (the topbar band is above it)"
)
expect(
	cornerRadius(window.elementsCorner, "BottomRightRadius") == roundness,
	"P3 the pane owns the window's bottom-right arc"
)
expect(
	cornerRadius(window.elementsCorner, "TopLeftRadius") == 0
		and cornerRadius(window.elementsCorner, "BottomLeftRadius") == 0,
	"P3 the pane keeps the corners it shares with the chrome square"
)
expect(
	cornerRadius(window.bottomFadeCorner, "BottomRightRadius") == roundness,
	"P3 the bottom fade carries the pane's bottom-right arc"
)

-- The same has to hold when the theme really rounds: a band that reached an
-- edge without the arc would put a square corner behind the silhouette.
window:ChangeTheme({ CornerRoundness = UDim.new(0, 20) })
TestPump(0.6)
expect(
	cornerRadius(window.topbarCorner, "TopLeftRadius") == 20
		and cornerRadius(window.topbarCorner, "TopRightRadius") == 20,
	"P3 a rounded theme rounds the topbar band's top corners"
)
expect(
	cornerRadius(railCorner, "BottomLeftRadius") == 20,
	"P3 a rounded theme rounds the rail band's bottom-left corner"
)
expect(
	cornerRadius(window.elementsCorner, "BottomRightRadius") == 20
		and cornerRadius(window.elementsCorner, "TopLeftRadius") == 0,
	"P3 a rounded theme rounds the pane's bottom-right corner only"
)
window:ChangeTheme("default")
TestPump(0.6)

-- ===== P4: the bands fold with the shell =====

window:ToggleHide()
TestPump(1.5)
expect(window.hidden == true, "P4 the window folded into its capsule")
for _, band in { { "topbar", window.topbar }, { "rail", window.sidebar }, { "pane", window.elements }, { "fade", window.bottomFade } } do
	expect(
		band[2].BackgroundTransparency == 1,
		"P4 the " .. band[1] .. " band is not painted over the capsule ("
			.. tostring(band[2].BackgroundTransparency) .. ")"
	)
end

window:ToggleHide()
TestPump(1.5)
for _, band in { { "topbar", window.topbar }, { "rail", window.sidebar }, { "pane", window.elements }, { "fade", window.bottomFade } } do
	expect(
		band[2].BackgroundTransparency == 0,
		"P4 the " .. band[1] .. " band is painted again on restore ("
			.. tostring(band[2].BackgroundTransparency) .. ")"
	)
end

-- ===== P5: a layout switch keeps the planes and rebuilds only the rail =====

local paneCornerObject = window.elementsCorner
local paneStroke = window.elementsStroke
expect(window:_setLayoutMode("collapsedSidebar") == true, "P5 the window switched to the collapsed rail")
TestPump(1.2)

expect(
	window.sidebar ~= nil and window.sidebar.Size.X.Offset == window.layout.railCollapsedWidth,
	"P5 the rebuilt rail band is the collapsed width"
)
expect(
	-window.elements.Size.X.Offset == window.sidebar.Size.X.Offset,
	"P5 the pane still starts where the rebuilt rail band ends"
)
expect(
	window.elementsCorner == paneCornerObject and window.elementsStroke == paneStroke,
	"P5 the switch reuses the pane's corner and stroke instead of rebuilding them"
)
expect(
	rgb(window.sidebar.BackgroundColor3) == rgb(window.theme.SidebarSurface),
	"P5 the rebuilt rail band is painted SidebarSurface"
)
local collapsedRailCorner = window.sidebar:FindFirstChild("UICorner")
expect(
	cornerRadius(collapsedRailCorner, "BottomLeftRadius") == roundness,
	"P5 the rebuilt rail band carries the bottom-left arc"
)
expect(window:_setLayoutMode("sidebar") == true, "P5 the window switched back to the expanded rail")
TestPump(1.2)
expect(
	-window.elements.Size.X.Offset == window.sidebar.Size.X.Offset,
	"P5 the expanded rail band and the pane meet again"
)

-- The rebuilt band is a themed surface like the one the shell opened: a later
-- theme change still lands on it.
window:ChangeTheme({ CornerRoundness = UDim.new(0, 20) })
TestPump(0.6)
local rebuiltRailCorner = window.sidebar:FindFirstChild("UICorner")
expect(
	cornerRadius(rebuiltRailCorner, "BottomLeftRadius") == 20
		and cornerRadius(rebuiltRailCorner, "TopLeftRadius") == 0,
	"P5 the rebuilt rail band follows a later theme change"
)
window:ChangeTheme("default")
TestPump(0.6)

print("CHROME: all assertions passed")
