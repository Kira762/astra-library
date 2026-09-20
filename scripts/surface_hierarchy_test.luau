-- [[Surface hierarchy & flush spacing: the three sections of the window
-- [[(topbar, tab rail, elements area) must each carry their own theme
-- [[surface, ordered darkest → lightest from chrome to content, sit flush
-- [[against each other (no card notch, no gaps), and the selected tab row
-- [[must be painted with the same token as the elements area so it visually
-- [[connects to the page it opens.
--
--   S1 the three frames are painted with their theme tokens
--   S2 the hierarchy holds in every built-in theme: topbar < rail < elements,
--      with steps large enough to read (not near-miss shades)
--   S3 the sections are opaque while shown and geometrically flush
--      (the old floating-card notch at the elements' top-left is gone)
--   S4 the selected row is the elements-area colour, opaque; the unselected
--      row falls back to the rail's own shade; no gradient tints the row
--   S5 the capsule state folds the topbar surface away (the 64px band would
--      overshoot the 50px capsule) and restore brings it back; the minimised
--      bar keeps it (the bar IS the topbar)
--   S6 the bottom fade blends into the elements surface, not the window base

local function expect(cond, message)
	if not cond then
		error("SURFACE HIERARCHY FAIL: " .. tostring(message), 0)
	end
end

-- [[0-255 luminance (Color3 components are normalised floats).]]
local function lum(color)
	return (0.299 * color.R + 0.587 * color.G + 0.114 * color.B) * 255
end

local function findChild(instance, className)
	for _, child in instance:GetChildren() do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

local window = Astra:CreateWindow({
	name = "Surface hierarchy",
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.8)
window:Show()
TestPump(1.0)

-- ===== S1: each section carries its own theme surface =====
expect(window.topbar.BackgroundColor3 == window.theme.TopbarSurface, "the topbar band is painted TopbarSurface")
expect(window.sidebar.BackgroundColor3 == window.theme.SidebarSurface, "the tab rail is painted SidebarSurface")
expect(window.elements.BackgroundColor3 == window.theme.ElementSurface, "the elements area is painted ElementSurface")

-- ===== S2: darkest → lightest from chrome to content =====
local t = lum(window.theme.TopbarSurface)
local s = lum(window.theme.SidebarSurface)
local e = lum(window.theme.ElementSurface)
expect(t < s, "the topbar is darker than the tab rail")
expect(s < e, "the tab rail is darker than the elements area")
expect(s - t > 3 and e - s > 3, "the steps are visible, not near-miss shades")

-- ===== S3: opaque while shown, flush against each other =====
expect(window.topbar.BackgroundTransparency == 0, "the topbar band is opaque while shown")
expect(window.sidebar.BackgroundTransparency == 0, "the tab rail is opaque while shown")
expect(window.elements.BackgroundTransparency == 0, "the elements area is opaque while shown")

-- no vertical gap between the topbar and the two lower bands (both offsets
-- are relative to the window's height, so they must sum to zero)
expect(window.elements.Size.Y.Offset + window.topbar.Size.Y.Offset == 0, "the elements band starts exactly where the topbar ends")
-- no horizontal gap between the rail and the elements band
expect(window.sidebar.Size.X.Offset + window.elements.Size.X.Offset == 0, "the elements band starts exactly where the rail ends")

-- the elements area is a band, not a floating card: its top edge is square
local elementsCorner = findChild(window.elements, "UICorner")
expect(elementsCorner ~= nil, "the elements area carries a UICorner")
expect(elementsCorner.TopLeftRadius.Offset == 0, "the elements top-left edge is square (the old card notch is gone)")
expect(elementsCorner.TopRightRadius.Offset == 0, "the elements top edge is square (flush against the topbar)")

-- the topbar mirrors the window's top silhouette corners
local topbarCorner = findChild(window.topbar, "UICorner")
expect(topbarCorner ~= nil, "the topbar band carries a UICorner")
local roundness = window.theme.CornerRoundness
expect(topbarCorner.TopLeftRadius.Offset == roundness.Offset, "the topbar's top-left corner mirrors the window corner")
expect(topbarCorner.TopRightRadius.Offset == roundness.Offset, "the topbar's top-right corner mirrors the window corner")

-- the rail mirrors the window's bottom-left silhouette corner
local railCorner = findChild(window.sidebar, "UICorner")
expect(railCorner ~= nil, "the tab rail carries a UICorner")
expect(railCorner.BottomLeftRadius.Offset == roundness.Offset, "the rail's bottom-left corner mirrors the window corner")

-- ===== S4: the selected row IS the elements-area colour =====
local tabA = window:CreateTab({ name = "Alpha" })
local tabB = window:CreateTab({ name = "Beta" })
tabB:Select()
TestPump(0.5)

local rowA, rowB = tabA.topbarItem, tabB.topbarItem
expect(rowB.BackgroundColor3 == window.theme.ElementSurface, "the selected row is painted with the elements-area colour")
expect(rowB.BackgroundTransparency == 0, "the selected row is opaque (it continues the content band)")
expect(rowA.BackgroundTransparency == 1, "the unselected row falls back to the rail's own shade")
expect(tabA.topbarItemStroke.Transparency == 0.8, "unselected row keeps its outline")
expect(tabB.topbarItemStroke.Transparency == 0.5, "selected row keeps its existing outline")
expect(tabB.topbarItemShadow.Transparency == 0.8, "selected highlight shadow is unchanged")
tabA.topbarItemInteract.MouseEnter:Fire()
TestPump(0.3)
expect(rowA.BackgroundTransparency == 1, "hover cannot highlight an unselected row")
expect(tabA.topbarItemStroke.Transparency < 1, "hover keeps the outline")
expect(tabA.topbarItemShadow.Transparency == 1, "unselected hover has no shadow highlight")
tabA.topbarItemInteract.MouseLeave:Fire()
tabA:Select()
TestPump(0.3)
expect(rowA.BackgroundTransparency == 0, "new selection gains its highlight")
expect(rowB.BackgroundTransparency == 1, "old selection loses its highlight")
expect(tabB.topbarItemStroke.Transparency == 0.8, "old selection keeps its outline")
tabB:Select()
TestPump(0.3)
expect(findChild(rowB, "UIGradient") == nil, "no background gradient tints the row off the content colour")

-- ===== S5: the theme switch keeps every section and the row in step =====
local builtinThemes = { "default", "amethyst", "cobalt", "crimson", "ember", "emerald", "frost", "gold", "onyx", "rose" }
for _, name in builtinThemes do
	window:ChangeTheme(name)
	TestPump(0.6)
	expect(window.topbar.BackgroundColor3 == window.theme.TopbarSurface, name .. ": the topbar follows the theme")
	expect(window.sidebar.BackgroundColor3 == window.theme.SidebarSurface, name .. ": the rail follows the theme")
	expect(window.elements.BackgroundColor3 == window.theme.ElementSurface, name .. ": the elements follow the theme")
	expect(rowB.BackgroundColor3 == window.theme.ElementSurface, name .. ": the selected row follows the theme")
	local th, rs, el = lum(window.theme.TopbarSurface), lum(window.theme.SidebarSurface), lum(window.theme.ElementSurface)
	expect(th < rs and rs < el, name .. ": the hierarchy holds (topbar < rail < elements)")
	expect(rs - th > 3 and el - rs > 3, name .. ": the steps are visible, not near-miss shades")
end

-- ===== S6: capsule folds the topbar surface away; the minimised bar keeps it =====
window:Hide()
TestPump(1.2)
expect(window.topbar.BackgroundTransparency == 1, "capsule state: the topbar surface folds away (the 64px band would overshoot the capsule)")
expect(window.sidebar.Visible == false, "capsule state: the rail is hidden")
expect(window.elements.Visible == false, "capsule state: the elements area is hidden")

window:Show()
TestPump(1.2)
expect(window.topbar.BackgroundTransparency == 0, "the restore brings the topbar surface back")
expect(window.sidebar.BackgroundTransparency == 0, "the restore brings the rail surface back")

window:ToggleMinimise()
TestPump(1.2)
expect(window.minimised == true, "the minimise move ran")
expect(window.topbar.BackgroundTransparency == 0, "the minimised bar keeps the topbar surface (the bar IS the topbar)")

window:ToggleMinimise()
TestPump(1.2)
expect(window.minimised == false, "the restore from the bar ran")
expect(window.topbar.BackgroundTransparency == 0, "the restore from the bar keeps the topbar surface")

-- ===== S7: the bottom fade blends into the elements surface =====
local bottomFadeGradient = findChild(window.bottomFade, "UIGradient")
expect(bottomFadeGradient ~= nil, "the bottom fade carries a gradient")
expect(bottomFadeGradient.Color.Keypoints[1].Value == window.theme.ElementSurface, "the bottom fade blends into the elements surface, not the window base")

print("SURFACE HIERARCHY TEST PASSED")
