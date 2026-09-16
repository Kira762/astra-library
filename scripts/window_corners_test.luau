-- Corner integrity: nothing in the window's tree may draw a GuiObject border.
--
-- Roblox gives every GuiObject a 1px border by default (BorderSizePixel = 1).
-- The border draws the rectangular outline of the frame -- straight lines
-- that do not follow UICorner arcs -- so on any rounded surface it reads as
-- straight lines drawn over the rounded corners. The window's own frame was
-- the last surface shipping with that default: once its background faded in,
-- a hard 1px outline crossed all four rounded corners. These assertions pin
-- the whole tree to borderless surfaces.
--
--   C1 the window's main frame explicitly opts out of the border,
--   C2 after a full exercise (first show, elements, toast, settings mode,
--      profile card, dropdown, popup, collapse and restore) no visible
--      surface anywhere in the ScreenGui carries a non-zero border,
--   C3 the window's corner radius is the theme's CornerRoundness (the
--      "original rounded corners" the border used to cross).

local function expect(cond, message)
	if not cond then
		error("CORNER FAIL: " .. tostring(message), 0)
	end
end

local PAINTABLE = {
	Frame = true,
	ScrollingFrame = true,
	ImageLabel = true,
	ImageButton = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
}

local window = Astra:CreateWindow({
	name = "Corner integrity",
	configuration = { autoSave = false, autoLoad = false },
})
local tab = window:CreateTab({ name = "Home" })
TestPump(0.2)
window:Show()
TestPump(1.0)

-- C1: the shell itself is borderless.
expect(window.main.BorderSizePixel == 0, "C1 the window's main frame carries BorderSizePixel = 0")

-- Exercise every lazily-built surface so the audit below sees them.
tab:CreateDropdown({ name = "Options", options = { "One", "Two", "Three" } })
tab:CreateInput({ name = "Field", value = "value" })
tab:CreateButton({ name = "Button", callback = function() end })
TestPump(0.8)

window:Toast({ title = "Corner audit", subtitle = "toast body" })
TestPump(0.8)

for _, element in tab.elements do
	if element.__type == "Dropdown" then
		pcall(function() element:_open() end)
	end
end
TestPump(0.8)

pcall(function()
	window:Popup({
		title = "Corner audit",
		content = "Popup body",
		options = { { text = "OK" } },
	})
end)
TestPump(0.8)

local profileToggle = FindSettingsElement(window, "Appearance", "Show profile")
if profileToggle then
	profileToggle:Set(true)
	TestPump(0.8)
end

pcall(function() window:ToggleHide() end)
TestPump(1.0)
pcall(function() window:ToggleHide() end)
TestPump(1.0)

-- C2: no visible, painting surface anywhere carries a border.
local offenders = 0
for _, inst in window.screenGui:GetDescendants() do
	if PAINTABLE[inst.__props.ClassName] then
		local paintsBackground = (inst.BackgroundTransparency or 1) < 1
		local paintsImage = ((inst.ImageTransparency or 1) < 1) and ((inst.Image or "") ~= "")
		if (paintsBackground or paintsImage) and (inst.BorderSizePixel or 0) ~= 0 then
			offenders += 1
			print(
				"C2 offender: "
					.. tostring(inst.__props.ClassName)
					.. "/"
					.. tostring(inst.__props.Name)
					.. " bgT="
					.. tostring(inst.BackgroundTransparency)
			)
		end
	end
end
expect(offenders == 0, "C2 every visible surface is borderless (" .. tostring(offenders) .. " offenders)")

-- C3: the window rounds with the theme's CornerRoundness, not a default.
local radius = window.windowCorner.CornerRadius
expect(radius.Offset == window.theme.CornerRoundness.Offset, "C3 the window's corner radius follows CornerRoundness")

print("CORNER: all assertions passed")
