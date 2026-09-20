-- A minimal in-memory stand-in for the executor filesystem API that Astra's
-- persistence layer talks to (writefile / readfile / isfile / listfiles /
-- delfile). Config and settings suites need it; without it `isfile` is nil and
-- the first autosave assertion dies with "attempt to call a nil value".
--
-- `listfiles` reports everything `writefile` created, so config listing can be
-- exercised: a fake filesystem where `isfile` says yes but the listing comes
-- back empty cannot test the saved-configurations dropdown at all.
local files = {}
writefile = function(path, content) files[path] = content end
readfile = function(path) return files[path] or "" end
isfile = function(path) return files[path] ~= nil end
isfolder = function() return true end
makefolder = function() end
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
