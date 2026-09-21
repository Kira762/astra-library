local window = Astra:CreateWindow({ name = "Capsule reset" })
TestPump(0.8)
window:_buildSettingsUI()
local general
for _, tab in window._settingsTabs do
    if tab.name == "Controls" then general = tab end
end
assert(general, "Controls tab exists")
general:Select()
TestPump(0.6)
local reset
local function scan(elements)
    for index, control in elements do
        if control.name == "Reset Capsule Position" then
            reset = control
            assert(elements[index - 1].name == "Reset Window Position", "Reset actions are adjacent")
            return
        end
        if control.elements then
            scan(control.elements)
            if reset then return end
        end
    end
end
scan(general.elements)
assert(reset and reset.__type == "Button", "Capsule reset is a settings button")
local function samePosition(actual, expected)
    assert(actual.X.Scale == expected.X.Scale and actual.X.Offset == expected.X.Offset
        and actual.Y.Scale == expected.Y.Scale and actual.Y.Offset == expected.Y.Offset, "Position mismatch")
end
for _, iconOnly in { false, true } do
    window.showIconOnly = iconOnly
    window.main.Position = UDim2.fromOffset(400, 300)
    window._restorePosition = UDim2.fromOffset(400, 300)
    window._collapsedPosition = UDim2.fromOffset(750, 400)
    reset.callback()
    TestPump(0.6)
    assert(window._collapsedPosition == nil, "Reset clears the capsule drag override")
    samePosition(window.main.Position, UDim2.fromOffset(400, 300))
    samePosition(window._restorePosition, UDim2.fromOffset(400, 300))
    local defaultPosition, size = window:_collapsedRect()
    samePosition(defaultPosition, UDim2.new(0.5, 0, 0, 20 + size.Y.Offset / 2))
    window:Hide()
    TestPump(0.8)
    samePosition(window.main.Position, defaultPosition)
    -- Also safe if invoked programmatically while the capsule is already visible.
    window.main.Position = UDim2.fromOffset(900, 450)
    window._collapsedPosition = window.main.Position
    reset.callback()
    TestPump(0.6)
    samePosition(window.main.Position, defaultPosition)
    reset.callback()
    TestPump(0.6)
    samePosition(window.main.Position, defaultPosition)
    window:Show()
    TestPump(0.8)
    samePosition(window.main.Position, UDim2.fromOffset(400, 300))
end
print("CAPSULE RESET: settings placement, both capsule styles, restore and repeated reset passed")
