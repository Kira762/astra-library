--[[
===== stepper value assertions: stepping, clamping, typed commits =========
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

The Stepper is the [−] [value] [+] counter: three controls in one
horizontal cluster around the focal value field. Behaviour under test:

  * S1 the default state: the value starts at 0 and the display shows it,
  * S2 a (+) tap adds step and the display + callback follow at once,
  * S3 a (−) tap never takes the value below min (default 0) — a tap at
       the floor is a deliberate no-op and fires no callback,
  * S4 max caps taps and Set alike when specified, and without max the
       control has no upper limit,
  * S5 typed commits round/clamp into range and unparseable text
       restores the previous value,
  * S6 the callback fires only on real changes,
  * S7 layout: minus, field and plus share one horizontal cluster and
       the value field wears the larger text (the focal point).
]]

local function expect(cond, message)
	if not cond then
		error("STEPPER VALUE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"STEPPER VALUE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Stepper Value Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })

local fired = {}
local stepper = tab:CreateStepper({
	name = "Value Configuration",
	flag = "value",
	value = 0,
	min = 0,
	max = 5,
	step = 1,
	callback = function(v)
		table.insert(fired, v)
	end,
})
TestPump(0.4)

-- ===== S1: default state =================================================

expect(stepper ~= nil, "S1 CreateStepper returned an element")
eq(stepper.value, 0, "S1 the value starts at 0")
eq(stepper.input.Text, "0", "S1 the display shows 0")

-- ===== S2: (+) steps up, display and callback follow ======================

stepper.plusButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(stepper.value, 1, "S2 one (+) tap adds one step")
eq(stepper.input.Text, "1", "S2 the display updates after the click")
eq(fired[#fired], 1, "S2 the callback received the new value")

stepper.plusButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(stepper.value, 2, "S2 a second (+) tap keeps counting")
eq(stepper.input.Text, "2", "S2 the display keeps following")

-- ===== S3: (−) clamps at the floor (0), silently ==========================

stepper.minusButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(stepper.value, 1, "S3 one (−) tap subtracts one step")

local beforeFloor = #fired
for _ = 1, 5 do
	stepper.minusButton.MouseButton1Click:Fire()
end
TestPump(0.2)
eq(stepper.value, 0, "S3 the value never goes below 0")
eq(stepper.input.Text, "0", "S3 the display shows the floor")
eq(#fired, beforeFloor + 1, "S3 a (−) tap at the floor fires no extra callback")
eq(fired[#fired], 0, "S3 the floor value itself was reported once")

-- ===== S4: max caps taps and Set; no max means no ceiling =================

stepper:Set(5)
TestPump(0.2)
eq(stepper.value, 5, "S4 Set clamps into the ceiling")

local beforeCap = #fired
stepper.plusButton.MouseButton1Click:Fire()
stepper.plusButton.MouseButton1Click:Fire()
TestPump(0.2)
eq(stepper.value, 5, "S4 a (+) tap at max is a no-op")
eq(#fired, beforeCap, "S4 ceiling no-ops fire no callback")

stepper:Set(99)
TestPump(0.2)
eq(stepper.value, 5, "S4 Set clamps to max")
stepper:Set(-10)
TestPump(0.2)
eq(stepper.value, 0, "S4 Set clamps to min")

local open = tab:CreateStepper({ name = "Open", value = 0, step = 2 })
TestPump(0.3)
open:Set(1000)
eq(open.value, 1000, "S4 without max there is no upper limit")
open:Increment()
eq(open.value, 1002, "S4 Increment adds step even far above 0")
open:Decrement()
open:Decrement()
eq(open.value, 998, "S4 Decrement subtracts step")

-- ===== S5: typed commits round/clamp; junk restores ======================

stepper.input.Text = "3"
stepper.input.FocusLost:Fire(false)
TestPump(0.2)
eq(stepper.value, 3, "S5 a typed number commits")
eq(stepper.input.Text, "3", "S5 the display shows the typed value")

stepper.input.Text = "9"
stepper.input.FocusLost:Fire(false)
TestPump(0.2)
eq(stepper.value, 5, "S5 a typed over-cap clamps into range")
eq(stepper.input.Text, "5", "S5 the display shows the clamped value")

stepper.input.Text = "abc"
TestPump(0.1)
stepper.input.FocusLost:Fire(false)
TestPump(0.2)
eq(stepper.value, 5, "S5 unparseable text never lands")
eq(stepper.input.Text, "5", "S5 unparseable text restores the display")

-- ===== S6: the callback fires only on real changes ========================

local countBefore = #fired
stepper:Set(5) -- already 5
stepper:Decrement() -- 5 -> 4, fires
stepper:Set(4) -- already 4
stepper:Increment() -- 4 -> 5, fires
TestPump(0.3)
eq(#fired, countBefore + 2, "S6 only the two real changes fired")

-- ===== S7: the three controls share one horizontal cluster =================

eq(stepper.minusButton.Parent, stepper.cluster, "S7 minus sits in the cluster")
eq(stepper.box.Parent, stepper.cluster, "S7 the value field sits in the cluster")
eq(stepper.plusButton.Parent, stepper.cluster, "S7 plus sits in the cluster")

local layout
for _, child in stepper.cluster:GetChildren() do
	if child:IsA("UIListLayout") then
		layout = child
		break
	end
end
expect(layout ~= nil, "S7 the cluster has a list layout")
eq(layout.FillDirection, Enum.FillDirection.Horizontal, "S7 the three controls align horizontally")

expect(stepper.input.TextSize > stepper.title.TextSize, "S7 the value field is the focal point (larger text)")

local minusGlyph, plusGlyph = false, false
for _, child in stepper.minusButton:GetChildren() do
	if child:IsA("ImageLabel") then
		minusGlyph = true
	end
end
for _, child in stepper.plusButton:GetChildren() do
	if child:IsA("ImageLabel") then
		plusGlyph = true
	end
end
expect(minusGlyph, "S7 the minus control is icon-style (glyph, not a text label)")
expect(plusGlyph, "S7 the plus control is icon-style (glyph, not a text label)")
