-- ===== Theme settings group behavior assertions =====
-- Runs the real Astra bundle against the mini Roblox environment from
-- sidebar_sizing_stubs.luau, then exercises the Appearance Theme group:
--   * the active-theme stat reads the whole theme name out as text,
--   * Reset to Default is always on the row,
--   * changing the dropdown past the active theme reveals Apply beside Reset,
--   * picking the active theme again hides Apply (Reset never moves),
--   * Reset swaps back to Default and re-syncs the stat + dropdown,
--   * Apply switches the theme, re-syncs the stat + dropdown and hides again.
-- The confirmation popups are intercepted: the click captures the popup props
-- and the confirm option's callback is invoked directly, so the same code the
-- real popup button runs is what this suite runs.

local function expect(cond, message)
	if not cond then
		error("THEME SETTINGS FAIL: " .. tostring(message), 0)
	end
end

local function findSettingsElement(targetWindow, tabName, elementName)
	targetWindow:_buildSettingsUI() -- settings shells are lazy
	for _, tab in targetWindow._settingsTabs do
		if tab.name == tabName then
			tab:Select()
			TestPump(0.15)
			local function scan(elements)
				for _, element in elements do
					if element.name == elementName then
						return element
					end
					if element.elements then
						local found = scan(element.elements)
						if found then
							return found
						end
					end
				end
				return nil
			end
			return scan(tab.elements)
		end
	end
	return nil
end

local window = Astra:CreateWindow({ name = "Theme Settings Test", configuration = { autoSave = false, autoLoad = false } })
TestPump(1.2)

local themeGroup = findSettingsElement(window, "Appearance", "Theme")
expect(themeGroup ~= nil, "the Theme collapsible group exists")
expect(themeGroup.__type == "CollapsibleGroup", "the Theme entry is the collapsible group")

local stat = themeGroup.elements[1]
local dropdown = themeGroup.elements[2]
local buttonRow = themeGroup.elements[3]
expect(stat and stat.name == "Current theme", "the stat is the group's first element")
expect(dropdown and dropdown.__type == "Dropdown", "the dropdown follows the stat")
expect(buttonRow and buttonRow.__type == "Group", "the reset/apply row follows the dropdown")
local resetBtn = buttonRow.elements[1]
local applyBtn = buttonRow.elements[2]
expect(resetBtn and resetBtn.name == "Reset to Default", "left button is Reset to Default")
expect(applyBtn and applyBtn.name == "Apply Theme", "right button is Apply Theme")

-- Defaults: window.settings.theme starts as the built-in default.
expect(window.settings.theme == "default", "a fresh window starts on the default theme")

-- The stat reads the full theme name: a text readout, no letter badge and no
-- numeric odometers.
expect(stat.letter == false, "the current-theme stat is not in letter mode")
expect(stat.textValue == true, "a text value without the badge is a text readout")
expect(stat.letterGlyph == nil, "no letter badge is built for it")
expect(stat.textLabel ~= nil and stat.textLabel.Text == "Default", "the stat reads the whole theme name")
expect(stat.valueOdo == nil and stat.changeOdo == nil, "the text readout builds no numeric odometers")

-- Reset is permanent; only Apply is staged.
expect(buttonRow.main.Visible == true, "the button row is always present")
expect(resetBtn.main.Visible == true, "no pending change: Reset stays visible")
expect(applyBtn.main.Visible == false, "no pending change: Apply is absent")

-- Navigate away and back: the staged state survives tab switches.
for _, otherTab in window._settingsTabs do
	if otherTab.name == "General" then
		otherTab:Select()
		TestPump(0.15)
		break
	end
end
findSettingsElement(window, "Appearance", "Theme")
expect(resetBtn.main.Visible == true, "Reset stays visible across a tab switch")
expect(applyBtn.main.Visible == false, "Apply stays absent across a tab switch")

-- Pick a different theme: Apply appears beside Reset.
dropdown:Set("Cobalt")
TestPump(0.2)
expect(applyBtn.main.Visible == true, "a pending change reveals Apply")
expect(resetBtn.main.Visible == true, "a pending change leaves Reset visible")
expect(window.settings.theme == "default", "selecting a candidate never applies it yet")
expect(stat.textLabel.Text == "Default", "the stat still reads the active theme")

-- Pick the active theme again: Apply goes back to absent, Reset stays.
dropdown:Set("Default")
TestPump(0.2)
expect(applyBtn.main.Visible == false, "choosing the active theme clears the pending change")
expect(resetBtn.main.Visible == true, "Reset stays visible with no pending change")

