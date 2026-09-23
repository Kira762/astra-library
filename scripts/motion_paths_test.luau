--[[
Motion paths: the window's full choreography runs with animation ON under
the stub's synchronous tweens. The stub plays every tween on the spot and
fires Completed synchronously, so any path that touches an instance after
its own settle callback destroyed it (or that leaves the state machine
half-settled) fails here. Assertions:

  P1 the first show settles: visible, not animating, surface faded in,
  P2 hide folds to the capsule: hidden, collapsed shown, corner on the pill,
  P3 show restores: size back, corner back to CornerRoundness,
  P4 minimise/expand keeps the bar at the topbar height and restores,
  P5 a theme change with animation on does not error and reaches strokes,
  P6 a layout switch (sidebar -> collapsedSidebar -> sidebar) settles back,
  P7 close tears the window down (the destroy-sensitive ordering path).
]]

local function expect(cond, message)
	if not cond then
		error("MOTION PATHS FAIL: " .. tostring(message), 0)
	end
end

local motion = Astra.Motion
motion.setProfile("normal")

local window = Astra:CreateWindow({
	name = "Motion paths",
	configuration = { autoSave = false, autoLoad = false },
})
window:CreateTab({ name = "Home" })
TestPump(0.2)
window:Show()
TestPump(1.2)

-- P1
expect(window.main.Visible == true, "P1 the first show leaves the window visible")
expect(window.animating == false, "P1 the first show settles its animation state")
expect(window.main.BackgroundTransparency == 0, "P1 the window surface is fully faded in")

-- P2
window:Hide()
TestPump(1.0)
expect(window.hidden == true, "P2 hide marks the window hidden")
expect(window.animating == false, "P2 the fold settles")
expect(window._collapsedShown == true, "P2 the capsule is the shown face")
expect(window.windowCorner.CornerRadius.Offset == (window.theme.PillCornerRadius or UDim.new(1, 0)).Offset,
	"P2 the folded window wears the pill corner")

-- P3
window:Show()
TestPump(1.0)
expect(window.hidden == false, "P3 show restores the window")
expect(window.animating == false, "P3 the restore settles")
expect(window.main.Size == window.size, "P3 the window is back at its full size")
expect(window.windowCorner.CornerRadius == window.theme.CornerRoundness,
	"P3 the corner is back on CornerRoundness")

-- P4
window:ToggleMinimise()
TestPump(1.0)
expect(window.minimised == true, "P4 minimise marks the bar")
expect(window.animating == false, "P4 the fold-down settles")
expect(window.main.Size.Y.Offset == window.layout.topbarHeight, "P4 the bar sits at the topbar height")
window:ToggleMinimise()
TestPump(1.0)
expect(window.minimised == false, "P4 expand clears the bar state")
expect(window.main.Size == window.size, "P4 the window is back at full size")

-- P5
local accent = Color3.fromRGB(200, 80, 80)
window:ChangeTheme({ Accent = accent })
TestPump(0.8)
expect(
	window.theme.Accent ~= nil
		and window.theme.Accent.R == accent.R
		and window.theme.Accent.G == accent.G
		and window.theme.Accent.B == accent.B,
	"P5 a custom theme table applies with animation on"
)

-- P6
window:_setLayoutMode("collapsedSidebar")
TestPump(1.0)
expect(window.layout.mode == "sidebar" and window.layout.forceCollapsed, "P6 the collapsedSidebar layout applies")
window:_setLayoutMode("sidebar")
TestPump(1.0)
expect(window.layout.mode == "sidebar" and not window.layout.forceCollapsed, "P6 the sidebar layout applies back")
expect(window.animating == false, "P6 the layout switch settles")

-- P7
window:Close()
TestPump(0.8)
expect(window.unloaded == true, "P7 close tears the window down")

motion.setProfile("normal")
print("MOTION PATHS: all assertions passed")
