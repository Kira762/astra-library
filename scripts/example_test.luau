--[[
Appended to the real example, using the locally built bundle instead of HTTP.
The studio is gated: the key card comes up first and nothing exists until a
key passes, so this harness drives the gate through the same `_submit` path
the Continue button and Enter key take before it can assert on the studio.
]]
TestPump(2)
assert(keyGate ~= nil and not keyGate.passed and not keyGate.closed, "Demo opens on the key gate")
assert(window == nil and overview == nil, "No studio is built before the key passes")
keyGate:_submit("not-the-demo-key")
TestPump(0.6)
assert(keyGate.attempts == 1 and not keyGate.passed and window == nil, "A wrong key costs an attempt and builds nothing")
keyGate:_submit("  ASTRA-STUDIO-2026  ")
TestPump(2)
assert(keyGate.passed and keyGate.closed, "The demo key passes the gate (trimmed)")
assert(window ~= nil and overview ~= nil, "The studio is built inside onSuccess")
--[[
BuildStudio runs on the thread the gate spawns for `onSuccess`, so the
window's budget-paced construction yields real frames here (the main
thread's stray-wait no-op cannot save it): pump until the build has
streamed to completion, which is what the studioReady seam marks.
]]
for _ = 1, 120 do
    if studioReady then
        break
    end
    TestPump(0.25)
end
assert(studioReady, "The gated build streams to completion before the harness inspects it")
assert(window.selectedTab == overview and overview.name == "Overview", "Demo starts with information")
local userTabs = {}
for _, tab in window.tabs do
    if not tab._isSettingsTab then table.insert(userTabs, tab) end
end
assert(#userTabs == 13, "Demo has thirteen purpose-based tabs, including New Elements, All Elements and Steppers")
local allElementsTab
for _, tab in userTabs do
    if tab.name == "All Elements" then
        allElementsTab = tab
        break
    end
end
assert(allElementsTab ~= nil, "Demo includes the All Elements tab")
local allElementNames = {}
for _, element in allElementsTab.elements do
    local kind = if element.__type == "Statistic" then "Stat" else element.__type
    local visibleName = element.name
    if kind == "Footer" then
        visibleName = element.parts[1] and element.parts[1].value
    elseif kind == "Divider" then
        visibleName = element.text
    elseif kind == "Group" then
        visibleName = element.elements[1] and element.elements[1].name
    end
    allElementNames[kind] = visibleName
end
for _, kind in { "Section", "Text", "Button", "Toggle", "Slider", "Stepper", "Dropdown", "Input", "Keybind", "Stat", "Link", "AboutCard", "Footer", "Changelog", "Divider", "Group", "CollapsibleGroup", "ModePicker", "Isolated" } do
    assert(allElementNames[kind] == kind, "All Elements names its " .. kind .. " entry correctly")
end
local types = {}
local function scan(elements, informationOnlyHere)
    for _, element in elements do
        types[if element.__type == "Statistic" then "Stat" else element.__type] = true
        if element.__type == "AboutCard" or element.__type == "Changelog" or element.__type == "Link" or element.__type == "Footer" then
            assert(informationOnlyHere, "Information belongs in the first tab")
        end
        if element.__type == "CollapsibleGroup" then
            assert(#element.elements > 1, "Never wrap a lone element in a collapsible group")
        end
        if element.elements then scan(element.elements, informationOnlyHere) end
    end
end
for _, tab in userTabs do
    tab:Select()
    TestPump(0.5)
    scan(tab.elements, tab == overview or tab.name == "All Elements")
end
for _, kind in { "AboutCard", "Section", "Text", "Stat", "Divider", "Link", "Changelog", "Isolated", "Footer", "Button", "Group", "CollapsibleGroup", "Input", "Keybind", "Toggle", "Stepper", "Slider", "Dropdown" } do
    assert(types[kind], "Demo exercises " .. kind)
end
window:_buildSettingsUI()
for _, tab in window._settingsTabs do
    tab:Select()
    TestPump(0.5)
    scan(tab.elements, tab == window.rfSettings)
end
assert(window.rfSettings.name == "Overview" and window.rfSettings.elements[1].__type == "AboutCard", "Settings information is first")
local appearance
for _, tab in window._settingsTabs do if tab.name == "Appearance" then appearance = tab end end
local layout
for _, element in appearance.elements do if element.name == "Bar Layout" then layout = element end end
assert(layout and layout.__type == "Dropdown", "Layout is a standalone setting, not a one-child fold")
print("EXAMPLE: all elements, information-first tabs, purpose-based settings and multi-child folds passed")
