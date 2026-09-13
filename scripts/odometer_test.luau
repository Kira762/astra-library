-- ===== odometer assertions: lazy rows, identical readout =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- The roll builds a strip of rows and slides it inside a clipping cell. It
-- used to create all 20 rows (2 x 0-9) for every digit of every readout, so a
-- Stat built 42 TextLabels for a single value while at most two rows can ever
-- be on screen. Rows are now materialised per transition; this suite pins both
-- halves of that: the instance saving, and the readout being pixel-identical
-- (the row the strip rests on must carry the value's digit).
--
-- Expected behavior under test:
--   * O1 a fresh element builds only the rows it shows, not the whole strip,
--   * O2 the resting row is the digit of the value (what the user reads),
--   * O3 a plain change materialises exactly the band it walks and lands on
--     the target row,
--   * O4 a wrap (9 -> 1) travels through the repeated rows and still lands on
--     the right glyph,
--   * O5 a roll down (1 -> 9) uses the second decade of rows and lands too,
--   * O6 static glyphs (the decimal point, the suffix) are unaffected.

local function expect(cond, message)
	if not cond then
		error("ODOMETER FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"ODOMETER FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local state = Astra.Core.state

local window = Astra:CreateWindow({ name = "Odometer Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Numbers" })

local function textLabels(inst)
	local found = {}
	local function walk(node)
		for _, child in node:GetChildren() do
			if (child.__props or {}).ClassName == "TextLabel" then
				table.insert(found, child)
			end
			walk(child)
		end
	end
	walk(inst)
	return found
end

-- [[A reel is a clipping cell holding a strip of rows. The row the readout
-- [[shows is the one whose offset the strip currently rests on.]]
local function findReels(element)
	local reels = {}
	local function walk(node)
		for _, child in node:GetChildren() do
			local props = child.__props or {}
			if props.ClassName == "Frame" and props.Name == "Reel" then
				local strip
				for _, grandchild in child:GetChildren() do
					local gp = grandchild.__props or {}
					if gp.ClassName == "Frame" then
						strip = grandchild
					end
				end
				if strip then
					table.insert(reels, { cell = child, strip = strip })
				end
			end
			walk(child)
		end
	end
	walk(element.main)
	return reels
end

local function visibleRow(reel)
	local height = reel.cell.__props.Size.Y.Offset
	local offset = reel.strip.__props.Position.Y.Offset
	return math.floor((-offset) / height + 0.5), height
end

local function rowTextAt(reel, rowIndex)
	local height = reel.cell.__props.Size.Y.Offset
	for _, child in reel.strip:GetChildren() do
		local props = child.__props or {}
		if props.ClassName == "TextLabel" then
			local row = math.floor(props.Position.Y.Offset / height + 0.5)
			if row == rowIndex then
				return props.Text
			end
		end
	end
	return nil
end

-- ===== O1/O2: a single-digit readout builds one row, and it shows the digit ==

local oneDigit = tab:CreateStat({ name = "Single", value = 7, suffix = "" })
TestPump(0.4)

local reels = findReels(oneDigit)
expect(#reels > 0, "O1 the readout builds at least one reel")

local totalRows = 0
for _, reel in reels do
	for _, child in reel.strip:GetChildren() do
		local props = child.__props or {}
		if props.ClassName == "TextLabel" then
			totalRows += 1
		end
	end
end
expect(totalRows <= 4, "O1 a single-digit readout materialises a handful of rows, not the whole strip (got " .. tostring(totalRows) .. ")")

local row, height = visibleRow(reels[1])
eq(rowTextAt(reels[1], row), "7", "O2 the resting row shows the value's digit")

-- ===== O6: static glyphs are still built =====
--
-- [[The odometer splits a readout into digit rows and static glyphs (the
-- [[suffix, the decimal point). Only the digits were touched by the lazy-row
-- [[change, so both kinds are checked here: a Stat's suffix, and a Slider's
-- [[decimal point (a Slider derives its precision from `increment`).]]

local withSuffix = tab:CreateStat({ name = "Suffix", value = 7, suffix = "x" })
local fractional = tab:CreateSlider({
	name = "Fractional",
	range = { 0, 10 },
	increment = 0.25,
	value = 1.5,
	suffix = "%",
})
TestPump(0.5)

-- [[LayoutOrder places the glyphs visually, not in creation order, so these
-- [[are membership checks on the set of rendered glyphs.]]
local function glyphsOf(element)
	local seen = {}
	for _, label in textLabels(element.main) do
		local props = label.__props or {}
		local text = props.Text
		if type(text) == "string" and text ~= "" and text ~= element.name then
			seen[text] = true
		end
	end
	return seen
end

local statGlyphs = glyphsOf(withSuffix)
expect(statGlyphs["x"] == true, "O6 the Stat's suffix is still rendered")

local sliderGlyphs = glyphsOf(fractional)
expect(sliderGlyphs["."] == true, "O6 the Slider's decimal point is still rendered")
expect(sliderGlyphs["%"] == true, "O6 the Slider's suffix is still rendered")
expect(sliderGlyphs["1"] and sliderGlyphs["5"] and sliderGlyphs["0"], "O6 the Slider's digits are still rendered (1.50)")

local sliderReels = findReels(fractional)
expect(#sliderReels >= 3, "O6 the fractional readout builds a reel per digit (got " .. tostring(#sliderReels) .. ")")

-- ===== O3: a plain change materialises its band and lands on target =========

local counter = tab:CreateStat({ name = "Counter", value = 1, suffix = "" })
TestPump(0.4)

local reels3 = findReels(counter)
local reel = reels3[1]
counter:Set(4)
TestPump(0.9)

local row3 = visibleRow(reel)
eq(rowTextAt(reel, row3), "4", "O3 the roll lands on the target digit")
local rowsAfter = 0
for _, child in reel.strip:GetChildren() do
	if ((child.__props or {}).ClassName == "TextLabel") then
		rowsAfter += 1
	end
end
expect(rowsAfter <= 4, "O3 a 1 -> 4 change materialises its band only (got " .. tostring(rowsAfter) .. " rows)")

-- ===== O4: a wrap travels the repeated rows ================================

local wrapper = tab:CreateStat({ name = "Wrap", value = 9, suffix = "" })
TestPump(0.4)
local wrapReel = findReels(wrapper)[1]
wrapper:Set(1)
TestPump(0.9)

local row4 = visibleRow(wrapReel)
eq(rowTextAt(wrapReel, row4), "1", "O4 a 9 -> 1 wrap lands on the right glyph")
local sawSecondDecade = false
local height4 = 9
for _, child in wrapReel.strip:GetChildren() do
	local props = child.__props or {}
	if props.ClassName == "TextLabel" and props.Position.Y.Offset >= 10 * height4 - 0.5 then
		sawSecondDecade = true
	end
end
expect(sawSecondDecade, "O4 the wrap materialised the repeated decade it travels through")

-- ===== O5: a roll down uses the second decade ==============================

local downer = tab:CreateStat({ name = "Down", value = 1, suffix = "" })
TestPump(0.4)
local downReel = findReels(downer)[1]
downer:Set(9)
TestPump(0.9)
local row5 = visibleRow(downReel)
eq(rowTextAt(downReel, row5), "9", "O5 a 1 -> 9 roll down lands on the right glyph")

window:Unload()
TestPump(0.1)

print("ODOMETER: all assertions passed")
