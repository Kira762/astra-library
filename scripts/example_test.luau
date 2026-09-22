-- Appended to the real example, using the locally built bundle instead of HTTP.
TestPump(2)
assert(window.selectedTab == overview and overview.name == "Overview", "Demo starts with information")
local userTabs = {}
for _, tab in window.tabs do
    if not tab._isSettingsTab then table.insert(userTabs, tab) end
end
assert(#userTabs == 10, "Demo has ten purpose-based tabs")
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
    scan(tab.elements, tab == overview)
end
for _, kind in { "AboutCard", "Section", "Text", "Stat", "Divider", "Link", "Changelog", "Isolated", "Footer", "Button", "Group", "CollapsibleGroup", "Input", "Keybind", "Toggle", "Slider", "Dropdown" } do
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
