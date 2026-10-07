--[[
===== Tab reveal: every row of a tab gets shown, in every order =====
Runs the real Astra bundle against the mini Roblox environment from
sidebar_sizing_stubs.luau and pins the contract the Fields section of the
example depends on: a tab that owes a reveal is shown *completely*, no matter
who asks for it or which page the player is looking at.

The bug this suite was written for: a long tab (more rows than one reveal
batch) that nobody had opened yet was asked for its reveal by the search index
— `search.collectElements` shows every tab still marked pending while the
search page, not the tab, is on screen. The batched path revealed its first
batch, cleared the tab's pending mark up front, and handed the rest of the tab
to a stream whose loop only runs while that tab is the page on screen — so the
stream never ran, and the tail rows (in the example: the Dropdown, the Input
and the Keybind under the Fields divider) stayed transparent for the life of
the window. The cards themselves came back on the next theme pass, which is
what made the rows read as empty boxes.

  * S1  showing a tab that is not the page on screen reveals every row of it,
       including the last one, and the tab no longer owes anything;
  * S2  the player path: search opened before a long tab is ever visited, then
       closed, then the tab opened — every row is shown, and an Input row shows
       its title and its field text rather than rendering as a blank card;
  * S3  the adaptive reveal is still adaptive: the page on screen takes its
       first batch on the frame it opens and streams the rest, so a long tab
       never spends its whole reveal on one frame.
]]

local function expect(cond, message)
	if not cond then
		error("TAB REVEAL STREAM FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"TAB REVEAL STREAM FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local ROWS = 30

local window = Astra:CreateWindow({ name = "Tab Reveal Stream" })
TestPump(0.6)

local front = window:CreateTab({ name = "Front" })
front:CreateToggle({ name = "Front row" })
front:Select()
TestPump(0.5)

local long = window:CreateTab({ name = "Long" })
local tailInput
for index = 1, ROWS do
	if index == ROWS then
		-- The last row is the one the old code stranded: make it an Input so
		-- the suite can see the field inside the card, not just the card.
		tailInput = long:CreateInput({ name = "Nickname", placeholder = "Type a name" })
	else
		long:CreateToggle({ name = ("Row %d"):format(index) })
	end
end
TestPump(0.5)

local function shownRows(tab)
	local shown = 0
	for _, element in ipairs(tab.elements) do
		if element.title and element.title.TextTransparency == 0 then
			shown += 1
		end
	end
	return shown
end

-- Nothing has been opened yet: the whole tab still owes its reveal.
eq(shownRows(long), 0, "S0 an unopened tab shows no rows")

-- ===== S1: a reveal asked for off-screen still finishes the tab =============
window:_showTabElements(long)
TestPump(0.5)

eq(shownRows(long), #long.elements, "S1 every row of an off-screen tab is shown")
eq(long._elementsPending, false, "S1 the tab no longer owes a reveal")
eq(tailInput.title.TextTransparency, 0, "S1 the last row's title is opaque")
eq(tailInput.input.TextTransparency, 0.6, "S1 the last row's field text is shown")

-- ===== S2: search, then the tab =================================================
local second = window:CreateTab({ name = "Second" })
local secondRows = 0
for index = 1, ROWS do
	second:CreateToggle({ name = ("Second %d"):format(index) })
	secondRows += 1
end
TestPump(0.5)
eq(shownRows(second), 0, "S2 the second long tab is unvisited")

window.searchAction.callback()
TestPump(0.6)
expect(window._searching, "S2 search is open")
eq(shownRows(second), secondRows, "S2 search shows every row it lays out on its page")

window.searchAction.callback()
TestPump(0.6)
eq(window._searching, false, "S2 search closed again")

second:Select()
TestPump(0.8)
eq(shownRows(second), secondRows, "S2 opening the tab after search finds no missing rows")

long:Select()
TestPump(0.8)
eq(shownRows(long), #long.elements, "S2 the searched-then-opened tab is complete")

-- ===== S3: the page on screen still streams its tail ==========================
local third = window:CreateTab({ name = "Third" })
for index = 1, ROWS do
	third:CreateToggle({ name = ("Third %d"):format(index) })
end
TestPump(0.5)

third:Select()
-- The frame the tab opens on: the first batch has landed, the rest is queued.
local openedRows = shownRows(third)
expect(openedRows > 0, "S3 the page on screen reveals its first batch immediately")
expect(openedRows < #third.elements, "S3 the tail of a long tab is streamed, not spent on one frame")

TestPump(0.8)
eq(shownRows(third), #third.elements, "S3 the stream finishes the tab")
eq(third._elementsPending, false, "S3 the tab no longer owes a reveal")

print("TAB REVEAL STREAM: all assertions passed")
