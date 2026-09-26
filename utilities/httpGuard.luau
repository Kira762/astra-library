--[[
HttpGuard — HTTP interception (spy / hook) detection for Astra.

HttpSpy-style tools work by hooking the exact functions Astra fetches with:
`__namecall` on `game` (for `game:HttpGet` / `game:HttpPost` / `GetObjects`),
the executor's `request` function (`(syn or http).request`, aliased over the
global `request`), and the `game.HttpGet` / `game.HttpPost` closures directly.
Once hooked, every URL Astra touches is logged to a file and a CoreGui window,
and responses can be rewritten before Astra sees them (response spoofing).

What this module can and cannot do (read before relying on it)
--------------------------------------------------------------
* CAN: detect the fingerprints such tools leave behind, and let Astra refuse
  to fetch while they are present. Detection is layered so no single probe is
  load-bearing (see below).
* CANNOT: prevent a hook. `hookfunction` patches the closure itself, so code
  running inside the executor cannot hide from it or remove it. Anything that
  must be enforced (keys, purchases, permissions) needs a server — same trust
  model as the signed loader: tamper *evidence*, not a trust root.

Layers
------
* A — tool artifacts. Order-independent: they work even when the spy loaded
  before Astra. `genv-spy-api` (a `getgenv().HttpSpy` table with the spy's API
  shape), `coregui-spy-window` (a `HttpSpyGui` ScreenGui under CoreGui/gethui),
  `spy-log-files` (`HttpSpy_*.txt` in the workspace listing).
* B — baseline drift. `capture()` snapshots the pristine references (the
  entrypoint calls it on load); `scan()` reports `namecall-swapped`,
  `method-swapped` and `requestfn-swapped` when they no longer match. Blind
  when the spy loaded first — that is what layers A and C are for.
* C — baseline-free heuristics. `namecall-lclosure` (a pristine DataModel
  `__namecall` is a C closure; a hooked one is an executor Lua closure) and
  `cfunc-lua-source` (`debug.getinfo` no longer reports `[C]` for engine HTTP
  functions). Positive signals only: anything unknown is skipped, never a hit.

The whole scanner is gated on executor evidence (hook/introspection
primitives). A spy cannot run without them, so plain Studio and bare Luau
always scan clean — and every probe is pcall-wrapped, so `scan()` never
raises. Policies: `audit` (report only), `warn` (report + `warn()`),
`strict` (raise on any signal; unknown policies fail closed too), `off`.

Enforcement points (strict where it matters, quiet everywhere else)
-------------------------------------------------------------------
* `loader.luau` runs an inline preflight before fetching the bundle or the
  signature: a hit returns the quiet stub, like any other loader failure.
* `components/keySystem.luau` guards each `grabKeyFromSite` fetch: a hit
  drops the key exactly like a failed fetch (the gate fails closed, no
  raise surfaces).
* `utilities/assetResolver.luau` resolves its request function through
  `network.getGuardedRequestFn` with `warn`: icon/CDN URLs are public by
  design, so interception there warns and falls back instead of breaking.
* Hosts that want strict-at-load call `Astra.HttpGuard.check("strict")`
  before `CreateWindow`. It is not the entrypoint default on purpose: the
  C-layer trips on *any* `__namecall` hook (admin tools hook it too), and a
  UI library that refuses to coexist with those is a support burden.
]]

export type GuardPolicy = "audit" | "warn" | "strict" | "off"
export type GuardSignal = {
    id: string,
    layer: string,
    detail: string,
}
export type GuardReport = {
    clean: boolean,
    executor: boolean,
    captured: boolean,
    httpSpy: boolean,
    hooked: boolean,
    signals: { GuardSignal },
}

local HttpGuard = {}

local DEFAULT_POLICY: GuardPolicy = "strict"

-- Hook/introspection primitives whose presence proves an executor. Deliberately
-- narrow: filesystem functions are NOT evidence (Astra's own test stubs define
-- `writefile`/`listfiles`, and `getgenv` is stubbed too), and neither is
-- `debug` (plain Luau ships it). HttpSpy itself cannot load without
-- `hookfunction`/`hookmetamethod`/`newcclosure`, so anything it hooked trips
-- this gate, while Studio, bare Luau and every stub harness stay out.
local EVIDENCE_NAMES = {
    "hookfunction",
    "hookmetamethod",
    "islclosure",
    "iscclosure",
    "newcclosure",
    "getrawmetatable",
    "getgc",
    "checkcaller",
    "getnamecallmethod",
    "replaceclosure",
}

-- The `game` methods HttpSpy hooks (namecall table + direct closure hooks).
local GAME_METHODS = { "HttpGet", "HttpGetAsync", "GetObjects", "HttpPost", "HttpPostAsync" }

