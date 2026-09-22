--[[
===== input field assertions: the field wears the element corner =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

Expected behavior under test:
  * F1 the input's field box rounds with the theme's ElementCornerRadius —
       the same token the card it sits in, the Text card, the profile
       containers and every other element surface read — instead of a
       capsule (UDim.new(1, 0)) of its own,
  * F2 that roundness is a theme binding, so a theme switch re-states the
       field's corner exactly like the card's own corner,
  * F3 the field and its card therefore always share one corner family.
]]

local function expect(cond, message)
	if not cond then
		error("INPUT FIELD FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"INPUT FIELD FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local window = Astra:CreateWindow({ name = "Input Field Test" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
local input = tab:CreateInput({ name = "Display name", placeholder = "Enter a name" })
TestPump(0.3)

local function cornerOf(frame)
	for _, child in frame:GetChildren() do
		if child.ClassName == "UICorner" then
			return child
		end
	end
	return nil
end

-- ===== F1: the field box wears the element corner radius ===================

local corner = cornerOf(input.box)
expect(corner ~= nil, "F1 the field box carries a corner")
eq(corner.CornerRadius.Scale, 0, "F1 the field corner is a pixel radius, not a capsule scale")
eq(
	tostring(corner.CornerRadius.Offset),
	tostring(window.theme.ElementCornerRadius.Offset),
	"F1 the field wears the element corner radius"
)

-- ===== F2: the corner is a theme binding, not a baked number ===============

window:ChangeTheme({ ElementCornerRadius = UDim.new(0, 4) })
TestPump(0.3)
eq(
	tostring(corner.CornerRadius.Offset),
	tostring(window.theme.ElementCornerRadius.Offset),
	"F2 a theme switch re-states the field corner"
)
eq(corner.CornerRadius.Offset, 4, "F2 ... to the overlay's element radius")
window:ChangeTheme("default")
TestPump(0.3)
eq(
	tostring(corner.CornerRadius.Offset),
	tostring(window.theme.ElementCornerRadius.Offset),
	"F2 ... and switching back restores it"
)

-- ===== F3: field and card share one corner family ==========================

local cardCorner = cornerOf(input.main)
expect(cardCorner ~= nil, "F3 the card carries its own corner")
eq(
	tostring(cardCorner.CornerRadius.Offset),
	tostring(corner.CornerRadius.Offset),
	"F3 field and card round with the same token"
)

window:Unload()
TestPump(0.2)

print("INPUT FIELD: all assertions passed")
