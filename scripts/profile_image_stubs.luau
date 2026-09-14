-- Model cached executor images as local Roblox URIs, never renderable HTTPS URLs.
local files = {}
writefile = function(path, content) files[path] = content end
readfile = function(path) return files[path] or "" end
isfile = function(path) return string.match(path, "icon_%d+%.png$") ~= nil or files[path] ~= nil end
isfolder = function() return true end
makefolder = function() end
-- [[A real executor's listfiles sees everything writefile created; the old]]
-- [[hard-coded {} here made the fake filesystem inconsistent (isfile true,]]
-- [[listing empty), so config listing could never be exercised in tests.]]
listfiles = function(dir)
    local prefix = tostring(dir or ""):gsub("/+$", "") .. "/"
    local names = {}
    for filePath in pairs(files) do
        if filePath:sub(1, #prefix) == prefix then
            table.insert(names, filePath)
        end
    end
    table.sort(names)
    return names
end
delfile = function(path) files[path] = nil end
delfolder = function() end
getcustomasset = function(path) return "rbxasset://test/" .. string.match(path, "[^/]+$") end
function TestImageUri(url)
    local hash = 0
    for index = 1, #url do
        hash = (hash * 33 + string.byte(url, index)) % 2147483647
    end
    return "rbxasset://test/icon_" .. tostring(hash) .. ".png"
end
