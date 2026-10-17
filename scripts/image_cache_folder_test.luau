--[[
===== workspace ImageCache leftover =====
Runs the real Mova bundle (loaded as global `Mova` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau plus a folder-
tracking executor filesystem.

Mova never creates a workspace-root `ImageCache` folder — images live
under `Mova/assets/images-icon`, configs under `Mova/config`. Some
executors mkdir `ImageCache` on `getcustomasset` and leave it empty.
This suite pins the cleanup:
  * C1  configs stay under Mova/config, never ImageCache,
  * C2  an empty ImageCache created by getcustomasset is discarded,
  * C3  an ImageCache that actually holds files is left alone.
]]

local function expect(cond, message)
	if not cond then
		error("IMAGE CACHE FOLDER FAIL: " .. tostring(message), 0)
	end
end

local function hashUrl(url)
	local hash = 0
	for index = 1, #url do
		hash = (hash * 33 + string.byte(url, index)) % 2147483647
	end
	return hash
end

local function cachePathFor(url)
	return "Mova/assets/images-icon/icon_" .. tostring(hashUrl(url)) .. ".png"
end

local SIRIUS_URL = "https://raw.githubusercontent.com/Kira762/astra-library/main/assets/window-icons/sirius.png"
local OTHER_URL = "https://example.com/mova-other-icon.png"

expect(isfolder("Mova"), "C1 Mova root exists after load")
expect(isfolder("Mova/assets"), "C1 Mova/assets exists after load")
expect(isfile("Mova/config/legacy.txt"), "C1 legacy Astra configs migrate to Mova")
expect(readfile("Mova/config/legacy.txt") == "legacy-config", "C1 config contents survive migration")
expect(readfile("Mova/config/shared.txt") == "new-mova-data", "C1 migration never overwrites Mova data")
expect(readfile("Astra/config/shared.txt") == "old-astra-data", "C1 old conflicting data remains untouched")
expect(isfile("Mova/keys/legacy.txt"), "C1 legacy saved keys migrate to Mova")
expect(readfile("Mova/keys/legacy.txt") == "legacy-key", "C1 saved key contents survive migration")
expect(isfile("Astra/config/legacy.txt"), "C1 migration leaves the old copy untouched")
local _, settingsPath = Mova.Settings.persistence.path()
expect(settingsPath == "Mova/settings/mova.txt", "C1 settings use the Mova filename")
expect(Mova.Settings.readPersisted("migrationProbe", "missing") == "legacy-settings", "C1 old settings are readable after migration")
expect(not isfolder("ImageCache"), "C1 Mova does not create ImageCache itself")

local window = Mova:CreateWindow({
	name = "ImageCacheFolder",
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.4)

local folder, file = window:GetPath()
expect(type(folder) == "string" and folder ~= "", "C1 GetPath returns a folder")
expect(string.find(folder, "Mova/config", 1, true) ~= nil, "C1 configs live under Mova/config")
expect(string.find(folder, "ImageCache", 1, true) == nil, "C1 configs are not stored under ImageCache")
expect(type(file) == "string" and string.find(file, "Mova/config", 1, true) ~= nil, "C1 config file is under Mova/config")

window:Unload()

-- ===== C2: empty executor ImageCache is discarded ========================

writefile(cachePathFor(SIRIUS_URL), "png-bytes")

local imported = {}
getcustomasset = function(path)
	imported[path] = true
	makefolder("ImageCache")
	expect(isfolder("ImageCache"), "C2 executor created ImageCache")
	return "rbxasset://from-cache/" .. tostring(path)
end

local empty = Mova:CreateWindow({
	name = "EmptyImageCache",
	icon = SIRIUS_URL,
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.4)

expect(imported[cachePathFor(SIRIUS_URL)] == true, "C2 getcustomasset ran for the cached window icon")
expect(not isfolder("ImageCache"), "C2 empty ImageCache leftover is discarded")

empty:Unload()

-- ===== C3: a non-empty ImageCache is left alone ==========================

writefile(cachePathFor(OTHER_URL), "png-bytes")

getcustomasset = function(path)
	makefolder("ImageCache")
	writefile("ImageCache/keep.bin", "executor-cache")
	return "rbxasset://ImageCache/keep.bin"
end

local kept = Mova:CreateWindow({
	name = "KeptImageCache",
	icon = OTHER_URL,
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.4)

expect(isfolder("ImageCache"), "C3 ImageCache with files is kept")
expect(isfile("ImageCache/keep.bin"), "C3 executor cache files are not deleted")

kept:Unload()

print("IMAGE CACHE FOLDER: empty leftover discarded, occupied cache kept, configs under Mova/config")
