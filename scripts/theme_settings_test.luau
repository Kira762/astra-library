-- ===== Theme settings group behavior assertions =====
-- Runs the real Astra bundle against the mini Roblox environment from
-- sidebar_sizing_stubs.luau, then exercises the Appearance Theme group:
--   * the active-theme stat renders as a letter badge (no icon, one glyph),
--   * changing the dropdown past the active theme reveals the reset/apply pair,
--   * picking the active theme again hides the pair,
--   * Reset swaps back to Default and re-syncs the stat + dropdown,
--   * Apply switches the theme, re-syncs the stat + dropdown.
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

-- The stat is letter mode: a glyph label exists and numeric odometers do not.
expect(stat.letter == true, "the current-theme stat uses letter mode")
expect(stat.letterGlyph ~= nil and stat.letterGlyph.Text == "D", "the stat shows the letter D for Default")
expect(stat.valueOdo == nil and stat.changeOdo == nil, "letter mode builds no numeric odometers")

-- The reset/apply pair is hidden with no pending change.
expect(buttonRow.main.Visible == false, "no pending change: the pair is hidden")

-- Pick a different theme: the pair appears.
dropdown:Set("Cobalt")
TestPump(0.2)
expect(buttonRow.main.Visible == true, "a pending change reveals the pair")
expect(window.settings.theme == "default", "selecting a candidate never applies it yet")
expect(stat.letterGlyph.Text == "D", "the stat still shows the active theme letter")

-- Pick the active theme again: the pair hides.
dropdown:Set("Default")
TestPump(0.2)
expect(buttonRow.main.Visible == false, "choosing the active theme clears the pending change")

-- Intercept the popup so the confirmation can be run deterministically.
local realPopup = window.Popup
local lastPopup = nil
window.Popup = function(self, props)
	lastPopup = props
end

-- Reset with no pending change but a non-default active theme: confirmations.
dropdown:Set("Frost")
TestPump(0.2)
expect(buttonRow.main.Visible == true, "a pending change reveals the pair again")

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
expect(stat.letterGlyph.Text == "F", "apply re-syncs the stat to F")
expect(dropdown.value[1] == "Frost", "apply re-syncs the dropdown to Frost")
expect(buttonRow.main.Visible == false, "apply hides the pair")

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
expect(stat.letterGlyph.Text == "D", "reset re-syncs the stat to D")
expect(dropdown.value[1] == "Default", "reset re-syncs the dropdown to Default")
expect(buttonRow.main.Visible == false, "reset hides the pair")

-- Reset still asks for confirmation when the active theme is already Default
-- but a different theme is pending in the dropdown.
dropdown:Set("Cobalt")
TestPump(0.2)
expect(buttonRow.main.Visible == true, "a pending change reveals the pair on Default")
lastPopup = nil
resetBtn.interact.MouseButton1Click:Fire()
TestPump(0.3)
expect(lastPopup ~= nil and lastPopup.title == "Reset theme?", "reset from Default with a pending change still asks for confirmation")
lastPopup.options[2].callback()
TestPump(0.3)
expect(window.settings.theme == "default", "confirming reset keeps the window on Default")
expect(stat.letterGlyph.Text == "D", "reset keeps the stat at D")
expect(dropdown.value[1] == "Default", "reset re-syncs the dropdown back to Default")
expect(buttonRow.main.Visible == false, "reset hides the pair again")

-- Stat:Set keeps the badge in step without numeric readouts.
stat:SetText("Onyx")
expect(stat.letterGlyph.Text == "O", "SetText updates the letter badge")
stat:Set("Default")
expect(stat.letterGlyph.Text == "D", "numeric Set on a letter stat updates the badge")

window.Popup = realPopup
window:Unload()
TestPump(0.2)

print("THEME SETTINGS: stat letter, staged apply and reset/apply pair all passed")
