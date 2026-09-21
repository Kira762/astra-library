-- Regression test for duplicate notification replacement. An exact duplicate
-- must retire the old live card and build a new card through the normal
-- entrance path; only requests that have not been built yet may coalesce.
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

local function advance(seconds)
    for _ = 1, math.ceil(seconds / 0.05) do TestPump(0.05) end
end

local function expect(condition, message)
    if not condition then error("NOTIFICATION REPLACEMENT FAIL: " .. message, 0) end
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

-- Pending duplicates still collapse because there is no old card to remove.
local window = Astra:CreateWindow({ name = "Replacement" })
window:CreateTab({ name = "Home" })
window:Notify({ title = "Other", content = "Do not evict", duration = 30 })
local pending = { title = "Same", content = "Value", duration = 1 }
for index = 1, 20 do
    pending.duration = index
    window:Notify(pending)
end
expect(#window._overlayQueue.pending == 2, "pending duplicate keeps one queue entry")
pending.title = "Mutated after request"
advance(2)
expect(built(window) == 2 and #live(window) == 2, "only two distinct cards were constructed")
local card = find(window, "Same", "Value")
expect(card ~= nil and card.duration == 20, "pending card uses newest copied props")

-- A live duplicate is dismissed before a fresh replacement is queued.
local oldMain = card.main
local before = built(window)
window:Notify({ title = "Same", content = "Value", duration = 4 })
expect(card._dismissed and table.find(live(window), card) == nil, "old matching card leaves the live registry")
advance(1)
local replacement = find(window, "Same", "Value")
expect(replacement ~= nil and replacement ~= card, "duplicate builds a new card")
expect(built(window) == before + 1, "replacement takes a new build turn")
expect(oldMain.Parent == nil, "old duplicate is removed from the notification layer")
expect(countInstances(window) == 2, "replacement does not leave an overlapping duplicate")

-- Repeating while the replacement is visible always creates a new generation;
-- the queued part of the burst is still bounded to one pending snapshot.
local generations = { replacement }
for _ = 1, 4 do
    window:Notify({ title = "Same", content = "Value", duration = 4 })
    local current = find(window, "Same", "Value")
    if current and current ~= generations[#generations] then
        table.insert(generations, current)
    end
end
advance(1.5)
local newest = find(window, "Same", "Value")
expect(newest ~= replacement and not newest._dismissed, "repeated duplicate has a fresh live card")
expect(built(window) >= before + 2, "repeated duplicate is rebuilt, not refreshed in place")
expect(#live(window) <= 6, "visibility cap remains bounded")

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

-- Empty/default text and replacement during entrance use the same path.
local entrance = Astra:CreateWindow({ name = "Entrance replacement" })
entrance:CreateTab({ name = "Home" })
advance(1.5)
entrance:Notify({ duration = 30 })
advance(0.05)
local first = live(entrance)[1]
expect(first ~= nil, "card is constructed during its entrance")
entrance:Notify({ Title = "Notification", Content = "", Duration = 12 })
expect(first._dismissed, "default aliases dismiss the active card")
advance(1)
local second = find(entrance, "Notification", "")
expect(built(entrance) == 2 and second ~= first, "default duplicate receives a fresh card")
entrance:Unload()
advance(0.5)

-- The registry is per window; unloading clears pending identity entries.
local other = Astra:CreateWindow({ name = "Independent replacement" })
other:CreateTab({ name = "Home" })
other:Notify({ duration = 12 })
advance(1.5)
expect(built(other) == 1, "matching text in another window is independent")
other:Notify({ title = "Pending", content = "Remove on unload" })
other:Notify({ title = "Pending", content = "Remove on unload" })
local beforeUnload = built(other)
other:Unload()
advance(1)
expect(built(other) == beforeUnload, "unload prevents queued construction")
expect(#other._overlayQueue.pending == 0, "unload clears queued identity entries")

-- A request parked behind a cancelled entrance still coalesces by snapshot and
-- then builds one fresh card when the gate opens.
local gated = Astra:CreateWindow({ name = "Gated replacement" })
gated:CreateTab({ name = "Home" })
gated:Hide()
advance(0.2)
gated:Notify({ title = "Held", content = "Same text", duration = 1 })
advance(0.1)
expect(built(gated) == 0, "closed entrance gate defers construction")
gated:Notify({ title = "Held", content = "Same text", duration = 25 })
expect(#gated._overlayQueue.pending == 1, "gated duplicate uses one pending snapshot")
gated:Show()
advance(1.5)
expect(built(gated) == 1 and live(gated)[1].duration == 25, "opening gate builds newest snapshot")

Astra.Motion.setProfile("instant")
local instant = find(gated, "Held", "Same text")
gated:Notify({ title = "Held", content = "Same text", duration = 10 })
advance(0.2)
expect(built(gated) == 2 and find(gated, "Held", "Same text") ~= instant, "instant mode still replaces active duplicate")
gated:Unload()
Astra.Motion.setProfile("normal")
advance(0.2)
print("NOTIFICATION REPLACEMENT: pending coalescing, active removal, fresh animation path and cleanup passed")
