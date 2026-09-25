--[[
Executor workspace filesystem that actually tracks folders, so tests can
assert that an empty leftover `ImageCache` is discarded and a non-empty
one is left alone. The persistence stubs always report `isfolder == true`,
which cannot observe this.
]]
local files = {}
local folders = {}

local function parentOf(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local function ensureParents(path: string)
	local parent = parentOf(path)
	while parent and parent ~= "" do
		folders[parent] = true
		parent = parentOf(parent)
	end
end

writefile = function(path, content)
	files[path] = content
	ensureParents(path)
end

readfile = function(path)
	local body = files[path]
	if body == nil then
		error("file not found: " .. tostring(path))
	end
	return body
end

isfile = function(path)
	return files[path] ~= nil
end

isfolder = function(path)
	return folders[path] == true
end

makefolder = function(path)
	folders[path] = true
	ensureParents(path)
end

delfile = function(path)
	files[path] = nil
end

delfolder = function(path)
	folders[path] = nil
	local prefix = tostring(path) .. "/"
	for filePath in pairs(files) do
		if string.sub(filePath, 1, #prefix) == prefix then
			files[filePath] = nil
		end
	end
	for folderPath in pairs(folders) do
		if string.sub(folderPath, 1, #prefix) == prefix then
			folders[folderPath] = nil
		end
	end
end

listfiles = function(dir)
	local prefix = tostring(dir or ""):gsub("/+$", "") .. "/"
	local names = {}
	local seen = {}
	local function add(full: string)
		if not seen[full] then
			seen[full] = true
			table.insert(names, full)
		end
	end
	for filePath in pairs(files) do
		if string.sub(filePath, 1, #prefix) == prefix then
			local rest = string.sub(filePath, #prefix + 1)
			local child = string.match(rest, "^[^/]+")
			if child then
				add(prefix .. child)
			end
		end
	end
	for folderPath in pairs(folders) do
		if string.sub(folderPath, 1, #prefix) == prefix then
			local rest = string.sub(folderPath, #prefix + 1)
			local child = string.match(rest, "^[^/]+")
			if child then
				add(prefix .. child)
			end
		end
	end
	table.sort(names)
	return names
end
