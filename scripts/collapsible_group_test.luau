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
    { type = "Stat", name = "Score", value = 10 },
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
local group = tab:CreateCollapsibleGroup({ name = "LocalPlayer", icon = "user-round", elements = defs })
local other = tab:CreateCollapsibleGroup({ name = "Other", elements = { { type = "Text", name = "Independent", text = "text" } } })
TestPump(1)
assert(#group.elements == #defs, "Every tab element type must be supported")
assert(group.elements[12].compact, "Compact ordinary Groups remain rows")
assert(not group.elements[13].compact, "Noncompact elements in ordinary Groups become columns")
assert(not group._expanded and not group.body.Visible, "Starts collapsed without a usage option")
assert(window:Get("active") == true and window:Get("speed") == 50, "Collapsed controls register their values")

-- The header must use the standard element surface recipe: a white base under
-- StyleElementBody's ElementGradient, exactly like every other element. A
-- themed base color would be multiplied by the gradient and draw nearly black.
local toggle = group.elements[2]
local base = group.headerSurface.BackgroundColor3
assert(base.R == 1 and base.G == 1 and base.B == 1, "Header keeps the plain white gradient base")
local function gradientOf(frame)
    for _, child in frame:GetChildren() do
        if child.ClassName == "UIGradient" then return child end
    end
    return nil
end
assert(gradientOf(group.headerSurface) and gradientOf(group.headerSurface).Color == gradientOf(toggle.main).Color, "Header gradient matches element surfaces")

-- One connected card: the container clips its surfaces to the rounded
-- silhouette with a border stroke, the header band rides the element
-- gradient over the darker body surface, and a 1px divider separates them.
-- The reveal mask spans the container and rides its bottom edge; children at
-- UDim2.new(1, -20) of the full-width body land one gutter inside on each
-- side instead of running edge to edge against the container stroke.
assert(group.main.ClipsDescendants, "Container clips its surfaces to the rounded silhouette")
assert(group.stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border, "Outer stroke uses a supported border mode")
assert(group.bodyClip.ClipsDescendants, "Only the body clipper masks content")
assert(group.bodyClip.Size.X.Scale == 1 and group.bodyClip.Size.X.Offset == 0, "Clipper spans the container")
assert(group.bodyClip.Position.Y.Offset == group.headerHeight + 1, "Clipper starts under the divider")
assert(group.body.Size.X.Scale == 1 and group.body.Size.X.Offset == 0, "Body spans the clipper")
assert(group.body.Position.Y.Offset == 10, "Content starts one gutter under the divider")
assert(not group.divider.Visible, "Divider stays hidden while collapsed")
local containerCorner
local containerGradient
for _, child in group.main:GetChildren() do
    if child.ClassName == "UICorner" then containerCorner = child end
    if child.ClassName == "UIGradient" then containerGradient = child end
end
assert(containerCorner and containerCorner.CornerRadius == window.theme.ElementCornerRadius, "Container keeps the element corner radius")
-- Roblox rounds a GuiObject's own surface but never clips its descendants to
-- the arcs, so the band (a child, spanning the full width) used to fill the
-- card's top-left and top-right corners and square off the silhouette the
-- stroke draws. The band now carries the container's own top-corner radius,
-- and the container's surface is the element surface the band paints, so the
-- corner arcs resolve to the band's colour instead of the body's.
assert(containerGradient and containerGradient.Color == window.theme.ElementGradient, "Container surface matches the header band")
local bandCorner
for _, child in group.headerSurface:GetChildren() do
    if child.ClassName == "UICorner" then bandCorner = child end
end
assert(bandCorner, "Header band rounds its own corners")
assert(bandCorner.TopLeftRadius == window.theme.ElementCornerRadius, "Band's top-left corner matches the container arc")
assert(bandCorner.TopRightRadius == window.theme.ElementCornerRadius, "Band's top-right corner matches the container arc")
-- Collapsed, the band is the whole card, so its bottom edge is the card's bottom
-- edge: it carries the container's bottom arcs too, or its square corners paint
-- past the stroke and the card reads rounded on top and uneven below.
assert(bandCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Closed band carries the container's bottom-left arc")
assert(bandCorner.BottomRightRadius == window.theme.ElementCornerRadius, "Closed band carries the container's bottom-right arc")
assert(group.headerCorner == bandCorner, "The band keeps one corner for both states")
-- The revealed body's darker window surface is painted by the clipper, which
-- is flush with the container's bottom edge and keeps its arcs.
local bodyCorner
local bodyGradient
for _, child in group.bodyClip:GetChildren() do
    if child.ClassName == "UICorner" then bodyCorner = child end
    if child.ClassName == "UIGradient" then bodyGradient = child end
end
assert(bodyGradient and bodyGradient.Color == window.theme.WindowColor, "Body clipper paints the window surface")
assert(bodyCorner, "Body clipper rounds its own corners")
assert(bodyCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Body keeps the container's bottom-left arc")
assert(bodyCorner.BottomRightRadius == window.theme.ElementCornerRadius, "Body keeps the container's bottom-right arc")
assert(bodyCorner.TopLeftRadius.Scale == 0 and bodyCorner.TopLeftRadius.Offset == 0, "Body's top-left corner stays square under the divider")
assert(bodyCorner.TopRightRadius.Scale == 0 and bodyCorner.TopRightRadius.Offset == 0, "Body's top-right corner stays square under the divider")
-- Grouped children render as defined cards: a visible stroke and a surface a
-- shade under the header band, like the design reference.
assert(window.theme.CollapsibleChildElementStrokeTransparency == 0, "Grouped child cards keep a visible stroke")
-- Header metrics mirror the Text element.
assert(group.title.TextColor3 == window.theme.TitlingColor, "Title uses the Text title color")
assert(group.title.Position.X.Offset == 42, "Icon-to-text gap matches the Text element")
assert(group.chevron.Position.X.Offset == -36, "Chevron keeps the 20px Text gutter")
-- Children keep their normal recipes; the clipper compensates, so inner
-- content resolves to exactly the header's width (no second inset).
assert(group.elements[9].main.Size.X.Offset == -20, "Text child keeps its normal width recipe")
assert(group.elements[8].main.Size.X.Offset == -40, "Section child keeps its normal width recipe")

-- The stub does not simulate UIListLayout measurement; drive its engine signal.
group.contentLayout.AbsoluteContentSize = Vector2.new(400, 900)
group.interact.Activated:Fire()
TestPump(0.4)
assert(group._expanded and group.body.Visible and group.bodyClip.Visible and group.main.Size.Y.Offset == group.headerHeight + 921, "Expand to divider + padded content height")
assert(group.divider.Visible, "Divider reveals with the body")
-- Open, the band stops at the straight divider and the clipper below takes the
-- card's bottom edge, so the bottom pair squares off again on the same corner.
assert(bandCorner.TopLeftRadius == window.theme.ElementCornerRadius, "Open band keeps the container's top arcs")
assert(bandCorner.BottomLeftRadius.Scale == 0 and bandCorner.BottomLeftRadius.Offset == 0, "Open band squares its bottom-left against the divider")
assert(bandCorner.BottomRightRadius.Scale == 0 and bandCorner.BottomRightRadius.Offset == 0, "Open band squares its bottom-right against the divider")
assert(toggle.stroke.Transparency == 0, "Grouped child stroke is painted once revealed")
assert(toggle.main.BackgroundTransparency < 0.5, "Grouped child cards keep a defined surface")
assert(group.chevron.Rotation == 90, "Chevron animates open")
assert(not other._expanded, "Sibling expansion is independent")
group.interact.Activated:Fire()
TestPump(0.4)
assert(not group.body.Visible and not group.bodyClip.Visible and group.main.Size.Y.Offset == group.headerHeight, "Collapse releases layout height")
assert(bandCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Settled collapse hands the bottom arc back to the band")
assert(bandCorner.BottomRightRadius == window.theme.ElementCornerRadius, "Settled collapse rounds both bottom corners of the band")
assert(callbacks == 0, "Opening and closing must never run value callbacks")
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
group.interact.Activated:Fire()
TestPump(0.5)
assert(not dropdown._isOpen and dropdown.value[1] == "Sprint", "Collapse closes menu without changing its selection")
assert(not focused and input.value == "Player" and input.input.Text == "Player", "Collapse cancels uncommitted edits")
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
assert(not group._expanded and not group.body.Visible and not group.bodyClip.Visible, "Rapid clicks settle collapsed")
assert(bandCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Reversed clicks still settle on a rounded closed band")
Astra.Motion.setProfile("instant")
group.interact.Activated:Fire()
assert(group._expanded and group.body.Visible and group.bodyClip.Visible and group.chevron.Rotation == 90, "Instant animation profile")
assert(bandCorner.BottomLeftRadius.Scale == 0 and bandCorner.BottomLeftRadius.Offset == 0, "Instant expand squares the band in the same step")
group.interact.Activated:Fire()
assert(not group.body.Visible and not group.bodyClip.Visible, "Instant collapse is synchronous")
assert(bandCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Instant collapse rounds the band in the same step")
Astra.Motion.setProfile("normal")

-- The corner set is re-read from the theme, so a radius change follows the
-- band's bottom arcs as well as the container's own (ChangeTheme binds the
-- band's top corners directly; the element's refresh owns the bottom pair).
local elementRadius = window.theme.ElementCornerRadius
window:ChangeTheme({ ElementCornerRadius = UDim.new(0, 5) })
TestPump(0.2)
group:_refreshTheme()
assert(bandCorner.TopLeftRadius == window.theme.ElementCornerRadius, "Theme radius reaches the band's top corner")
assert(bandCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Theme radius reaches the closed band's bottom corner")
assert(bodyCorner.BottomLeftRadius == window.theme.ElementCornerRadius, "Theme radius reaches the body clipper")
window:ChangeTheme({ ElementCornerRadius = elementRadius })
TestPump(0.2)
group:_refreshTheme()
assert(bandCorner.BottomLeftRadius == elementRadius, "Restored radius returns to the closed band")

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
print("COLLAPSIBLE: all element types, state, layouts, motion, search, validation and cleanup passed")
