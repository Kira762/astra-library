--[[
===== catalog icons under a hook-heuristic guard verdict =====
Runs the real Astra bundle against an executor whose `request` is a Lua
wrapper and whose `__namecall` carries someone else's hook (see
image_asset_guard_stubs.luau). Both trip HttpGuard's layer-C heuristics, so
the scan is not clean - but neither is an HTTP spy, and the PNGs the catalog
resolves to are public, cosmetic CDN files.

This suite pins the split that keeps the two halves true at once:
  * A1  the heuristics really do trip: the scan is not clean and reports the
        two signals, which is what the guard is for,
  * A2  no HTTP-spy artifact is present (httpSpy stays false), so a public
        asset still downloads and renders instead of blanking the UI -
        the reported bug: numeric window glyphs rendered while every
        catalog icon (tabs, element icons, the topbar mark) stayed blank,
  * A3  the download still goes through the executor's request function,
        imports as a custom asset and lands on the label,
  * A4  element icons - not just the window's own mark - resolve too,
  * A5  a real HTTP-spy artifact (layer A) still refuses the fetch: the
        security half of the guard is untouched.
]]

local function expect(cond, message)
    if not cond then
        error("IMAGE ASSET GUARD FAIL: " .. tostring(message), 0)
    end
end

local harness = getgenv().__AssetGuardTest
expect(type(harness) == "table", "the executor stubs are installed")
expect(type(Astra.HttpGuard) == "table", "Astra.HttpGuard is exposed")

local ASSET_BASE = "https://raw.githubusercontent.com/Kira762/astra-library/main/"
local houseUrl = ASSET_BASE .. "assets/icons/lucide-pack/lucideHouse.png"

local report = Astra.HttpGuard.scan()

-- ===== A1: the heuristics trip ==============================================
expect(report.executor == true, "A1 the executor gate is open")
expect(report.clean == false, "A1 a namecall hook / Lua request wrapper is a signal")
local signals = {}
for _, signal in ipairs(report.signals) do
    signals[signal.id] = true
end
expect(signals["namecall-lclosure"] == true, "A1 the namecall closure heuristic fires")
expect(signals["cfunc-lua-source"] == true, "A1 the Lua-source heuristic fires")
for id in signals do
    expect(
        not (id == "genv-spy-api" or id == "coregui-spy-window" or id == "spy-log-files"),
        "A1 no HTTP-spy artifact is planted (saw " .. id .. ")"
    )
end

-- ===== A2: but a public asset is not refused ================================
expect(report.httpSpy == false, "A2 a hook heuristic is not an HTTP spy")

local window = Astra:CreateWindow({
    name = "Asset Guard",
    icon = "house",
    configuration = { autoSave = false, autoLoad = false },
})
TestPump(1)

expect(window.topbarIcon ~= nil, "A2 the window created its topbar icon")
expect(
    type(window.topbarIcon.Image) == "string"
        and string.find(window.topbarIcon.Image, "rbxasset://asset-guard/Astra/assets/images-icon/icon_", 1, true) == 1,
    "A2 the topbar catalog icon renders (got " .. tostring(window.topbarIcon.Image) .. ")"
)
expect(
    harness.fetched[houseUrl] == 1,
    "A2 the catalog PNG was downloaded exactly once"
)

-- ===== A3: the download used the executor's request function ================
local importedCatalog = false
for path in harness.imported do
    if string.find(path, "Astra/assets/images-icon/icon_", 1, true) == 1 then
        importedCatalog = true
        break
    end
end
expect(importedCatalog, "A3 the downloaded PNG was written before import")

-- ===== A4: element icons resolve too ========================================
local tab = window:CreateTab({ name = "Icons", icon = "keyboard" })
TestPump(0.2)
local button = tab:CreateButton({ name = "Save", icon = "save" })
TestPump(0.2)
expect(button.iconLabel ~= nil, "A4 the button built its icon label")
expect(
    type(button.iconLabel.Image) == "string"
        and string.find(button.iconLabel.Image, "rbxasset://asset-guard/", 1, true) == 1,
    "A4 an element icon renders (got " .. tostring(button.iconLabel.Image) .. ")"
)

-- ===== A5: layer A still refuses the fetch ==================================
local resolver = Astra.Core.state.assetResolver
local spyUrl = "https://example.test/spied-icon.png"
local before = 0
for _ in harness.fetched do
    before += 1
end
getgenv().HttpSpy = {
    OnRequest = {},
    BlockUrl = function() end,
}
local spyReport = Astra.HttpGuard.scan()
expect(spyReport.httpSpy == true, "A5 the spy artifacts flag httpSpy")
expect(
    resolver:getAssetContentFromUrl(spyUrl, nil, true) == nil,
    "A5 a public asset is refused while an HTTP spy is present"
)
expect(harness.fetched[spyUrl] == nil, "A5 the refused fetch never reached the request function")
getgenv().HttpSpy = nil
expect(Astra.HttpGuard.scan().httpSpy == false, "A5 removing the spy clears the flag")

window:Unload()
TestPump(0.1)
print("IMAGE ASSET GUARD: catalog icons render under hook-heuristic guard verdicts")
