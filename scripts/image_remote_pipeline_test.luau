-- Regression for catalog icon images in executors with partial filesystem
-- APIs and game:HttpGet but no request function.
local function expect(condition, message)
    if not condition then
        error("IMAGE REMOTE PIPELINE FAIL: " .. tostring(message), 0)
    end
end

local harness = getgenv().__ImageRemotePipeline
expect(type(harness) == "table", "the partial executor stubs are installed")
expect(Astra.Icons.get("house") == "assets/icons/lucide-pack/lucideHouse.png", "the example's bare icon name resolves")

local window = Astra:CreateWindow({
    name = "Remote Icon Pipeline",
    icon = "house",
    configuration = { autoSave = false, autoLoad = false },
})
TestPump(1)

expect(window.topbarIcon ~= nil, "the window created its topbar icon")
expect(
    type(window.topbarIcon.Image) == "string"
        and string.find(window.topbarIcon.Image, "rbxasset://partial-filesystem/", 1, true) == 1,
    "a catalog PNG downloads through game:HttpGet and imports through getsynasset"
)

local foundCatalogRequest = false
for url, count in harness.fetched do
    if string.find(url, "/assets/icons/lucide-pack/lucideHouse.png", 1, true) then
        foundCatalogRequest = count == 1
        break
    end
end
expect(foundCatalogRequest, "the exact catalog PNG URL was fetched once")

local importedCatalogImage = false
for path in harness.imported do
    if string.find(path, "Astra/assets/images-icon/icon_", 1, true) == 1 then
        importedCatalogImage = true
        break
    end
end
expect(importedCatalogImage, "the downloaded PNG was written before import")
expect(harness.folders["Astra"] and harness.folders["Astra/assets/images-icon"], "partial filesystem folder APIs were used")

-- A request API exposed only through getgenv() should take precedence over
-- HttpGet for another catalog icon.
local requestFetched = {}
getgenv().request = function(payload)
    requestFetched[payload.Url] = (requestFetched[payload.Url] or 0) + 1
    return { Success = true, StatusCode = 200, Body = harness.png }
end
local requestWindow = Astra:CreateWindow({
    name = "Genv Request Icon",
    icon = "lucide:code",
    configuration = { autoSave = false, autoLoad = false },
})
TestPump(1)
local codeUrl = "https://raw.githubusercontent.com/Kira762/astra-library/main/assets/icons/lucide-pack/lucideCode.png"
expect(requestFetched[codeUrl] == 1, "a request function in getgenv() downloads the next icon")
expect(harness.fetched[codeUrl] == nil, "HttpGet is not used when a request API exists")
expect(
    type(requestWindow.topbarIcon.Image) == "string"
        and string.find(requestWindow.topbarIcon.Image, "rbxasset://partial-filesystem/", 1, true) == 1,
    "the request-downloaded icon imports through getsynasset"
)

window:Unload()
requestWindow:Unload()
TestPump(0.1)
print("IMAGE REMOTE PIPELINE: partial filesystem, genv globals and guarded HTTP fallbacks passed")
