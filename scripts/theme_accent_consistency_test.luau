--[[
===== active control colors share the theme accent =======================
Runs the real Astra bundle against the mini Roblox environment. A partial
AccentColor override must recolor toggles, slider progress and Stat accents
as one system; explicit AccentStroke/SliderProgress overrides remain valid.
]]

local function expect(cond, message)
	if not cond then
		error("THEME ACCENT CONSISTENCY FAIL: " .. tostring(message), 0)
	end
end

local function colorEq(actual, wanted, message)
	expect(
		actual ~= nil and wanted ~= nil
			and math.abs(actual.R - wanted.R) < 1e-6
			and math.abs(actual.G - wanted.G) < 1e-6
			and math.abs(actual.B - wanted.B) < 1e-6,
		message
	)
end

local function firstColor(sequence)
	return sequence.Keypoints[1].Value
end

local function childOfClass(parent, className)
	for _, child in parent:GetChildren() do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

local window = Astra:CreateWindow({ name = "Theme Accent Consistency Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
local toggle = tab:CreateToggle({ name = "Enabled", value = true })
local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 60 })
local stat = tab:CreateStat({ name = "Score", value = 10 })
local negativeStat = tab:CreateStat({ name = "Loss", value = 10 })
local input = tab:CreateInput({ name = "Name", placeholder = "Type here" })
TestPump(0.6)

local sliderGradient = childOfClass(slider.progress, "UIGradient")
expect(sliderGradient ~= nil, "the slider progress keeps its themed gradient")
colorEq(toggle.indicator.BackgroundColor3, window.theme.AccentColor, "the active toggle uses AccentColor")
colorEq(firstColor(sliderGradient.Color), window.theme.AccentColor, "the slider starts on the same default accent")
colorEq(firstColor(stat.mainGradient.Color), window.theme.AccentColor, "a neutral Stat uses the shared accent")

stat:Set(12)
negativeStat:Set(8)
TestPump(0.2)
colorEq(firstColor(stat.mainGradient.Color), window.theme.AccentColor, "positive Stat accents use the shared active hue")
colorEq(firstColor(negativeStat.mainGradient.Color), window.theme.ErrorColor, "negative Stat accents remain semantic error red")

-- The documented partial theme override recolors the whole active-control
-- family and derives matching stroke/fill colors when those tokens are omitted.
local purple = Color3.fromRGB(120, 90, 220)
window:ChangeTheme({ AccentColor = purple })
TestPump(0.5)
colorEq(window.theme.Accent, purple, "the legacy Accent alias follows AccentColor")
colorEq(window.theme.AccentColor, purple, "the custom AccentColor is preserved")
colorEq(toggle.indicator.BackgroundColor3, purple, "the toggle follows a partial AccentColor override")
colorEq(firstColor(sliderGradient.Color), purple, "the slider follows a partial AccentColor override")
colorEq(firstColor(stat.mainGradient.Color), purple, "positive Stat follows a partial AccentColor override")
colorEq(firstColor(negativeStat.mainGradient.Color), window.theme.ErrorColor, "negative Stat remains an error state after recoloring")
colorEq(window.theme.AccentStroke, purple:Lerp(Color3.new(1, 1, 1), 0.2), "matching AccentStroke is derived")
colorEq(window.theme.SliderProgress.Keypoints[1].Value, purple, "matching SliderProgress is derived")

-- A field's success flash uses the same accent, not a separately hard-coded teal.
window:_flashResult(input, true)
colorEq(input.box.BackgroundColor3, purple, "successful field feedback uses the current AccentColor")

-- Explicit theme tokens still take precedence over automatic derivation.
local gold = Color3.fromRGB(235, 185, 55)
local explicitStroke = Color3.fromRGB(245, 220, 120)
local explicitProgress = ColorSequence.new(gold, Color3.fromRGB(180, 110, 20))
window:ChangeTheme({ AccentColor = gold, AccentStroke = explicitStroke, SliderProgress = explicitProgress })
TestPump(0.5)
colorEq(toggle.indicator.BackgroundColor3, gold, "the toggle follows the second accent")
colorEq(window.theme.AccentStroke, explicitStroke, "an explicit AccentStroke is preserved")
colorEq(firstColor(sliderGradient.Color), gold, "explicit SliderProgress remains on the chosen accent hue")
colorEq(firstColor(stat.mainGradient.Color), gold, "Stat gradients refresh with the theme")

-- The legacy Accent key remains a supported shorthand for the same palette.
local blue = Color3.fromRGB(55, 135, 225)
window:ChangeTheme({ Accent = blue })
TestPump(0.5)
colorEq(window.theme.AccentColor, blue, "the legacy Accent key updates AccentColor")
colorEq(toggle.indicator.BackgroundColor3, blue, "the toggle follows the legacy Accent key")
colorEq(firstColor(sliderGradient.Color), blue, "the slider follows the legacy Accent key")
colorEq(firstColor(stat.mainGradient.Color), blue, "Stats follow the legacy Accent key")

window:Unload()
TestPump(0.3)

-- Partial themes are also resolved at construction, not only by ChangeTheme.
local startupAccent = Color3.fromRGB(180, 95, 205)
local startupWindow = Astra:CreateWindow({
	name = "Initial Theme Accent Test",
	theme = { AccentColor = startupAccent },
})
TestPump(0.6)
local startupTab = startupWindow:CreateTab({ name = "Controls" })
local startupToggle = startupTab:CreateToggle({ name = "Enabled", value = true })
local startupStat = startupTab:CreateStat({ name = "Score", value = 10 })
TestPump(0.5)
colorEq(startupWindow.theme.Accent, startupAccent, "initial theme resolution syncs the Accent alias")
colorEq(startupWindow.theme.AccentStroke, startupAccent:Lerp(Color3.new(1, 1, 1), 0.2), "initial theme resolution derives AccentStroke")
colorEq(startupToggle.indicator.BackgroundColor3, startupAccent, "initial theme applies to toggles")
colorEq(firstColor(startupStat.mainGradient.Color), startupAccent, "initial theme applies to Stats")
startupWindow:Unload()
TestPump(0.3)

print("THEME ACCENT CONSISTENCY: all assertions passed")
