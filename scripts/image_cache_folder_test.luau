--[[
===== workspace ImageCache leftover =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau plus a folder-
tracking executor filesystem.

Astra never creates a workspace-root `ImageCache` folder — images live
under `Astra/assets/images-icon`, configs under `Astra/config`. Some
executors mkdir `ImageCache` on `getcustomasset` and leave it empty.
This suite pins the cleanup:
  * C1  configs stay under Astra/config, never ImageCache,
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
	return "Astra/assets/images-icon/icon_" .. tostring(hashUrl(url)) .. ".png"
end

local SIRIUS_URL = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/assets/window-icons/sirius.png"
local OTHER_URL = "https://example.com/astra-other-icon.png"

expect(isfolder("Astra"), "C1 Astra root exists after load")
expect(isfolder("Astra/assets"), "C1 Astra/assets exists after load")
expect(not isfolder("ImageCache"), "C1 Astra does not create ImageCache itself")

local window = Astra:CreateWindow({
	name = "ImageCacheFolder",
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.4)

local folder, file = window:GetPath()
expect(type(folder) == "string" and folder ~= "", "C1 GetPath returns a folder")
expect(string.find(folder, "Astra/config", 1, true) ~= nil, "C1 configs live under Astra/config")
expect(string.find(folder, "ImageCache", 1, true) == nil, "C1 configs are not stored under ImageCache")
expect(type(file) == "string" and string.find(file, "Astra/config", 1, true) ~= nil, "C1 config file is under Astra/config")

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

local empty = Astra:CreateWindow({
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

local kept = Astra:CreateWindow({
	name = "KeptImageCache",
	icon = OTHER_URL,
	configuration = { autoSave = false, autoLoad = false },
})
TestPump(0.4)

expect(isfolder("ImageCache"), "C3 ImageCache with files is kept")
expect(isfile("ImageCache/keep.bin"), "C3 executor cache files are not deleted")

kept:Unload()

print("IMAGE CACHE FOLDER: empty leftover discarded, occupied cache kept, configs under Astra/config")
