-- The minimal Enum stub omits EnumType; Roblox supplies it on real keys.
Enum.KeyCode.P.EnumType = Enum.KeyCode
local window = Astra:CreateWindow({ name = "Collapsible groups", configuration = { autoSave = false, autoLoad = false } })
local tab = window:CreateTab({ name = "Controls" })
local callbacks = 0
local defs = {
    { type = "Button", name = "Action", callback = function() callbacks += 1 end },
    { type = "Toggle", name = "Active", flag = "active", value = true, callback = function() callbacks += 1 end },
    { type = "Switch", name = "Switch", value = false },
    { type = "Slider", name = "Speed", flag = "speed", range = { 0, 100 }, value = 50 },
    { type = "Dropdown", name = "Mode", options = { "Normal", "Sprint" }, value = "Sprint" },
    { type = "Input", name = "Nickname", value = "Player" },
    { type = "Keybind", name = "Hotkey", value = Enum.KeyCode.P, callback = function() callbacks += 1 end },
    { type = "Stat", name = "Score", value = 10 },
    { type = "Progress", name = "Loading", value = 50 },
    { type = "Console", name = "Log" },
    { type = "Section", name = "Section" },
    { type = "Text", name = "Help", text = "Contents" },
    { type = "Changelog", name = "Changes", entries = { { version = "1", changes = { { text = "Added" } } } } },
    { type = "Divider", text = "End" },
    { type = "Group", elements = {
        { type = "Button", name = "Reset" }, { type = "Button", name = "Apply" },
    } },
    { type = "Group", elements = {
        { type = "Input", name = "Nested input", value = "inside" },
        { type = "Group", elements = { { type = "Toggle", name = "Nested toggle", value = true } } },
    } },
}
local group = tab:CreateCollapsibleGroup({ name = "LocalPlayer", icon = "user-round", description = "Player controls", elements = defs })
local other = tab:CreateCollapsibleGroup({ name = "Other", elements = { { type = "Text", name = "Independent", text = "text" } } })
TestPump(1)
assert(#group.elements == #defs, "Every tab element type must be supported")
assert(group.elements[15].compact, "Compact ordinary Groups remain rows")
assert(not group.elements[16].compact, "Noncompact elements in ordinary Groups become columns")
assert(not group._expanded and not group.body.Visible, "Starts collapsed without a usage option")
assert(window:Get("active") == true and window:Get("speed") == 50, "Collapsed controls register their values")

-- The header must use the standard element surface recipe: a white base under
-- StyleElementBody's ElementGradient, exactly like every other element. A
-- themed base color would be multiplied by the gradient and draw nearly black.
local toggle = group.elements[2]
local base = group.header.BackgroundColor3
assert(base.R == 1 and base.G == 1 and base.B == 1, "Header keeps the plain white gradient base")
local function gradientOf(frame)
    for _, child in frame:GetChildren() do
        if child.ClassName == "UIGradient" then return child end
    end
    return nil
end
assert(gradientOf(group.header) and gradientOf(group.header).Color == gradientOf(toggle.main).Color, "Header gradient matches element surfaces")

-- The stub does not simulate UIListLayout measurement; drive its engine signal.
group.contentLayout.AbsoluteContentSize = Vector2.new(400, 900)
group.interact.Activated:Fire()
TestPump(0.4)
assert(group._expanded and group.body.Visible and group.main.Size.Y.Offset == group.headerHeight + 914, "Expand to content height")
assert(group.chevron.Rotation == 90, "Chevron animates open")
assert(not other._expanded, "Sibling expansion is independent")
group.interact.Activated:Fire()
TestPump(0.4)
assert(not group.body.Visible and group.main.Size.Y.Offset == group.headerHeight, "Collapse releases layout height")
assert(callbacks == 0, "Opening and closing must never run value callbacks")
Astra.Core.state.userInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, false)
TestPump(0.1)
assert(callbacks == 1, "Keybinds keep functioning while collapsed")
assert(window:_keybindUsing(Enum.KeyCode.P) == group.elements[7], "Conflict checks include grouped keybinds")
group.elements[4]:Set(75)
TestPump(0.1)
group.interact.Activated:Fire()
TestPump(0.4)
assert(window:Get("active") == true and window:Get("speed") == 75, "Reopen retains current state")

