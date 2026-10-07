--[[
Built-in window icons — the art Astra draws for itself.

This folder is deliberately NOT `icons/`. `icons/` is the user-facing
catalog: seven third-party packs, `packBuilder`, custom-asset resolution and
`Icons.resolve` for whatever a host script asks for by name. This folder is
the other half — the fixed set of glyphs the library needs to render its own
chrome (close, minimise, maximise, settings, search), its own affordances
(chevron, check, config) and its brand mark (the window icon). Hosts never
look these up by name and cannot swap them for a pack icon; they are Astra's
internals, not part of the icon API.

Three tables describe the same ten glyphs from three sides, because three
different layers need them:

  ids    name -> rbxassetid:// number, what Roblox loads directly
  files  name -> PNG filename under assets/window-icons/, the GitHub source
         `cache/imageCache` fetches when secure mode rewrites assets
  roles  name -> human label, used only for preload failure messages
  names  name -> the request string handed to `icons.resolve` (the window
         topbar mark, the settings gear, ...)

`ids`/`files`/`roles` live in `icons.luau`, `names` in `names.luau`; this
module is the one place that owns all four plus the derived lookups, so a
new built-in glyph is one edit in one folder.
]]

local icons = require(script.icons)
local names = require(script.names)

local windowIcons = {
    ids = icons.ids,
    files = icons.files,
    roles = icons.roles,
    names = names,
}

function windowIcons.manifest(): { [number]: { roles: { string } } }
    return icons.manifest()
end

function windowIcons.roleForId(id: number): string
    return icons.roleForId(id)
end

function windowIcons.roleList(): { string }
    return icons.roleList()
end

return windowIcons
