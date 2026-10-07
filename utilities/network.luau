local HttpGuard = require(script.Parent.httpGuard)

local network = {}
network.__index = network

export type RequestFn = (...any) -> any

--[[
The caller's environment, or nil when it cannot be read. `getfenv` is
neither guaranteed to exist nor guaranteed to work: a sandbox that ships a
throwing one must not take down the paths that look for a request function
(asset downloads, a notification's icon), so the probe is pcall'd and `_G`
is the fallback — the same shape `utilities/httpGuard.luau` uses to find
live globals.
]]
local function environment(): any?
    local getfenvFn: any = nil
    pcall(function()
        getfenvFn = getfenv
    end)
    if type(getfenvFn) == "function" then
        local ok, env = pcall(getfenvFn)
        if ok and type(env) == "table" then
            return env
        end
    end
    local g: any = nil
    pcall(function()
        g = _G
    end)
    return if type(g) == "table" then g else nil
end

function network.getRequestFn(env: any?): RequestFn?
    env = env or environment()
    if type(env) ~= "table" then
        return nil
    end
    return env.request
        or env.http_request
        or (env.http and env.http.request)
        or (env.syn and env.syn.request)
        or (env.fluxus and env.fluxus.request)
end

--[[
Resolve the request function, refusing to hand it back while HTTP
interception is detected. `warn` (the default) returns nil so callers fall
back to their no-request-function path; `strict` raises instead. Both are
silent: the guard reports through `Astra.HttpGuard`, never the console, so
the tool that hooked the fetch cannot read a denial. `audit` returns nil
too, `off` skips the scan.
]]
function network.getGuardedRequestFn(env: any?, policy: HttpGuard.GuardPolicy?): RequestFn?
    local fn = network.getRequestFn(env)
    if fn == nil then
        return nil
    end
    local allowed = HttpGuard.check(policy or "warn")
    if not allowed then
        return nil
    end
    return fn
end

return network
