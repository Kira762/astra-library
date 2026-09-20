-- The shared stub completes tweens synchronously but omits PlaybackState.
-- Supply the Roblox completion argument so dismissal cleanup is exercised.
local tweens = game:GetService("TweenService")
local createTween = tweens.Create
tweens.Create = function(self, ...)
    local tween = createTween(self, ...)
    local fire = tween.Completed.Fire
    tween.Completed.Fire = function(signal)
        fire(signal, Enum.PlaybackState.Completed)
    end
    return tween
end

-- Advance one frame at a time: large TestPump calls jump virtual time in the
-- stub scheduler and are unsuitable for expiry/deadline assertions.
local function advance(seconds)
    for _ = 1, math.ceil(seconds / 0.05) do TestPump(0.05) end
end

local function expect(condition, message)
    if not condition then error("NOTIFICATION DEDUP FAIL: " .. message, 0) end
end
local function live(window)
    return window._liveNotifications or {}
end
local function find(window, title, content)
    for _, card in live(window) do
        if card.title == title and card.content == content then return card end
    end
    return nil
end
local function built(window)
    return window._notificationCount or 0
end
local function countInstances(window)
    local count = 0
    for _, child in window.notifications:GetChildren() do
        if child.Name == "Notification" then count += 1 end
    end
    return count
end

-- Exact queued duplicates coalesce before the cap and use the newest snapshot.
local window = Astra:CreateWindow({ name = "Deduplication" })
window:CreateTab({ name = "Home" })
window:Notify({ title = "Other", content = "Do not evict", duration = 30 })
local reused = { title = "Same", content = "Value", duration = 1 }
for index = 1, 20 do
    reused.duration = index
    window:Notify(reused)
end
expect(#window._overlayQueue.pending == 2, "spam does not evict unrelated queued text")
reused.title = "Mutated after request"
advance(2)
expect(built(window) == 2 and #live(window) == 2, "only two distinct cards were constructed")
local card = find(window, "Same", "Value")
expect(card ~= nil and card.duration == 20, "queued card uses newest copied props")
local main = card.main
local before = built(window)
for _ = 1, 20 do
    window:Notify({ Title = "Same", Content = "Value", Duration = 4 })
end
expect(built(window) == before and card.main == main, "active duplicates update the same instance")
expect(countInstances(window) == 2, "no overlapping duplicate instances")
expect(card._elapsed == 0 and card.duration == 4, "duplicate resets lifetime using aliased props")

-- The old expiry must not dismiss the refreshed card; hover still pauses time.
advance(2.5)
window:Notify({ title = "Same", content = "Value", duration = 4 })
advance(2)
expect(not card._dismissed, "refreshed card survives its original expiry")
card.body.MouseEnter:Fire()
local elapsed = card._elapsed
advance(3)
expect(card._elapsed == elapsed and not card._dismissed, "hover pauses the refreshed hold")
card.body.MouseLeave:Fire()
advance(2.5)
expect(card._dismissed and not card.main.Parent, "refreshed card eventually expires and is destroyed")
window:Notify({ title = "Same", content = "Value", duration = 20 })
advance(0.8)
expect(find(window, "Same", "Value").main ~= main, "expired text may open a fresh card")

-- Title AND body must match exactly: preserve case, whitespace and boundaries.
local distinct = {
    { title = "Same", content = "value" },
    { title = "Same", content = "Value " },
    { title = "Different", content = "Value" },
    { title = "a:b", content = "c" },
    { title = "a", content = "b:c" },
}
for _, props in distinct do props.duration = 30; window:Notify(props) end
advance(2)
for _, props in distinct do
    expect(find(window, props.title, props.content) ~= nil, "non-identical title/body values stay distinct")
end
expect(#live(window) <= 6, "visibility cap remains bounded")
window:Unload()
advance(0.5)

-- Empty/default text and duplicates during entrance use the same path.
local entrance = Astra:CreateWindow({ name = "Entrance dedup" })
entrance:CreateTab({ name = "Home" })
advance(1.5)
entrance:Notify({ duration = 30 })
advance(0.05)
local first = live(entrance)[1]
expect(first ~= nil, "card is constructed during its entrance")
entrance:Notify({ Title = "Notification", Content = "", Duration = 12 })
expect(built(entrance) == 1 and first.duration == 12, "defaults and aliases match during entrance")
first:_dismiss()
entrance:Notify({ title = "Notification", content = "", duration = 12 })
advance(1)
expect(built(entrance) == 2 and #live(entrance) == 1, "dismissed card does not suppress later messages")

-- The registry is per window; unloading clears the pending queue.
local other = Astra:CreateWindow({ name = "Independent dedup" })
other:CreateTab({ name = "Home" })
other:Notify({ duration = 12 })
advance(1.5)
expect(built(other) == 1, "matching message in another window is independent")
other:Notify({ title = "Pending", content = "Remove on unload" })
other:Notify({ title = "Pending", content = "Remove on unload" })
local beforeUnload = built(other)
other:Unload()
advance(1)
expect(built(other) == beforeUnload, "unload prevents queued duplicate construction")
expect(#other._overlayQueue.pending == 0, "unload clears queued identity entries")
entrance:Unload()
advance(0.5)
-- A request already parked inside the entrance gate must still be replaceable.
local gated = Astra:CreateWindow({ name = "Gated duplicates" })
gated:CreateTab({ name = "Home" })
gated:Hide() -- cancel auto-show so the pump genuinely waits at the gate
advance(0.2)
gated:Notify({ title = "Held", content = "Same text", duration = 1 })
advance(0.1)
expect(built(gated) == 0, "closed entrance gate defers construction")
gated:Notify({ title = "Held", content = "Same text", duration = 25 })
expect(#gated._overlayQueue.pending == 1, "in-flight gated request is still coalesced")
gated:Show()
advance(1.5)
expect(built(gated) == 1 and live(gated)[1].duration == 25, "opening gate builds only the newest snapshot")
Astra.Motion.setProfile("instant")
gated:Notify({ title = "Instant", content = "Duplicate", duration = 10 })
gated:Notify({ title = "Instant", content = "Duplicate", duration = 20 })
advance(0.2)
expect(built(gated) == 2, "motion-off duplicate builds once")
gated:Notify({ title = "Instant", content = "Duplicate", duration = 30 })
expect(built(gated) == 2 and find(gated, "Instant", "Duplicate").duration == 30, "motion-off active refresh works")
gated:Unload()
Astra.Motion.setProfile("normal")
advance(0.2)
print("NOTIFICATION DEDUP: exact matching, active refresh, queued coalescing, lifetime and cleanup passed")
