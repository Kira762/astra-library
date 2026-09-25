local function create()
    local window = Astra:CreateWindow({ name = "Preferences" })
    local tab = window:CreateTab({ name = "Main" })
    local group = tab:CreateCollapsibleGroup({ name = "Saved controls", elements = {
        { type = "Toggle", name = "Active", flag = "savedActive", value = false },
        { type = "Slider", name = "Speed", flag = "savedSpeed", range = { 0, 100 }, value = 16 },
    } })
    TestPump(1)
    return window, group
end
local function settings(window)
    window:_buildSettingsUI()
    for _, tab in window._settingsTabs do
        if tab.name == "Persistence" then
            tab:Select()
            TestPump(0.4)
            local found = {}
            local function collect(elements)
                for _, element in elements do
                    if element.name then found[element.name] = element end
                    if element.elements then collect(element.elements) end
                end
            end
            collect(tab.elements)
            return found
        end
    end
    error("Persistence settings missing")
end
local window, group = create()
assert(window.configuration.autoSave and window.configuration.autoLoad, "Save/load defaults are on")
assert(window.configuration.customFolder == "AstraConfigs" and window.configuration.fileName == "Astra-Hub", "Hidden path defaults")
local folder, path = window:GetPath()
assert(path:match("AstraConfigs/Astra%-Hub%.txt$"), "Default path is used without a configuration prop")
local writes = 0
local originalSave = window.Save
window.Save = function(self, ...)
    writes += 1
    return originalSave(self, ...)
end
for n = 1, 30 do group.elements[2]:Set(n) end
group.elements[1]:Set(true)
TestPump(0.5)
assert(writes == 1, "Autosave coalesces bursts of changes")
assert(isfile(path), "Autosave writes the default config")
local controls = settings(window)
assert(controls["Auto Save Config"] and controls["Auto Load Config"], "Both switches are in Persistence")
assert(table.find(controls["Saved Configurations"].options, "Astra-Hub"), "Saved configuration is exposed in Settings")
local savedData = readfile(path)
controls["Auto Save Config"]:Set(false)
controls["Auto Load Config"]:Set(false)
TestPump(0.3)
group.elements[2]:Set(99)
TestPump(0.5)
assert(readfile(path) == savedData, "Disabled autosave never overwrites or deletes the config")
window:Unload()
window, group = create()
assert(not window.configuration.autoSave and not window.configuration.autoLoad, "Preferences survive while autosave is off")
assert(group.elements[2].value == 16 and group.elements[1].value == false, "Disabled autoload leaves defaults")
controls = settings(window)
controls["Auto Load Config"]:Set(true)
TestPump(0.3)
assert(group.elements[2].value == 16, "Enabling autoload does not overwrite this session")
window:Unload()
window, group = create()
assert(group.elements[2].value == 30 and group.elements[1].value == true, "Next startup restores collapsed controls")
assert(not group._expanded, "Control persistence does not force expansion")
assert(not window.configuration.autoSave, "Save preference remains independent of load")
assert(Astra.Settings.newManager():set("autoSaveConfig", false), "Settings manager accepts the preference")
controls = settings(window)
controls["Auto Save Config"]:Set(true)
TestPump(0.2)
group.elements[2]:Set(44)
window:Unload() -- deliberately before the debounce fires
window, group = create()
assert(group.elements[2].value == 44, "Closing promptly flushes the last edit")
window:Unload()

--[[ Settings -> Configurations is live: the "Saved Configurations" list
re-reads on every save/delete (autosave included), so a config written
after the panel was built still shows up. This is the "autosaved config
is not showing in the settings Config section" regression. ]]
window = Astra:CreateWindow({
    name = "List freshness",
    configuration = { fileName = "Autosave-Visible", customFolder = "AstraVisibility", autoSave = true, autoLoad = true },
})
group = window:CreateTab({ name = "Main" }):CreateCollapsibleGroup({ name = "Saved controls", elements = {
    { type = "Toggle", name = "Active", flag = "freshActive", value = false },
} })
TestPump(1)
controls = settings(window) -- the panel builds BEFORE anything is saved
assert(not table.find(controls["Saved Configurations"].options, "Autosave-Visible"), "Nothing is saved before the first change")
group.elements[1]:Set(true)
TestPump(0.5)
assert(isfile((select(2, window:GetPath()))), "Autosave wrote the default config")
assert(table.find(controls["Saved Configurations"].options, "Autosave-Visible"), "Autosaved config shows in the settings Config section")
assert(window:Save("Named While Open"), "Host-side named save works")
assert(table.find(controls["Saved Configurations"].options, "Named While Open"), "A named save shows without a manual refresh")
assert(window:DeleteConfig("Named While Open"), "Host-side delete works")
assert(not table.find(controls["Saved Configurations"].options, "Named While Open"), "A deleted config leaves the list")
local disconnect = window:OnConfigsChanged(function() end)
assert(type(disconnect) == "function", "OnConfigsChanged returns an unsubscribe")
disconnect()
window:Unload()
print("CONFIG PREFERENCES: defaults, coalesced saving, independent toggles, next-startup loading and the live config list passed")
