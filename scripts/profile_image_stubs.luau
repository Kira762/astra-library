-- Model cached executor images as local Roblox URIs, never renderable HTTPS URLs.
local files = {}
writefile = function(path, content) files[path] = content end
readfile = function(path) return files[path] or "" end
isfile = function(path) return string.match(path, "icon_%d+%.png$") ~= nil or files[path] ~= nil end
isfolder = function() return true end
makefolder = function() end
listfiles = function() return {} end
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
