-- [[Astra overlay entrance queue.
--
-- Notifications and toasts are the cheapest thing in the interface to look at
-- and the most expensive thing to build on a cold start: a host that fires
-- twenty of them while it boots — one per module it loaded — builds twenty
-- cards on the same frame the window's own entrance lands, and every card is
-- a dozen instances plus its full set of entrance tweens. The frame spikes,
-- the entrance stutters, and the whole interface pops in at once.
--
-- The queue turns that burst into a cascade:
--   * an overlay is *built* on its own turn rather than on the frame it was
--     asked for, so the construction cost is spread over frames instead of
--     stacked onto one;
--   * only one entrance is in flight at a time, and the next turn starts
--     after a cooldown, so the cards arrive one at a time;
--   * the gate holds every turn while the window is busy with its own
--     entrance, so the window arrives first and the overlays follow it;
--   * a backlog is bounded: past `maxQueued` pending requests the oldest one
--     that has not been built yet gives up its slot, the same way
--     `maxVisible` retires cards that are already on screen.
--
-- The queue owns no timing of its own beyond the cooldown: an overlay keeps
-- its entrance and simply calls `release()` when the last piece of it is
-- committed, which is what hands the slot to the next card. The cooldown
-- answers to the motion service, so the "Instant" speed profile (or animation
-- switched off) drains the queue one overlay per frame instead of one per
-- cooldown — ordered, but never slow. The gate is polled a frame at a time
-- rather than slept through, because the thing it waits for is another
-- coroutine's completion, not a duration.
-- ]]
local utilities = script.Parent.Parent.utilities

local motion = require(utilities.motion)
local log = require(utilities.log)

local OverlayQueue = {}

-- [[Cooldown between two overlays landing, and the shorter one used while a
-- backlog is still waiting so a long queue drains instead of crawling. Both
-- are beats for the *next* card to start on: the entrance itself belongs to
-- the overlay.]]
local entranceGap = 0.18
local backlogGap = 0.06
local backlogSize = 3

-- [[Safety budgets, in seconds of waiting rather than in frames: an entrance
-- that never reports back (a card dismissed mid-flight by the visibility cap,
-- say) must not strand the queue behind it, and a gate nobody opens must not
-- strand it either.]]
local entranceBudget = 1.2
local gateBudget = 2.5

-- [[Pending requests kept during a burst. Anything past this is dropped
-- before it is ever built, which is the whole point.]]
local maxQueued = 6

-- [[The queue table lives on the window, but the window is allowed to hold a
-- placeholder for it: `Window.new` pre-seeds `_overlayQueue` so `Window:Unload`
-- always has something to clear, and a host that assigns its own table lands
-- here too. A placeholder is not a queue — it has no `pending` list to pump —
-- so the shape is completed rather than trusted. Every entry point into the
-- queue comes through here, which is what lets the rest of the module read
-- `queue.pending` unconditionally.]]
local function queueFor(window): { [string]: any }
    local queue = window._overlayQueue
    if type(queue) ~= "table" or type(queue.pending) ~= "table" then
        local previous = if type(queue) == "table" then queue else nil
        queue = {
            pending = {},
            running = false,
            paused = false,
            closed = false,
        }
        -- [[A placeholder is the queue's *initial* state: a window paused
        -- before its first request has to stay paused through the upgrade, or
        -- the entrance gate would open on the very thing that made it wait.]]
        if previous then
            queue.running = previous.running == true
            queue.paused = previous.paused == true
            queue.closed = previous.closed == true
        end
        window._overlayQueue = queue
    end
    return queue
end

-- [[Suspend the queue. Called when the window starts a transition that should
-- read as the main event — its own entrance — and paired with
-- `OverlayQueue.resume` when that transition is over.]]
function OverlayQueue.pause(window)
    local queue = queueFor(window)
    queue.paused = true
end

-- [[Open the gate. A window that never queued anything has a placeholder or no
-- queue at all, so there is nothing to wake: read the shape through
-- `queueFor` and the `paused` test below does the rest of the work.]]
function OverlayQueue.resume(window)
    local queue = queueFor(window)
    if not queue.paused then
        return
    end
    queue.paused = false
    -- [[A pump that gave up on a gate nobody opened (gateBudget) leaves the
    -- backlog parked until the next request, so wake it here too.]]
    if not queue.running and #queue.pending > 0 and not window.unloaded then
        OverlayQueue.pump(window, queue)
    end
