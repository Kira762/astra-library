--[[
HttpGuard suite: every probe trips on its artifact and stays quiet without
it, policies enforce (`strict` raises, `warn`/`audit` deny, `off` skips) with
nothing on the console — a tripped scan is indistinguishable from a clean one
unless the caller reads the report — and the executor gate keeps non-executor
environments clean. The library prints nothing at all; the suite asserts that
against the global warn/print for the guard and for the asset path.

Runs against the generated bundle with scripts/http_guard_stubs.luau
providing the fake executor. Each phase restores what it mutates so phases
stay independent; the final phase re-asserts a fully clean scan.
]]

local function expect(condition, message)
    if not condition then
        error("HTTPGUARD FAIL: " .. tostring(message), 0)
    end
end

local function eq(actual, wanted, message)
    if actual ~= wanted then
        error(
            ("HTTPGUARD FAIL: %s (got %s, want %s)"):format(
                tostring(message),
                tostring(actual),
                tostring(wanted)
            ),
            0
        )
    end
end

local function hasSignal(report, id)
    for _, signal in ipairs(report.signals) do
        if signal.id == id then
            return true
        end
    end
    return false
end

local function expectOnly(report, ids, message)
    eq(#report.signals, #ids, message .. " (signal count)")
    for _, id in ipairs(ids) do
        expect(hasSignal(report, id), message .. " (missing " .. id .. ")")
    end
end

local guard = (Astra :: any).HttpGuard
expect(guard ~= nil, "Astra.HttpGuard is exposed")
expect(guard.capture() == true, "capture reports success")

local genv = getgenv()
local handles = genv.__HttpGuardTest
expect(type(handles) == "table", "stub control handles are present")

eq(guard.getDefaultPolicy(), "strict", "default policy is strict")

-- 1 — clean baseline: gate open (fake executor), nothing planted.
local report = guard.scan()
eq(report.executor, true, "fake executor is detected")
eq(report.captured, true, "entrypoint captured a baseline")
eq(report.clean, true, "clean environment scans clean")
eq(#report.signals, 0, "clean scan carries no signals")
local checkOk = guard.check("strict")
eq(checkOk, true, "strict check passes when clean")

-- 2 — genv spy API: shape needs two hits, one is not enough.
genv.HttpSpy = { OnRequest = {} }
report = guard.scan()
eq(hasSignal(report, "genv-spy-api"), false, "single-key HttpSpy table is not a signal")
genv.HttpSpy = {
    OnRequest = {},
    HookSynRequest = function() end,
    BlockUrl = function() end,
}
report = guard.scan()
eq(report.clean, false, "spy API table trips the scan")
eq(report.httpSpy, true, "layer-A hit flags httpSpy")
expectOnly(report, { "genv-spy-api" }, "spy API table")

local strictOk = pcall(function()
    guard.check("strict")
end)
eq(strictOk, false, "strict check raises under a spy")

-- Silence is the contract: the library never writes to the console, so a
-- tripped scan leaves no trace for the tool that tripped it to read. Capture
-- the global warn/print and assert both stay empty for every policy.
local warns = {}
local prints = {}
local realWarn = warn
local realPrint = print
warn = function(message)
    warns[#warns + 1] = message
end
print = function(...)
    prints[#prints + 1] = select(1, ...)
end
local function resetConsole()
    table.clear(warns)
    table.clear(prints)
end

local warnOk, warnReport = guard.check("warn")
eq(warnOk, false, "warn check returns false under a spy")
eq(warnReport.clean, false, "warn check returns the tripped report")
eq(#warns, 0, "warn check warns about nothing")
eq(#prints, 0, "warn check prints nothing")

local auditSilent = guard.check("audit")
eq(auditSilent, false, "audit check returns false under a spy")
eq(#warns, 0, "audit check prints nothing")

guard.scan()
eq(#warns, 0, "scan warns about nothing")
eq(#prints, 0, "scan prints nothing")

local denied, deniedBody = guard.guardFetch("https://example.test/key", function()
    return "body"
end, "warn")
eq(denied, false, "guardFetch denies under a spy")
eq(deniedBody, nil, "a denied guardFetch returns nil")
eq(#warns, 0, "a denied guardFetch warns about nothing")
eq(#prints, 0, "a denied guardFetch prints nothing")

pcall(function()
    guard.check("strict")
end)
eq(#warns, 0, "strict prints nothing either")

-- The library's own fetch points are silent too. Drive the asset resolver with
-- a request function the source probe reads as C (an executor's would be):
-- clean it downloads and says nothing, and with a spy planted it falls back to
-- nil and still says nothing — the behaviour the old "No request function
-- available to download asset content." warning broke.
local resolver = (Astra :: any).Core.state.assetResolver
local fetched = {}
local requestStub = function()
    fetched[#fetched + 1] = true
    return { Success = true, StatusCode = 200, Body = "asset-bytes" }
end
handles.cfuncs[requestStub] = true
request = requestStub

-- The phase-2 spy table is still planted here: the guarded case first.
resetConsole()
eq(
    resolver:getAssetContentFromUrl("https://example.test/icon.png", nil, true),
    nil,
    "a guarded asset download falls back to nil"
)
eq(#fetched, 0, "a guarded asset download never reaches the request function")
eq(#warns, 0, "a guarded asset download warns about nothing")
eq(#prints, 0, "a guarded asset download prints nothing")

-- Now the same call on a clean environment: it must go through, and still
-- say nothing (a download that succeeds has nothing to report).
genv.HttpSpy = nil
resetConsole()
eq(
    resolver:getAssetContentFromUrl("https://example.test/icon.png", nil, true),
    "asset-bytes",
    "a clean asset download returns the body"
)
eq(#fetched, 1, "a clean asset download reaches the request function")
eq(#warns, 0, "a clean asset download warns about nothing")
eq(#prints, 0, "a clean asset download prints nothing")

-- Restore phase 2's state for the assertions that follow it.
genv.HttpSpy = { OnRequest = {}, BlockUrl = function() end }
request = nil
handles.cfuncs[requestStub] = nil
resetConsole()

warn = realWarn
print = realPrint

local auditOk, auditReport = guard.check("audit")
eq(auditOk, false, "audit check returns false under a spy")
eq(auditReport.clean, false, "audit check returns the tripped report")

local offOk, offReport = guard.check("off")
eq(offOk, true, "off skips enforcement")
eq(offReport.clean, true, "off reports clean without scanning")

local fetchRan = false
local proceed, fetchResult = guard.guardFetch("https://example.test/key", function()
    fetchRan = true
    return "body"
end, "audit")
eq(proceed, false, "denied guardFetch does not proceed")
eq(fetchResult, nil, "denied guardFetch returns nil")
eq(fetchRan, false, "denied guardFetch never runs the fetch")

genv.HttpSpy = nil
eq(guard.scan().clean, true, "scan is clean again after removing the spy table")

-- 3 — spy window under the hui root.
handles.guiChildren[#handles.guiChildren + 1] = { Name = "HttpSpyGui", ClassName = "ScreenGui" }
report = guard.scan()
expectOnly(report, { "coregui-spy-window" }, "spy window")
handles.guiChildren[#handles.guiChildren] = nil
eq(guard.scan().clean, true, "scan is clean again after removing the window")

-- 4 — spy log files (and near-miss names that must not trip).
handles.files[#handles.files + 1] = "HttpSpy_120543_87231.txt"
report = guard.scan()
expectOnly(report, { "spy-log-files" }, "spy log file")
handles.files[#handles.files] = nil
handles.files[#handles.files + 1] = "HttpSpy_log.txt"
eq(hasSignal(guard.scan(), "spy-log-files"), true, "default HttpSpy_log name trips")
handles.files[#handles.files] = nil
handles.files[#handles.files + 1] = "NotHttpSpy.txt"
handles.files[#handles.files + 1] = "HttpSpy_notes.md"
report = guard.scan()
eq(hasSignal(report, "spy-log-files"), false, "near-miss names do not trip")
handles.files[#handles.files] = nil
handles.files[#handles.files] = nil
eq(guard.scan().clean, true, "scan is clean again after clearing the listing")

-- 5 — swapped game method: baseline drift plus the Lua-source heuristic.
local pristineHttpGet = game.HttpGet
game.HttpGet = function()
    return "hooked"
end
report = guard.scan()
expectOnly(report, { "method-swapped", "cfunc-lua-source" }, "swapped game.HttpGet")
-- Re-baselining blinds layer B by design; layer C keeps firing.
guard.capture()
report = guard.scan()
eq(hasSignal(report, "method-swapped"), false, "re-capture absorbs the swapped reference")
eq(hasSignal(report, "cfunc-lua-source"), true, "Lua source still trips without a baseline")
game.HttpGet = pristineHttpGet
guard.capture()
eq(guard.scan().clean, true, "scan is clean again after restoring the method")

-- 6 — swapped __namecall: baseline drift plus the closure-type heuristic.
handles.mt.__namecall = function()
    return nil
end
report = guard.scan()
expectOnly(report, { "namecall-swapped", "namecall-lclosure" }, "swapped __namecall")
handles.mt.__namecall = handles.pristineNamecall
eq(guard.scan().clean, true, "scan is clean again after restoring __namecall")

-- 7 — request-function path with no pristine reference: layer B skips paths
-- the baseline never saw (capture ran with no `request` global), while layer
-- C still flags the Lua chunk source.
request = function()
    return {}
end
report = guard.scan()
eq(hasSignal(report, "requestfn-swapped"), false, "unbaselined path skips layer B")
eq(hasSignal(report, "cfunc-lua-source"), true, "Lua request fn trips the source heuristic")
request = nil
eq(guard.scan().clean, true, "scan is clean again after removing the request fn")

-- 8 — gate control: with every hook primitive hidden, even planted artifacts
-- scan clean, because a spy cannot run where no hook primitive exists.
local evidenceNames = {
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
local G: any = (getfenv and getfenv(0)) or _G
local stashed = {}
for _, name in ipairs(evidenceNames) do
    stashed[name] = G[name]
    G[name] = nil
end
genv.HttpSpy = { OnRequest = {}, BlockUrl = function() end }
handles.guiChildren[#handles.guiChildren + 1] = { Name = "HttpSpyGui", ClassName = "ScreenGui" }
handles.files[#handles.files + 1] = "HttpSpy_120543_87231.txt"
report = guard.scan()
eq(report.executor, false, "gate closes with no hook primitives")
eq(report.clean, true, "artifacts are inert with the gate closed")
eq(#report.signals, 0, "gate closed means no signals at all")
for _, name in ipairs(evidenceNames) do
    G[name] = stashed[name]
end
genv.HttpSpy = nil
handles.guiChildren[#handles.guiChildren] = nil
handles.files[#handles.files] = nil
report = guard.scan()
eq(report.executor, true, "gate reopens when primitives return")
eq(report.clean, true, "scan is clean again after restoring the gate")

-- 9 — default policy: invalid values raise, the default applies to bare calls.
local badPolicyOk = pcall(function()
    guard.setDefaultPolicy("explode")
end)
eq(badPolicyOk, false, "invalid policy raises")
eq(guard.setDefaultPolicy("audit"), "audit", "setDefaultPolicy returns the policy")
genv.HttpSpy = { OnRequest = {}, BlockUrl = function() end }
local defaultedOk = guard.check()
eq(defaultedOk, false, "bare check() follows the default policy")
genv.HttpSpy = nil
eq(guard.setDefaultPolicy("strict"), "strict", "default policy restores to strict")

-- 10 — allowed fetch runs exactly once and returns its result.
local runs = 0
local allowedOk, allowedResult = guard.guardFetch("https://example.test/asset", function()
    runs = runs + 1
    return "bytes"
end, "strict")
eq(allowedOk, true, "clean guardFetch proceeds")
eq(allowedResult, "bytes", "clean guardFetch returns the fetch result")
eq(runs, 1, "clean guardFetch runs the fetch exactly once")

report = guard.scan()
eq(report.clean, true, "final scan is clean")
eq(#report.signals, 0, "final scan carries no signals")

print("HTTP GUARD TEST PASSED")
