-- [[Astra changelog data file (host-side example).]]
-- [[Keep your release history in its own file like this one, require it, and]]
-- [[hand it to the window:]]
-- [[  local window = Astra:CreateWindow({ name = "My Hub", changelog = require(path.to["changelog-data"]) })]]
-- [[Entries are newest-first; the topbar's red dot tracks entries[1] and]]
-- [[reappears whenever it (or the entry count) changes. Update at runtime]]
-- [[with window:SetChangelog(entries) / window:AddChangelogEntry(entry).]]

return {
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "1.2.0",
            date = "2026-09-17",
            title = "Changelog panel",
            changes = {
                { symbol = "+", text = "Release history moved into its own topbar panel." },
                { symbol = "~", category = "Changed", text = "Tab:CreateChangelog forwards into the window store." },
            },
        },
        {
            version = "1.1.0",
            date = "2026-09-10",
            changes = {
                { symbol = "+", text = "Added the Stat element's text readout." },
                { symbol = "-", text = "Removed the legacy sub-tab API." },
            },
        },
        {
            version = "1.0.0",
            date = "2026-09-01",
            changes = {
                { symbol = "~", text = "First public changelog entry." },
            },
        },
    },
}