end

-- [[Give up the slot for a cooldown. A wait expressed in seconds rather than
-- `task.wait(seconds)`, because a frame that is already over must not be
-- charged against the beat: the queue should never run *ahead* of the clock it
-- is pacing itself against.]]
local function waitSeconds(seconds)
    local waited = 0
    while waited < seconds do
        waited += task.wait()
    end
end

-- [[Drain the pending list one overlay at a time. One pump per window at any
-- moment: a request that arrives while the queue is running is picked up by
-- the loop that is already going.]]
function OverlayQueue.pump(window, queue)
    queue = queue or queueFor(window)
    if queue.running then
        return
    end
    queue.running = true

    task.spawn(function()
        while #queue.pending > 0 do
            if window.unloaded or queue.closed then
                table.clear(queue.pending)
                break
            end

            local entry = table.remove(queue.pending, 1)

            -- [[Wait out the window's own entrance before taking the turn. The
            -- budget keeps a gate nobody opened from parking the queue: worst
            -- case the overlay arrives on its own instead of with the window.]]
            if queue.paused then
                local gateWaited = 0
                while queue.paused and gateWaited < gateBudget and not window.unloaded do
                    gateWaited += task.wait()
                end
            end

            if window.unloaded or queue.closed then
                table.clear(queue.pending)
                break
            end

            -- [[The overlay reports back when its entrance is committed. A
            -- build that errors out has already reported nothing, so the
            -- budget below moves the queue along regardless.]]
            local released = false
            local function release()
                released = true
            end

            local ok, err = pcall(entry.build, release)
            if not ok then
                log.warn("Astra: an overlay failed to open - " .. tostring(err))
            end

            local entranceWaited = 0
            while not released and entranceWaited < entranceBudget and not window.unloaded do
                entranceWaited += task.wait()
            end

            if window.unloaded or queue.closed then
                table.clear(queue.pending)
                break
            end

            -- [[The cooldown between two cards. A short one when the queue is
            -- still long, so a burst stays a cascade and does not turn into a
            -- slideshow.]]
            local gap = if #queue.pending > backlogSize then backlogGap else entranceGap
            waitSeconds(motion.step(gap))
        end

        queue.running = false
    end)
end

-- [[Ask for an overlay. `build(release)` constructs it on this overlay's turn —
-- never on the frame the request was made on — and the overlay calls
-- `release()` when its entrance is committed. Returns true when the request was
-- accepted, which is false only for a window that is already gone.]]
function OverlayQueue.request(window, build): boolean
    if window.unloaded then
        return false
    end

    local queue = queueFor(window)
    if queue.closed then
        return false
    end

    -- [[A burst stays bounded: the oldest request that was never built is
    -- dropped for the newest one, which is the one the host still cares about.]]
    while #queue.pending >= maxQueued do
        table.remove(queue.pending, 1)
    end

    table.insert(queue.pending, { build = build })

    OverlayQueue.pump(window, queue)
    return true
end

-- [[Stops the pump and drops everything that never got built. Called from
-- `Window:Unload`, where the whole overlay layer is going away anyway. A
-- window that never queued an overlay only has the placeholder, which is
-- already empty — `queueFor` gives the flag somewhere to live either way.]]
function OverlayQueue.close(window)
    -- [[A window that never had a queue at all has nothing to stop; a
    -- placeholder only has to be given somewhere to record the flag.]]
    local queue = if window._overlayQueue then queueFor(window) else nil
    if not queue then
        return
    end
    queue.closed = true
    -- [[`Window:Unload` clears the queue table whole afterwards, so *every*
    -- field has to be left at its placeholder value: a caller that reads the
    -- queue after the unload — the entrance coroutines still winding down do —
    -- must find an empty list, never a missing one.]]
    table.clear(queue.pending)
    queue.running = false
    queue.paused = false
end

return OverlayQueue
