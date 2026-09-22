--[[
===== Default-only theme behaviour =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau. Colour palettes other than `default` were
removed, so Appearance no longer offers a theme picker. This suite
pins that:
  * a fresh window is on the default palette,
  * Appearance has no Theme group,
  * Bar Layout and Motion & Feedback remain,
  * ChangeTheme("default") is a no-op on the palette,
  * an unknown built-in name falls back to default,
  * a custom theme table still overlays keys.
]]

local function expect(cond, message)
	if not cond then
		error("THEME SETTINGS FAIL: " .. tostring(message), 0)
	end
end

local function colorEq(actual, wanted, message)
	expect(
		actual ~= nil
			and wanted ~= nil
			and actual.R == wanted.R
			and actual.G == wanted.G
			and actual.B == wanted.B,
		message
	)
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

local defaultAccent = Color3.fromRGB(23, 153, 110)
local defaultTopbar = Color3.fromRGB(18, 18, 18)

expect(window.settings.theme == "default", "a fresh window starts on the default theme")
colorEq(window.theme.Accent, defaultAccent, "the default teal accent is in effect")

expect(findSettingsElement(window, "Appearance", "Theme") == nil, "Appearance has no Theme picker")
expect(findSettingsElement(window, "Appearance", "Current theme") == nil, "Appearance has no current-theme stat")
expect(findSettingsElement(window, "Appearance", "Bar Layout") ~= nil, "Bar Layout remains on Appearance")
expect(findSettingsElement(window, "Appearance", "Motion & Feedback") ~= nil, "Motion & Feedback remains on Appearance")

window:ChangeTheme("default")
TestPump(0.2)
colorEq(window.theme.Accent, defaultAccent, "ChangeTheme(\"default\") keeps the built-in palette")

window:ChangeTheme("frost")
TestPump(0.2)
colorEq(window.theme.Accent, defaultAccent, "an unknown built-in name falls back to default")
expect(window.settings.theme == "default", "falling back does not persist a removed name")

local override = Color3.fromRGB(120, 90, 220)
window:ChangeTheme({ Accent = override, AccentColor = override })
TestPump(0.3)
colorEq(window.theme.Accent, override, "a custom theme table overlays Accent")
colorEq(window.theme.AccentColor, override, "a custom theme table overlays AccentColor")
colorEq(window.theme.TopbarSurface, defaultTopbar, "keys the table omits stay on default")

window:ChangeTheme("default")
TestPump(0.3)
colorEq(window.theme.Accent, defaultAccent, "ChangeTheme(\"default\") restores the built-in palette")

window:Unload()
TestPump(0.2)

print("THEME SETTINGS: default-only palette, no picker, custom tables still overlay")
