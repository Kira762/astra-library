--[[
===== row-Group sliders keep their responsive layout ======================
Runs the real Astra bundle against the mini Roblox environment. Row Groups
shrink sliders after each control is built, and this can happen while the
window is animating. The slider must still switch to its narrow card layout
so the name/value row and the track do not overlap.
]]

local function expect(cond, message)
	if not cond then
		error("SLIDER GROUP LAYOUT FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"SLIDER GROUP LAYOUT FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Slider Group Layout Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
TestPump(0.3)

-- A realistic row: each slider is first built against the wide parent, then
-- the Group's flex layout gives it a narrower card. Keep the window in its
-- transition state while dispatching the size changes to cover the regression.
window.animating = true
local levels = tab:CreateGroup({ direction = "row" })
levels.main.Size = UDim2.fromOffset(600, 0)
local sliders = {
	levels:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 60, suffix = "%" }),
	levels:CreateSlider({ name = "Bass", range = { 0, 100 }, value = 40, suffix = "%" }),
}

for _, slider in sliders do
	eq(slider._layoutMode, "wide", slider.name .. " starts with the wide parent layout")

	-- Simulate the row flex layout's final child width and fire the derived
	-- AbsoluteSize signal (the stub does not calculate UIListLayout flex).
	slider.main.Size = UDim2.fromOffset(270, 70)
	slider.main:GetPropertyChangedSignal("AbsoluteSize"):Fire()

	eq(slider._layoutMode, "narrow", slider.name .. " switches layout while the window animates")
	eq(slider.main.Size.Y.Offset, 70, slider.name .. " has room for its title row and track")
	eq(slider.container.Position.X.Offset, 20, slider.name .. " keeps the label inset")
	eq(slider.container.Position.Y.Offset, 14, slider.name .. " moves the label to the top row")
	eq(slider.containerLayout.FillDirection, Enum.FillDirection.Horizontal, slider.name .. " places name and value on one line")
	eq(slider.track.Position.X.Scale, 0.5, slider.name .. " centers the track across its card")
	eq(slider.track.Position.Y.Scale, 1, slider.name .. " moves the track below the label")
	eq(slider.track.Position.Y.Offset, -14, slider.name .. " keeps the track inset from the card bottom")
	eq(slider.track.Size.X.Scale, 1, slider.name .. " lets the track fill the compact card")
	eq(slider.track.Size.X.Offset, -30, slider.name .. " preserves horizontal track insets")
end

-- The other suppressed case was a hidden window that had already been shown:
-- viewport changes there must also be picked up before the next reveal.
window.animating = false
window.hidden = true
window.hasShownOnce = true
local resized = sliders[1]
resized.main.Size = UDim2.fromOffset(320, 65)
resized.main:GetPropertyChangedSignal("AbsoluteSize"):Fire()
eq(resized._layoutMode, "wide", "a hidden, previously shown window still updates at the wide breakpoint")
eq(resized.track.Size.X.Offset, 222, "the wide track returns to its fixed width while hidden")

window.hidden = false
window.hasShownOnce = false
window:Unload()
TestPump(0.2)

print("SLIDER GROUP LAYOUT: all assertions passed")
