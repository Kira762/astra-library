-- ===== circle-alert description assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The circle-alert badge is the optional `info` description of a functional
-- element. This suite pins the contract the badge shipped broken against:
--
--   * A1 the badge is a sibling of the title and sits **right after the
--        name** - explicit `SortOrder = LayoutOrder` on the row, badge order
--        one past the title's, nothing between the two (the row's default
--        Name sort put "InfoIcon" in front of "TextLabel" instead),
--   * A2 `info` is optional and may be empty: no badge, and the title keeps
--        the width recipe it has without one,
--   * A3 hovering the badge opens the floating description with the element's
--        own text, and leaving closes it,
--   * A4 tapping toggles: open on the first tap (pinned, an existing hover
--        preview is kept and pinned instead), closed on the next,
--   * A5 press-and-hold opens it while the finger is still down and the
--        description stays after release - the gesture touch devices use,
--        where no hover ever fires,
--   * A6 hiding or closing the window takes every description with it, and a
--        press that was waiting out its hold cannot reopen one afterwards,
--   * A7 switching tabs closes the description of the tab being left,
--   * A8 `:SetInfo(text)` adds the badge after the name at runtime,
--        `:SetInfo(nil)` / `:SetInfo(\"\")` removes it and gives the title its
--        width back,
--   * A9 only one description is open at a time: a second badge takes it over,
--   * A10 the badge draws above the card's own click surface, so the tap
--        reaches the badge and not the control underneath,
--   * A11 the compact row (a Group's button) gets the same placement,
--   * A12 `infoIcon` replaces the badge glyph,
--   * A13 `Window:Close()` takes the descriptions with it.

local function expect(cond, message)
    if not cond then
        error("INFO ALERT FAIL: " .. tostring(message), 0)
    end
end

local function eq(actual, wanted, message)
    if actual ~= wanted then
        error(
            "INFO ALERT FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
            0
        )
    end
end

local function layoutOf(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UIListLayout") then
            return child
        end
    end
    return nil
end

-- [[The badge exists, belongs to the row that holds the title, and is the
-- [[next thing drawn after the name.]] 
local function assertPlaced(element, label)
    local badge = element.infoButton
    expect(badge ~= nil, label .. ": the circle-alert badge exists")
    if not badge then
        return
    end

    eq(badge.Name, "InfoIcon", label .. ": the badge is the info icon")
    eq(badge.Parent, element.title.Parent, label .. ": the badge shares the name's row")
    eq(badge.LayoutOrder, (element.title.LayoutOrder or 0) + 1, label .. ": the badge holds the slot after the name")

    local layout = layoutOf(badge.Parent)
    expect(layout ~= nil, label .. ": the row is laid out")
    eq(layout.SortOrder, Enum.SortOrder.LayoutOrder, label .. ": the row states an explicit order, not Name sort")

    for _, child in ipairs(badge.Parent:GetChildren()) do
        if child ~= badge and child ~= element.title and child:IsA("GuiObject") then
            local order = child.LayoutOrder or 0
            if order > (element.title.LayoutOrder or 0) and order < badge.LayoutOrder then
                error("INFO ALERT FAIL: " .. label .. ": " .. tostring(child.Name) .. " sits between the name and the badge", 0)
            end
        end
    end

    if element.iconLabel then
        expect(
            (element.iconLabel.LayoutOrder or 0) < (element.title.LayoutOrder or 0),
            label .. ": the icon stays left of the name"
        )
    end

    if element.interact then
        expect(
            badge.ZIndex > (element.interact.ZIndex or 0),
            label .. ": the badge draws above the card's click surface"
        )
    end
end

local window = Astra:CreateWindow({ name = "Info Alert Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Alerts" })

local button = tab:CreateButton({
    name = "Button",
    icon = "hand-tap",
    info = "Runs the action.",
    callback = function() end,
})
local toggle = tab:CreateToggle({
    name = "Toggle",
    info = "Turns the switch on.",
    callback = function() end,
})
local slider = tab:CreateSlider({
    name = "Slider",
    info = "Sets the level.",
    range = { 1, 10 },
    value = 5,
    suffix = "x",
    callback = function() end,
})
local dropdown = tab:CreateDropdown({
    name = "Dropdown",
    info = "Picks a preset.",
    options = { "Low", "High" },
    value = "Low",
    callback = function() end,
})
local input = tab:CreateInput({
    name = "Input",
    info = "Types the value.",
    placeholder = "Value",
    callback = function() end,
})

-- [[No description at all: absent, empty and whitespace-only all mean the
-- [[same thing - no badge, no reserved room.]] 
local plain = tab:CreateToggle({ name = "Plain", callback = function() end })
local blank = tab:CreateToggle({ name = "Blank", info = "   ", callback = function() end })
local empty = tab:CreateButton({ name = "Empty", info = "", callback = function() end })
local emptySlider = tab:CreateSlider({
    name = "Empty Slider",
    info = "",
    range = { 0, 1 },
    value = 0,
    callback = function() end,
})
local emptyDropdown = tab:CreateDropdown({
    name = "Empty Dropdown",
    info = "",
    options = { "One" },
    value = "One",
    callback = function() end,
})
local emptyInput = tab:CreateInput({
    name = "Empty Input",
    info = "",
    placeholder = "Value",
    callback = function() end,
})
local customIcon = tab:CreateButton({
    name = "Custom Icon",
    info = "Custom glyph.",
    infoIcon = "rbxassetid://1234567890",
    callback = function() end,
})

TestPump(0.8)

-- ===== A1: the badge follows the name ======================================

assertPlaced(button, "A1 Button")
assertPlaced(toggle, "A1 Toggle")
assertPlaced(slider, "A1 Slider")
assertPlaced(dropdown, "A1 Dropdown")
assertPlaced(input, "A1 Input")

-- ===== A2: the description is optional, empty means no badge ===============

for _, case in ipairs({
    { plain, "A2 no info" },
    { blank, "A2 whitespace info" },
    { empty, "A2 empty info" },
    { emptySlider, "A2 empty slider info" },
    { emptyDropdown, "A2 empty dropdown info" },
    { emptyInput, "A2 empty input info" },
}) do
    local element, label = case[1], case[2]
    eq(element.infoButton, nil, label .. ": no badge is built")
    eq(element.title.AutomaticSize, Enum.AutomaticSize.None, label .. ": the title keeps its fixed width")
    eq(element.title.Size.X.Scale, 1, label .. ": the title still fills the row")
end

-- ===== A3: hover opens and leaving closes ==================================

local badge = toggle.infoButton
eq(window.elementTooltip, nil, "A3 no panel exists until a description is asked for")

badge.MouseEnter:Fire()
TestPump(0.05)

local tip = window.elementTooltip
expect(tip ~= nil, "A3 the window owns one floating description panel")
eq(tip.Visible, true, "A3 hovering the badge opens the description")
eq(tip.Label.Text, "Turns the switch on.", "A3 the description shows the element's own info text")
eq(window._tooltipAnchor, badge, "A3 the open description knows which badge it belongs to")

badge.MouseLeave:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A3 leaving the badge closes the hovering description")
eq(window._tooltipAnchor, nil, "A3 the closed panel releases its anchor")

-- ===== A4: tap toggles =====================================================

badge.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A4 a tap opens the description")
eq(window._tooltipPinned, true, "A4 a tapped description is pinned")
eq(tip.Label.Text, "Turns the switch on.", "A4 the tapped description carries the text")

badge.MouseLeave:Fire()
TestPump(0.3)
eq(tip.Visible, true, "A4 a pinned description survives the pointer leaving")

badge.MouseEnter:Fire()
TestPump(0.05)
expect(window._tooltipPinned == true, "A4 hovering a pinned description leaves it pinned")

badge.Activated:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A4 tapping the badge again closes the description")

-- ===== A5: press-and-hold ==================================================

badge.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch })
TestPump(0.1)
eq(tip.Visible, false, "A5 a hold shorter than the threshold has not opened yet")

TestPump(0.3)
eq(tip.Visible, true, "A5 holding the badge opens the description while the finger is down")
eq(tip.Label.Text, "Turns the switch on.", "A5 the held description carries the text")

badge.InputEnded:Fire({ UserInputType = Enum.UserInputType.Touch })
badge.Activated:Fire()
TestPump(0.1)
eq(tip.Visible, true, "A5 the description stays open after the hold is released")

badge.Activated:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A5 a tap after the hold closes it again")

-- [[A quick tap is not a hold: the press is released before the threshold.]] 
badge.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch })
badge.InputEnded:Fire({ UserInputType = Enum.UserInputType.Touch })
badge.Activated:Fire()
TestPump(0.4)
eq(tip.Visible, true, "A5 a quick tap still opens the description")
eq(tip.Label.Text, "Turns the switch on.", "A5 the tapped description carries the text")
badge.Activated:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A5 and the next tap closes it")

-- ===== A6: the window owns the descriptions ================================

badge.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A6 a description is open before the window hides")

window:Hide()
TestPump(0.5)
eq(tip.Visible, false, "A6 hiding the window closes the description")
eq(window._tooltipAnchor, nil, "A6 the hidden window releases the anchor")

-- [[The regression this suite was written for: a press that began before the
-- [[window hid must not reopen a description behind the fold.]] 
window:Show()
TestPump(0.6)
badge.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch })
window:Hide()
TestPump(0.8)
eq(tip.Visible, false, "A6 a hold interrupted by the window hiding never opens")

window:Show()
TestPump(0.6)

-- ===== A7: switching tabs closes descriptions ==============================

badge.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A7 a description is open before the tab switch")

local other = window:CreateTab({ name = "Other" })
other:Select()
TestPump(0.5)
eq(tip.Visible, false, "A7 switching tabs closes the description of the tab being left")

tab:Select()
TestPump(0.6)

-- ===== A8: SetInfo adds and removes the badge ==============================

local runtime = tab:CreateButton({ name = "Runtime", callback = function() end })
TestPump(0.3)
eq(runtime.infoButton, nil, "A8 an element without info carries no badge")

runtime:SetInfo("Appears on demand.")
TestPump(0.1)
assertPlaced(runtime, "A8 runtime SetInfo")
eq(runtime.infoButton.ImageTransparency, 0.45, "A8 a badge added at runtime joins the revealed row")

runtime.infoButton.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A8 the runtime badge opens the description")
eq(tip.Label.Text, "Appears on demand.", "A8 the runtime description carries the new text")

runtime:SetInfo("")
TestPump(0.3)
eq(runtime.infoButton, nil, "A8 clearing the text removes the badge")
eq(runtime.title.AutomaticSize, Enum.AutomaticSize.None, "A8 the title gets its width recipe back")
eq(tip.Visible, false, "A8 clearing the text closes the description")

runtime:SetInfo(nil)
TestPump(0.1)
eq(runtime.infoButton, nil, "A8 a nil text leaves the badge away")

runtime:SetInfo("Second copy.")
TestPump(0.1)
assertPlaced(runtime, "A8 re-added badge")
eq(runtime.infoButton.Parent:FindFirstChild("InfoIcon"), runtime.infoButton, "A8 only one badge exists per element")

-- ===== A9: one description at a time =======================================

toggle.infoButton.Activated:Fire()
TestPump(0.05)
eq(window._tooltipAnchor, toggle.infoButton, "A9 the toggle's badge owns the description")

button.infoButton.Activated:Fire()
TestPump(0.05)
eq(window._tooltipAnchor, button.infoButton, "A9 a second badge takes the description over")
eq(tip.Label.Text, "Runs the action.", "A9 the description carries the second element's text")
eq(tip.Visible, true, "A9 the description stays open across the handover")

button.infoButton.Activated:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A9 closing the second badge leaves nothing open")

-- ===== A10: the badge is above the card's click surface ====================

for _, case in ipairs({
    { button, "A10 Button" },
    { toggle, "A10 Toggle" },
    { slider, "A10 Slider" },
    { dropdown, "A10 Dropdown" },
}) do
    local element, label = case[1], case[2]
    if element.interact then
        expect(
            element.infoButton.ZIndex > element.interact.ZIndex,
            label .. ": the badge outranks the card's click surface"
        )
    end
end

-- ===== A11: the compact row places the badge the same way ==================

local group = tab:CreateGroup()
local compactButton = group:CreateButton({
    name = "Compact",
    info = "Compact row copy.",
    callback = function() end,
})
TestPump(0.4)

assertPlaced(compactButton, "A11 group button")
compactButton.infoButton.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A11 the compact badge opens the description")
eq(tip.Label.Text, "Compact row copy.", "A11 the compact description carries the text")
compactButton.infoButton.Activated:Fire()
TestPump(0.3)
eq(tip.Visible, false, "A11 and closes it again")

-- ===== A12: infoIcon replaces the badge glyph =============================

assertPlaced(customIcon, "A12 custom icon")
eq(customIcon.infoButton.Image, "rbxassetid://1234567890", "A12 the badge uses the requested glyph")

-- ===== A13: closing the window closes descriptions ========================

customIcon.infoButton.Activated:Fire()
TestPump(0.05)
eq(tip.Visible, true, "A13 a description is open before the window closes")

window:Close()
TestPump(0.6)
eq(tip.Visible, false, "A13 closing the window closes the description")
eq(window._tooltipAnchor, nil, "A13 the closed window releases the anchor")

print("INFO ALERT OK")
