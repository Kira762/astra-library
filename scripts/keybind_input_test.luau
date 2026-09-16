-- Settings binds the menu key through the shared Input element (a typed field).
local window = Astra:CreateWindow({ name = "Keybind input test" })
TestPump(0.6)
window:Show()
TestPump(0.6)
window:_buildSettingsContent(window.rfSettings)

-- [[Settings controls live inside Collapsible Groups, so the menu binding is]]
-- [[one level below the tab's top-level elements.]]
local function scan(elements, wanted)
    for _, control in elements do
        if wanted(control) then
            return control
        end
        if control.elements then
            local found = scan(control.elements, wanted)
            if found then
                return found
            end
        end
    end
    return nil
end

local field = scan(window.rfSettings.elements, function(control)
    return control.name == "Toggle Keybind"
end)
assert(field, "Settings must expose the menu binding")
assert(field.__type == "Input", "Settings must bind the menu key through the Input element")
assert(field.input.ClassName == "TextBox", "The binding must be a typed field")
assert(field.value == "K", "The field shows the bound key's name")
assert(typeof(window.settings.toggleKeybind) == "EnumItem", "The setting stays an EnumItem")

local saves = 0
window.SaveSettings = function()
    saves += 1
end

-- Typing into the field and leaving it is the commit, exactly like every other
-- Input element in the library.
local function typeKey(text)
    field.input.Text = text
    field.input.FocusLost:Fire(true)
    TestPump(0.1)
end

local function press(key, processed)
    Astra.Core.state.userInputService.InputBegan:Fire({
        UserInputType = Enum.UserInputType.Keyboard,
        KeyCode = key,
    }, processed == true)
    TestPump(0.1)
end

typeKey("P")
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "A typed key must bind")
assert(saves == 1, "A changed binding must be saved")
assert(field.value == "P" and field.input.Text == "P", "The field reads back the bound key")
assert(not window.hidden, "Binding must not hide the window")

typeKey("p") -- Case-insensitive, and the same key: normalised without a save.
assert(window.settings.toggleKeybind == Enum.KeyCode.P, "Lowercase must reach the same KeyCode")
assert(field.value == "P", "The field normalises the typed case")
assert(saves == 1, "Re-typing the bound key must not save again")

-- Text-focused input is game-processed, so typing the bound key cannot toggle.
press(Enum.KeyCode.P, true)
assert(not window.hidden, "Typing the bound key inside the field must not hide the window")

typeKey("space") -- Names people type that are not enum names as typed.
assert(window.settings.toggleKeybind == Enum.KeyCode.Space, "Aliased and lowercase names must bind")
assert(field.value == "Space", "The field shows the enum's own name")
assert(saves == 2, "A changed binding must be saved")

typeKey("MB2")
assert(window.settings.toggleKeybind == Enum.UserInputType.MouseButton2, "Right mouse must bind")
assert(field.value == "MB2", "Mouse bindings use the short label the caps use")
assert(saves == 3, "Mouse binding must save")

typeKey("MB1")
assert(
    window.settings.toggleKeybind == Enum.UserInputType.MouseButton2 and saves == 3,
    "Left click must be refused as a menu toggle"
)
assert(field.value == "MB2", "A refused key must restore the field")

typeKey("???")
assert(window.settings.toggleKeybind == Enum.UserInputType.MouseButton2 and saves == 3, "Junk text must not bind")
assert(field.value == "MB2", "Junk text must restore the field")

typeKey("none")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown, "'none' must clear the binding")
assert(field.value == "None", "A cleared binding reads None")
assert(saves == 4, "Clearing must save")

typeKey("")
assert(window.settings.toggleKeybind == Enum.KeyCode.Unknown and saves == 4, "An empty field stays cleared")
assert(field.value == "None", "An empty field reads None back")

typeKey("T")
assert(window.settings.toggleKeybind == Enum.KeyCode.T, "A key must bind after clearing")
assert(saves == 5, "A changed binding must be saved")

-- Outside the field, the newly saved key still toggles the window.
press(Enum.KeyCode.T, false)
TestPump(0.6)
assert(window.hidden, "The new key must toggle the window")
press(Enum.KeyCode.T, false)
TestPump(0.6)
assert(not window.hidden, "The new key must toggle the window back")

print("Keybind field commits, refusals and toggle passed")
