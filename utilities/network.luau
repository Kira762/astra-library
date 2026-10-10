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
-- loader) but do not expose a separate `request` function. This is the bare
-- transport: `getGuardedHttpGetFn` is the guarded one, and callers that have
-- their own gate (see `publicAssetAllowed`) use this.
function network.getHttpGetFn(): RequestFn?
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

    return function(url: string): any
        return httpGet(gameRef, url)
    end
end

function network.getGuardedHttpGetFn(policy: HttpGuard.GuardPolicy?): RequestFn?
    if not HttpGuard.check(policy or "warn") then
        return nil
    end
    return network.getHttpGetFn()
end

--[[
=========================================================================
Public asset transports
=========================================================================
`icons.resolve` answers with a raw.githubusercontent.com URL, so every
catalog PNG is fetched through here. Those files are public, cosmetic and
identical for every user: they are not a trust boundary, and a gate there
must never be the reason a window renders with no icons.

The full guard is the wrong gate for them. Two of its probes are layer-C
heuristics - they fire on *any* `__namecall` hook installed by another
script (an admin panel, ESP, aimbot) and on an executor whose `request` is
a Lua wrapper rather than a C closure. Neither means Astra's own requests
are being read or rewritten, yet `getGuardedRequestFn`/`getGuardedHttpGetFn`
refuse on any signal, so the fetch returned nil, `cache/imageCache` kept its
empty `Image`, and the numeric window glyphs (rbxassetids, no download) were
the only icons left on screen.

What does justify refusing a public asset is an actual HTTP-spy artifact:
layer A's `getgenv().HttpSpy` API shape, the spy's CoreGui window, or its
log files. Those are what `publicAssetAllowed` gates on, for both
transports. The sensitive paths - the signed loader's bundle/signature
preflight and `components/keySystem.luau` - keep using the full guard.

Callers keep the historic order: the request function first, and the
HttpGet fallback only when no request function is available at all.
]]

local function publicAssetAllowed(policy: HttpGuard.GuardPolicy?): boolean
    local allowed, report = HttpGuard.check(policy or "warn")
    if allowed then
        return true
    end
    -- The scan is not clean: only a real spy artifact refuses the fetch.
    return report ~= nil and report.httpSpy ~= true
end

function network.getAssetRequestFn(policy: HttpGuard.GuardPolicy?): RequestFn?
    local fn = network.getRequestFn(nil)
    if fn == nil or not publicAssetAllowed(policy) then
        return nil
    end
    return fn
end

function network.getAssetHttpGetFn(policy: HttpGuard.GuardPolicy?): RequestFn?
    if not publicAssetAllowed(policy) then
        return nil
    end
    return network.getHttpGetFn()
end

return network
