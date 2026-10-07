--[[
===== Settings -> Persistence -> Configurations: every button wears an icon =====
Runs the real Astra bundle (loaded as global `Astra` above) against the mini
Roblox environment from sidebar_sizing_stubs.luau, plus the in-memory files
from filesystem_stubs.luau (the Configurations panel lists the config folder).

Save carried the `config` glyph while Load and Delete were built with no
`icon` at all, so the three-button row read as one finished button next to
two blank ones. This suite pins:
  * C1  Save, Load and Delete each own an icon label,
  * C2  each carries a loadable value - a built-in asset id or a catalog
        URL, never a bare name that no Image property can load,
  * C3  the three glyphs are distinct, so the row tells its actions apart.
]]

local function expect(cond, message)
	if not cond then
		error("CONFIG ICONS FAIL: " .. tostring(message), 0)
	end
end

local function isLoadable(value)
	if type(value) == "number" then
		return value > 0
	end
	return type(value) == "string" and (value:match("^https?://") ~= nil or value:match("^rbxasset") ~= nil)
end

local window = Astra:CreateWindow({ name = "ConfigIcons" })
TestPump(0.6)

-- The Settings panel builds lazily: shells first, each tab's elements the
-- first time that tab is opened.
window:_buildSettingsUI()
local persistence
for _, tab in window._settingsTabs do
	if tab.name == "Persistence" then
		persistence = tab
		break
	end
end
expect(persistence ~= nil, "the Persistence settings tab exists")
persistence:Select()
TestPump(0.4)

local found = {}
local function collect(elements)
	for _, element in elements do
		if element.name then
			found[element.name] = element
		end
		if element.elements then
			collect(element.elements)
		end
	end
end
collect(persistence.elements)

-- ===== C1 / C2 / C3: the Save / Load / Delete row ==========================

local seen = {}
for _, name in { "Save", "Load", "Delete" } do
	local button = found[name]
	expect(button ~= nil, "C1 the " .. name .. " button exists under Configurations")
	expect(button.iconLabel ~= nil, "C1 the " .. name .. " button owns an icon label")
	expect(isLoadable(button.icon), "C2 the " .. name .. " icon is loadable (got " .. tostring(button.icon) .. ")")
	local key = tostring(button.icon)
	expect(seen[key] == nil, "C3 " .. name .. " repeats the glyph of " .. tostring(seen[key]) .. " (" .. key .. ")")
	seen[key] = name
end

window:Unload()
print("SETTINGS CONFIG ICONS: Save, Load and Delete each carry a distinct, loadable icon")
