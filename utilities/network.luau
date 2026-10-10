local HttpGuard = require(script.Parent.httpGuard)
local globals = require(script.Parent.globals)

local network = {}
network.__index = network

export type RequestFn = (...any) -> any

local REQUEST_PATHS = {
    { "request" },
    { "http_request" },
    { "http", "request" },
    { "syn", "request" },
    { "fluxus", "request" },
}

local function functionAt(root: any, path: { string }): RequestFn?
    local current = root
    for _, key in path do
        if type(current) ~= "table" then
            return nil
        end
        local ok, value = pcall(function()
            return current[key]
        end)
        if not ok then
            return nil
        end
        current = value
        if current == nil then
            return nil
        end
    end
    return if type(current) == "function" then current else nil
end

function network.getRequestFn(env: any?): RequestFn?
    if env ~= nil then
        for _, path in REQUEST_PATHS do
            local fn = functionAt(env, path)
            if fn then
                return fn
            end
        end
        return nil
    end

    for _, root in globals.roots() do
        for _, path in REQUEST_PATHS do
            local fn = functionAt(root, path)
            if fn then
                return fn
            end
        end
    end
    return nil
end

-- Resolve the request function, refusing to hand it back while HTTP
-- interception is detected. `warn` (the default) returns nil so callers
-- can take a quiet fallback path; `strict` raises instead.
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

-- Some executors can run `game:HttpGet` (including the bundle's documented
-- loader) but do not expose a separate `request` function. This fallback is
-- guarded against the same HTTP interception checks; callers must not use it
-- after a request function was found but denied, or it would bypass a refusal.
function network.getGuardedHttpGetFn(policy: HttpGuard.GuardPolicy?): RequestFn?
    local gameRef = globals.get("game")
    if gameRef == nil then
        return nil
    end

    local httpGet: any = nil
    pcall(function()
        httpGet = gameRef.HttpGet
        if type(httpGet) ~= "function" then
            httpGet = gameRef.HttpGetAsync
        end
    end)
    if type(httpGet) ~= "function" then
        return nil
    end

    if not HttpGuard.check(policy or "warn") then
        return nil
    end

    return function(url: string): any
        return httpGet(gameRef, url)
    end
end

return network