-- Request-function paths, same resolution order as `network.getRequestFn`.
local REQUEST_PATHS = {
    { "request" },
    { "http_request" },
    { "http", "request" },
    { "syn", "request" },
    { "fluxus", "request" },
}

-- `getgenv().HttpSpy` keys that make up the spy's API shape (layer A1 needs
-- at least two so a stray user table named HttpSpy does not false-positive).
local SPY_API_KEYS = { "OnRequest", "HookSynRequest", "BlockUrl", "ProxyHost", "ToggleGui", "SaveLogs" }

type Baseline = {
    namecall: any,
    methods: { [string]: any },
    requestFns: { [string]: any },
}

local baseline: Baseline? = nil

--[[
Live global environments, in lookup order. `getfenv(0)` is the live table on
the luau CLI and on executors; `_G` is stale under the CLI (it locks `_G`)
but live on Roblox and executors, where `getfenv` may not exist at all.
Probing both keeps every runtime working.
]]
local function globalRoots(): { { [string]: any } }
    local roots: { { [string]: any } } = {}
    local getfenvFn: any = nil
    pcall(function()
        getfenvFn = getfenv
    end)
    if type(getfenvFn) == "function" then
        local env: any = nil
        local ok = pcall(function()
            env = getfenvFn(0)
        end)
        if ok and type(env) == "table" then
            roots[#roots + 1] = env
        end
    end
    local g: any = nil
    pcall(function()
        g = _G
    end)
    if type(g) == "table" and g ~= roots[1] then
        roots[#roots + 1] = g
    end
    return roots
end

local function globalValue(name: string): any
    for _, root in globalRoots() do
        local value: any = nil
        local found = false
        pcall(function()
            value = root[name]
            found = value ~= nil
        end)
        if found then
            return value
        end
    end
    return nil
end

local function resolvePath(path: { string }): any
    for _, root in globalRoots() do
        local current: any = root
        local resolved = true
        for _, key in path do
            local nextValue: any = nil
            local ok = pcall(function()
                if type(current) == "table" then
                    nextValue = current[key]
                end
            end)
            if not ok then
                resolved = false
                break
            end
            current = nextValue
            if current == nil then
                resolved = false
                break
            end
        end
        if resolved then
            return current
        end
    end
    return nil
end

local function detectExecutor(): boolean
    for _, name in EVIDENCE_NAMES do
        if type(globalValue(name)) == "function" then
            return true
        end
    end
    return false
end

local function currentNamecall(): any
    local gameRef = globalValue("game")
    if gameRef == nil then
        return nil
    end
    local getrawmetatable = globalValue("getrawmetatable")
    if type(getrawmetatable) ~= "function" then
        return nil
    end
    local mt: any = nil
    local ok = pcall(function()
        mt = getrawmetatable(gameRef)
    end)
    if not ok or type(mt) ~= "table" then
        return nil
    end
    local namecall: any = nil
    pcall(function()
        namecall = mt.__namecall
    end)
    return namecall
end

local function emit(signals: { GuardSignal }, id: string, layer: string, detail: string)
    signals[#signals + 1] = { id = id, layer = layer, detail = detail }
end

--[[
Snapshot the pristine HTTP references. Called by the entrypoint on load; safe
to call again, but re-capturing after a spy loads blinds layer B (layers A
and C keep working). Returns false only when the environment could not be
read at all.
]]
function HttpGuard.capture(): boolean
    local ok = pcall(function()
        local snap: Baseline = { namecall = nil, methods = {}, requestFns = {} }
        snap.namecall = currentNamecall()
        local gameRef = globalValue("game")
        if gameRef ~= nil then
            for _, method in GAME_METHODS do
                local fn: any = nil
                local readOk = pcall(function()
                    fn = gameRef[method]
                end)
                if readOk and type(fn) == "function" then
                    snap.methods[method] = fn
                end
            end
        end
        for _, path in REQUEST_PATHS do
            local fn: any = nil
            local readOk = pcall(function()
                fn = resolvePath(path)
            end)
            if readOk and type(fn) == "function" then
                snap.requestFns[table.concat(path, ".")] = fn
            end
        end
        baseline = snap
    end)
    return ok and baseline ~= nil
end

local function probeGenvSpyApi(signals: { GuardSignal })
    local getgenv = globalValue("getgenv")
    if type(getgenv) ~= "function" then
        return
    end
    local genv: any = nil
    local ok = pcall(function()
        genv = getgenv()
    end)
    if not ok or type(genv) ~= "table" then
        return
    end
    local spy: any = nil
    pcall(function()
        spy = genv.HttpSpy
    end)
    if type(spy) ~= "table" then
        return
    end
    local hits = 0
    for _, key in SPY_API_KEYS do
        local present = false
        pcall(function()
            present = spy[key] ~= nil
        end)
        if present then
            hits = hits + 1
        end
    end
    if hits >= 2 then
        emit(signals, "genv-spy-api", "A", "getgenv().HttpSpy matches the HttpSpy API shape")
    end
end

local function probeCoreGuiWindow(signals: { GuardSignal })
    local gameRef = globalValue("game")
    if gameRef == nil then
        return
    end
    local roots: { any } = {}
    local coreGui: any = nil
    local svcOk = pcall(function()
        coreGui = gameRef:GetService("CoreGui")
    end)
    if svcOk and coreGui ~= nil then
        roots[#roots + 1] = coreGui
    end
    local gethui = globalValue("gethui")
    if type(gethui) == "function" then
        local hui: any = nil
        local huiOk = pcall(function()
            hui = gethui()
        end)
        if huiOk and hui ~= nil then
            roots[#roots + 1] = hui
        end
    end
    for _, root in roots do
        local found: any = nil
        local findOk = pcall(function()
            local finder = root.FindFirstChild
            if type(finder) == "function" then
                found = finder(root, "HttpSpyGui", true)
            end
        end)
        if findOk and found ~= nil then
            local name: any = nil
            local class: any = nil
            pcall(function()
                name = found.Name
            end)
            pcall(function()
                class = found.ClassName
            end)
            if name == "HttpSpyGui" and (class == "ScreenGui" or class == nil) then
                emit(signals, "coregui-spy-window", "A", "HttpSpyGui window is present")
                return
            end
        end
    end
end

local function probeSpyLogFiles(signals: { GuardSignal })
    local listfiles = globalValue("listfiles")
    if type(listfiles) ~= "function" then
        return
    end
    for _, dir in { "", "." } do
        local files: any = nil
        local ok = pcall(function()
            files = listfiles(dir)
        end)
        if ok and type(files) == "table" then
            for _, path in files do
                if
                    type(path) == "string"
                    and (
                        path:match("HttpSpy_[^/\\]*%.txt$")
                        or path:match("HttpSpy_log[^/\\]*%.txt$")
                    )
                then
                    emit(signals, "spy-log-files", "A", "spy log file is present: " .. path)
                    return
                end
            end
        end
    end
end

local function probeBaselineDrift(signals: { GuardSignal })
    local snap = baseline
    if snap == nil then
        return
    end
    if snap.namecall ~= nil then
        local current: any = nil
        local ok = pcall(function()
            current = currentNamecall()
        end)
        if ok and type(current) == "function" and not rawequal(current, snap.namecall) then
            emit(signals, "namecall-swapped", "B", "game __namecall no longer matches the captured reference")
        end
    end
    local gameRef = globalValue("game")
    if gameRef ~= nil then
        for _, method in GAME_METHODS do
            local pristine = snap.methods[method]
            if pristine ~= nil then
                local current: any = nil
                local ok = pcall(function()
                    current = gameRef[method]
                end)
                if ok and type(current) == "function" and not rawequal(current, pristine) then
                    emit(signals, "method-swapped", "B", "game." .. method .. " no longer matches the captured reference")
                end
            end
        end
    end
    for _, path in REQUEST_PATHS do
        local key = table.concat(path, ".")
        local pristine = snap.requestFns[key]
        if pristine ~= nil then
            local current: any = nil
            local ok = pcall(function()
                current = resolvePath(path)
            end)
            if ok and type(current) == "function" and not rawequal(current, pristine) then
                emit(signals, "requestfn-swapped", "B", key .. " no longer matches the captured reference")
            end
        end
    end
end

local function probeNamecallClosure(signals: { GuardSignal })
    local namecall: any = nil
    local ok = pcall(function()
        namecall = currentNamecall()
    end)
    if not ok or type(namecall) ~= "function" then
        return
    end
    local islclosure = globalValue("islclosure")
    if type(islclosure) == "function" then
        local isLua = false
        local checkOk = pcall(function()
            isLua = islclosure(namecall) == true
        end)
        if checkOk and isLua then
            emit(signals, "namecall-lclosure", "C", "game __namecall is a Lua closure (pristine is a C closure)")
        end
        return
    end
    local iscclosure = globalValue("iscclosure")
    if type(iscclosure) == "function" then
        local isC = true
        local checkOk = pcall(function()
            isC = iscclosure(namecall) ~= false
        end)
        if checkOk and not isC then
            emit(signals, "namecall-lclosure", "C", "game __namecall is not a C closure")
        end
    end
end

local function probeCfuncSource(signals: { GuardSignal })
    -- debug.getinfo exists on executors (stock Luau/Roblox omit it); when it
    -- is absent there is nothing to compare, so the probe skips.
    local debugLib = globalValue("debug")
    if type(debugLib) ~= "table" then
        return
    end
    local getinfo = debugLib.getinfo
    if type(getinfo) ~= "function" then
        return
    end
    local candidates: { { label: string, fn: (...any) -> any } } = {}
    local gameRef = globalValue("game")
    if gameRef ~= nil then
        for _, method in GAME_METHODS do
            local fn: any = nil
            local ok = pcall(function()
                fn = gameRef[method]
            end)
            if ok and type(fn) == "function" then
                candidates[#candidates + 1] = { label = "game." .. method, fn = fn }
            end
        end
    end
    for _, path in REQUEST_PATHS do
        local fn: any = nil
        local ok = pcall(function()
            fn = resolvePath(path)
        end)
        if ok and type(fn) == "function" then
            candidates[#candidates + 1] = { label = table.concat(path, "."), fn = fn }
        end
    end
    for _, candidate in candidates do
        local label = candidate.label
        local fn = candidate.fn
        local info: any = nil
        local ok = pcall(function()
            info = getinfo(fn)
        end)
        if ok and type(info) == "table" and type(info.source) == "string" and info.source ~= "[C]" then
            -- Engine HTTP entry points are C functions. A Lua chunk source here
            -- means the reference was swapped for (or reports as) script code.
            -- Some executors keep reporting `[C]` through `hookfunction`, so a
            -- `[C]` source is *not* proof of clean — only a non-`[C]` source
            -- is a signal.
            emit(signals, "cfunc-lua-source", "C", label .. " reports a Lua source (" .. info.source .. ")")
        end
    end
end

--[[
Run every probe and return the report. Never raises: each probe is isolated,
unknowns are skipped, and without executor evidence the report is clean by
construction (a spy cannot run where no hook primitive exists).
]]
function HttpGuard.scan(): GuardReport
    local report: GuardReport = {
        clean = true,
        executor = false,
        captured = baseline ~= nil,
        httpSpy = false,
        hooked = false,
        signals = {},
    }
    local execOk, exec = pcall(detectExecutor)
    report.executor = execOk and exec == true
    if not report.executor then
        return report
    end
    local probes = {
        probeGenvSpyApi,
        probeCoreGuiWindow,
        probeSpyLogFiles,
        probeBaselineDrift,
        probeNamecallClosure,
        probeCfuncSource,
    }
    for _, probe in probes do
        pcall(probe, report.signals)
    end
    for _, signal in report.signals do
        if signal.layer == "A" then
            report.httpSpy = true
        else
            report.hooked = true
        end
    end
    report.clean = #report.signals == 0
    return report
end

--[[
Enforce a policy against a fresh scan. Returns `true` when the environment is
clean. Otherwise `audit` and `warn` return `false` (warn also `warn()`s every
signal), while `strict` raises. Unknown policies fail closed like `strict`.
`off` skips the scan and always returns `true`.
]]
function HttpGuard.check(policy: GuardPolicy?): (boolean, GuardReport)
    local effective: string = policy or DEFAULT_POLICY
    if effective == "off" then
        return true, {
            clean = true,
            executor = false,
            captured = baseline ~= nil,
            httpSpy = false,
            hooked = false,
            signals = {},
        }
    end
    local report = HttpGuard.scan()
    if report.clean then
        return true, report
    end
    if effective == "audit" then
        return false, report
    end
    if effective == "warn" then
        local warnFn = globalValue("warn")
        if type(warnFn) == "function" then
            for _, signal in report.signals do
                pcall(warnFn, ("Astra HttpGuard [%s/%s]: %s"):format(signal.layer, signal.id, signal.detail))
            end
        end
        return false, report
    end
    local parts: { string } = {}
    for _, signal in report.signals do
        parts[#parts + 1] = signal.layer .. "/" .. signal.id
    end
    error(("Astra: refusing to continue — HTTP interception detected (%s)"):format(table.concat(parts, ", ")), 0)
    return false, report
end

--[[
Run `fetch` only when the policy allows it. Returns `(true, result)` on a
clean scan; on a hit, `audit`/`warn` return `(false, nil)` without calling
`fetch`, and `strict` raises (callers that soft-fail wrap this in `pcall`,
like the key system does).
]]
function HttpGuard.guardFetch(url: string, fetch: () -> any, policy: GuardPolicy?): (boolean, any)
    local allowed = HttpGuard.check(policy)
    if not allowed then
        return false, nil
    end
    return true, fetch()
end

function HttpGuard.setDefaultPolicy(policy: GuardPolicy): GuardPolicy
    if policy ~= "audit" and policy ~= "warn" and policy ~= "strict" and policy ~= "off" then
        error(("Astra HttpGuard: invalid policy %q (want audit, warn, strict or off)"):format(tostring(policy)), 0)
    end
    DEFAULT_POLICY = policy
    return DEFAULT_POLICY
end

function HttpGuard.getDefaultPolicy(): GuardPolicy
    return DEFAULT_POLICY
end

return HttpGuard
