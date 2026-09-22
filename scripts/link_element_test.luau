-- ===== Link (CreateLink) assertions =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The Link card carries a URL that is never rendered: it shows an icon, a
-- title and a subtitle, and its trailing control copies the hidden link and
-- confirms with a check mark before reverting. It is the first element whose
-- whole purpose lives outside the library's own surface — it has to reach the
-- host's clipboard — and the first whose feedback is a timed state that a
-- container can interrupt by hiding the card.
--
-- Expected behavior under test:
--   * L1 the card renders the icon, the title and the subtitle, and never the
--        URL it carries,
--   * L2 the trailing control is a real tap target carrying a resolved glyph,
--   * L3 a tap copies the hidden link through the host clipboard, swaps the
--        glyph for the confirmation, fires the callback and reverts on its own,
--   * L4 every card owns its cycle — a confirming card leaves its neighbour on
--        the copy mark,
--   * L5 the card builds in a Group and in a Collapsible Group, a card inside a
--        container copies its own link, and a card hidden while it is
--        confirming is back on the copy mark when the container reveals it,
--   * L6 the setters retitle the card, drop and restore the subtitle's height,
--        and the copy follows the link they wrote,
--   * L7 a locked card copies nothing and confirms nothing,
--   * L8 the compact row a horizontal Group asks for carries the same control
--        in the same trailing position,
--   * L9 with no clipboard API the card keeps the copy mark: the check mark
--        means the link is on the clipboard, so nothing else may show it,
--   * L10 the trailing glyph is drawn while the card is and hidden when it is
--        not — the card owns that fade, so nothing else can be relied on for it.

