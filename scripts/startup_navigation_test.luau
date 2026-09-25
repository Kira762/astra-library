--[[
Startup navigation: the window is on screen and tappable while the host is
still building it (the shell reveals after one frame and the remaining
constructors are paced across later frames). A tab or Settings the user
opens during that build must stay open when the host's own startup
selection runs — the closing `tab:Select()` every script ends with, or the
first-tab auto-select of a tab created late. Once the build has gone quiet,
host selections apply again as before.

  N1 a row tap mid-build survives the host's closing `tab:Select()`,
     and the page on screen is the tapped tab's,
  N2 the Settings action mid-build survives it too (settings rail stays),
  N3 a first main tab created after the user opened Settings does not
     auto-select itself,
  N4 once the build is quiet, host `Select` / `Navigate` work again,
  N5 without a user tap, the host's closing `Select` still applies.

The host build runs in its own thread and yields through
`window:_paceBudget(true)`, which is exactly what the library's
construction checkpoints do between batches on a real device.
]]

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"STARTUP NAVIGATION FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function nameOf(tab)
	return if tab then tostring(tab.name) else "nil"
end

--[[
Runs a paced host build: `build(window, pace)` creates the tabs and
controls and calls `pace()` wherever the library would yield. `onShown`
runs on its own thread once the window is visible — the user's taps.
]]
local function runStartup(name, build, onShown)
	local state = { done = false }
	task.spawn(function()
		local window = Astra:CreateWindow({ name = name })
		state.window = window
		build(window, function()
			window:_paceBudget(true)
		end, state)
		state.done = true
	end)
	task.spawn(function()
		while not state.window or state.window.hidden do
			task.wait()
		end
		onShown(state.window, state)
	end)
	local waited = 0
	while not state.done and waited < 20 do
		TestPump(0.05)
		waited += 0.05
	end
	eq(state.done, true, name .. ": host build finished")
	TestPump(1)
	return state
end

-- N1: a row tap mid-build survives the host's closing Select.
do
	local s = runStartup("Nav Row", function(window, pace, st)
		st.home = window:CreateTab({ name = "Home", icon = "house" })
		st.second = window:CreateTab({ name = "Second", icon = "star" })
		for i = 1, 30 do
			st.home:CreateButton({ name = "Button " .. i, callback = function() end })
			pace()
		end
		st.hostSelectRanAfterTap = st.tapped == true
		st.home:Select()
	end, function(window, st)
		task.wait(0.1)
		st.second.topbarItemInteract.MouseButton1Click:Fire()
		st.tapped = true
	end)
	eq(s.hostSelectRanAfterTap, true, "N1 the user tapped before the host's closing Select")
	eq(nameOf(s.window.selectedTab), "Second", "N1 the tapped tab stays selected")
	eq(s.window.elementsLayout.__currentPage, s.second.tabPage, "N1 the tapped tab's page stays on screen")
end

-- N2: the Settings action mid-build survives the host's closing Select.
do
	local s = runStartup("Nav Settings", function(window, pace, st)
		st.home = window:CreateTab({ name = "Home", icon = "house" })
		for i = 1, 30 do
			st.home:CreateButton({ name = "Button " .. i, callback = function() end })
			pace()
		end
		st.hostSelectRanAfterTap = st.tapped == true
		st.home:Select()
	end, function(window, st)
		task.wait(0.1)
		window.settingsAction.interact.MouseButton1Click:Fire()
		st.tapped = true
	end)
	eq(s.hostSelectRanAfterTap, true, "N2 the user opened Settings before the host's closing Select")
	eq(s.window.selectedTab and s.window.selectedTab._isSettingsTab, true, "N2 a settings tab stays selected")
	eq(s.window._settingsMode, true, "N2 the settings rail stays active")

	-- Leaving Settings through the same action goes back to the host's tab.
	s.window.settingsAction.interact.MouseButton1Click:Fire()
	TestPump(0.5)
	eq(nameOf(s.window.selectedTab), "Home", "N2 closing Settings returns to the main rail")
	eq(s.window._settingsMode, false, "N2 closing Settings leaves the settings rail")
end

-- N3: a late first main tab does not pull the user out of Settings.
do
	local s = runStartup("Nav Late Tab", function(window, pace, st)
		while not st.tapped do
			pace()
		end
		st.home = window:CreateTab({ name = "Home", icon = "house" })
		for i = 1, 5 do
			st.home:CreateButton({ name = "Button " .. i, callback = function() end })
			pace()
		end
	end, function(window, st)
		window.settingsAction.interact.MouseButton1Click:Fire()
		st.tapped = true
	end)
	eq(s.window._settingsMode, true, "N3 the user is still in Settings")
	eq(s.window.selectedTab and s.window.selectedTab._isSettingsTab, true, "N3 the late first tab did not select itself")
	s.window.settingsAction.interact.MouseButton1Click:Fire()
	TestPump(0.5)
	eq(nameOf(s.window.selectedTab), "Home", "N3 closing Settings opens the late first tab")
end

-- N4: once the build is quiet, host selections apply again.
do
	local s = runStartup("Nav Settled", function(window, pace, st)
		st.home = window:CreateTab({ name = "Home", icon = "house" })
		st.second = window:CreateTab({ name = "Second", icon = "star" })
		for i = 1, 10 do
			st.home:CreateButton({ name = "Button " .. i, callback = function() end })
			pace()
		end
	end, function(window, st)
		task.wait(0.1)
		st.second.topbarItemInteract.MouseButton1Click:Fire()
	end)
	eq(s.window._hostBuildSettled, true, "N4 the entrypoint marked the build settled")
	eq(nameOf(s.window.selectedTab), "Second", "N4 the user's tap applied")
	s.home:Select()
	TestPump(0.3)
	eq(nameOf(s.window.selectedTab), "Home", "N4 a host Select after startup applies")
	s.window:Navigate("Second")
	TestPump(0.3)
	eq(nameOf(s.window.selectedTab), "Second", "N4 a host Navigate after startup applies")
	s.home.topbarItemInteract.MouseButton1Click:Fire()
	TestPump(0.3)
	eq(nameOf(s.window.selectedTab), "Home", "N4 row taps keep working")
end

-- N5: with no user tap, the host's closing Select applies.
do
	local s = runStartup("Nav Host", function(window, pace, st)
		st.home = window:CreateTab({ name = "Home", icon = "house" })
		st.second = window:CreateTab({ name = "Second", icon = "star" })
		for i = 1, 10 do
			st.home:CreateButton({ name = "Button " .. i, callback = function() end })
			pace()
		end
		st.second:Select()
	end, function() end)
	eq(nameOf(s.window.selectedTab), "Second", "N5 the host's startup selection applies")
	eq(s.window.elementsLayout.__currentPage, s.second.tabPage, "N5 the host's tab page is on screen")
end

print("startup navigation: all assertions passed")
