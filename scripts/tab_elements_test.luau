-- ===== tab element assertions: tabs nobody opened cost nothing =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Opening a window (and every show/minimise/layout switch after it) used to
-- walk every element of every tab to keep the tabs nobody had opened in step:
-- a 4-tab x 5-element window wrote 20 element visibility sets per show, 15 of
-- them onto pages UIPageLayout is not rendering. Tabs are now marked instead,
-- and their elements are shown when the player opens the tab (or when the
-- search lays them out on its own page). This suite pins both halves: the
-- saving, and a tab opened later looking exactly like the tab that was
-- revealed at show time.
--
-- Expected behavior under test:
--   * E1 the first show walks the selected tab and marks the rest,
--   * E2 opening a tab shows its elements in the same frame, in the state the
--     reveal left the selected tab in,
--   * E3 a hide/show round trip shows the selected tab again without walking
--     the others,
--   * E4 opening the search shows every tab's elements (it renders them all),
--   * E5 an element created in a tab nobody has opened is visible when it is,
--   * E6 reopening an already-shown tab costs nothing.

local function expect(cond, message)
	if not cond then
		error("TABS FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error("TABS FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")", 0)
	end
end

local window = Astra:CreateWindow({ name = "Tabs Test" })

-- [[Count every element visibility set the library performs, per step.]]
local shownCalls = 0
local function instrument()
	for _, tab in pairs(window.tabs) do
		for _, element in ipairs(tab.elements) do
			if not element.__instrumented then
				element.__instrumented = true
				local original = element._setShown
				element._setShown = function(self, ...)
					shownCalls += 1
					return original(self, ...)
				end
			end
		end
	end
end

-- [[Every Transparency property the element's frame tree carries plus its
-- [[Visible flags: the element's visible state, independent of where the
-- [[element is currently parented (the search re-parents elements).]]
local function fingerprint(element)
	local out = {}
	local function walk(node, path)
		local props = node.__props or {}
		-- [[Visible defaults to true: a row the harness never touched and one
		-- [[it set to true are the same frame, so normalise the default away.]]
		local keys = { "Visible=" .. tostring(props.Visible ~= false) }
		for key, value in props do
			local name = tostring(key)
			if string.sub(name, -12) == "Transparency" then
				keys[#keys + 1] = name .. "=" .. tostring(value)
			end
		end
		table.sort(keys)
		out[#out + 1] = path .. "[" .. table.concat(keys, " ") .. "]"
		for index, child in node:GetChildren() do
			walk(child, path .. "/" .. tostring((child.__props or {}).Name) .. index)
		end
	end
	walk(element.main, "main")
	return table.concat(out, " ")
end

local function parentName(element)
	local parent = element.main.Parent
	return tostring(parent and parent.__props and parent.__props.Name)
end

local function sameState(a, b)
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index] ~= b[index] then
			return false
		end
	end
	return true
end

local tabs = {}
for index = 1, 4 do
	local tab = window:CreateTab({ name = "Tab " .. index })
	tabs[index] = tab
	for sub = 1, 5 do
		tab:CreateButton({ name = ("T%d B%d"):format(index, sub), callback = function() end })
	end
end
instrument()

-- ===== E1: the first show walks the selected tab and marks the rest ========

TestPump(1.4)
eq(#tabs[1].elements, 5, "E1 the fixture has five elements per tab")
expect(shownCalls <= 5, "E1 the first show walks the selected tab, not all four (used " .. tostring(shownCalls) .. ")")
eq(tabs[1]._elementsPending, false, "E1 the selected tab is not pending")
for index = 2, 4 do
	eq(tabs[index]._elementsPending, true, "E1 tab " .. index .. " waits until it is opened")
end

local revealedState = {}
for index, element in ipairs(tabs[1].elements) do
	revealedState[index] = fingerprint(element)
end

-- ===== E2: opening a tab shows its elements in the same frame ==============

shownCalls = 0
tabs[2]:Select()
eq(shownCalls, 5, "E2 opening a tab shows exactly its own elements")
eq(tabs[2]._elementsPending, false, "E2 the tab is marked shown")
eq(parentName(tabs[2].elements[1]), "Tab 2", "E2 the elements stay on their own page")

local openedState = {}
for index, element in ipairs(tabs[2].elements) do
	openedState[index] = fingerprint(element)
end
expect(
	sameState(openedState, revealedState),
	"E2 a tab opened later looks exactly like the tab revealed at show time"
)

-- ===== E3: hide/show shows the selected tab again ==========================

window:Hide()
TestPump(0.8)
shownCalls = 0
window:Show()
TestPump(0.8)
instrument()

expect(shownCalls <= 5, "E3 showing again walks the selected tab, not all four (used " .. tostring(shownCalls) .. ")")
eq(tabs[2]._elementsPending, false, "E3 the selected tab is shown again")
for index, element in ipairs(tabs[2].elements) do
	eq(fingerprint(element), revealedState[index], "E3 element " .. index .. " comes back in the shown state")
end

-- ===== E4: the search shows every tab's elements ===========================

shownCalls = 0
window.searchAction.interact.MouseButton1Click:Fire()
TestPump(0.6)
instrument()

expect(shownCalls <= 10, "E4 the search shows the tabs it renders, not the ones it does not (used " .. tostring(shownCalls) .. ")")
for index = 1, 4 do
	eq(parentName(tabs[index].elements[1]), "Search", "E4 tab " .. index .. " is on the search page")
	for sub, element in ipairs(tabs[index].elements) do
		eq(fingerprint(element), revealedState[sub], "E4 tab " .. index .. " element " .. sub .. " renders its text")
	end
end

window.searchAction.interact.MouseButton1Click:Fire()
TestPump(0.6)

-- ===== E5: an element created while the window is hidden ==================

tabs[1]:Select()
TestPump(0.4)
window:Hide()
TestPump(0.8)
local late = tabs[3]:CreateButton({ name = "Late", callback = function() end })
instrument()
TestPump(0.3)
eq(tabs[3]._elementsPending, true, "E5 a tab that gains an element while hidden waits")

window:Show()
TestPump(0.8)
instrument()
eq(tabs[3]._elementsPending, true, "E5 the restore shows the selected tab, not this one")

tabs[3]:Select()
TestPump(0.4)
eq(#tabs[3].elements, 6, "E5 the late element joined the tab")
eq(fingerprint(late), revealedState[1], "E5 the late element shows with the rest of its tab")

-- ===== E6: reopening an already-shown tab costs nothing ====================

shownCalls = 0
tabs[4]:Select()
tabs[3]:Select()
eq(shownCalls, 0, "E6 tabs that were already shown are not walked again")

window:Unload()
TestPump(0.1)

print("TABS: all assertions passed")
