--[[
===== Stat text-readout assertions =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau and pins the Stat's third presentation:
  * a string value that opts out of the letter badge (letter = false) reads
    the whole value out in one TextLabel — no odometer, no change readout,
    in the full card and in the compact row card,
  * the label reveals and hides with the card,
  * Set / SetText / ResetBaseline all write to it, prefix and suffix still
    wrap the value,
  * numeric stats keep their odometers and text values still default to the
    single-letter badge, so nothing that existed before changes.
]]

local function expect(cond, message)
	if not cond then
		error("STAT TEXT FAIL: " .. tostring(message), 0)
	end
end

local window = Astra:CreateWindow({ name = "Stat Text Test", configuration = { autoSave = false, autoLoad = false } })
TestPump(1.2)

local tab = window:CreateTab({ name = "Probe", icon = "house" })
tab:Select()
TestPump(0.3)

-- Full card: one label, the whole value, affixes intact.
local full = tab:CreateStat({ name = "Theme", value = "Emerald", letter = false, prefix = "< ", suffix = " >" })
TestPump(0.2)
expect(full.textValue == true, "a string value with letter = false is a text readout")
expect(full.letter == false, "and it is not in letter mode")
expect(full.letterGlyph == nil, "no letter badge is built")
expect(full.textLabel ~= nil and full.textLabel.Text == "< Emerald >", "the whole value reads out, affixes included")
expect(full.textLabel.Parent == full.main, "the label sits on the stat card")
expect(full.textLabel.TextTruncate == Enum.TextTruncate.AtEnd, "a long value truncates instead of overflowing")
expect(full.valueOdo == nil and full.changeOdo == nil, "no odometers are built for a text stat")

-- Reveal and hide round trip — the path a tab switch or window show drives.
full:_setShown(true, false)
TestPump(0.2)
expect(full.textLabel.TextTransparency == 0, "reveal makes the label opaque")
full:_setShown(false, false)
TestPump(0.2)
expect(full.textLabel.TextTransparency == 1, "hide fades the label out")
full:_setShown(true, false)
TestPump(0.2)
expect(full.textLabel.TextTransparency == 0, "and it comes back")

-- Every write path lands on the label.
full:Set("Onyx")
expect(full.textLabel.Text == "< Onyx >", "Set rewrites the text readout")
full:SetText("Cobalt")
expect(full.textLabel.Text == "< Cobalt >", "SetText rewrites the text readout")
full:ResetBaseline("Gold")
expect(full.textLabel.Text == "< Gold >", "ResetBaseline rewrites the text readout")

-- Compact card: no host frame, no odometer, the label joins the card's row.
local row = tab:CreateGroup({ direction = "row" })
local compactStat = row:CreateStat({ name = "Mode", value = "Rose", letter = false })
TestPump(0.2)
expect(compactStat.compact == true, "the row child is compact")
expect(compactStat.textValue == true, "the compact stat is a text readout too")
expect(compactStat.readoutOdo == nil, "no odometer on the compact text stat")
expect(compactStat.readoutHost == nil, "and no empty host frame measuring zero")
expect(compactStat.textLabel ~= nil and compactStat.textLabel.Text == "Rose", "the compact card shows the whole value")
expect(compactStat.textLabel.Parent == compactStat.card, "the label joins the card's own flex row")
expect(compactStat:_minWidth() > 60, "minWidth measures the word, got " .. tostring(compactStat:_minWidth()))
compactStat:_setShown(true, false)
TestPump(0.2)
expect(compactStat.textLabel.TextTransparency == 0, "compact reveal makes the label opaque")
compactStat:SetText("Frost")
expect(compactStat.textLabel.Text == "Frost", "compact SetText rewrites the label")

-- Untouched: the numeric path.
local numeric = tab:CreateStat({ name = "Kills", value = 128 })
TestPump(0.2)
expect(numeric.textValue == false and numeric.letter == false, "a numeric stat is neither text nor letter mode")
expect(numeric.valueOdo ~= nil and numeric.changeOdo ~= nil, "a numeric stat still builds its odometers")
expect(numeric.textLabel == nil, "and no text label")
numeric:Set(256)
expect(numeric.value == 256, "numeric Set still drives the readout")
numeric:ResetBaseline(0)
expect(numeric.value == 0, "numeric ResetBaseline still works")

-- Untouched: the letter badge is still the default for text values.
local badge = tab:CreateStat({ name = "Region", value = "Onyx" })
expect(badge.letter == true, "a text value with no letter prop still gets the badge")
expect(badge.textValue == false and badge.textLabel == nil, "and no text readout")
expect(badge.letterGlyph ~= nil and badge.letterGlyph.Text == "O", "the badge still shows one letter")
badge:SetText("Frost")
expect(badge.letterGlyph.Text == "F", "the badge still follows SetText")

window:Unload()
TestPump(0.2)

print("STAT TEXT: full and compact text readouts, reveal, writes and untouched defaults all passed")
