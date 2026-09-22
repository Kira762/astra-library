--[[
Runtime test for the overlay entrance queue and the staged window entrance.

Pins the behavior the startup-cascade patch is about:
  Q1 nothing an overlay asked for is built before the window's own entrance
     has arrived (the gate), and every request waits its turn;
  Q2 one card per turn: a burst that used to spend ~14 instances per
     notification on a single frame is spread over frames instead;
  Q3 a backlog is bounded, so twenty requests at load do not turn into a
     twenty-card slideshow;
  Q4 a card retired before it finishes opening releases the slot at once, so
     the queue never wedges behind a tween that will not complete;
  Q5 unloading stops the pump with the window;
  Q6 with animation switched off the queue still drains — ordered, but with
     no cooldown to wait for;
  Q7 the page's controls are staged behind the window's entrance rather than
     all written on the frame `Show` opens on;
  Q8 a window that never queued an overlay survives its entrance being
     cancelled: `Window.new` seeds a placeholder for the queue and pauses it,
     so a window with no requests owns a paused queue with no `pending` list —
     and the gate-opening path used to read `#queue.pending` straight off it
     (`attempt to get length of a nil value`, raised out of the entrance's
     `resume` on the first host that hid a window before it had shown).

Counts instance allocations per simulated frame, the way the startup suite
does: the queue's whole job is that no frame pays for two cards.
]]

local newInstance = Instance.new
local allocations = 0
Instance.new = function(...)
	allocations += 1
	return newInstance(...)
end

