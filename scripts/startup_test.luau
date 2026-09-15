-- Count work per simulated frame, not wall-clock timings from the mock runtime.
local newInstance = Instance.new
local allocations = 0
Instance.new = function(...)
    allocations += 1
    return newInstance(...)
end
local window, completed, shellInstances
local built = 0
local builtAtReveal
local peak = 0
local frames = 0
local first, second
task.spawn(function()
    window = Astra:CreateWindow({ name = "Staged startup" })
    window.settings.welcomeToast = false
    shellInstances = #window.instances
    first = window:CreateTab({ name = "Visible" })
    second = window:CreateTab({ name = "Later" })
    for index = 1, 100 do
        first:CreateToggle({ name = "Control " .. index, value = false })
        built += 1
    end
    completed = true
end)
for _ = 1, 160 do
    local before = allocations
    TestPump(0.05)
    local delta = allocations - before
    peak = math.max(peak, delta)
    if window and window.hasShownOnce and not builtAtReveal then
        builtAtReveal = built
    end
    if not completed then frames += 1 end
    if completed and window and not window.animating and window.hasShownOnce then break end
end
print(
    "STARTUP metrics: shell instances=" .. tostring(shellInstances)
        .. ", peak allocations/frame=" .. peak
        .. ", build frames=" .. frames
        .. ", controls at reveal=" .. tostring(builtAtReveal)
)
assert(completed and built == 100, "All controls must finish building")
assert(frames >= 3, "Startup must give rendering time between batches")
assert(peak < 250, "No single frame may allocate the entire UI")
assert(window.hasShownOnce and not window.hidden, "The UI must auto-show on its reveal deadline")
assert(builtAtReveal and builtAtReveal < 100, "A large initial build must continue after the window is visible")
assert(window.windowScale and window.windowScale.Scale == 1, "The UIScale entrance settles at full scale")
assert(Astra.Motion.spec("pop").Time >= 0.5, "The opening animation is long enough to be visible")
assert(not window.searchPage and not window.searchInput, "Search content must stay lazy")
assert(#window._settingsTabs == 1, "Unused settings tab shells must stay lazy")
assert(not window._settingsUIBuilt, "Startup must not build the settings panels")

-- Notifications and toasts share one rate-limited entrance queue. A burst
-- allocates only the first overlay, then starts each following transition once
-- the previous 0.6s entrance has finished.
local function launchedOverlays()
    local count = #(window._liveNotifications or {})
    for _, list in window._liveToasts or {} do
        count += #list
    end
    return count
end
window:Notify({ title = "Queued 1", content = "First" })
window:Toast({ title = "Queued 2", subtitle = "Second" })
window:Notify({ title = "Queued 3", content = "Third" })
assert(#window._overlayQueue.pending == 3, "Overlay burst is queued before any component allocation")
TestPump(0.1)
assert(launchedOverlays() == 1 and #window._overlayQueue.pending == 2, "Only the first overlay starts immediately")
TestPump(0.4)
assert(launchedOverlays() == 1, "A second overlay cannot overlap the first entrance")
TestPump(0.3)
assert(launchedOverlays() == 2 and #window._overlayQueue.pending == 1, "The next overlay starts after the entrance cooldown")

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
print("STARTUP: batching, deadline reveal, overlay pacing, lazy panels and hidden-tab tests passed")

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
