local function create()
    local window = Astra:CreateWindow({ name = "Saved keybind" })
    local tab = window:CreateTab({ name = "Main" })
    local field = tab:CreateKeybind({ name = "Shortcut", value = "A", flag = "shortcut" })
    TestPump(1)
    return window, field
end
local window, field = create()
field:Set("z")
window.settings.toggleKeybind = Enum.KeyCode.P
assert(window:SaveSettings(), "Save menu binding")
TestPump(0.5)
window:Unload()
window, field = create()
assert(field.value == "Z", "Flag restores a required uppercase letter")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Settings restore the enum binding")
-- Simulate a legacy file containing a non-letter key, then reopen the window.
local _, settingsPath = Astra.Settings.persistence.path()
local http = Astra.Core.state.httpService
for _, oldKey in { Enum.KeyCode.Space, Enum.KeyCode.Unknown, Enum.UserInputType.MouseButton2 } do
    window:Unload()
    local legacy = {
        settingsVersion = 1,
        toggleKeybind = { tostring(oldKey.EnumType), oldKey.Value },
    }
    writefile(settingsPath, http:JSONEncode(legacy))
    window, field = create()
    assert(window.settings.toggleKeybind == Enum.KeyCode.K, "Legacy non-letter/empty/mouse bindings migrate to K")
    local migrated = http:JSONDecode(readfile(settingsPath))
    assert(migrated.settingsVersion == 2 and migrated.toggleKeybind[2] == Enum.KeyCode.K.Value, "Migration saves the required letter")
end
window:Unload()
print("KEYBIND PERSISTENCE: config flags, settings round trip and legacy migration passed")
