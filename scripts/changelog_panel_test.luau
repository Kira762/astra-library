-- ===== changelog panel assertions: dedicated space, badge, seen persistence =====
-- [[Runs the real Astra bundle against the mini Roblox environment plus the]]
-- [[in-memory filesystem from profile_image_stubs.luau.]]
-- [[
-- [[C1  the topbar gains a changelog action + divider left of search; the shell
-- [[    is lazy; first boot captures its entries as the seen baseline (silent).
-- [[C2  toggling opens the changelog view (only the changelog tab in the rail,
-- [[    exactly one element) and toggling again restores the previous tab.
-- [[C3  changelog and settings modes are mutually exclusive.
-- [[C4  Set/Add/Clear update the store, the open view, and the badge.
-- [[C5  Tab:CreateChangelog forwards into the store and returns a working handle.
-- [[C6  seen state persists across windows sharing a key.
-- [[C7  divider + badge survive hide/show.]]

local function expect(cond, message)
    if not cond then
        error("CHANGELOG FAIL: " .. tostring(message), 0)
    end
end

local writes = {}
local realWritefile = writefile
writefile = function(path, content)
    writes[path] = content
    return realWritefile(path, content)
end

local v1 = { version = "1.0", date = "2026-09-01", changes = { { symbol = "+", text = "First." } } }
local v2 = { version = "2.0", date = "2026-09-17", changes = { { symbol = "~", text = "Second." } } }

-- ===== C1: construction & silent baseline ================================
local window = Astra:CreateWindow({
    name = "Log",
    configuration = { fileName = "LogHub", customFolder = "LogFolder" },
    changelog = { name = "History", entries = { v1 } },
})
local tab = window:CreateTab({ name = "Main" })
TestPump(1)

expect(window.changelogAction ~= nil, "C1 topbar changelog action exists")
expect(window.changelogDivider ~= nil, "C1 divider exists")
expect(window.changelogAction.action.LayoutOrder < window.searchAction.action.LayoutOrder, "C1 changelog sits left of search")
expect(window.changelogDivider.LayoutOrder == -5, "C1 divider sits between changelog and search")
expect(window._changelogTab == nil, "C1 shell is lazy")
expect(window.changelogAction.badge ~= nil, "C1 action carries a badge")
expect(window.changelogAction.badge.Visible == false, "C1 first boot is silent (baseline captured)")
expect(#window._changelog.entries == 1, "C1 store holds the prop entries")
local seenPath
for path in writes do
    if string.match(path, "astra%-changelog%.rfld$") then
        seenPath = path
    end
end
expect(seenPath ~= nil, "C1 baseline file written")
expect(string.find(writes[seenPath], "1%.0") ~= nil, "C1 baseline file carries the marker")
window:AddChangelogEntry(v2)
TestPump(0.2)
expect(window.changelogAction.badge.Visible, "C1 a newer entry raises the dot")

-- ===== C2: toggle, lazy content, restore ================================
window.changelogAction.callback()
TestPump(0.5)
local ctab = window._changelogTab
expect(ctab ~= nil and window.selectedTab == ctab, "C2 toggle opens the changelog view")
expect(window._changelogMode, "C2 changelog mode is active")
expect(ctab._changelogElement ~= nil and #ctab.elements == 1, "C2 view hosts exactly the changelog element")
expect(tab.topbarItem.Visible == false, "C2 main tab hidden in changelog mode")
expect(ctab.topbarItem.Visible == true, "C2 changelog tab shown in changelog mode")
expect(window.changelogAction.badge.Visible == false, "C2 viewing hides the dot")
expect(string.find(writes[seenPath], "2%.0") ~= nil, "C2 viewing persists the new marker")
window.changelogAction.callback()
TestPump(0.5)
expect(window.selectedTab == tab, "C2 toggle restores the previous tab")
expect(not window._changelogMode, "C2 changelog mode is off")
expect(tab.topbarItem.Visible == true, "C2 rail restored")

-- ===== C3: mutual exclusion with settings ===============================
window:_buildSettingsUI()
window.settingsAction.callback()
TestPump(0.5)
expect(window._settingsMode and not window._changelogMode, "C3 settings mode entered")
expect(ctab.topbarItem.Visible == false, "C3 changelog tab hidden in settings mode")
window.changelogAction.callback()
TestPump(0.5)
expect(window._changelogMode and not window._settingsMode, "C3 changelog mode exits settings mode")
for _, stab in window._settingsTabs do
    expect(stab.topbarItem.Visible == false, "C3 settings tabs hidden in changelog mode")
end
window.changelogAction.callback()
TestPump(0.3)
expect(window.selectedTab == tab, "C3 exiting from settings lands back on the main tab")

-- ===== C4: data API =====================================================
window:SetChangelog({ v2, v1 })
TestPump(0.2)
expect(window.changelogAction.badge.Visible == false, "C4 same entries keep the dot away")
local v3 = { version = "3.0", date = "2026-09-18", changes = {} }
window:AddChangelogEntry(v3)
TestPump(0.2)
expect(window.changelogAction.badge.Visible, "C4 a new entry raises the dot live")
expect(window._changelog.entries[1].version == "3.0", "C4 prepends by default")
expect(#ctab._changelogElement.entries == 3, "C4 open view re-renders from the store")
window:AddChangelogEntry(v1, false)
expect(window._changelog.entries[#window._changelog.entries].version == "1.0", "C4 appends on prepend=false")
window:ClearChangelog()
TestPump(0.2)
expect(#window._changelog.entries == 0, "C4 clear empties the store")
expect(window.changelogAction.badge.Visible == false, "C4 clear hides the dot")
window:SetChangelog({ name = "History", entries = { v3 } })
TestPump(0.2)
expect(#window._changelog.entries == 1 and window._changelog.entries[1].version == "3.0", "C4 set accepts a full props table")
expect(window.changelogAction.badge.Visible, "C4 set with newer entries raises the dot")

-- ===== C5: option-A redirect ============================================
local warnings = 0
warn = function(message)
    if string.find(tostring(message), "CreateChangelog") then
        warnings += 1
    end
end
local log1 = tab:CreateChangelog({ name = "Old", entries = { v1 } })
expect(log1 ~= nil, "C5 tab calls still return a handle")
expect(#window._changelog.entries == 2, "C5 tab calls forward entries into the store")
expect(#tab.elements == 0, "C5 forwarded calls build no tab UI")
log1:Add(v2)
expect(window._changelog.entries[1].version == "2.0", "C5 facade Add writes the store")
log1:Clear()
expect(#window._changelog.entries == 0, "C5 facade Clear writes the store")
log1:MoveToBottom()
local log2 = tab:CreateChangelog({ entries = { v1 } })
expect(warnings == 1, "C5 redirect warns once per window")
expect(log2.entries == window._changelog.entries, "C5 facade entries track the store")

-- ===== C6: seen persists across windows =================================
local w2 = Astra:CreateWindow({
    name = "Log2",
    configuration = { fileName = "SeenHub", customFolder = "SeenFolder" },
    changelog = { entries = { v1 } },
})
TestPump(0.5)
expect(w2.changelogAction.badge.Visible == false, "C6 fresh key baselines silently")
w2:AddChangelogEntry(v2)
TestPump(0.2)
expect(w2.changelogAction.badge.Visible, "C6 newer entries raise the dot")
w2.changelogAction.callback()
TestPump(0.5)
expect(w2.changelogAction.badge.Visible == false, "C6 viewing clears the dot")
local w3 = Astra:CreateWindow({
    name = "Log3",
    configuration = { fileName = "SeenHub", customFolder = "SeenFolder" },
    changelog = { entries = { v2, v1 } },
})
TestPump(0.5)
expect(w3.changelogAction.badge.Visible == false, "C6 seen state survives across windows")

-- ===== C7: chrome survives hide/show ====================================
w3:AddChangelogEntry(v3)
TestPump(0.2)
expect(w3.changelogAction.badge.Visible, "C7 dot raised for the hide/show pass")
w3:Hide()
TestPump(0.3)
w3:Show()
TestPump(0.5)
expect(w3.changelogAction.badge.Visible, "C7 dot survives hide/show")
expect(w3.changelogAction.badge.BackgroundTransparency == 0, "C7 dot restores opaque")
expect(w3.changelogDivider.BackgroundTransparency < 1, "C7 divider restores with the topbar")
window:Unload()
w2:Unload()
w3:Unload()
TestPump(0.2)

print("CHANGELOG: panel, badge, seen persistence and redirect passed")