for _, mode in { "sidebar", "collapsedSidebar", "top" } do
    window:_setLayoutMode(mode)
    TestPump(0.8)
    assert(group._expanded and group.body.Visible, "Layout changes keep expanded state")
    assert(group.main.Parent == tab.tabPage and group.elements[1].main.Parent == group.body, "Layout preserves ownership")
end
-- Closing an open dropdown or editor must preserve committed values.
local dropdown = group.elements[5]
dropdown:_open()
TestPump(0.4)
assert(dropdown._isOpen, "Dropdown opens inside the container")
local input = group.elements[6]
local focused = true
input.input.IsFocused = function() return focused end
input.input.ReleaseFocus = function()
    focused = false
    input.input.FocusLost:Fire()
end
input.input.Text = "Uncommitted edit"
local keybind = group.elements[7]
keybind.keyLabel.IsFocused = function() return false end
keybind:_startRecording()
group.interact.Activated:Fire()
TestPump(0.5)
assert(not dropdown._isOpen and dropdown.value[1] == "Sprint", "Collapse closes menu without changing its selection")
assert(not focused and input.value == "Player" and input.input.Text == "Player", "Collapse cancels uncommitted edits")
assert(not keybind.recording and keybind.value == Enum.KeyCode.P, "Collapse cancels recording without changing binding")
group.interact.Activated:Fire()
TestPump(0.4)
-- Ordinary element locking applies to the container header.
group:Lock()
group.interact.Activated:Fire()
assert(group._expanded, "Locked header ignores interaction")
group:Unlock()

-- Fast reversals and instant motion must settle correctly.
for _ = 1, 5 do group.interact.Activated:Fire() end
TestPump(0.5)
assert(not group._expanded and not group.body.Visible, "Rapid clicks settle collapsed")
Astra.Motion.setProfile("instant")
group.interact.Activated:Fire()
assert(group._expanded and group.body.Visible and group.chevron.Rotation == 90, "Instant animation profile")
group.interact.Activated:Fire()
assert(not group.body.Visible, "Instant collapse is synchronous")
Astra.Motion.setProfile("normal")

-- Search includes children, temporarily expands matches, then restores state.
window.searchAction.callback()
TestPump(0.3)
window.searchInput.Text = "Nickname"
assert(group._expanded and group.main.Visible, "Search reveals matching hidden controls")
window.searchAction.callback()
TestPump(0.3)
assert(not group._expanded and not group.body.Visible, "Search restores prior collapsed state")

-- Validate before creating anything, including nesting hidden inside Group.
for _, invalid in {
    { { type = "CollapsibleGroup", elements = {} } },
    { { type = "Group", elements = { { type = "CollapsibleGroup" } } } },
    { { type = "NotAnElement" } },
} do
    local count = #window.instances
    local ok = pcall(function() tab:CreateCollapsibleGroup({ elements = invalid }) end)
    assert(not ok and #window.instances == count, "Invalid definitions must leave no partial UI")
end
local cyclic = {}
cyclic[1] = { type = "Group", elements = cyclic }
assert(not pcall(function() tab:CreateCollapsibleGroup({ elements = cyclic }) end), "Cycles must be rejected")
local count = #window.instances
group:MoveToBottom()
assert(tab.elements[#tab.elements] == group, "Group supports normal element ordering")
assert(#window.instances == count, "Open/close/move reuses controls")
tab:Remove()
assert(window:Get("active") == nil and window:Get("speed") == nil, "Removing tab unregisters nested controls")
local before = callbacks
Astra.Core.state.userInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, false)
TestPump(0.1)
assert(callbacks == before, "Removing the tab disconnects nested keybinds")
print("COLLAPSIBLE: all element types, state, layouts, motion, search, validation and cleanup passed")
