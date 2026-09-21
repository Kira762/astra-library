-- [[Runtime test for the Isolated changelog container: header recipe, the
-- Changelog-only guard, runtime setters and the CollapsibleGroup-style
-- expansion tween. Runs under scripts/isolated_test.sh with the stub harness.]]
local window = Astra:CreateWindow({ name = "Isolated", configuration = { autoSave = false, autoLoad = false } })
local tab = window:CreateTab({ name = "Notes" })

local entries = {
	{
		version = "1.2.0",
		date = "2025-06-14",
		changes = {
			{ symbol = "+", text = "Added Isolated changelog container" },
			{ symbol = "~", text = "Chevron now rotates when expanded" },
		},
	},
	{
		version = "1.1.0",
		date = "2025-05-02",
		changes = { { symbol = "-", text = "Fixed CollapsibleGroup tween overflow" } },
	},
}

local panel = tab:CreateIsolated({
	name = "View Changelog",
	subtitle = "See what's new in this version",
	icon = "file-text",
	elements = {
		{ type = "Changelog", name = "History", entries = entries },
		{ type = "Changelog", name = "Beta", entries = { { version = "1.3.0-beta", changes = { { text = "Pending" } } } } },
	},
})
TestPump(1)

-- Header recipe: two-line stack, repo icon on the left, built-in chevron right.
assert(panel.__type == "Isolated", "CreateIsolated returns an Isolated container")
assert(panel.title.Text == "View Changelog", "Title renders the given name")
assert(panel.subtitleLabel.Text == "See what's new in this version", "Subtitle renders under the title")
assert(panel.headerHeight == 61, "Two-line header uses the 61px band")
assert(panel.main.Size.Y.Offset == 61, "Collapsed card is exactly the header band")
assert(panel.iconLabel and panel.iconLabel.Parent == panel.header, "Left icon label renders in the header")
assert(panel.icon == window:ResolveIcon("file-text"), "Left icon resolves from the repo packs")
assert(panel.iconLabel.Position.Y.Offset == 22, "Icon is centred on the two-line band")
assert(panel.chevron and panel.chevron.ClassName == "ImageLabel", "Chevron is the built-in expansion glyph")
assert(panel.chevron.Position.Y.Offset == 22, "Chevron is centred on the two-line band")
assert(panel.title.Position.X.Offset == 42 and panel.subtitleLabel.Position.X.Offset == 42, "Text stack clears the icon gutter")

