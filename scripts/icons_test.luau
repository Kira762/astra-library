-- ===== icon resolver assertions: name-only lookup, qualified names, caching =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
-- [[
-- [[The resolver used to answer a bare name from one pack (lucide) and to]]
-- [[probe the custom asset folder with up to five `getcustomasset` calls on]]
-- [[every lookup, misses included. This suite pins the replacement contract:
-- [[  * I1  every pack is still reachable through the old API,
-- [[  * I2  nothing is loaded until a lookup needs it, and a lucide name
-- [[        loads lucide alone,
-- [[  * I3  a bare name searches the packs in priority order and stops at the
-- [[        first match - duplicates are resolved by priority, never randomly,
-- [[  * I4  every pack reports a full, properly sized catalog,
-- [[  * I5  `pack:name` and `get(name, pack)` address one pack exactly - an
-- [[        explicit pack is answered or refused, never overruled by the
-- [[        order (the profile card's alias chain relies on that),
-- [[  * I6  names and pack names are case-sensitive (never corrected),
-- [[  * I7  an unknown pack warns once and does not resolve to another pack,
-- [[  * I8  loadable values pass through and misses keep the old fallback,
-- [[  * I9  custom files resolve, are imported once per path, and misses are
-- [[        cached (no repeated probing),
-- [[  * I10 the folder index (listfiles) resolves subfolders and extension
-- [[        preference, and costs nothing for names it does not contain,
-- [[  * I11 one icon's cached answer never stands in for another's,
-- [[  * I12 window:ResolveIcon still resolves inside the window's own pack
-- [[        (or an explicit one), keeping the old fallback for a name that
-- [[        pack does not have.]]

local function expect(cond, message)
	if not cond then
		error("ICONS FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"ICONS FAIL: "
				.. tostring(message)
				.. " (got "
				.. tostring(actual)
				.. ", wanted "
				.. tostring(wanted)
				.. ")"
		)
	end
end

local Icons = Astra.Icons
local PACK_ORDER = { "lucide", "material", "tabler", "phosphor", "heroicons", "feather" }
local ASSET_BASE = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/"

local function urlOf(path)
	return ASSET_BASE .. path
end

-- ===== I1: packs and the legacy API (no pack is read here) =================

eq(type(Icons.get), "function", "I1 get")
eq(type(Icons.getByPack), "function", "I1 getByPack")
eq(type(Icons.resolve), "function", "I1 resolve")
eq(type(Icons.list), "function", "I1 list")
eq(type(Icons.packs), "function", "I1 packs")
eq(type(Icons.count), "function", "I1 count")
eq(type(Icons.isPack), "function", "I1 isPack")
eq(type(Icons.priority), "function", "I1 priority")
eq(type(Icons.loaded), "function", "I1 loaded")
eq(type(Icons.refreshCustom), "function", "I1 refreshCustom")

local packs = Icons.packs()
eq(#packs, #PACK_ORDER, "I1 packs() lists all six packs")
for index, name in ipairs(PACK_ORDER) do
	eq(packs[index], name, "I1 packs() keeps its documented order (" .. name .. ")")
	expect(Icons.isPack(name), "I1 isPack(" .. name .. ")")
	eq(Icons[name:sub(1, 1):upper() .. name:sub(2)], name, "I1 legacy constant for " .. name)
end
eq(Icons.Lucide, "lucide", "I1 Icons.Lucide")
eq(Icons.Feather, "feather", "I1 Icons.Feather")
expect(not Icons.isPack("Lucide"), "I1 pack names are case-sensitive")
expect(not Icons.isPack("nope"), "I1 unknown packs are not packs")

local priority = Icons.priority()
eq(#priority, #PACK_ORDER, "I1 priority() lists every pack")
eq(priority[1], "lucide", "I1 priority() starts at lucide")
priority[1] = "feather"
eq(Icons.priority()[1], "lucide", "I1 priority() hands out a copy")

-- ===== I2: lazy loading ====================================================

eq(#Icons.loaded(), 0, "I2 no pack is loaded before the first lookup")

local house = Icons.get("house")
eq(house, "assets/icons/lucide-pack/h/lucideHouse.png", "I2 a bare lucide name resolves")
eq(table.concat(Icons.loaded(), ","), "lucide", "I2 one lucide name loads lucide alone")

-- ===== I3: name-only lookup searches every pack, in priority order =========

local materialHome = Icons.get("home", "material")
expect(materialHome ~= nil, "I3 material has home")
eq(Icons.get("ac_unit"), Icons.get("ac_unit", "material"), "I3 a material-only name resolves through the search")
eq(table.concat(Icons.loaded(), ","), "lucide,material", "I3 ... and stops loading at material")

eq(Icons.get("airplane-takeoff"), Icons.get("airplane-takeoff", "phosphor"), "I3 the search crosses packs")
eq(table.concat(Icons.loaded(), ","), "lucide,material,phosphor,tabler", "I3 the search stops before the packs it did not need")
expect(Icons.loaded()[5] == nil, "I3 heroicons and feather are still unloaded")

local tablerHome = Icons.get("home", "tabler")
expect(tablerHome ~= nil, "I3 tabler has home")
eq(Icons.get("home"), materialHome, "I3 the first pack in priority order wins a duplicate")
expect(Icons.get("home") ~= tablerHome, "I3 the duplicate is not answered from a later pack")

eq(Icons.get("bar-chart"), Icons.get("bar-chart", "feather"), "I3 the search reaches the last pack")
eq(Icons.resolve("bar-chart"), urlOf(Icons.get("bar-chart", "feather")), "I3 resolve of a late-pack name")
expect(#Icons.loaded() == 6, "I3 only a name from the last pack loads all six")

-- ===== I4: every pack still reports its catalog ============================

for _, name in ipairs(PACK_ORDER) do
	expect(Icons.count(name) > 0, "I4 count(" .. name .. ") is non-empty")
	eq(#Icons.list(name), Icons.count(name), "I4 list/count agree for " .. name)
end
expect(type(Icons.lucide) == "table", "I4 direct pack access (Icons.lucide) still works")
expect(type(Icons.feather) == "table", "I4 direct pack access (Icons.feather) still works")

-- ===== I5: explicit packs and pack-qualified names =========================

eq(Icons.get("material:home"), materialHome, "I5 pack:name addresses that pack")
eq(Icons.get("tabler:home"), tablerHome, "I5 pack:name addresses the requested pack")
eq(Icons.get("home", "tabler"), Icons.getByPack("tabler", "home"), "I5 getByPack is get with a pack")
expect(Icons.get("tabler:home") ~= Icons.get("home"), "I5 an explicit pack overrides priority")
expect(string.find(Icons.get("tabler:home"), "tabler%-pack") ~= nil, "I5 the returned path names the pack")

local resolvedHouse = Icons.resolve("house")
eq(resolvedHouse, urlOf(house), "I5 resolve returns the repo URL of the entry")
eq(Icons.resolve("tabler:home"), urlOf(tablerHome), "I5 a qualified resolve returns that pack's URL")
eq(Icons.resolve("lucide:house"), resolvedHouse, "I5 a qualified resolve matches the bare one")

-- ===== I6: case sensitivity ================================================

eq(Icons.get("Home"), nil, "I6 an upper-case initial does not match")
eq(Icons.get("HOME"), nil, "I6 an all-caps name does not match")
eq(Icons.get("Lucide:house"), nil, "I6 a mis-cased pack does not match")
eq(Icons.get("LUCIDE:house"), nil, "I6 an all-caps pack does not match")
eq(Icons.resolve("Lucide:house"), "Lucide:house", "I6 a mis-cased pack keeps the raw value")
expect(Icons.resolve("House") ~= resolvedHouse, "I6 a mis-cased name is not silently corrected")

-- ===== I7: unknown packs warn once and never substitute ====================

local warnings = {}
warn = function(message)
	table.insert(warnings, message)
end

eq(Icons.get("Nope:house"), nil, "I7 an unknown pack resolves to nothing")
eq(Icons.get("Nope:home"), nil, "I7 a second request through the same bad pack resolves to nothing")
eq(#warnings, 1, "I7 the unknown pack warns once, not per lookup")
expect(string.find(warnings[1], "Nope") ~= nil, "I7 the warning names the pack")
eq(Icons.resolve("house", "Nope"), "house", "I7 an unknown pack falls back to the raw value")
expect(Icons.resolve("house") ~= "house", "I7 ... and the good lookup is unaffected")

-- ===== I8: passthrough values and misses ===================================

eq(Icons.resolve("rbxassetid://123"), "rbxassetid://123", "I8 asset ids pass through")
eq(Icons.resolve("rbxasset://fonts/families/x.ttf"), "rbxasset://fonts/families/x.ttf", "I8 rbxasset passes through")
eq(Icons.resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48"), "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48", "I8 rbxthumb passes through")
eq(Icons.resolve("https://example.com/icon.png"), "https://example.com/icon.png", "I8 http(s) passes through")
eq(Icons.resolve(42), 42, "I8 numbers pass through")
eq(Icons.resolve(0), 0, "I8 zero passes through")
eq(Icons.resolve(""), "", "I8 empty passes through")
eq(Icons.resolve(nil), nil, "I8 nil passes through")
eq(Icons.get("this-icon-does-not-exist"), nil, "I8 a missing name is not invented")
eq(Icons.resolve("this-icon-does-not-exist"), "this-icon-does-not-exist", "I8 a missing name keeps the old fallback")
eq(Icons.resolve("this-icon-does-not-exist"), "this-icon-does-not-exist", "I8 the miss is stable")

-- ===== I9: custom assets, probe path (no listfiles) ========================

local customUris = {
	["custom_asset/brand.png"] = "rbxasset://custom/brand",
	["custom_asset/hero"] = "rbxasset://custom/hero",
}
local probes: { [string]: number } = {}
local probeTotal = 0

getcustomasset = function(path)
	probeTotal += 1
	probes[path] = (probes[path] or 0) + 1
	local uri = customUris[path]
	if uri then
		return uri
	end
	error("no such custom asset: " .. path)
end
listfiles = nil

Icons.refreshCustom()
eq(Icons.resolve("brand"), "rbxasset://custom/brand", "I9 a custom file resolves")
eq(probes["custom_asset/brand.png"], 1, "I9 the custom file is imported once")
for _ = 1, 3 do
	Icons.resolve("brand")
end
eq(probes["custom_asset/brand.png"], 1, "I9 repeated resolves reuse the import")
eq(Icons.resolve("hero"), "rbxasset://custom/hero", "I9 an extensionless custom file resolves")
eq(Icons.resolve("brand"), "rbxasset://custom/brand", "I9 the custom file still wins after other lookups")

local missStart = probeTotal
Icons.resolve("not-a-custom-file-either")
local missCost = probeTotal - missStart
expect(missCost > 0, "I9 a miss is probed once")
expect(missCost <= 5, "I9 a miss costs at most the historic probe chain")
local afterMiss = probeTotal
for _ = 1, 5 do
	Icons.resolve("not-a-custom-file-either")
	Icons.resolve("and-another-missing-one")
end
eq(probeTotal - afterMiss, 5, "I9 only the first probe of a new miss costs anything")
local beforeRecheck = probeTotal
Icons.resolve("not-a-custom-file-either", "feather")
eq(probeTotal, beforeRecheck, "I9 the remembered miss is reused, not re-probed")

-- ===== I10: custom assets, indexed path (listfiles) ========================

local listings = {
	"custom_asset/brand.png",
	"custom_asset/brand.webp",
	"custom_asset/logo.webp",
	"custom_asset/hero",
	"custom_asset/brand/house.png",
	"custom_asset/notes.txt",
	"custom_asset/ignored.md",
}
customUris["custom_asset/logo.webp"] = "rbxasset://custom/logo"
customUris["custom_asset/brand/house.png"] = "rbxasset://custom/brand-house"
listfiles = function(folder)
	eq(folder, "custom_asset", "I10 listfiles is asked for the custom asset folder")
	return listings
end

eq(Icons.refreshCustom(), 4, "I10 the index holds the files with a supported extension or none")
eq(Icons.resolve("brand"), "rbxasset://custom/brand", "I10 index: png wins the extension preference")
eq(Icons.resolve("logo"), "rbxasset://custom/logo", "I10 index: another extension resolves")
eq(Icons.resolve("hero"), "rbxasset://custom/hero", "I10 index: extensionless resolves")
eq(Icons.resolve("brand/house"), "rbxasset://custom/brand-house", "I10 index: subfolders resolve")

local indexMissStart = probeTotal
Icons.resolve("no-such-custom-file")
eq(probeTotal, indexMissStart, "I10 index: a name that is not there costs no import at all")
eq(Icons.resolve("no-such-custom-file"), "no-such-custom-file", "I10 index: the miss is the raw value")

customUris["custom_asset/house.png"] = "rbxasset://custom/house"
listings = { "custom_asset/house.png" }
Icons.refreshCustom()
eq(Icons.resolve("house"), "rbxasset://custom/house", "I10 index: a custom file beats the pack it shadows")
eq(Icons.resolve("material:home"), urlOf(materialHome), "I10 index: qualified names are not shadowed by the folder")

customUris["custom_asset/house.png"] = nil
listings = {}
Icons.refreshCustom()
eq(Icons.resolve("house"), resolvedHouse, "I10 index: dropping the file restores the pack icon")

-- ===== I11: one icon's answer never stands in for another's ================

listfiles = nil
Icons.refreshCustom()
eq(Icons.resolve("home", "tabler"), urlOf(tablerHome), "I11 tabler's home")
eq(Icons.resolve("home", "heroicons"), urlOf(Icons.get("home", "heroicons")), "I11 heroicons' home")
eq(Icons.resolve("home"), urlOf(materialHome), "I11 the bare name still answers from priority")
expect(Icons.resolve("home", "tabler") ~= Icons.resolve("home"), "I11 the three cache keys stay apart")
eq(Icons.resolve("material:home"), urlOf(materialHome), "I11 a qualified repeat answers the same")

-- ===== I12: window:ResolveIcon =============================================

local window = Astra:CreateWindow({ name = "Icons", iconPack = "feather" })
TestPump(0.6)

eq(window:ResolveIcon("bar-chart"), Icons.resolve("bar-chart", "feather"), "I12 the window resolves in its own pack")
eq(window:ResolveIcon("house"), "house", "I12 a name the window's pack lacks keeps the current fallback")
eq(window:ResolveIcon("house", "lucide"), resolvedHouse, "I12 an explicit pack argument still resolves")
eq(window:ResolveIcon("material:home"), urlOf(materialHome), "I12 the window honours a qualified name")
eq(window:ResolveIcon("rbxassetid://7"), "rbxassetid://7", "I12 the window passes asset ids through")
eq(window:ResolveIcon("nope-nope"), "nope-nope", "I12 the window keeps the old fallback")

window:Unload()
TestPump(0.1)

print("ICONS: all assertions passed")
