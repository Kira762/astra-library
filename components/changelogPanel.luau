local utilities = script.Parent.Parent.utilities

local persistence = require(utilities.persistence)

local changelogPanel = {}

local DEFAULT_NAME = "Changelog"
local DEFAULT_EMPTY = "No changelog entries yet."

local function readRaw(entry, lower, upper)
    if type(entry) ~= "table" then
        return nil
    end
    local value = entry[lower]
    if value == nil then
        value = entry[upper]
    end
    return value
end

-- [[What "new" means: the newest entry's version + date plus the entry count,]]
-- [[so a new release, a re-dated entry, or any add/remove trips the dot.]]
-- [[Entries are newest-first (window:AddChangelogEntry prepends).]]
function changelogPanel.marker(entries): string?
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end
    local newest = entries[1]
    if type(newest) ~= "table" then
        return "count:" .. #entries
    end
    local version = readRaw(newest, "version", "Version") or ""
    local date = readRaw(newest, "date", "Date")
    if date == nil then
        date = readRaw(newest, "updatedAt", "UpdatedAt")
    end
    return tostring(version) .. "\n" .. tostring(date or "") .. "\n" .. #entries
end

function changelogPanel.storeFromProps(props)
    props = if typeof(props) == "table" then props else {}
    local entries = {}
    local raw = props.entries or props.Entries
    if typeof(raw) == "table" then
        for _, entry in ipairs(raw) do
            table.insert(entries, entry)
        end
    end
    return {
        name = tostring(props.name or props.Name or DEFAULT_NAME),
        emptyText = tostring(props.emptyText or props.EmptyText or DEFAULT_EMPTY),
        entries = entries,
    }
end

function changelogPanel.loadSeen(window): { [string]: string }
    local ok, seen = pcall(persistence.loadChangelogSeen)
    if not ok or type(seen) ~= "table" then
        return {}
    end
    return seen
end

function changelogPanel.isNew(window): boolean
    local store = window._changelog
    if not store then
        return false
    end
    local marker = changelogPanel.marker(store.entries)
    if not marker then
        return false
    end
    local key = persistence.windowChangelogKey(window)
    return window._changelogSeen[key] ~= marker
end

function changelogPanel.refreshBadge(window, animate)
    if not window.changelogAction then
        return
    end
    window.changelogAction:SetBadge(changelogPanel.isNew(window), animate)
end

-- [[Viewing marks seen: the stored marker catches up, the file is written]]
-- [[through, and the dot fades out. Idempotent - re-opening the same history]]
-- [[writes nothing. With no entries there is nothing to mark.]]
function changelogPanel.markSeen(window)
    local store = window._changelog
    if not store then
        return
    end
    local marker = changelogPanel.marker(store.entries)
    if not marker then
        changelogPanel.refreshBadge(window, true)
        return
    end
    local key = persistence.windowChangelogKey(window)
    if window._changelogSeen[key] == marker then
        changelogPanel.refreshBadge(window, true)
        return
    end
    window._changelogSeen[key] = marker
    pcall(persistence.saveChangelogSeen, window._changelogSeen)
    changelogPanel.refreshBadge(window, true)
end

-- [[Silent first boot: when the window has no stored marker yet, the entries]]
-- [[it was constructed with become the baseline (written, not shown). Without]]
-- [[this, every install would open with a dot for history nobody missed; with]]
-- [[it, the dot means strictly "changed since the window was created or last]]
-- [[viewed". Entries arriving later (runtime Set/Add) still raise the dot.]]
function changelogPanel.captureBaseline(window)
    local key = persistence.windowChangelogKey(window)
    if window._changelogSeen[key] ~= nil then
        return
    end
    local marker = changelogPanel.marker(window._changelog.entries)
    if not marker then
        return
    end
    window._changelogSeen[key] = marker
    pcall(persistence.saveChangelogSeen, window._changelogSeen)
end

function changelogPanel.buildUI(window)
    if window._changelogUIBuilt then
        return
    end
    window._changelogUIBuilt = true
    local store = window._changelog
    local tab = window:CreateTab({
        name = store.name,
        icon = "scroll-text",
        customOrder = 1005,
        forgetState = true,
        isChangelogTab = true,
    })
    tab._isChangelogTab = true
    window._changelogTab = tab
    if window.changelogAction then
        window.changelogAction.linkedTab = tab
    end
end

function changelogPanel.buildContent(window, tab)
    if tab._changelogElement or window._changelogContentBuilt then
        return
    end
    window._changelogContentBuilt = true
    local store = window._changelog
    local ok, err = pcall(function()
        local element = require(script.Parent.Parent.elements.changelog).new(tab, {
            name = store.name,
            emptyText = store.emptyText,
            entries = store.entries,
        })
        tab:_register(element)
        tab._changelogElement = element
    end)
    if not ok then
        window:Notify({ title = "Changelog", content = "Changelog content failed to load: " .. tostring(err) })
    end
end

function changelogPanel.toggleMode(window)
    if window._changelogMode then
        local previousTab = window._previousTab
        window._previousTab = nil
        if previousTab and previousTab.window == window and previousTab.tabPage
            and not previousTab._isSettingsTab and not previousTab._isChangelogTab then
            previousTab:Select()
            return
        end
        for _, tab in window.tabs do
            if not tab._isSettingsTab and not tab._isChangelogTab
                and tab.window == window and tab.tabPage then
                tab:Select()
                return
            end
        end
        return
    end

    if window._previousTab == nil and window.selectedTab
        and not window.selectedTab._isSettingsTab and not window.selectedTab._isChangelogTab then
        window._previousTab = window.selectedTab
    end
    changelogPanel.buildUI(window)
    window._changelogTab:Select()
end

function changelogPanel.setMode(window, active)
    active = active == true
    if active and window._constructed then
        changelogPanel.buildUI(window)
    end
    if active then
        window._settingsMode = false
    end
    window._changelogMode = active
    if active and window._previousTab == nil and window.selectedTab
        and not window.selectedTab._isSettingsTab and not window.selectedTab._isChangelogTab then
        window._previousTab = window.selectedTab
    end
    for _, tab in window.tabs do
        if tab.topbarItem then
            tab.topbarItem.Visible = not window.hidden and not window.minimised
                and (window:_railGroup(tab) == window:_activeRail())
        end
    end
    window:_applySettingsLayout(window._settingsMode)
    if active then
        changelogPanel.markSeen(window)
    end
end

return changelogPanel
