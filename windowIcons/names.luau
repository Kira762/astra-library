--[[
Single source of truth for Astra's window and Settings UI icons.
Names are intentionally lowercase and case-sensitive. Custom assets resolve
from the executor's custom_asset/ directory.

`load` and `delete` have no Roblox asset id in `icons.luau`: they are
catalog icons asked for by name, worn by the Load and Delete buttons under
Settings -> Persistence -> Configurations (Save wears the `config` glyph).
]]
return {
    window = "sirius",
    close = "close",
    minimise = "minimise",
    maximise = "maximise",
    settings = "settings",
    search = "search",
    chevron = "chevron",
    check = "check",
    config = "config",
    load = "download",
    delete = "trash",
}
