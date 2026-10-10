--[[
Executor layer for the public-asset transport regression.

Models the environment that made every catalog icon blank while the numeric
window glyphs still rendered: an executor with the usual filesystem and
`getcustomasset`, a `request` function that is a Lua wrapper (so the source
probe reads a chunk path, not "[C]"), and a `__namecall` that some other
script has hooked - an admin panel, ESP, aimbot, anything. Both are layer-C
heuristics: they say an executor is present, not that Astra's own requests
are being read or rewritten. There is no HTTP-spy artifact here.

The request function counts its URLs; `game:HttpGet` is deliberately absent
(the executor exposes `request`, so nothing should need it).
]]

local genv = getgenv()
local files = {}
local folders = {}
local imported = {}
local fetched = {}
local png = "\137PNG\r\n\26\n" .. "asset-guard-body"

genv.writefile = function(path, body)
    files[path] = body
end

genv.isfile = function(path)
    return files[path] ~= nil
end

genv.isfolder = function(path)
    return folders[path] == true
end

genv.makefolder = function(path)
    folders[path] = true
end

genv.getcustomasset = function(path)
    if files[path] == nil then
        error("missing local image: " .. path)
    end
    imported[path] = true
    return "rbxasset://asset-guard/" .. path
end

local requestFn = function(payload)
    fetched[payload.Url] = (fetched[payload.Url] or 0) + 1
    return { Success = true, StatusCode = 200, Body = png }
end
genv.request = requestFn

-- Hook/introspection primitives: the guard's executor gate is open.
genv.hookfunction = function(fn)
    return fn
end
genv.newcclosure = function(fn)
    return fn
end
genv.checkcaller = function()
    return false
end
genv.getnamecallmethod = function()
    return "HttpGet"
end

-- Someone else's namecall hook: a Lua closure where a pristine DataModel
-- __namecall is a C closure.
local hookedNamecall = function() end
genv.getrawmetatable = function()
    return { __namecall = hookedNamecall }
end

genv.islclosure = function(fn)
    return type(fn) == "function"
end
genv.iscclosure = function()
    return false
end

-- `debug.getinfo` as an executor exposes it: Astra's own engine HTTP entry
-- points read as "[C]", the executor's `request` wrapper reads as a chunk.
genv.debug = {
    getinfo = function(fn)
        if fn == requestFn then
            return { source = "=executor/request.lua", short_src = "request.lua", what = "Lua" }
        end
        return { source = "[C]", short_src = "[C]", what = "C" }
    end,
}

genv.__AssetGuardTest = {
    files = files,
    folders = folders,
    imported = imported,
    fetched = fetched,
    png = png,
    request = requestFn,
}
