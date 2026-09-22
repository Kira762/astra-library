-- Regression: Anti Duplicate Window must leave exactly one live window even
-- when CreateWindow is re-entered while a previous construction is still
-- yielding at its startup checkpoints (the spam-execute race). Replacing a
-- window whose constructors are still suspended at a checkpoint must not
-- crash those threads: the window is marked unloaded and vanishes at once,
-- but its tree is only destroyed once that construction has gone quiet.

local function expect(condition, message)
	if not condition then
		error("ANTI DUPLICATE FAIL: " .. message, 0)
	end
end

local function alive(window)
	return window ~= nil and window.unloaded ~= true
end

local function countAlive(windows)
	local n = 0
	for _, window in windows do
		if alive(window) then
			n += 1
		end
	end
	return n
end

local function screenGuis()
	local container = game:GetService("CoreGui")
	local n = 0
	for _, child in container:GetChildren() do
		if child.ClassName == "ScreenGui" and not child.__destroyed then
			n += 1
		end
	end
	return n
end

-- Sequential CreateWindow still replaces the previous window.
local first = Astra:CreateWindow({ name = "First", configuration = { autoSave = false, autoLoad = false } })
expect(alive(first) and #first.instances > 0, "first window is constructed")
local second = Astra:CreateWindow({ name = "Second", configuration = { autoSave = false, autoLoad = false } })
expect(first.unloaded, "sequential CreateWindow unloads the previous window")
expect(alive(second), "the replacement window stays alive")
expect(#first.instances == 0, "unloaded window has no leftover instances")
second:Unload()
TestPump(0.2)

-- Per-window opt-out still allows a second window to coexist.
local kept = Astra:CreateWindow({ name = "Opt out", configuration = { autoSave = false, autoLoad = false } })
kept.settings.antiWindowDuplicate = false
local extra = Astra:CreateWindow({ name = "Allowed extra", configuration = { autoSave = false, autoLoad = false } })
expect(alive(kept) and alive(extra), "opt-out keeps the previous window")
kept:Unload()
extra:Unload()
TestPump(0.2)

-- Overlapping constructions: several CreateWindow calls start before any
-- of them has registered in the global store. Only the latest claim survives.
local overlapping = {}
local entered = 0
local finished = 0
for index = 1, 8 do
	task.spawn(function()
		entered += 1
		overlapping[index] = Astra:CreateWindow({
			name = "Spam " .. index,
			configuration = { autoSave = false, autoLoad = false },
		})
		finished += 1
	end)
end

local sawOverlap = false
for _ = 1, 80 do
	TestPump(0.05)
	if entered >= 2 and finished < 8 then
		sawOverlap = true
	end
	if finished == 8 then
		break
	end
end

expect(finished == 8, "every overlapping CreateWindow returns")
expect(sawOverlap, "CreateWindow was re-entered while a previous construction was still yielding")

-- A window overtaken mid-construction unloads once its construction goes
-- quiet, so the final state settles a few frames after the last call
-- returns. Pump until it has.
for _ = 1, 200 do
	if countAlive(overlapping) == 1 and screenGuis() == 1 then
		break
	end
	TestPump(0.05)
end

expect(countAlive(overlapping) == 1, "rapid re-entry leaves exactly one live window")

local survivor
for index = 8, 1, -1 do
	if alive(overlapping[index]) then
		survivor = overlapping[index]
		break
	end
end
expect(survivor ~= nil, "a survivor exists")
expect(survivor == overlapping[8], "the latest CreateWindow claim is the one that remains")
expect(#survivor.instances > 0, "the surviving window still owns its instances")
expect(screenGuis() == 1, "only one ScreenGui remains under CoreGui")

for _, window in overlapping do
	if window ~= survivor then
		expect(window.unloaded, "superseded window is marked unloaded")
		expect(#window.instances == 0, "superseded window destroyed its instances")
	end
end

-- A later sequential create still replaces the overlapping survivor.
local followup = Astra:CreateWindow({ name = "Follow-up", configuration = { autoSave = false, autoLoad = false } })
expect(survivor.unloaded, "a later CreateWindow unloads the overlapping survivor")
expect(alive(followup) and countAlive({ survivor, followup }) == 1, "follow-up is the only live window")
followup:Unload()
TestPump(0.2)
expect(screenGuis() == 0, "unloading the last window removes its ScreenGui")

-- The reported crash: re-executing while the previous script's host thread
-- is suspended at a construction checkpoint (mid-CreateCollapsibleGroup).
-- The replacement must mark the window unloaded and take the screen at once
-- without pulling the tree out from under the suspended constructors; the
-- superseded host thread resumes, finishes its build harmlessly, and the
-- tree is destroyed once that construction has gone quiet.
local busy = Astra:CreateWindow({ name = "Busy", configuration = { autoSave = false, autoLoad = false } })
local busyTab = busy:CreateTab({ name = "Busy tab" })
local busyHostDone = false
task.spawn(function()
	local elements = {}
	for index = 1, 40 do
		table.insert(elements, { type = "Button", name = "Busy " .. index, callback = function() end })
	end
	busyTab:CreateCollapsibleGroup({ name = "Busy group", elements = elements })
	busyHostDone = true
end)

-- Pump until the host thread is suspended inside a pacing checkpoint.
local caughtSuspended = false
for _ = 1, 200 do
	TestPump(0.05)
	if (busy._constructionBusy or 0) > 0 then
		caughtSuspended = true
		break
	end
end
expect(caughtSuspended, "a host thread was caught suspended at a construction checkpoint")

local replacer = Astra:CreateWindow({ name = "Replacer", configuration = { autoSave = false, autoLoad = false } })
expect(busy.unloaded, "a window under construction is marked unloaded at once")
expect(alive(replacer), "the replacement window stays alive")
expect(screenGuis() == 1, "the replacement is the only window on screen")

for _ = 1, 400 do
	TestPump(0.05)
	if busyHostDone and #busy.instances == 0 then
		break
	end
end
expect(busyHostDone, "the superseded host thread finished its construction without crashing")
expect(#busy.instances == 0, "the superseded tree was destroyed once construction went quiet")
expect(alive(replacer), "the replacement survives the superseded teardown")

-- A selection call the superseded script still owed (builds that end with a
-- Select, like the published examples) lands after the tree is gone; it must
-- be a no-op, not a write into destroyed chrome.
local lateSelectOk = pcall(function()
	busyTab:Select()
end)
expect(lateSelectOk, "Select on an unloaded window is a harmless no-op")

-- A CreateTab owed after the tree is gone — a key-system onSuccess build
-- starts with exactly one — must build detached instead of asserting the
-- window alive. That assert surfaced as "Astra: key system callback errored:
-- ... Cannot create a tab on an unloaded window."
local lateTabOk, lateTab = pcall(function()
	return busy:CreateTab({ name = "Late tab" })
end)
expect(lateTabOk, "CreateTab on an unloaded window is harmless")
expect(lateTab ~= nil and lateTab.tabPage ~= nil, "the late tab is built detached")
local lateButtonOk = pcall(function()
	lateTab:CreateButton({ name = "Late button", callback = function() end })
end)
expect(lateButtonOk, "element construction on a late tab is harmless")
local lateSectionOk, lateSection = pcall(function()
	return busy:CreateSection({ name = "Late section" })
end)
expect(lateSectionOk, "CreateSection on an unloaded window is harmless")
expect(lateSection ~= nil and lateSection.main ~= nil, "the late section is built detached")
expect(#busy.instances == 0, "late construction never resurrects the live tree")

replacer:Unload()
TestPump(0.2)
expect(screenGuis() == 0, "unloading the replacer clears the screen")

-- Overtaken while still inside Window.new: the overtaken CreateWindow must
-- hand its host a window that keeps accepting constructors; that window is
-- never shown and is torn down once the host's construction goes quiet.
local overtaken
local overtakenHostDone = false
task.spawn(function()
	overtaken = Astra:CreateWindow({ name = "Overtaken", configuration = { autoSave = false, autoLoad = false } })
	local tab = overtaken:CreateTab({ name = "Overtaken tab" })
	local elements = {}
	for index = 1, 24 do
		table.insert(elements, { type = "Toggle", name = "Overtaken " .. index })
	end
	tab:CreateCollapsibleGroup({ name = "Overtaken group", elements = elements })
	-- The published examples end their build with a selection; a superseded
	-- script's must survive the same way.
	tab:Select()
	overtakenHostDone = true
end)
-- One frame: the overtaken construction is suspended inside Window.new.
TestPump(0.05)
local overtopper = Astra:CreateWindow({ name = "Overtopper", configuration = { autoSave = false, autoLoad = false } })

for _ = 1, 400 do
	TestPump(0.05)
	if overtakenHostDone and overtaken and overtaken.unloaded and #overtaken.instances == 0 then
		break
	end
end
expect(overtakenHostDone, "the overtaken host finished adding its elements")
expect(overtaken.unloaded, "the overtaken window was unloaded")
expect(#overtaken.instances == 0, "the overtaken window destroyed its instances")
expect(alive(overtopper), "the overtaking window survives")
expect(screenGuis() == 1, "only the overtaker's ScreenGui remains")

overtopper:Unload()
TestPump(0.2)
expect(screenGuis() == 0, "unloading the overtaker clears the screen")

print("ANTI DUPLICATE: sequential replace, opt-out, overlapping spam, mid-build replace, and cleanup passed")
