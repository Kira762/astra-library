--[[
Astra changelog data file (host-side example).
Keep your release history in its own file like this one, require it, and
hand it to a Changelog element:
  local tab = window:CreateTab({ name = "Changelog" })
  tab:CreateChangelog(require(path.to["changelog-data"]))
Entries are newest-first. Update at runtime with changelog:Add(entry) / Set / Clear.
]]

return {
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "1.2.0",
            date = "2026-09-17",
            title = "Changelog element",
            changes = {
                { symbol = "+", text = "Changelog renders as a standalone element." },
                { symbol = "~", category = "Changed", text = "Removed window changelog panel; use tab:CreateChangelog." },
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
