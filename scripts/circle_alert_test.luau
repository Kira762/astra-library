-- ===== Circle Alert (!) Descriptions on Functional Elements Test Suite =====

local function expect(cond, message)
	if not cond then
		error("CIRCLE ALERT FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"CIRCLE ALERT FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local window = Astra:CreateWindow({
	title = "Circle Alert Tests",
	size = UDim2.fromOffset(600, 420),
})
TestPump(0.6)

local tab = window:CreateTab({ name = "Controls" })
local compactGroup = tab:CreateGroup()

-- 1. Optional description & empty description checks
local undescribedToggle = tab:CreateToggle({ name = "No Desc Toggle" })
local emptyDescToggle = tab:CreateToggle({ name = "Empty Desc Toggle", description = "" })
local describedToggle = tab:CreateToggle({ name = "Described Toggle", description = "Toggles an awesome feature." })
local legacyInfoToggle = tab:CreateToggle({ name = "Legacy Info Toggle", info = "Supported via info prop too." })

local undescribedButton = tab:CreateButton({ name = "No Desc Button", callback = function() end })
local emptyDescButton = tab:CreateButton({ name = "Empty Desc Button", description = "", callback = function() end })
local describedButton = tab:CreateButton({ name = "Described Button", description = "Executes an action immediately.", callback = function() end })

local undescribedSlider = tab:CreateSlider({ name = "No Desc Slider", range = { 0, 100 }, value = 25 })
local emptyDescSlider = tab:CreateSlider({ name = "Empty Desc Slider", description = "", range = { 0, 100 }, value = 25 })
local describedSlider = tab:CreateSlider({ name = "Described Slider", description = "Controls target value.", range = { 0, 100 }, value = 50 })

local undescribedDropdown = tab:CreateDropdown({ name = "No Desc Dropdown", options = { "A", "B" } })
local emptyDescDropdown = tab:CreateDropdown({ name = "Empty Desc Dropdown", description = "", options = { "A", "B" } })
local describedDropdown = tab:CreateDropdown({ name = "Described Dropdown", description = "Chooses active profile.", options = { "A", "B" } })

local undescribedInput = tab:CreateInput({ name = "No Desc Input" })
local emptyDescInput = tab:CreateInput({ name = "Empty Desc Input", description = "" })
local describedInput = tab:CreateInput({ name = "Described Input", description = "Custom text value." })

local compactToggle = compactGroup:CreateToggle({ name = "Compact Toggle", description = "Compact toggle description." })
local compactButton = compactGroup:CreateButton({ name = "Compact Button", description = "Compact button description.", callback = function() end })

TestPump(0.6)

-- Requirement 1: Empty or omitted description shows NO circle-alert
eq(undescribedToggle.infoButton, nil, "R1 undescribed toggle has no circle alert")
eq(emptyDescToggle.infoButton, nil, "R1 empty desc toggle has no circle alert")
eq(undescribedButton.infoButton, nil, "R1 undescribed button has no circle alert")
eq(emptyDescButton.infoButton, nil, "R1 empty desc button has no circle alert")
eq(undescribedSlider.infoButton, nil, "R1 undescribed slider has no circle alert")
eq(emptyDescSlider.infoButton, nil, "R1 empty desc slider has no circle alert")
eq(undescribedDropdown.infoButton, nil, "R1 undescribed dropdown has no circle alert")
eq(emptyDescDropdown.infoButton, nil, "R1 empty desc dropdown has no circle alert")
eq(undescribedInput.infoButton, nil, "R1 undescribed input has no circle alert")
eq(emptyDescInput.infoButton, nil, "R1 empty desc input has no circle alert")

-- Requirement 2: Non-empty description creates circle-alert
expect(describedToggle.infoButton ~= nil, "R2 described toggle carries circle alert")
expect(legacyInfoToggle.infoButton ~= nil, "R2 legacy info toggle carries circle alert")
expect(describedButton.infoButton ~= nil, "R2 described button carries circle alert")
expect(describedSlider.infoButton ~= nil, "R2 described slider carries circle alert")
expect(describedDropdown.infoButton ~= nil, "R2 described dropdown carries circle alert")
expect(describedInput.infoButton ~= nil, "R2 described input carries circle alert")
expect(compactToggle.infoButton ~= nil, "R2 compact toggle carries circle alert")
expect(compactButton.infoButton ~= nil, "R2 compact button carries circle alert")

-- Requirement 3: Circle alert is right AFTER the element's name not before
local function verifyOrder(element, name)
	local title = element.title
	local infoBtn = element.infoButton
	expect(title ~= nil, name .. " has title")
	expect(infoBtn ~= nil, name .. " has infoButton")
	eq(title.LayoutOrder, 1, name .. " title has LayoutOrder 1")
	eq(infoBtn.LayoutOrder, 2, name .. " infoButton has LayoutOrder 2")
	expect(infoBtn.LayoutOrder > title.LayoutOrder, name .. " circle alert is positioned after element name")

	local parent = infoBtn.Parent
	local layout = nil
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UIListLayout") then
			layout = child
			break
		end
	end
	expect(layout ~= nil, name .. " parent has UIListLayout")
	eq(layout.SortOrder, Enum.SortOrder.LayoutOrder, name .. " layout sorts by LayoutOrder")
end

verifyOrder(describedToggle, "Full Toggle")
verifyOrder(describedButton, "Full Button")
verifyOrder(describedSlider, "Slider")
verifyOrder(describedDropdown, "Dropdown")
verifyOrder(describedInput, "Input")
verifyOrder(compactToggle, "Compact Toggle")
verifyOrder(compactButton, "Compact Button")

-- Requirement 4: Tapping circle-alert shows floating description, tapping again closes it
describedToggle.infoButton.MouseButton1Down:Fire()
describedToggle.infoButton.MouseButton1Click:Fire()
TestPump(0.1)

local tip = window.elementTooltip
local tipLabel = window.elementTooltipLabel
expect(tip ~= nil, "R4 tooltip exists")
eq(tip.Visible, true, "R4 tooltip is visible after tap")
eq(tipLabel.Text, "Toggles an awesome feature.", "R4 tooltip text matches toggle description")

-- Tap again closes it
describedToggle.infoButton.MouseButton1Down:Fire()
describedToggle.infoButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(window._tooltipPinnedAnchor, nil, "R4 tooltip unpinned on second tap")

-- Requirement 5: Holding circle-alert opens up description
describedSlider.infoButton.MouseButton1Down:Fire()
TestPump(0.1)
eq(tip.Visible, true, "R5 holding slider circle alert opens description immediately")
eq(tipLabel.Text, "Controls target value.", "R5 tooltip text matches slider description")
-- Release click from the same hold
describedSlider.infoButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(tip.Visible, true, "R5 tooltip stays open after releasing hold")

-- Tap again closes it
describedSlider.infoButton.MouseButton1Down:Fire()
describedSlider.infoButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(window._tooltipPinnedAnchor, nil, "R5 tooltip unpinned on tap again")

-- Requirement 6: If the window closes / hides, all circle-alert descriptions are hidden
describedDropdown.infoButton.MouseButton1Down:Fire()
describedDropdown.infoButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(tip.Visible, true, "R6 tooltip is open before window hide")

window:Hide()
eq(tip.Visible, false, "R6 tooltip is immediately hidden when window hides")
eq(window._tooltipPinnedAnchor, nil, "R6 pinned anchor cleared on window hide")
eq(window._tooltipActiveAnchor, nil, "R6 active anchor cleared on window hide")

window:Show()
TestPump(0.6)

-- Requirement 7: Dynamic updates via :SetDescription and :SetInfo
describedToggle:SetDescription("Updated dynamic description.")
describedToggle.infoButton.MouseButton1Down:Fire()
describedToggle.infoButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(tip.Visible, true, "R7 tooltip open after dynamic update")
eq(tipLabel.Text, "Updated dynamic description.", "R7 tooltip text shows updated description")

-- Setting empty description hides icon and tooltip
describedToggle:SetDescription("")
eq(describedToggle.infoButton.Visible, false, "R7 infoButton hidden when description cleared")
eq(tip.Visible, false, "R7 tooltip closed when description cleared")

-- Re-enabling description shows icon again
describedToggle:SetDescription("Restored description.")
eq(describedToggle.infoButton.Visible, true, "R7 infoButton visible again")

-- SetInfo alias works identically
describedToggle:SetInfo("Aliased info description.")
describedToggle.infoButton.MouseButton1Down:Fire()
describedToggle.infoButton.MouseButton1Click:Fire()
TestPump(0.1)
eq(tipLabel.Text, "Aliased info description.", "R7 SetInfo alias updates description")

-- Requirement 8: Window:Close() also immediately dismisses tooltips
window:Close()
eq(tip.Visible, false, "R8 tooltip is immediately hidden when window closes")
eq(window._tooltipPinnedAnchor, nil, "R8 pinned anchor cleared on window close")
eq(window._tooltipActiveAnchor, nil, "R8 active anchor cleared on window close")

print("CIRCLE ALERT ALL TESTS PASSED")
