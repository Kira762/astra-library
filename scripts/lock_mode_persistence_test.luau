--[[
Runtime coverage for the Element Lock Mode's round trip through the config.

The controller's control is the Settings → Controls picker, and settings
panels build lazily on first open — so the saved tier has to reach the
window on load even while no control owns its flag. These cases pin that:
the tier is written, it locks the page on the next execution before
Settings is ever opened, the lazily built picker agrees with it, and a
config saved without that panel still carries the tier.
]]

local function expect(condition, message)
	if not condition then
		error("LOCK MODE PERSISTENCE FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"LOCK MODE PERSISTENCE FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local http = Astra.Core.state.httpService

local function savedTier(window)
	local _, path = window:GetPath()
	if not isfile(path) then
		return nil
	end
	return http:JSONDecode(readfile(path))["astra.elementLockMode"]
end

local function build()
	local window = Astra:CreateWindow({ name = "Lock Mode Persistence" })
	local tab = window:CreateTab({ name = "Main" })
	local controls = {
		toggle = tab:CreateToggle({ name = "Feature", flag = "featureToggle", value = false }),
		link = tab:CreateLink({ name = "Docs", id = "docsLink", link = "https://example.com" }),
		group = tab:CreateCollapsibleGroup({
			name = "Advanced",
			elements = { { type = "Button", name = "Run", id = "runButton", callback = function() end } },
		}),
	}
	TestPump(0.6)
	return window, controls
end

local function openControls(window)
	window:_buildSettingsUI()
	for _, settingsTab in ipairs(window._settingsTabs) do
		if settingsTab.name == "Controls" then
			settingsTab:Select()
			TestPump(0.6)
			return window._elementLockModePicker
		end
	end
	error("built-in Controls settings tab is missing")
end

-- L1: the player picks Mode 5 and the tier lands in the config file.
local window, controls = build()
window:Show()
TestPump(0.6)
local controller = openControls(window)
expect(controller ~= nil and controller.__type == "ModePicker", "L1 the built-in controller exists")
controller:Set(5)
TestPump(0.8)
eq(window:GetElementLockMode(), 5, "L1 the controller selects Mode 5")
expect(controls.toggle:IsLocked(), "L1 Mode 5 locks a toggle in the same session")
eq(savedTier(window), 5, "L1 the tier is written to the config")
window:Unload()
TestPump(0.6)

-- L2: re-execution applies the saved tier before Settings is ever opened.
window, controls = build()
window:Show()
TestPump(1.0)
eq(window:GetElementLockMode(), 5, "L2 the saved tier is live on the next execution")
expect(controls.toggle:IsLocked(), "L2 a level 3 control is locked before Settings is opened")
expect(controls.link:IsLocked(), "L2 a level 2 control is locked before Settings is opened")
expect(controls.group:IsLocked(), "L2 a level 5 header is locked before Settings is opened")
eq(window._elementLockModePicker, nil, "L2 the settings panel is still unbuilt at this point")

-- L3: opening Settings afterwards agrees with the tier instead of resetting it.
controller = openControls(window)
eq(controller.mode, 5, "L3 the lazily built picker shows the saved mode")
eq(window:GetElementLockMode(), 5, "L3 building the picker keeps the tier")
expect(controls.toggle:IsLocked(), "L3 the controls stay locked after the picker is built")
eq(controller.flag, "astra.elementLockMode", "L3 the controller keeps the shared flag")
expect(window.controls[controller.flag] == controller, "L3 the built picker owns the flag")
window:Unload()
TestPump(0.6)

-- L4: a config written before the panel was ever opened still carries the tier.
window, controls = build()
window:Show()
TestPump(0.6)
expect(window:DeleteConfig(window.configuration.fileName), "L4 the previous configuration is cleared")
eq(savedTier(window), nil, "L4 no tier is stored before one is chosen")
window:SetElementLockMode(4)
expect(window:Save(), "L4 the host can save the configuration")
eq(savedTier(window), 4, "L4 a host-driven tier is saved without the settings panel")
window:Unload()
TestPump(0.6)

window, controls = build()
window:Show()
TestPump(1.0)
eq(window:GetElementLockMode(), 4, "L4 the host-driven tier comes back on the next execution")
expect(controls.toggle:IsLocked(), "L4 Mode 4 still locks a level 3 control")
window:Unload()
TestPump(0.6)

-- L5: a lowered tier is honored too, so no stale locks survive a re-execution.
window, controls = build()
window:Show()
TestPump(0.6)
controller = openControls(window)
controller:Set(1)
TestPump(0.8)
eq(savedTier(window), 1, "L5 Mode 1 overwrites the stored tier")
window:Unload()
TestPump(0.6)

window, controls = build()
window:Show()
TestPump(1.0)
eq(window:GetElementLockMode(), 1, "L5 the next execution starts unlocked")
expect(not controls.toggle:IsLocked(), "L5 no stale lock survives the re-execution")
expect(not controls.group:IsLocked(), "L5 no stale header lock survives the re-execution")
window:Unload()
TestPump(0.6)

print("LOCK MODE PERSISTENCE: tier written, applied on the next execution, picker sync and Mode 1 reset passed")
