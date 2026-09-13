-- Count work per simulated frame, not wall-clock timings from the mock runtime.
local newInstance = Instance.new
local allocations = 0
Instance.new = function(...)
    allocations += 1
    return newInstance(...)
end
local window, completed, shellInstances
local built = 0
local peak = 0
local frames = 0
local first, second
task.spawn(function()
    window = Astra:CreateWindow({ name = "Staged startup" })
    shellInstances = #window.instances
    first = window:CreateTab({ name = "Visible" })
    second = window:CreateTab({ name = "Later" })
    for index = 1, 100 do
        first:CreateToggle({ name = "Control " .. index, value = false })
        built += 1
        assert(not window.hasShownOnce, "Auto-show must wait for the build batch")
    end
    completed = true
end)
for _ = 1, 100 do
    local before = allocations
    TestPump(0.05)
    local delta = allocations - before
    peak = math.max(peak, delta)
    if not completed then frames += 1 end
    if completed and not window.animating and window.hasShownOnce then break end
end
print("STARTUP metrics: shell instances=" .. tostring(shellInstances) .. ", peak allocations/frame=" .. peak .. ", build frames=" .. frames)
assert(completed and built == 100, "All controls must finish building")
assert(frames >= 3, "Startup must give rendering time between batches")
assert(peak < 250, "No single frame may allocate the entire UI")
assert(window.hasShownOnce and not window.hidden, "Finished UI must auto-show")
assert(not window.searchPage and not window.searchInput, "Search content must stay lazy")
assert(#window._settingsTabs == 1, "Unused settings tab shells must stay lazy")
assert(not window._settingsUIBuilt, "Startup must not build the settings panels")

window:_toggleSettingsMode()
TestPump(0.6)
assert(#window._settingsTabs == 4, "Opening settings builds all navigation tabs")
assert(#window.rfSettings.elements > 0, "General builds on first access")
for _, tab in window._settingsTabs do
    if tab ~= window.rfSettings then assert(#tab.elements == 0, "Unopened settings content stays lazy") end
end
local count = #window.instances
window:_buildSettingsUI()
assert(#window.instances == count, "Settings initialization must be idempotent")
first:Select()
TestPump(0.6)

-- Hidden pages should never start a reveal tween when adding a control.
local late = second:CreateToggle({ name = "Hidden control", value = false })
assert(second._elementsPending, "Hidden-tab control is marked for first reveal")
assert(late.title.TextTransparency == 1, "Off-screen control is not animated")
second:Select()
TestPump(0.6)
assert(late.title.TextTransparency < 1, "Control reveals when selected")

window.searchAction.callback()
TestPump(0.3)
assert(window._searching and window.searchPage and window.searchInput, "First search builds its controls")
window.searchInput.Text = "Hidden control"
assert(late.main.Parent == window.searchPage and late.main.Visible, "Lazy search can find controls")
window.searchAction.callback()
TestPump(0.3)
assert(late.main.Parent == second.tabPage, "Closing search restores the source tab")
local count = #window.instances
window.searchAction.callback()
TestPump(0.3)
assert(#window.instances == count, "Reopening search must reuse the same instances")

-- An explicit Hide still cancels the delayed auto-show.
window:Unload()
local hidden = Astra:CreateWindow({ name = "Stay hidden" })
hidden:Hide()
TestPump(1)
assert(hidden.hidden and not hidden.hasShownOnce, "Hide must cancel pending auto-show")
hidden:Unload()
TestPump(0.2)
print("STARTUP: batching, quiet-frame reveal, lazy panels and hidden-tab tests passed")

local building, done, buildOk
local added = 0
task.spawn(function()
    buildOk = pcall(function()
        building = Astra:CreateWindow({ name = "Cancel build" })
        local tab = building:CreateTab({ name = "Batch" })
        for i = 1, 100 do
            tab:CreateToggle({ name = "Cancel " .. i, value = false })
            added += 1
        end
    end)
    done = true
end)
for _ = 1, 20 do
    TestPump(0.05)
    if building and (building._constructionBusy or 0) > 0 then break end
end
assert(building and added < 100, "Test must intercept a yielding batch")
building:Unload()
TestPump(0.6)
assert(done and buildOk == false, "Unloading must stop the in-flight builder")
assert(not building.hasShownOnce and #building.instances == 0, "Canceled window cannot reappear or keep instances")
print("STARTUP: unloading during construction is safe")
