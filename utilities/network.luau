local HttpGuard = require(script.Parent.httpGuard)

local network = {}
network.__index = network

export type RequestFn = (...any) -> any

function network.getRequestFn(env: any?): RequestFn?
    env = env or getfenv()
    return env.request
        or env.http_request
        or (env.http and env.http.request)
        or (env.syn and env.syn.request)
        or (env.fluxus and env.fluxus.request)
end

--[[
Resolve the request function, refusing to hand it back while HTTP
interception is detected. `warn` (the default) reports and returns nil so
callers fall back to their no-request-function path; `strict` raises instead.
`audit` returns nil silently, `off` skips the scan.
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