-- Intercept the popup so the confirmation can be run deterministically.
local realPopup = window.Popup
local lastPopup = nil
window.Popup = function(self, props)
	lastPopup = props
end

-- Reset with no pending change but a non-default active theme: confirmations.
dropdown:Set("Frost")
TestPump(0.2)
expect(applyBtn.main.Visible == true, "a pending change reveals Apply again")

-- Apply asks for confirmation before touching the theme.
applyBtn.interact.MouseButton1Click:Fire()
TestPump(0.3)
expect(lastPopup ~= nil and lastPopup.title == "Apply theme?", "apply asks for confirmation")
expect(type(lastPopup.content) == "string" and string.find(lastPopup.content, "Frost", 1, true) ~= nil,
	"apply confirmation names the pending theme")
expect(#lastPopup.options == 2 and lastPopup.options[1].text == "Cancel", "apply confirmation offers Cancel")
expect(lastPopup.options[1].callback == nil, "Cancel only dismisses (no callback)")
expect(window.settings.theme == "default", "opening the confirmation does not apply yet")

-- Confirm apply for real.
lastPopup = nil
applyBtn.interact.MouseButton1Click:Fire()
TestPump(0.3)
expect(lastPopup ~= nil and lastPopup.title == "Apply theme?", "apply asks again after reopening")
lastPopup.options[2].callback()
TestPump(0.3)
expect(window.settings.theme == "frost", "apply commits the chosen theme")
expect(stat.textLabel.Text == "Frost", "apply re-syncs the stat to the full theme name")
expect(dropdown.value[1] == "Frost", "apply re-syncs the dropdown to Frost")
expect(applyBtn.main.Visible == false, "apply hides Apply once the theme is applied")
expect(resetBtn.main.Visible == true, "Reset is untouched by applying a theme")

-- …and stays that way across a tab switch.
for _, otherTab in window._settingsTabs do
	if otherTab.name == "General" then
		otherTab:Select()
		TestPump(0.15)
		break
	end
end
findSettingsElement(window, "Appearance", "Theme")
expect(resetBtn.main.Visible == true, "Reset stays visible after the round trip")
expect(applyBtn.main.Visible == false, "Apply stays absent after the round trip")

-- Now reset from a non-default theme: a confirmation popup is requested.
lastPopup = nil
resetBtn.interact.MouseButton1Click:Fire()
TestPump(0.3)
expect(lastPopup ~= nil and lastPopup.title == "Reset theme?", "reset from a custom theme asks for confirmation")
expect(type(lastPopup.content) == "string" and string.find(lastPopup.content, "Default", 1, true) ~= nil,
	"reset confirmation names the Default theme")
lastPopup.options[2].callback()
TestPump(0.3)
expect(window.settings.theme == "default", "reset returns the window to the default theme")
expect(stat.textLabel.Text == "Default", "reset re-syncs the stat to Default")
expect(dropdown.value[1] == "Default", "reset re-syncs the dropdown to Default")
expect(applyBtn.main.Visible == false, "reset leaves Apply absent")
expect(resetBtn.main.Visible == true, "Reset stays visible after resetting")

-- Reset still asks for confirmation when the active theme is already Default
-- but a different theme is pending in the dropdown.
dropdown:Set("Cobalt")
TestPump(0.2)
expect(applyBtn.main.Visible == true, "a pending change reveals Apply on Default")
lastPopup = nil
resetBtn.interact.MouseButton1Click:Fire()
TestPump(0.3)
expect(lastPopup ~= nil and lastPopup.title == "Reset theme?", "reset from Default with a pending change still asks for confirmation")
lastPopup.options[2].callback()
TestPump(0.3)
expect(window.settings.theme == "default", "confirming reset keeps the window on Default")
expect(stat.textLabel.Text == "Default", "reset keeps the stat on Default")
expect(dropdown.value[1] == "Default", "reset re-syncs the dropdown back to Default")
expect(applyBtn.main.Visible == false, "reset hides Apply again")
expect(resetBtn.main.Visible == true, "Reset stays visible through the whole cycle")

-- The stat's text readout follows SetText and Set.
stat:SetText("Onyx")
expect(stat.textLabel.Text == "Onyx", "SetText updates the text readout")
stat:Set("Default")
expect(stat.textLabel.Text == "Default", "Set on a text stat updates the text readout")
stat:ResetBaseline("Emerald")
expect(stat.textLabel.Text == "Emerald", "ResetBaseline on a text stat updates the text readout")

window.Popup = realPopup
window:Unload()
TestPump(0.2)

print("THEME SETTINGS: full-name stat, permanent reset and staged apply all passed")