-- Children: Changelog definitions only, rendered as regular children.
assert(#panel.elements == 2, "Both Changelog children are built")
assert(panel.elements[1].__type == "Changelog" and #panel.elements[1].entries == 2, "Changelog children keep their entries")
assert(panel.elements[1].main.Parent == panel.body, "Children live inside the reveal mask")

-- Guard: every non-Changelog child definition errors with the guard message.
local guardMessage = "Astra:CreateIsolated — only Changelog elements can be placed inside Isolated"
for _, bad in ipairs({
	{ type = "Button", name = "Nope" },
	{ type = "Toggle", name = "Nope" },
	{ type = "Text", name = "Nope", text = "nope" },
	{ type = "CollapsibleGroup", name = "Nope" },
	{ type = "Isolated", name = "Nope" },
	{ type = "Changelog", entries = {}, elements = {} },
	"changelog",
}) do
	local ok, message = pcall(function()
		return tab:CreateIsolated({ name = "Guard", elements = { bad } })
	end)
	assert(not ok, "Non-Changelog children must be rejected: " .. tostring(bad))
	assert(tostring(message) == guardMessage, "Guard message is exact, got: " .. tostring(message))
end
local okNested = pcall(function()
	return tab:CreateCollapsibleGroup({ name = "Wrap", elements = { { type = "Isolated", name = "Nope" } } })
end)
assert(not okNested, "Isolated containers cannot nest inside CollapsibleGroups")

-- Runtime setters for the changeable slots.
panel:SetTitle("Release Notes")
assert(panel.title.Text == "Release Notes", "SetTitle rewrites the header title")
panel:SetSubtitle("v1.2.0 is live")
assert(panel.subtitleLabel.Text == "v1.2.0 is live", "SetSubtitle rewrites the subtitle line")
panel:SetSubtitle(nil)
TestPump(0.3)
assert(panel.subtitleLabel.Text == "" and panel.headerHeight == 41, "Clearing the subtitle returns the single-line band")
assert(panel.main.Size.Y.Offset == 41, "Collapsed height follows the released subtitle band")
assert(panel.iconLabel.Position.Y.Offset == 12 and panel.chevron.Position.Y.Offset == 12, "Icon and chevron re-centre on the shorter band")
panel:SetSubtitle("See what's new in this version")
TestPump(0.3)
assert(panel.headerHeight == 61 and panel.main.Size.Y.Offset == 61, "Restoring the subtitle restores the two-line band")
local chevronImage = panel.chevron.Image
panel:SetIcon("scroll-text")
assert(panel.icon == window:ResolveIcon("scroll-text"), "SetIcon swaps the left icon")
assert(panel.chevron.Image == chevronImage, "SetIcon never touches the built-in chevron")
panel:SetIcon(nil)
assert(panel.iconLabel == nil and panel.title.Position.X.Offset == 20, "Clearing the icon returns the 20px gutter")
assert(panel.chevron.Image == chevronImage, "Clearing the icon never touches the built-in chevron")
panel:SetIcon("file-text")
assert(panel.iconLabel and panel.title.Position.X.Offset == 42, "Re-adding an icon restores the icon gutter")
assert(panel.icon == window:ResolveIcon("file-text"), "Re-added icon resolves from the repo packs")
-- The chevron has no setter on purpose.
assert(panel.SetChevron == nil and panel.SetChevronIcon == nil, "The built-in chevron exposes no setter")

-- Expansion behaves exactly like CollapsibleGroup: tap or public API.
assert(not panel._expanded and not panel.body.Visible, "Starts collapsed")
panel.contentLayout.AbsoluteContentSize = Vector2.new(400, 300)
panel:Expand()
TestPump(0.4)
assert(panel._expanded and panel.body.Visible and panel.bodyClip.Visible, "Expand reveals the body")
assert(panel.main.Size.Y.Offset == 61 + 1 + 10 + 300 + 10, "Expanded height is header + divider + padded content")
assert(panel.chevron.Rotation == 90, "Built-in chevron rotates open")
assert(panel.elements[1]._shown, "Changelog children reveal with the body")
panel:Toggle()
TestPump(0.4)
assert(not panel._expanded and not panel.body.Visible and panel.main.Size.Y.Offset == 61, "Toggle collapses back to the header")
assert(panel.chevron.Rotation == 0, "Chevron rotates closed")
panel.interact.Activated:Fire()
TestPump(0.4)
assert(panel._expanded, "Header tap still expands")
panel:Collapse()
TestPump(0.4)
assert(not panel._expanded, "Collapse closes from the public API")

-- Locking gates the header like every other lockable element.
panel:Lock()
panel.interact.Activated:Fire()
assert(not panel._expanded, "Locked header ignores taps")
panel:Unlock()
panel.interact.Activated:Fire()
TestPump(0.4)
assert(panel._expanded, "Unlocked header expands again")
panel:Collapse(false)

-- Instant motion profile settles synchronously, like CollapsibleGroup.
Astra.Motion.setProfile("instant")
panel:Expand()
assert(panel._expanded and panel.body.Visible and panel.chevron.Rotation == 90, "Instant expand is synchronous")
panel:Collapse()
assert(not panel.body.Visible and panel.chevron.Rotation == 0, "Instant collapse is synchronous")
Astra.Motion.setProfile("normal")

print("ISOLATED CONTAINER OK")