local function expect(cond, message)
	if not cond then
		error("LINK FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"LINK FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

-- [[The host clipboard: the API the library looks for, recorded per call. A
-- [[plain global, exactly where an executor puts it.]]
local copied = {}
setclipboard = function(text)
	copied[#copied + 1] = text
end

local function texts(inst, out)
	out = out or {}
	local props = inst.__props or {}
	if props.ClassName == "TextLabel" or props.ClassName == "TextButton" then
		out[#out + 1] = tostring(props.Text or "")
	end
	for _, child in inst:GetChildren() do
		texts(child, out)
	end
	return out
end

local window = Astra:CreateWindow({ name = "Link Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Links" })

local callbacks = 0
local card = tab:CreateLink({
	name = "Discord",
	subtitle = "Join our community",
	link = "https://discord.gg/astra",
	icon = "message-circle",
	callback = function(link)
		callbacks += 1
	end,
})
TestPump(0.4)

-- ===== L1: what the card shows, and what it never shows ====================

expect(card ~= nil, "L1 CreateLink returned an element")
eq(card.__type, "Link", "L1 the element reports its type")

local rendered = texts(card.main)
local showsTitle, showsSubtitle, leaksLink = false, false, false
for _, value in ipairs(rendered) do
	if value == "Discord" then
		showsTitle = true
	end
	if value == "Join our community" then
		showsSubtitle = true
	end
	if string.find(value, "discord.gg", 1, true) then
		leaksLink = true
	end
end
expect(showsTitle, "L1 the title renders")
expect(showsSubtitle, "L1 the subtitle renders")
expect(not leaksLink, "L1 the link is never rendered as text")
expect(card.iconLabel ~= nil, "L1 the leading icon renders")
eq(card.link, "https://discord.gg/astra", "L1 the link is stored on the element")

-- ===== L2: the copy control ================================================

expect(card.copyButton ~= nil, "L2 the card builds a copy control")
expect(card.tapIcon ~= nil, "L2 ... carrying a glyph")
expect(card.copyImage ~= nil and card.copyImage ~= "copy", "L2 the copy glyph resolved through the icon catalog")
expect(card.checkImage ~= nil and card.checkImage ~= "check", "L2 ... and so did the confirmation glyph")
expect(card.copyImage ~= card.checkImage, "L2 the two marks are different icons")
eq(card._glyph, "copy", "L2 the glyph rests on the copy mark")
eq(card:IsConfirming(), false, "L2 ... and the card is not mid-confirmation")
expect(card.copyButton.Size.X.Offset > card.tapIcon.Size.X.Offset, "L2 the tap target is bigger than the glyph")
expect(card.tapIcon.Parent == card.copyButton, "L2 the glyph sits inside the tap target")
eq(card.copyButton.Text, "", "L2 the control carries no text")

-- [[The glyph is built invisible like every other card part, and the card owns
-- [[its fade: `Window:_revealCommon` walks only the shared parts (stroke,
-- [[title, body, leading icon, description), so a glyph nothing reveals stays
-- [[at 1 forever and the control reads as an empty square. Both builds and
-- [[both marks — copy and check — ride the same label.]]
expect(card.tapIcon.ImageTransparency < 1, "L2 the shown card fades its glyph in")
eq(card.tapIcon.ImageTransparency, 0.5, "L2 ... to the resting glyph transparency")
eq(card.iconLabel.ImageTransparency, 0, "L2 ... and draws the leading icon fully")

-- ===== L3: tap, copy, confirm, revert ======================================

card.copyButton.MouseButton1Click:Fire()
TestPump(0.3)

eq(#copied, 1, "L3 the tap copied once")
eq(copied[1], "https://discord.gg/astra", "L3 ... the hidden link, not the title")
eq(card._glyph, "check", "L3 the glyph swapped to the check mark")
eq(card:IsConfirming(), true, "L3 ... and the card reports the confirmation window")
eq(callbacks, 1, "L3 the callback ran once")

TestPump(2.4)
eq(card._glyph, "copy", "L3 the glyph reverted to the copy mark on its own")
eq(card:IsConfirming(), false, "L3 ... and the confirmation window closed")

-- ===== L4: each card owns its cycle ========================================

local neighbour = tab:CreateLink({
	name = "YouTube",
	subtitle = "Watch the trailer",
	link = "https://youtu.be/astra",
})
TestPump(0.4)

card.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(card._glyph, "check", "L4 the tapped card confirms")
eq(neighbour._glyph, "copy", "L4 ... and its neighbour stays on the copy mark")

neighbour.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(neighbour._glyph, "check", "L4 tapping the neighbour confirms it instead")

-- [[The first card is still inside its own hold: a second tap must not be cut
-- [[short by the neighbour's cycle.]]
card.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
TestPump(2.4)
eq(card._glyph, "copy", "L4 a card's hold is its own, and it ends on the copy mark")
eq(neighbour._glyph, "copy", "L4 ... and so does its neighbour's")

-- ===== L5: Group and Collapsible Group =====================================

local group = tab:CreateGroup({ direction = "column" })
local inGroup = group:CreateLink({
	name = "Docs",
	subtitle = "Read the guide",
	link = "https://example.com/docs",
})
TestPump(0.4)

expect(inGroup ~= nil, "L5 a column Group accepts a link card")
eq(inGroup.compact, false, "L5 ... as a full card, with its whole layout")
expect(inGroup.copyButton ~= nil and inGroup.tapIcon ~= nil, "L5 ... and its own copy control")
eq(inGroup.main.Size.Y.Offset, 56, "L5 ... at the two-line height")

-- [[The structure the design calls for: several cards alongside other
-- [[components, every card keeping its whole layout and its own cycle.]]
group:CreateButton({ name = "Grouped button" })
local secondInGroup = group:CreateLink({
	name = "Support",
	subtitle = "Open a ticket",
	link = "https://example.com/support",
})
TestPump(0.4)
expect(secondInGroup ~= nil and secondInGroup.copyButton ~= nil, "L5 the Group takes another card next to a button")

inGroup.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(copied[#copied], "https://example.com/docs", "L5 tapping it copies that card's link")
eq(inGroup._glyph, "check", "L5 ... and confirms on that card alone")
eq(secondInGroup._glyph, "copy", "L5 ... while the other card in the same Group keeps the copy mark")

local collapsible = tab:CreateCollapsibleGroup({
	name = "Community",
	elements = {
		{ type = "Link", name = "Group Discord", subtitle = "Join us", link = "https://discord.gg/group" },
		{ type = "Link", name = "Group YouTube", subtitle = "Watch", link = "https://youtu.be/group" },
	},
})
TestPump(0.4)

eq(#collapsible.elements, 2, "L5 the Collapsible Group built both link cards")
local firstChild = collapsible.elements[1]
local secondChild = collapsible.elements[2]
expect(firstChild ~= nil and firstChild.__type == "Link", "L5 ... as link cards")
expect(firstChild.copyButton ~= nil, "L5 ... each with its copy control")

collapsible.interact.Activated:Fire()
TestPump(0.6)
expect(collapsible._expanded, "L5 the container opened")

firstChild.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(copied[#copied], "https://discord.gg/group", "L5 a card inside the container copies its own link")
eq(firstChild._glyph, "check", "L5 ... and confirms")
eq(secondChild._glyph, "copy", "L5 ... while its sibling keeps the copy mark")

-- [[Collapse over a confirming card: the hold ends with the card it belongs
-- [[to, so the container cannot carry the check mark into the next reveal.]]
collapsible.interact.Activated:Fire()
TestPump(0.8)
expect(not collapsible._expanded, "L5 the container closed")
eq(firstChild._glyph, "copy", "L5 closing returns the confirming card to the copy mark")
-- [[Collapsing puts the body away by visibility, not by pushing `_setShown`
-- [[into the children, so the glyph keeps its resting transparency here; the
-- [[hide/show fade itself is covered by L10, which uses a path that does.]]
eq(firstChild.tapIcon.ImageTransparency, 0.5, "L5 ... and leaves the glyph as the body hid it")

collapsible.interact.Activated:Fire()
TestPump(0.8)
expect(collapsible._expanded, "L5 the container reopened")
eq(firstChild._glyph, "copy", "L5 ... revealing the copy mark, not a stale check")

-- ===== L6: the setters =====================================================

card:SetLink("https://example.com/new")
eq(card.link, "https://example.com/new", "L6 SetLink rewrote the hidden link")

card:SetTitle("Website")
TestPump(0.2)
eq(card.title.Text, "Website", "L6 SetTitle retitled the card")

card:SetSubtitle("Fresh copy")
TestPump(0.2)
eq(card.subtitleLabel.Text, "Fresh copy", "L6 SetSubtitle rewrote the subtitle")

card.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(copied[#copied], "https://example.com/new", "L6 the copy follows the link the setter wrote")

card:SetSubtitle("")
TestPump(0.2)
eq(card.subtitleLabel.Visible, false, "L6 clearing the subtitle hides the line")
eq(card.main.Size.Y.Offset, 43, "L6 ... and the card drops to the single-line height")

card:SetSubtitle("Back again")
TestPump(0.2)
eq(card.subtitleLabel.Visible, true, "L6 restoring it brings the line back")
eq(card.main.Size.Y.Offset, 56, "L6 ... and grows the card again")

card:SetIcon(nil)
TestPump(0.2)
eq(card.iconLabel.Visible, false, "L6 SetIcon(nil) drops the leading icon")
card:SetIcon("link")
TestPump(0.2)
eq(card.iconLabel.Visible, true, "L6 SetIcon puts one back")

-- [[The slot exists on a card built without one, so a host can add an icon
-- [[later instead of the call doing nothing.]]
local bare = tab:CreateLink({ name = "No icon", subtitle = "Add one later", link = "https://example.com/bare" })
TestPump(0.4)
eq(bare.iconLabel.Visible, false, "L6 a card built without an icon hides the slot")
bare:SetIcon("link")
TestPump(0.2)
eq(bare.iconLabel.Visible, true, "L6 ... and SetIcon adds one to it anyway")

-- ===== L7: a locked card does not copy =====================================

local locked = tab:CreateLink({ name = "Locked", subtitle = "Nothing to copy", link = "https://example.com/locked" })
TestPump(0.4)
locked:Lock()
TestPump(0.4)

local beforeLocked = #copied
locked.copyButton.MouseButton1Click:Fire()
TestPump(0.4)
eq(#copied, beforeLocked, "L7 a locked card copies nothing")
eq(locked._glyph, "copy", "L7 ... and does not show the check mark")

locked:Unlock()
TestPump(0.4)
locked.copyButton.MouseButton1Click:Fire()
TestPump(0.4)
eq(copied[#copied], "https://example.com/locked", "L7 unlocking restores the copy")

-- ===== L8: the compact row =================================================

local row = tab:CreateGroup()
local inRow = row:CreateLink({ name = "Row link", subtitle = "In a row", link = "https://example.com/row" })
TestPump(0.4)

expect(inRow ~= nil, "L8 a row Group accepts a link card")
eq(inRow.compact, true, "L8 ... as a compact row")
expect(inRow.copyButton ~= nil and inRow.tapIcon ~= nil, "L8 ... carrying the same copy control")
eq(inRow.title.Parent, inRow.interact, "L8 the title sits in the row")
expect(
	inRow.tapIcon.Parent == inRow.copyButton and inRow.copyButton.Parent == inRow.interact,
	"L8 the control sits in the row too"
)
expect(inRow.title.LayoutOrder < inRow.copyButton.LayoutOrder, "L8 ... trailing the title")
eq(inRow.subtitleLabel.Text, "In a row", "L8 the subtitle rides the row")
eq(inRow.tapIcon.ImageTransparency, 0.5, "L8 the compact row fades its glyph in too")
expect(inRow:_minWidth() > 40, "L8 the row card declares a minimum width for the layout")

inRow.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(copied[#copied], "https://example.com/row", "L8 tapping it copies")
eq(inRow._glyph, "check", "L8 ... and confirms")

-- ===== L9: no clipboard, no check mark =====================================

setclipboard = nil
-- [[Reset the glyph first: the card under test has to be on the copy mark for
-- [[the assertion to mean anything.]]
card:_resetCopyState()
TestPump(0.2)

local beforeMissing = #copied
card.copyButton.MouseButton1Click:Fire()
TestPump(0.4)
eq(#copied, beforeMissing, "L9 without a clipboard API nothing is copied")
eq(card._glyph, "copy", "L9 the card keeps the copy mark instead of claiming success")

setclipboard = function(text)
	copied[#copied + 1] = text
end
card.copyButton.MouseButton1Click:Fire()
TestPump(0.3)
eq(copied[#copied], "https://example.com/new", "L9 the host clipboard is picked up per tap, not cached")

-- ===== L10: the glyph fades out and back with the card =====================

-- [[A hide path that really reaches the elements (`Window:Hide` walks the
-- [[selected tab's elements with `_setShown(false)`), unlike a container
-- [[collapse, which puts its body away by visibility. The glyph has to travel
-- [[both ways with the card: built at 1, drawn when the card is drawn, and
-- [[back at 1 when it is not, so a hidden card leaves no floating mark.]]
window:Hide()
TestPump(0.8)
eq(card.tapIcon.ImageTransparency, 1, "L10 hiding the window takes the glyph with it")
eq(card.iconLabel.ImageTransparency, 1, "L10 ... as it takes the leading icon")

window:Show()
TestPump(0.8)
eq(card.tapIcon.ImageTransparency, 0.5, "L10 showing it draws the glyph again")
eq(card.iconLabel.ImageTransparency, 0, "L10 ... and the leading icon")
eq(inRow.tapIcon.ImageTransparency, 0.5, "L10 the compact row's glyph comes back too")

window:Unload()
TestPump(0.1)

print("LINK: all assertions passed")
