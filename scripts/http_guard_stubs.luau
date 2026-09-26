--[[
Fake executor layer for the HttpGuard suite. Loaded after
sidebar_sizing_stubs.luau and before the bundle: hook/introspection
primitives plus mutable spy artifacts, so every HttpGuard probe can be driven
both clean and tripped inside one run.

Clean baseline (what the bundle captures at load): the `game` HTTP methods
and the fake `__namecall` are real C functions (`print`), no `HttpSpy` table
sits in the genv store, the fake hui root has no children, and the workspace
listing is empty. The test flips each of these and asserts the matching
signal id, then flips it back.

Control handles live at `getgenv().__HttpGuardTest` (`mt`, `files`,
`guiChildren`, `pristineNamecall`) — no new globals beyond the fake
executor functions themselves.
]]

-- Lua-vs-C closure tests answered from real debug info, like an executor's.
islclosure = function(fn)
    if type(fn) ~= "function" then
        return false
    end
    local ok, info = pcall(debug.getinfo, fn)
    return ok and type(info) == "table" and info.what == "Lua"
end

iscclosure = function(fn)
    if type(fn) ~= "function" then
        return false
    end
    local ok, info = pcall(debug.getinfo, fn)
    return ok and type(info) == "table" and info.what == "C"
end

-- Executors (and HttpSpy's own serializer) use debug.getinfo, which stock
-- Luau and Roblox omit. Swap the (readonly) debug table for a delegating one
-- so the source probe exercises genuine sources: "[C]" for C functions,
-- chunk paths for Lua. Everything else falls through to the real table.
local realDebug = debug
debug = setmetatable({
    getinfo = function(fn)
        local ok, source = pcall(realDebug.info, fn, "s")
        if not ok then
            return nil
        end
        return { source = source, short_src = source, what = if source == "[C]" then "C" else "Lua" }
    end,
}, { __index = realDebug })

-- Evidence shims: present so the executor gate opens. The test simulates
-- hooks by swapping values directly, which is what detection observes.
hookfunction = function(fn)
    return fn
end

newcclosure = function(fn)
    return fn
end

local fakeMt = { __namecall = print }
getrawmetatable = function(value)
    if value == game then
        return fakeMt
    end
    return getmetatable(value)
end

local fakeFiles = {}
listfiles = function()
    local out = {}
    for i, path in ipairs(fakeFiles) do
        out[i] = path
    end
    return out
end

local guiChildren = {}
gethui = function()
    return {
        FindFirstChild = function(_self, name)
            for _, child in ipairs(guiChildren) do
                if type(child) == "table" and child.Name == name then
                    return child
                end
            end
            return nil
        end,
    }
end

-- Pristine engine HTTP entry points are C functions.
game.HttpGet = print
game.HttpGetAsync = print
game.GetObjects = print
game.HttpPost = print
game.HttpPostAsync = print

getgenv().__HttpGuardTest = {
    mt = fakeMt,
    files = fakeFiles,
    guiChildren = guiChildren,
    pristineNamecall = print,
}
