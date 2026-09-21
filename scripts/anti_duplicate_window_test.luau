-- Regression: Anti Duplicate Window must leave exactly one live window even
-- when CreateWindow is re-entered while a previous construction is still
-- yielding at its startup checkpoints (the spam-execute race).

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

print("ANTI DUPLICATE: sequential replace, opt-out, overlapping spam, and cleanup passed")