local function expect(cond, message)
	if not cond then
		error("OVERLAY FAIL: " .. message, 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error("OVERLAY FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")", 0)
	end
end

local function liveCount(targetWindow)
	local live = targetWindow._liveNotifications
	return if live then #live else 0
end

local function builtCount(targetWindow)
	--[[
	How many cards the window has constructed, whether or not they are
	still on screen: the queue's turn-by-turn behaviour is what is under
	test, not how long each card stays up.
	]]
	return targetWindow._notificationCount or 0
end

local function queueOf(targetWindow)
	return targetWindow._overlayQueue
end

local function pumpUntilShown(targetWindow, limit)
	for _ = 1, limit or 40 do
		TestPump(0.1)
		if not targetWindow.hidden and not targetWindow.animating then
			return true
		end
	end
	return false
end

--[[
Let anything the window queued for itself (a notification) finish before
the assertions start counting, so a number below is always about the cards
this test asked for.
]]
local function drainOverlays(targetWindow, limit)
	for _ = 1, limit or 80 do
		TestPump(0.05)
		local queue = queueOf(targetWindow)
		if queue and #queue.pending == 0 and not queue.running then
			return true
		end
	end
	return false
end

local window = Astra:CreateWindow({ name = "Overlay queue" })
local tab = window:CreateTab({ name = "Home" })
for index = 1, 6 do
	tab:CreateToggle({ name = "Control " .. index, value = false })
end

-- ===== Q1: the gate holds every overlay until the window has arrived =========

for index = 1, 4 do
	window:Notify({ title = "Burst " .. index, content = "Notification number " .. index })
end
eq(window.hidden, true, "Q1 the window has not shown yet, so its entrance owns the frames")
eq(#queueOf(window).pending, 4, "Q1 all four requests are waiting for their turn")
eq(liveCount(window), 0, "Q1 no card is built while the gate is closed")
eq(queueOf(window).paused, true, "Q1 the gate is closed until the entrance lands")

-- ===== Q2/Q3: a burst lands one card per turn, and the queue is capped =======

local paced = Astra:CreateWindow({ name = "Overlay pacing" })
paced:CreateTab({ name = "Home" }):CreateToggle({ name = "Control", value = false })
expect(pumpUntilShown(paced), "Q2 the window must reach its shown state inside the pump budget")
expect(drainOverlays(paced), "Q2 the queue must come to rest once it has nothing to do")
expect(builtCount(paced) == 0, "Q2 a quiet window had nothing queued but its own notification")

for index = 1, 20 do
	paced:Notify({ title = "Module " .. index, content = "Loaded module " .. index })
end
expect(
	#queueOf(paced).pending <= 6,
	"Q3 a burst keeps at most `maxQueued` requests waiting (used " .. tostring(#queueOf(paced).pending) .. ")"
)

local framesWithACard = 0
local peakPerFrame = 0
for _ = 1, 60 do
	local before = allocations
	TestPump(0.05)
	local delta = allocations - before
	if delta > peakPerFrame then
		peakPerFrame = delta
	end
	if delta > 4 then
		framesWithACard += 1
	end
	if #queueOf(paced).pending == 0 and not queueOf(paced).running then
		break
	end
end

eq(builtCount(paced), 6, "Q3 the twenty-request burst was cut down to the queue's own cap")
expect(
	framesWithACard > 1,
	"Q2 the six cards were spread over " .. framesWithACard .. " frames, not stacked on one"
)
expect(peakPerFrame < 40, "Q2 no frame carried more than one card (peak " .. peakPerFrame .. " instances)")
eq(queueOf(paced).running, false, "Q2 the pump parks itself once the queue is empty")

-- ===== Q4: a card dismissed mid-entrance still hands the slot over ===========

local released = Astra:CreateWindow({ name = "Overlay release" })
released:CreateTab({ name = "Home" })
expect(pumpUntilShown(released), "Q4 the window must show inside the pump budget")
expect(drainOverlays(released), "Q4 the queue must come to rest before the two cards")

released:Notify({ title = "First", content = "Holds the slot" })
released:Notify({ title = "Second", content = "Waits for it" })
TestPump(0.05)
eq(builtCount(released), 1, "Q4 only one of the two cards is built while the first holds the slot")
eq(#queueOf(released).pending, 1, "Q4 the second card is still waiting")

local first = released._liveNotifications and released._liveNotifications[1]
expect(first ~= nil, "Q4 the first card opened on its turn")
first:_dismiss()
TestPump(0.3)
eq(builtCount(released), 2, "Q4 retiring the first card handed the slot to the next one")
eq(#queueOf(released).pending, 0, "Q4 the queue did not wedge behind a card that never finished")

-- ===== Q5: unloading stops the pump =========================================

released:Notify({ title = "Too late", content = "Never built" })
released:Notify({ title = "Also late", content = "Never built" })
local waiting = #queueOf(released).pending
expect(waiting > 0, "Q5 the fixture left a request waiting (" .. tostring(waiting) .. ")")
released:Unload()
TestPump(0.5)
eq(#queueOf(released).pending, 0, "Q5 an unload clears what was still waiting")
eq(queueOf(released).closed, true, "Q5 the queue is closed with its window")

-- ===== Q6: animation switched off still drains (ordered, no cooldowns) ======

local instant = Astra:CreateWindow({ name = "Overlay instant" })
instant:CreateTab({ name = "Home" })
expect(pumpUntilShown(instant), "Q6 the window must show inside the pump budget")
Astra.Motion.setProfile("instant")
expect(instant._overlayQueue.paused == false, "Q6 the entrance gate is open on a settled window")
for index = 1, 3 do
	instant:Notify({ title = "Instant " .. index, content = "No cooldown to wait for" })
end
local instantFrames = 0
while builtCount(instant) < 3 and instantFrames < 20 do
	TestPump(0.05)
	instantFrames += 1
end
eq(builtCount(instant), 3, "Q6 every card still opened with motion off")
--[[
Three cards at the normal pace are ~6 frames apart because of the cooldown
between turns; with the cooldowns scaled away they arrive back to back.
]]
expect(instantFrames <= 12, "Q6 the queue skipped its cooldowns (took " .. instantFrames .. " frames)")
Astra.Motion.setProfile("normal")
instant:Unload()
TestPump(0.2)

-- ===== Q7: the page's controls are staged behind the entrance ================

local staged = Astra:CreateWindow({ name = "Staged reveal" })
local stagedTab = staged:CreateTab({ name = "Home" })
for index = 1, 4 do
	stagedTab:CreateButton({ name = "Button " .. index, callback = function() end })
end
eq(stagedTab.elements[1].title.TextTransparency, 1, "Q7 a control is not drawn while the window is hidden")

staged:Show()
eq(staged.hidden, false, "Q7 the window is on screen")
eq(stagedTab._elementsPending, true, "Q7 the controls wait for a beat after the shell")
eq(
	stagedTab.elements[1].title.TextTransparency,
	1,
	"Q7 no control is written on the frame the entrance opens on"
)
local function revealedCount(targetTab)
	local revealed = 0
	for _, element in targetTab.elements do
		if element.title.TextTransparency == 0 then
			revealed += 1
		end
	end
	return revealed
end

for _ = 1, 20 do
	TestPump(0.05)
	if not stagedTab._elementsPending then
		break
	end
end
eq(stagedTab._elementsPending, false, "Q7 the cascade ran and cleared the mark")
--[[
One beat per control: when the mark cleared the cascade had committed the
first card of the page and no more. A page revealed on a single frame is
the regression this pin exists to catch.
]]
local staggered = revealedCount(stagedTab)
expect(
	staggered >= 1 and staggered < #stagedTab.elements,
	"Q7 the page came in a control at a time (got " .. staggered .. " of " .. #stagedTab.elements .. ")"
)
for _ = 1, 40 do
	TestPump(0.05)
	if revealedCount(stagedTab) == #stagedTab.elements then
		break
	end
end
for _, element in stagedTab.elements do
	eq(element.title.TextTransparency, 0, "Q7 every control on the page ends up revealed")
end

-- ===== Q8: the entrance gate on a window that queued no overlay ==============

--[[
`Window.new` pre-seeds `_overlayQueue` with a placeholder (so `Unload` always
has something to clear) and pauses the queue through that placeholder. A
window that never queued an overlay therefore owns a *paused* queue with no
pending list at all, and opening the gate read `#queue.pending` off it —
`attempt to get length of a nil value`, raised out of the entrance's resume,
on the first host that hid a window before it had ever shown.
]]
local gated = Astra:CreateWindow({ name = "Overlay gate" })
gated:CreateTab({ name = "Home" })
eq(gated.hidden, true, "Q8 the window has not shown yet")
eq(type(gated._overlayQueue), "table", "Q8 the window carries a placeholder for its queue")
eq(gated._overlayQueue.paused, true, "Q8 construction pauses the queue through the placeholder")

--[[
Hiding before the first show is the path that opens the gate on that
placeholder: the entrance is never going to arrive, so nothing may be left
parked behind it.
]]
local queuedBeforeGate = builtCount(gated)
gated:Hide()
eq(type(gated._overlayQueue.pending), "table", "Q8 opening the gate completes the placeholder into a queue")
eq(#gated._overlayQueue.pending, 0, "Q8 completing the queue invents no work")
eq(gated._overlayQueue.paused, false, "Q8 a cancelled entrance opens the gate")

--[[
...and a cancelled entrance still holds the gate for anything queued
afterwards: the queue was paused before it had a pending list, and that flag
has to survive the upgrade, or the cards would land on the hidden window.
]]
gated:Notify({ title = "Held", content = "Waits for the gate nobody will open" })
eq(#gated._overlayQueue.pending, 1, "Q8 the request waits its turn")
eq(gated._overlayQueue.paused, true, "Q8 the pause survives the placeholder being completed")
for _ = 1, 4 do
	TestPump(0.05)
end
eq(builtCount(gated), queuedBeforeGate, "Q8 nothing is built while the gate is held")

--[[
The window is unloaded while its queue still holds that request: `close`
runs against a queue that has a pending list to drop, and the deferred
auto-show that arrives afterwards must not try to open a window whose
instances are gone.
]]
gated:Unload()
eq(#gated._overlayQueue.pending, 0, "Q8 an unload drops what was still waiting")
eq(gated._overlayQueue.closed, true, "Q8 the queue is closed with its window")
gated:Show()
TestPump(0.2)
eq(gated.hidden, true, "Q8 an unloaded window cannot be shown")

window:Unload()
paced:Unload()
released:Unload()
staged:Unload()
TestPump(0.2)
expect(allocations > 0, "Q0 the harness counted real allocations")

print(
	"OVERLAY QUEUE: gating, one card per turn, bounded backlog, release on dismiss, motion-off drain and staged reveal passed"
)