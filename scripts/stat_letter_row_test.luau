--[[
===== Stat letter mode in a row Group =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau and pins what a letter Stat does where it cannot
have a badge: a row Group builds every child on the *compact* card, and the
compact card has no glyph surface.

  * the compact card carries the value in its readout odometer — the whole
    value ("A", "B+"), never a lone first letter, because a row card reads out
    text rather than drawing a badge,
  * showing the card reveals its accent fill, its outline, its title and that
    readout; hiding the card takes all four away again,
  * Set / SetText / ResetBaseline all write the readout,
  * the full (non-row) letter stat keeps its centered badge, and a row stat
    that is not in letter mode keeps the compact numeric card, so nothing that
    existed before changes.
]]

local function expect(cond, message)
	if not cond then
		error("STAT LETTER ROW FAIL: " .. tostring(message), 0)
	end
end

local window = Astra:CreateWindow({ name = "Stat Letter Row Test", configuration = { autoSave = false, autoLoad = false } })
TestPump(1.2)

local tab = window:CreateTab({ name = "Probe", icon = "house" })
tab:Select()
TestPump(0.3)

-- A row Group is what makes a Stat compact, and a compact card has no badge.
local row = tab:CreateGroup({ direction = "row" })
local rank = row:CreateStat({ name = "Rank", value = "A", letter = true })
TestPump(0.2)

expect(rank.compact == true, "a stat inside a row Group builds the compact card")
expect(rank.letter == true, "a text value with letter = true is in letter mode")
expect(rank.letterGlyph == nil, "the compact card builds no glyph badge")
expect(rank.glow == nil and rank.gradientContainer == nil, "and none of the full card's own surfaces")
expect(rank.textLabel == nil, "letter mode is not the text readout either")
expect(rank.readoutOdo ~= nil and rank.card ~= nil, "the letter rides the compact readout and its accent fill frame")
expect(rank.readoutOdo._lastText == "A", "the compact readout carries the value")

local readout = rank.readoutOdo.slots[0] and rank.readoutOdo.slots[0].static
expect(readout ~= nil and readout.Text == "A", "the value sits in the readout's own label")

-- Reveal round trip: the path a tab switch, a window show or a fold drives.
rank:_setShown(false, false)
TestPump(0.2)
expect(rank.card.BackgroundTransparency == 1, "hide takes the accent fill away")
expect(rank.stroke.Transparency == 1, "hide takes the outline away")
expect(rank.title.TextTransparency == 1, "hide takes the title away")
expect(readout.TextTransparency == 1, "hide takes the readout away")

rank:_setShown(true, false)
TestPump(0.2)
expect(rank.card.BackgroundTransparency == 0, "show reveals the accent fill")
expect(rank.stroke.Transparency < 1, "show reveals the outline")
expect(rank.title.TextTransparency == 0, "show reveals the title")
expect(readout.TextTransparency == 0, "show reveals the readout")

rank:_setShown(false, false)
TestPump(0.2)
rank:_setShown(true, false)
TestPump(0.2)
expect(rank.card.BackgroundTransparency == 0 and readout.TextTransparency == 0, "and a second show brings both back")

-- Every write path lands on the readout the compact card actually has.
rank:Set("B")
expect(rank.readoutOdo._lastText == "B", "Set rewrites the compact readout")
rank:SetText("Cobalt")
expect(rank.readoutOdo._lastText == "Cobalt", "SetText rewrites the compact readout")
rank:ResetBaseline("D")
expect(rank.readoutOdo._lastText == "D", "ResetBaseline rewrites the compact readout")

-- Affixes and multi-character values ride along: the row readout is the
-- value, not a digit roll and not a single glyph.
local affixed = row:CreateStat({ name = "Tier", value = "B+", letter = true, prefix = "< ", suffix = " >" })
TestPump(0.2)
affixed:_setShown(true, false)
TestPump(0.2)
expect(affixed.readoutOdo._lastText == "< B+ >", "the whole affixed value reads out")
local affixedLast = affixed.readoutOdo.slots[0] and affixed.readoutOdo.slots[0].static
expect(affixedLast ~= nil and affixedLast.Text == ">", "the trailing affix keeps the last slot")
expect(affixedLast.TextTransparency == 0, "the affixed readout reveals with the card")

-- Untouched: the full card keeps the centered badge.
local badge = tab:CreateStat({ name = "Region", value = "Onyx" })
TestPump(0.2)
expect(badge.compact == false and badge.letter == true, "a stat outside a row keeps the full card")
expect(badge.letterGlyph ~= nil and badge.letterGlyph.Text == "O", "the badge shows one letter")
badge:_setShown(true, false)
TestPump(0.2)
expect(badge.letterGlyph.TextTransparency == 0, "the badge reveals with the full card")
badge:_setShown(false, false)
TestPump(0.2)
expect(badge.letterGlyph.TextTransparency == 1, "and hides with it")
badge:SetText("Frost")
expect(badge.letterGlyph.Text == "F", "the badge still follows SetText")

-- Untouched: a numeric row stat keeps the compact numeric card.
local level = row:CreateStat({ name = "Level", value = 12 })
TestPump(0.2)
expect(level.compact == true and level.letter == false, "a numeric row stat is not in letter mode")
expect(level.readoutOdo ~= nil, "and keeps its readout odometer")
level:_setShown(false, false)
TestPump(0.2)
level:_setShown(true, false)
TestPump(0.2)
expect(level.card.BackgroundTransparency == 0, "and reveals its accent fill")
level:Set(13)
expect(level.value == 13, "and its Set still drives the value")

window:Unload()
TestPump(0.2)

print("STAT LETTER ROW: compact letter cards reveal, write and keep the full badge path")
