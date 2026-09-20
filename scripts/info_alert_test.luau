-- Functional info badges were permanently removed. Legacy props and SetInfo
-- remain safe to pass/call, but must never allocate a badge or input bindings.
local function expect(condition, message)
    if not condition then
        error("INFO REMOVAL FAIL: " .. message, 0)
    end
end

local window = Astra:CreateWindow({ name = "Info removal" })
local tab = window:CreateTab({ name = "Controls" })
local clicked = 0
local controls = {
    tab:CreateButton({ name = "Button", info = "Old info", infoIcon = "circle-alert", callback = function() clicked += 1 end }),
    tab:CreateToggle({ name = "Toggle", Info = "Old alias", InfoIcon = "shield-check" }),
    tab:CreateSlider({ name = "Slider", tooltip = "Old tooltip", range = { 0, 10 }, value = 5 }),
    tab:CreateDropdown({ name = "Dropdown", Tooltip = "Old alias", options = { "A", "B" }, value = "A" }),
    tab:CreateInput({ name = "Input", info = "Old info", placeholder = "Type here" }),
}
local group = tab:CreateGroup({ name = "Group" })
table.insert(controls, group:CreateButton({ name = "Compact", info = "Old compact badge" }))
local described = tab:CreateButton({ name = "Description", description = "Keep the inline helper text." })
TestPump(2)

local function noBadges()
    for _, child in window.screenGui:GetDescendants() do
        expect(child.Name ~= "InfoIcon", "no functional info icon exists in the instance tree")
    end
    for _, control in controls do
        expect(control.infoButton == nil, "no info button field on " .. control.name)
    end
end
noBadges()
for _, control in controls do
    local size, automatic = control.title.Size, control.title.AutomaticSize
    control:SetInfo("Must not recreate the badge")
    control:SetInfo("")
    control:SetInfo(nil)
    expect(control.title.Size == size, "legacy setter does not change title geometry")
    expect(control.title.AutomaticSize == automatic, "legacy setter does not change title sizing")
end
noBadges()
expect(window.elementTooltip == nil, "no automatic info popup is allocated")
expect(described.descriptionLabel ~= nil, "inline descriptions remain supported")
controls[1].interact.MouseButton1Click:Fire()
TestPump(0.2)
expect(clicked == 1, "removing info does not break the button callback")
controls[2]:Set(true)
controls[3]:Set(7)
controls[4]:Set("B")
controls[5]:Set("Updated")
expect(controls[2].value == true and controls[3].value == 7, "toggle and slider still work")
expect(controls[4].value[1] == "B" and controls[5].value == "Updated", "dropdown and input still work")

-- The independent programmatic tooltip API is not an info badge.
window:ShowTooltip(controls[1].title, "Host-provided tooltip")
TestPump(0.2)
expect(window.elementTooltip ~= nil, "programmatic tooltip API still works")
window:HideTooltip()
window:Hide()
TestPump(1)
window:Show()
TestPump(1)
noBadges()
window:Unload()
TestPump(0.2)
print("INFO REMOVAL: no badge instances or runtime recreation; controls and manual tooltips work")
