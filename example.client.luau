-- [[Astra Element Studio — a working testbed for every part of the public API.
--
-- [[The studio opens through the key gate: Astra:CreateKeySystem shows its
-- [[card first and the whole build runs in `onSuccess` (demo key
-- [[ASTRA-STUDIO-2026; a saved key skips the card on the next join).
-- [[
-- [[Ten tabs, built around things you can actually run: character and lighting
-- [[edits, a live performance sampler, the persistence API, the theme/motion
-- [[controls, and a lab that drives every element handle. Nothing here is a
-- [[dead `print`; each control either changes the game, changes the window, or
-- [[reports something real back through a Stat, a Text or a notification.
--
-- [[Roblox access is resolved through the small helper block below and is
-- [[nil-safe, so the same script runs in an executor, in Studio, and under the
-- [[repository's headless test harness (`scripts/example_test.luau`). Where a
-- [[service is missing the control says so instead of throwing.
--
-- [[Executor entry point. In Studio/Rojo, require ReplicatedStorage.Astra instead.]]
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

-- ===========================================================================
-- Environment
-- ===========================================================================

local function service(name)
    local ok, result = pcall(function()
        return game:GetService(name)
    end)
    if ok then
        return result
    end
    return nil
end

local function member(object, name)
    if not object then
        return nil
    end
    local ok, result = pcall(function()
        return object[name]
    end)
    if ok then
        return result
    end
    return nil
end

local Players = service("Players")
local RunService = service("RunService")
local UserInputService = service("UserInputService")
local Lighting = service("Lighting")
local Stats = service("Stats")
local Workspace = service("Workspace")

local localPlayer = member(Players, "LocalPlayer")
local startedAt = os.clock()

local function character()
    return member(localPlayer, "Character")
end

local function humanoid()
    local model = character()
    if not model then
        return nil
    end
    local ok, result = pcall(function()
        return model:FindFirstChildOfClass("Humanoid")
    end)
    if ok then
        return result
    end
    return nil
end

local function rootPart()
    local model = character()
    if not model then
        return nil
    end
    local ok, result = pcall(function()
        return model:FindFirstChild("HumanoidRootPart")
    end)
    if ok then
        return result
    end
    return nil
end

local function camera()
    return member(Workspace, "CurrentCamera")
end

local function round(value, places)
    local factor = 10 ^ (places or 0)
    return math.floor((value or 0) * factor + 0.5) / factor
end

local function commas(value)
    local text = tostring(math.floor((value or 0) + 0.5))
    local formatted = text:gsub("^(-?%d+)(%d*)", function(head, tail)
        return head .. (tail:reverse():gsub("(%d%d%d)", "%1,"):reverse())
    end)
    return formatted
end

-- ===========================================================================
-- Key gate
-- ===========================================================================

-- [[The whole studio sits behind Astra's standalone key gate: CreateKeySystem
-- [[draws its card *before* any window exists and everything below builds only
-- [[inside `onSuccess`, the way a hub that ships keys is wired. `window` and
-- [[`overview` are file-scope so the headless harness can drive the gate and
-- [[then assert on the studio; `saveKey` remembers a passing key at
-- [[Astra/keys/Astra-Example.txt, so a second join skips the card entirely.
-- [[`studioReady` is the harness seam: buildStudio's last act flips it, and
-- [[scripts/example_test.luau waits on it before touching the studio. The demo
-- [[key is ASTRA-STUDIO-2026.]]
local keyGate
local window
local overview
local studioReady

local function buildStudio(unlockedKey)

    -- ===========================================================================
    -- Window
    -- ===========================================================================

    window = Astra:CreateWindow({
        name = "Astra Element Studio",
        subtitle = "Every element, working",
        icon = "sirius",
        configuration = {
            fileName = "Astra-Example",
            customFolder = "AstraExamples",
            autoSave = true,
            autoLoad = true,
        },
    })

    local function tell(title, content, icon, duration)
        window:Notify({ title = title, content = content, icon = icon or "info", duration = duration or 4 })
    end

    -- ===========================================================================
    -- 1. Overview — information first
    -- ===========================================================================

    overview = window:CreateTab({ name = "Overview", icon = "house" })
    local releaseHistory

    overview:CreateAboutCard({
        name = "Astra",
        subtitle = "A live testbed for the whole API.",
        icon = 80387863064905,
        rows = {
            { icon = "code", label = "Version", value = "1.4.0" },
            { icon = "layers", label = "Tabs", value = "10" },
            { icon = "user", label = "Author", value = "Astra Team" },
        },
        description = "Nine working tabs plus a gated one: character and combat controls, real lighting and camera edits, teleporting, a live performance sampler, an element-handle lab, the persistence API, and theme/motion/window controls. Everything here does something.",
        action = {
            icon = "file-text",
            name = "Release history",
            subtitle = "Expand the changelog container",
            callback = function()
                if not releaseHistory then
                    return
                end
                overview:Select()
                releaseHistory:Expand()
                task.defer(function()
                    if not releaseHistory.main.Parent then
                        return
                    end
                    local page = overview.tabPage
                    local top = page.CanvasPosition.Y + releaseHistory.main.AbsolutePosition.Y - page.AbsolutePosition.Y
                    page.CanvasPosition = Vector2.new(0, math.max(0, top - 10))
                end)
            end,
        },
    })

    overview:CreateSection({ name = "Start here", icon = "compass" })
    overview:CreateText({
        name = "How to use this studio",
        text = "Player, Combat, Visuals and World drive the game. Live Stats samples the frame loop. Elements drives every element handle. Configs drives saving. Window drives theme, motion, visibility and overlays. Premium starts locked — unlock it from the Window tab.",
        icon = "book-open",
    })

    local actionsRun = overview:CreateStat({
        name = "Actions run",
        value = 0,
        changeMode = "delta",
        changeBaseline = "initial",
        description = "Every control on every tab reports back through the log below.",
    })

    overview:CreateDivider({ text = "Session log" })

    -- [[Every other tab writes into this element, so the changelog doubles as a
    -- [[live activity log rather than a static block of release notes.]]
    local eventLog = overview:CreateChangelog({
        name = "Activity",
        emptyText = "Nothing has run yet — try a control on any tab.",
        entries = {
            { version = "Session", date = os.date("%Y-%m-%d"), title = "Studio opened", changes = {
                { symbol = "+", category = "Ready", text = "Window built with ten tabs and auto save/load enabled." },
                { symbol = "+", category = "Key", text = "Key gate opened with " .. tostring(unlockedKey) .. "." },
            } },
        },
    })

    local logged = 0

    local function logEvent(text, symbol, category)
        if not text or text == "" then
            return
        end
        logged += 1
        actionsRun:Set(logged)
        eventLog:Add({
            version = "Event " .. tostring(logged),
            date = os.date("%H:%M:%S"),
            changes = { { symbol = symbol or "~", category = category, text = text } },
        })
    end

    overview:CreateDivider({ text = "Resources" })

    overview:CreateLink({
        name = "Source & releases",
        subtitle = "Copy the repository link",
        icon = "code",
        link = "https://github.com/Kira762/astra-version-1",
        callback = function(link)
            logEvent("Copied the repository link.", "+", "Clipboard")
            tell("Copied", link, "check")
        end,
    })
    overview:CreateLink({
        name = "Usage guide",
        subtitle = "Copy the API reference link",
        icon = "book-open",
        link = "https://github.com/Kira762/astra-version-1/blob/main/USAGE.md",
        callback = function()
            logEvent("Copied the usage guide link.", "+", "Clipboard")
        end,
    })
    overview:CreateLink({
        name = "Icon catalog",
        subtitle = "Copy the visual icon index",
        icon = "icons",
        link = "https://github.com/Kira762/astra-version-1/blob/main/assets/icons/README.md",
        callback = function()
            logEvent("Copied the icon catalog link.", "+", "Clipboard")
        end,
    })

    releaseHistory = overview:CreateIsolated({
        name = "Release history",
        subtitle = "Earlier library milestones",
        icon = "history",
        elements = {
            { type = "Changelog", name = "Recent releases", entries = {
                { version = "Current", date = "2026-09-22", title = "Link cards show their copy glyph again", changes = {
                    { symbol = "~", category = "Fixed", text = "The trailing copy/check mark faded in with the card instead of staying invisible." },
                } },
                { version = "1.4.0", date = "2026-09-12", changes = {
                    { symbol = "+", text = "About cards, links and richer grouped controls." },
                } },
            } },
            { type = "Changelog", name = "Earlier releases", entries = {
                { version = "1.2.0", title = "Structured content", changes = {
                    { symbol = "+", text = "Isolated changelog containers and collapsible groups." },
                    { symbol = "-", text = "Functional info badges removed from buttons and fields." },
                } },
            } },
        },
    })

    overview:CreateDivider()
    overview:CreateFooter({
        parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" }, { icon = "heart" } },
    })

    -- ===========================================================================
    -- 2. Player — real character edits
    -- ===========================================================================

    local player = window:CreateTab({ name = "Player", icon = "user-round" })

    player:CreateSection({ name = "Movement", icon = "footprints" })

    local walkStat = player:CreateStat({
        name = "Walk speed",
        value = 16,
        suffix = " studs/s",
        description = "Live value read back from the character's Humanoid.",
    })
    local jumpStat = player:CreateStat({ name = "Jump power", value = 50, suffix = " force" })
    local healthStat = player:CreateStat({
        name = "Health",
        value = 100,
        suffix = " hp",
        display = "change",
        changeMode = "percentage",
        changeBaseline = "previous",
    })

    local walkDefault, jumpDefault = 16, 50
    local frozenSpeed
    -- [[Forward declarations: the callbacks below close over these, and a Lua]]
    -- [[closure only captures a local that is already in scope.]]
    local identityText

    local function readCharacter()
        local hum = humanoid()
        if not hum then
            walkStat:SetText("No character")
            jumpStat:SetText("No character")
            healthStat:SetText("No character")
            return nil
        end
        walkDefault = hum.WalkSpeed or walkDefault
        jumpDefault = hum.JumpPower or hum.JumpHeight or jumpDefault
        walkStat:Set(round(hum.WalkSpeed or 0))
        jumpStat:Set(round(hum.JumpPower or hum.JumpHeight or 0))
        healthStat:Set(round(hum.Health or 0))
        identityText:Set(string.format(
            "%s (@%s) — UserId %s, health %s",
            tostring(member(localPlayer, "DisplayName") or member(localPlayer, "Name") or "Unknown"),
            tostring(member(localPlayer, "Name") or "?"),
            tostring(member(localPlayer, "UserId") or "?"),
            tostring(round(hum.Health or 0))
        ))
        return hum
    end

    local walkSlider = player:CreateSlider({
        name = "Walk speed",
        flag = "demo.walkSpeed",
        range = { 0, 250 },
        value = 16,
        increment = 1,
        suffix = " studs/s",
        description = "Writes Humanoid.WalkSpeed as you drag.",
        callback = function(value)
            local hum = humanoid()
            if not hum then
                return
            end
            hum.WalkSpeed = value
            walkStat:Set(value)
        end,
    })

    local jumpSlider = player:CreateSlider({
        name = "Jump power",
        flag = "demo.jumpPower",
        range = { 0, 200 },
        value = 50,
        increment = 1,
        suffix = " force",
        callback = function(value)
            local hum = humanoid()
            if not hum then
                return
            end
            if hum.UseJumpPower then
                hum.JumpPower = value
            else
                hum.JumpHeight = value / 5
            end
            jumpStat:Set(value)
        end,
    })

    local infiniteJump
    infiniteJump = player:CreateToggle({
        name = "Infinite jump",
        flag = "demo.infiniteJump",
        value = false,
        description = "Re-enters the jumping state on every jump request.",
        callback = function(enabled)
            if enabled then
                local signal = member(UserInputService, "JumpRequest")
                if not signal then
                    tell("Unavailable", "This runtime exposes no JumpRequest signal.", "triangle-alert")
                    infiniteJump:Set(false, true)
                    return
                end
                infiniteJump._connection = window:Connect(signal, function()
                    local hum = humanoid()
                    if hum then
                        pcall(function()
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end)
                    end
                end)
                logEvent("Infinite jump armed.", "+", "Player")
            elseif infiniteJump._connection then
                window:Disconnect(infiniteJump._connection)
                infiniteJump._connection = nil
                logEvent("Infinite jump released.", "-", "Player")
            end
        end,
    })

    local freezeToggle
    freezeToggle = player:CreateToggle({
        name = "Freeze in place",
        flag = "demo.freeze",
        value = false,
        description = "Zeroes WalkSpeed and restores the previous value on release.",
        callback = function(enabled)
            local hum = humanoid()
            if not hum then
                tell("Unavailable", "No character to freeze.", "triangle-alert")
                freezeToggle:Set(false, true)
                return
            end
            if enabled then
                frozenSpeed = hum.WalkSpeed
                hum.WalkSpeed = 0
                walkStat:Set(0)
            else
                hum.WalkSpeed = frozenSpeed or walkDefault
                walkStat:Set(round(hum.WalkSpeed))
            end
        end,
    })

    player:CreateKeybind({
        name = "Respawn character",
        value = "R",
        flag = "demo.respawnKey",
        icon = "rotate-cw",
        description = "Click the keycap, then press one letter A–Z.",
        callback = function(letter)
            local hum = humanoid()
            if hum then
                hum.Health = 0
                logEvent("Respawn requested on key " .. letter .. ".", "~", "Player")
            else
                tell("Unavailable", "No character to respawn.", "triangle-alert")
            end
        end,
    })

    local playerActions = player:CreateGroup({ direction = "row" })
    playerActions:CreateButton({
        name = "Read character",
        icon = "scan-line",
        callback = function()
            if readCharacter() then
                tell("Character read", "Stats refreshed from the Humanoid.", "check")
            else
                tell("No character", "Spawn into the game and try again.", "triangle-alert")
            end
        end,
    })
    playerActions:CreateButton({
        name = "Restore defaults",
        icon = "rotate-ccw",
        callback = function()
            freezeToggle:Set(false)
            infiniteJump:Set(false)
            walkSlider:Set(walkDefault)
            jumpSlider:Set(jumpDefault)
            local hum = humanoid()
            if hum then
                hum.WalkSpeed = walkDefault
                if hum.UseJumpPower then
                    hum.JumpPower = jumpDefault
                else
                    hum.JumpHeight = jumpDefault / 5
                end
            end
            logEvent("Movement restored to defaults.", "~", "Player")
        end,
    })

    identityText = player:CreateText({
        name = "Identity",
        text = "Press “Read character” to load live values.",
        icon = "id-card",
    })

    player:CreateCollapsibleGroup({
        name = "Character details",
        icon = "info",
        description = "Live values, refreshed by the button above.",
        elements = {
            { type = "Stat", name = "State", value = "Idle", letter = false },
            { type = "Stat", name = "Ground speed", value = 0, suffix = " s/s" },
            { type = "Text", name = "Note", text = "Values are read on demand — nothing polls in the background." },
        },
    })

    -- ===========================================================================
    -- 3. Combat — target list and live counters
    -- ===========================================================================

    local combat = window:CreateTab({ name = "Combat", icon = "sword" })

    combat:CreateSection({ name = "Targeting", icon = "crosshair" })

    local function roster()
        local names = {}
        local ok, list = pcall(function()
            return Players:GetPlayers()
        end)
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                if entry ~= localPlayer and entry.Name then
                    table.insert(names, entry.Name)
                end
            end
        end
        if #names == 0 then
            table.insert(names, "No other players")
        end
        return names
    end

    local targetText = combat:CreateText({
        name = "Current target",
        text = "None selected.",
        icon = "target",
    })

    local targetList = combat:CreateDropdown({
        name = "Target player",
        flag = "demo.target",
        options = roster(),
        placeholder = "Pick a player",
        description = "Rebuilt from Players:GetPlayers() by the refresh button.",
        callback = function(selected)
            targetText:Set("Locked on " .. tostring(selected) .. ".")
            logEvent("Target set to " .. tostring(selected) .. ".", "~", "Combat")
        end,
    })

    local rosterActions = combat:CreateGroup({ direction = "row" })
    rosterActions:CreateButton({
        name = "Refresh roster",
        icon = "refresh-cw",
        callback = function()
            local names = roster()
            targetList:Refresh(names)
            tell("Roster rebuilt", #names .. " option(s) in the list.", "users")
        end,
    })
    rosterActions:CreateButton({
        name = "Add dummy",
        icon = "user-plus",
        callback = function()
            local name = "Dummy-" .. tostring(math.random(100, 999))
            targetList:Add(name)
            tell("Option added", name .. " appended to the dropdown.", "plus")
        end,
    })
    rosterActions:CreateButton({
        name = "Clear target",
        icon = "x",
        callback = function()
            targetText:Set("None selected.")
            logEvent("Target cleared.", "-", "Combat")
        end,
    })

    combat:CreateDivider({ text = "Tuning" })

    combat:CreateSlider({
        name = "Aim smoothing",
        flag = "demo.smoothing",
        range = { 1, 100 },
        value = 35,
        suffix = "%",
        minimal = true,
    })
    combat:CreateSlider({
        name = "Aim radius",
        flag = "demo.aimFov",
        range = { 1, 50 },
        value = 12,
        suffix = "°",
        minimal = true,
    })
    combat:CreateDropdown({
        name = "Hitbox part",
        flag = "demo.hitbox",
        options = { "Head", "UpperTorso", "HumanoidRootPart", "Random" },
        value = "Head",
    })

    local engagements = combat:CreateStat({
        name = "Engagements",
        value = 0,
        changeMode = "delta",
        changeBaseline = "initial",
    })
    local accuracy = combat:CreateStat({
        name = "Accuracy",
        value = 0,
        suffix = "%",
        description = "Rolls a simulated engagement and updates the counters.",
    })
    local gradeBadge = combat:CreateStat({ name = "Grade", value = "C", letter = true })

    combat:CreateButton({
        name = "Simulate engagement",
        icon = "zap",
        description = "Rolls hits against the current smoothing setting and updates the stats.",
        callback = function()
            local smoothing = window:Get("demo.smoothing") or 35
            local shots = math.random(6, 18)
            local hitChance = math.clamp(0.25 + (smoothing / 100) * 0.6, 0, 0.98)
            local hits = 0
            for _ = 1, shots do
                if math.random() <= hitChance then
                    hits += 1
                end
            end
            local percent = round((hits / shots) * 100)
            engagements:Set(engagements.value + 1)
            accuracy:Set(percent)
            gradeBadge:Set(if percent >= 90 then "A" elseif percent >= 75 then "B" elseif percent >= 55 then "C" else "D")
            logEvent(string.format("%d/%d hits (%d%%) at %d%% smoothing.", hits, shots, percent, smoothing), "+", "Combat")
        end,
    })

    combat:CreateCollapsibleGroup({
        name = "Automation",
        icon = "bot",
        description = "Toggles that the panic key turns off.",
        elements = {
            { type = "Toggle", name = "Auto fire", flag = "demo.autoFire", value = false },
            { type = "Toggle", name = "Target closest", flag = "demo.closest", value = true },
            { type = "Slider", name = "Fire rate", flag = "demo.fireRate", range = { 1, 20 }, value = 8, suffix = " rps" },
        },
    })

    -- ===========================================================================
    -- 4. Visuals — real Lighting and Camera edits
    -- ===========================================================================

    local visuals = window:CreateTab({ name = "Visuals", icon = "eye" })

    local lightingAvailable = Lighting ~= nil
    if not lightingAvailable then
        visuals:CreateText({
            name = "Lighting unavailable",
            text = "This runtime exposes no Lighting service, so the lighting controls below report back instead of throwing. Camera controls still work.",
            icon = "triangle-alert",
        })
    end

    visuals:CreateSection({ name = "Lighting", icon = "sun" })

    visuals:CreateSlider({
        name = "Brightness",
        flag = "demo.brightness",
        range = { 0, 10 },
        value = 2,
        increment = 0.5,
        callback = function(value)
            if Lighting then
                Lighting.Brightness = value
            end
        end,
    })
    visuals:CreateSlider({
        name = "Time of day",
        flag = "demo.clockTime",
        range = { 0, 24 },
        value = 14,
        increment = 0.5,
        suffix = "h",
        callback = function(value)
            if Lighting then
                Lighting.ClockTime = value
            end
        end,
    })
    visuals:CreateSlider({
        name = "Fog distance",
        flag = "demo.fogEnd",
        range = { 50, 2000 },
        value = 1000,
        increment = 50,
        suffix = " studs",
        callback = function(value)
            if Lighting then
                Lighting.FogEnd = value
                Lighting.FogStart = math.min(Lighting.FogStart or 0, value * 0.25)
            end
        end,
    })
    visuals:CreateToggle({
        name = "Global shadows",
        flag = "demo.shadows",
        value = true,
        callback = function(enabled)
            if Lighting then
                Lighting.GlobalShadows = enabled
            end
        end,
    })

    visuals:CreateSection({ name = "Camera", icon = "video" })

    visuals:CreateSlider({
        name = "Field of view",
        flag = "demo.fov",
        range = { 30, 120 },
        value = 70,
        suffix = "°",
        description = "Writes CurrentCamera.FieldOfView.",
        callback = function(value)
            local cam = camera()
            if cam then
                cam.FieldOfView = value
            end
        end,
    })

    local colorCorrection
    visuals:CreateToggle({
        name = "Colour grade",
        flag = "demo.grade",
        value = false,
        description = "Inserts a ColorCorrectionEffect and removes it again on release.",
        callback = function(enabled)
            if not Lighting then
                tell("Unavailable", "No Lighting service to parent the effect to.", "triangle-alert")
                return
            end
            if enabled then
                if not colorCorrection then
                    colorCorrection = Instance.new("ColorCorrectionEffect")
                    colorCorrection.Name = "AstraGrade"
                    colorCorrection.Saturation = 0.25
                    colorCorrection.Contrast = 0.1
                    colorCorrection.Parent = Lighting
                end
                colorCorrection.Enabled = true
                logEvent("Colour grade enabled.", "+", "Visuals")
            elseif colorCorrection then
                colorCorrection.Enabled = false
                logEvent("Colour grade disabled.", "-", "Visuals")
            end
        end,
    })

    visuals:CreateSlider({
        name = "Saturation",
        flag = "demo.saturation",
        range = { -100, 100 },
        value = 25,
        suffix = "%",
        callback = function(value)
            if colorCorrection then
                colorCorrection.Saturation = value / 100
            end
        end,
    })

    local blurEffect
    visuals:CreateCollapsibleGroup({
        name = "Post effects",
        icon = "aperture",
        description = "Effects are created on first use and destroyed on release.",
        elements = {
            { type = "Toggle", name = "Background blur", flag = "demo.blur", value = false,
                callback = function(enabled)
                    local cam = camera()
                    if not cam then
                        return
                    end
                    if enabled then
                        if not blurEffect then
                            blurEffect = Instance.new("BlurEffect")
                            blurEffect.Name = "AstraBlur"
                            blurEffect.Size = 12
                            blurEffect.Parent = cam
                        end
                        blurEffect.Enabled = true
                    elseif blurEffect then
                        blurEffect.Enabled = false
                    end
                end },
            { type = "Slider", name = "Blur size", flag = "demo.blurSize", range = { 0, 56 }, value = 12, suffix = "px",
                callback = function(value)
                    if blurEffect then
                        blurEffect.Size = value
                    end
                end },
        },
    })

    visuals:CreateDivider({ text = "Presets" })

    local visualPresets = visuals:CreateGroup({ direction = "row" })
    visualPresets:CreateButton({
        name = "Golden hour",
        icon = "sunrise",
        callback = function()
            if Lighting then
                Lighting.ClockTime = 17.5
                Lighting.Brightness = 2.5
            end
            logEvent("Golden hour preset applied.", "~", "Visuals")
        end,
    })
    visualPresets:CreateButton({
        name = "Night",
        icon = "moon",
        callback = function()
            if Lighting then
                Lighting.ClockTime = 0.5
                Lighting.Brightness = 0.75
            end
            logEvent("Night preset applied.", "~", "Visuals")
        end,
    })
    visualPresets:CreateButton({
        name = "Reset",
        icon = "rotate-ccw",
        callback = function()
            if Lighting then
                Lighting.ClockTime = 14
                Lighting.Brightness = 2
                Lighting.FogEnd = 1000
                Lighting.GlobalShadows = true
            end
            if colorCorrection then
                colorCorrection:Destroy()
                colorCorrection = nil
            end
            if blurEffect then
                blurEffect:Destroy()
                blurEffect = nil
            end
            local cam = camera()
            if cam then
                cam.FieldOfView = 70
            end
            logEvent("Visuals reset.", "-", "Visuals")
        end,
    })

    -- ===========================================================================
    -- 5. World — coordinates, waypoints and teleporting
    -- ===========================================================================

    local world = window:CreateTab({ name = "World", icon = "map" })

    world:CreateSection({ name = "Coordinates", icon = "move-3d" })

    local posX = world:CreateInput({ name = "X", placeholder = "0", numeric = true, value = "0", flag = "demo.posX" })
    local posY = world:CreateInput({ name = "Y", placeholder = "0", numeric = true, value = "0", flag = "demo.posY" })
    local posZ = world:CreateInput({ name = "Z", placeholder = "0", numeric = true, value = "0", flag = "demo.posZ" })

    local positionText = world:CreateText({
        name = "Last known position",
        text = "Not read yet.",
        icon = "map-pin",
    })

    local travelled = world:CreateStat({
        name = "Distance teleported",
        value = 0,
        suffix = " studs",
        numberEasing = true,
    })

    local function currentPosition()
        local part = rootPart()
        if not part then
            return nil
        end
        local ok, position = pcall(function()
            return part.Position
        end)
        if not ok then
            return nil
        end
        return position
    end

    local coordActions = world:CreateGroup({ direction = "row" })
    coordActions:CreateButton({
        name = "Read position",
        icon = "scan-line",
        callback = function()
            local position = currentPosition()
            if not position then
                tell("No character", "Spawn in and try again.", "triangle-alert")
                return
            end
            posX:Set(tostring(round(position.X, 1)))
            posY:Set(tostring(round(position.Y, 1)))
            posZ:Set(tostring(round(position.Z, 1)))
            positionText:Set(string.format("%s, %s, %s", round(position.X, 1), round(position.Y, 1), round(position.Z, 1)))
        end,
    })
    coordActions:CreateButton({
        name = "Teleport",
        icon = "send",
        callback = function()
            local part = rootPart()
            if not part then
                tell("No character", "There is no HumanoidRootPart to move.", "triangle-alert")
                return
            end
            local target = Vector3.new(tonumber(posX.value) or 0, tonumber(posY.value) or 0, tonumber(posZ.value) or 0)
            local before = currentPosition()
            part.CFrame = CFrame.new(target)
            if before then
                travelled:Set(travelled.value + round((before - target).Magnitude))
            end
            logEvent(string.format("Teleported to %s, %s, %s.", round(target.X, 1), round(target.Y, 1), round(target.Z, 1)), "~", "World")
        end,
    })

    world:CreateDivider({ text = "Landmarks" })

    local landmarkList = world:CreateDropdown({
        name = "Landmark",
        flag = "demo.landmark",
        options = { "Origin", "Sky", "Underground" },
        value = "Origin",
        description = "Jump to a preset, or add your own from the current position.",
    })

    local landmarkTargets = {
        Origin = Vector3.zero,
        Sky = Vector3.new(0, 500, 0),
        Underground = Vector3.new(0, -50, 0),
    }

    world:CreateButton({
        name = "Go to landmark",
        icon = "flag",
        callback = function()
            local name = window:Get("demo.landmark") or "Origin"
            local target = landmarkTargets[name]
            if not target then
                tell("Unknown landmark", tostring(name) .. " has no stored position.", "triangle-alert")
                return
            end
            posX:Set(tostring(target.X))
            posY:Set(tostring(target.Y))
            posZ:Set(tostring(target.Z))
            local part = rootPart()
            if part then
                part.CFrame = CFrame.new(target)
                logEvent("Jumped to landmark " .. name .. ".", "~", "World")
            else
                tell("Coordinates set", "No character to move, but the fields are filled in.", "info")
            end
        end,
    })

    world:CreateCollapsibleGroup({
        name = "Waypoints",
        icon = "bookmark",
        description = "Save where you are and jump back to it later.",
        elements = {
            { type = "Text", name = "Stored", text = "No waypoints saved yet." },
            { type = "Group", elements = {
                { type = "Button", name = "Save current", icon = "bookmark-plus" },
                { type = "Button", name = "Clear list", icon = "trash-2" },
            } },
        },
    })

    local waypointPanel = world.elements[#world.elements]
    local waypointText = waypointPanel.elements[1]
    local waypoints = {}

    waypointPanel.elements[2].elements[1].callback = function()
        local position = currentPosition()
        if not position then
            tell("No character", "Nothing to store.", "triangle-alert")
            return
        end
        local name = "Waypoint " .. tostring(#waypoints + 1)
        waypoints[name] = position
        landmarkTargets[name] = position
        landmarkList:Add(name)
        waypointText:Set(string.format("%d saved — %s at %s, %s, %s", #waypoints, name, round(position.X, 1), round(position.Y, 1), round(position.Z, 1)))
        logEvent("Saved " .. name .. ".", "+", "World")
    end

    waypointPanel.elements[2].elements[2].callback = function()
        for name in waypoints do
            landmarkTargets[name] = nil
            landmarkList:Remove(name)
            waypoints[name] = nil
        end
        landmarkList:Refresh({ "Origin", "Sky", "Underground" })
        waypointText:Set("No waypoints saved yet.")
        logEvent("Waypoint list cleared.", "-", "World")
    end

    -- ===========================================================================
    -- 6. Live Stats — a real sampler on the frame loop
    -- ===========================================================================

    local stats = window:CreateTab({ name = "Live Stats", icon = "activity" })

    stats:CreateSection({ name = "Sampler", icon = "gauge" })

    local fpsStat = stats:CreateStat({ name = "Frame rate", value = 0, suffix = " fps", numberEasing = true })
    local frameStat = stats:CreateStat({ name = "Frame time", value = 0, suffix = " ms" })
    local memoryStat = stats:CreateStat({ name = "Lua memory", value = 0, suffix = " KB" })
    local uptimeStat = stats:CreateStat({ name = "Session", value = 0, suffix = " s" })
    local pingStat = stats:CreateStat({
        name = "Ping",
        value = 0,
        suffix = " ms",
        description = "Read from Stats when the runtime exposes it.",
    })
    local samplerState = stats:CreateStat({ name = "Sampler", value = "Idle", letter = false })
    local gradeStat = stats:CreateStat({ name = "Grade", value = "—", letter = true })

    local sampleRate = stats:CreateSlider({
        name = "Sample rate",
        flag = "demo.sampleRate",
        range = { 1, 10 },
        value = 2,
        increment = 1,
        suffix = " Hz",
    })

    local samplerConnection
    local lastSample = 0
    local smoothedFps = 0

    local function sample()
        local now = os.clock()
        local interval = 1 / math.clamp(sampleRate.value or 2, 1, 10)
        if now - lastSample < interval then
            return
        end
        local dt = now - lastSample
        lastSample = now

        smoothedFps = smoothedFps == 0 and (1 / math.max(dt, 0.0001)) or (smoothedFps * 0.7 + (1 / math.max(dt, 0.0001)) * 0.3)
        fpsStat:Set(round(math.clamp(smoothedFps, 0, 999)))
        frameStat:Set(round(dt * 1000, 1))
        memoryStat:Set(round(collectgarbage("count")))
        uptimeStat:Set(round(now - startedAt))
        gradeStat:Set(if smoothedFps >= 55 then "A" elseif smoothedFps >= 40 then "B" elseif smoothedFps >= 25 then "C" else "D")

        local ping = member(Stats, "Network") and member(member(Stats, "Network"), "ServerStatsItem")
        if ping and member(ping, "Data Ping") then
            pingStat:Set(round(ping["Data Ping"]:GetValue(), 1))
        end
    end

    local samplerToggle
    samplerToggle = stats:CreateToggle({
        name = "Live updates",
        flag = "demo.sampler",
        value = false,
        description = "Connects one Heartbeat listener and disconnects it again on release.",
        callback = function(enabled)
            if enabled then
                if not samplerConnection and RunService and member(RunService, "Heartbeat") then
                    lastSample = os.clock()
                    samplerConnection = window:Connect(RunService.Heartbeat, sample)
                    samplerState:SetText("Sampling")
                    logEvent("Live sampler connected to Heartbeat.", "+", "Stats")
                end
            elseif samplerConnection then
                window:Disconnect(samplerConnection)
                samplerConnection = nil
                samplerState:SetText("Idle")
                logEvent("Live sampler disconnected.", "-", "Stats")
            end
        end,
    })

    stats:CreateDivider({ text = "Snapshot" })

    stats:CreateButton({
        name = "Take a snapshot",
        icon = "camera",
        description = "Runs one sample immediately and logs the numbers.",
        callback = function()
            lastSample = os.clock() - 1
            sample()
            local summary = string.format(
                "%s fps, %s ms frame, %s KB Lua, %s s session",
                tostring(fpsStat.value), tostring(frameStat.value), commas(memoryStat.value), tostring(uptimeStat.value)
            )
            tell("Snapshot", summary, "camera")
            logEvent("Snapshot: " .. summary, "+", "Stats")
        end,
    })

    stats:CreateCollapsibleGroup({
        name = "Hardware report",
        icon = "cpu",
        description = "What the library's own performance module decided.",
        elements = {
            { type = "Text", name = "Profile", text = "Press “Refresh” to read the hardware module." },
            { type = "Group", elements = {
                { type = "Button", name = "Refresh", icon = "refresh-cw" },
                { type = "Stat", name = "Average fps", value = 0 },
            } },
        },
    })

    local hardwarePanel = stats.elements[#stats.elements]
    local hardwareText = hardwarePanel.elements[1]
    local hardwareFps = hardwarePanel.elements[2].elements[2]

    hardwarePanel.elements[2].elements[1].callback = function()
        local performance = Astra.Performance
        local lowEnd = performance.isLowEnd()
        local struggling = performance.isStruggling()
        local average = round(performance.getAverageFps())
        local frameBudget, instanceBudget = performance.getBudgets(120, 10)
        hardwareFps:Set(average)
        hardwareText:Set(string.format(
            "%s • %s • average %s fps • budgets %s ms / %s instances per frame",
            if lowEnd then "Low-end profile" else "Standard profile",
            if struggling then "struggling" else "steady",
            tostring(average),
            tostring(round(frameBudget * 1000, 1)),
            tostring(instanceBudget)
        ))
    end

    -- ===========================================================================
    -- 7. Elements — every handle, driven
    -- ===========================================================================

    local lab = window:CreateTab({ name = "Elements", icon = "flask-conical" })

    lab:CreateSection({ name = "Handles", icon = "sliders-horizontal" })

    -- [[Declared first: every handle callback below writes into this readout.]]
    local demoText
    local demoToggle = lab:CreateToggle({
        name = "Sample toggle",
        flag = "demo.lab.toggle",
        value = true,
        callback = function(value)
            demoText:Set("Toggle is " .. tostring(value) .. ".")
        end,
    })
    local demoSlider = lab:CreateSlider({
        name = "Sample slider",
        flag = "demo.lab.slider",
        range = { 0, 100 },
        value = 40,
        suffix = "%",
        callback = function(value, dragging)
            demoText:Set(string.format("Slider %d%s while dragging = %s.", value, "%", tostring(dragging)))
        end,
    })
    local demoDropdown = lab:CreateDropdown({
        name = "Sample dropdown",
        flag = "demo.lab.dropdown",
        options = { "Alpha", "Beta", "Gamma" },
        value = "Alpha",
        multiSelect = true,
        placeholder = "Pick any",
        callback = function(selected)
            demoText:Set("Dropdown: " .. table.concat(selected, ", "))
        end,
    })
    local demoInput = lab:CreateInput({
        name = "Sample input",
        flag = "demo.lab.input",
        placeholder = "Type something",
        value = "Hello",
        clearOnFocus = false,
        callback = function(text)
            demoText:Set("Input: " .. text)
        end,
    })
    local demoKeybind = lab:CreateKeybind({
        name = "Sample keybind",
        flag = "demo.lab.keybind",
        value = "P",
        callback = function(letter)
            demoText:Set("Keybind is " .. letter .. ".")
        end,
    })
    local demoStat = lab:CreateStat({
        name = "Sample stat",
        value = 10,
        changeMode = "delta",
        changeBaseline = "initial",
    })
    demoText = lab:CreateText({
        name = "Readout",
        text = "Use the buttons below to drive each handle.",
        icon = "terminal",
    })

    local handleActions = lab:CreateGroup({ direction = "row" })
    handleActions:CreateButton({ name = "Set toggle off", icon = "power-off", callback = function() demoToggle:Set(false) end })
    handleActions:CreateButton({ name = "Slider to 75", icon = "gauge", callback = function() demoSlider:Set(75) end })
    handleActions:CreateButton({ name = "Stat +5", icon = "plus", callback = function() demoStat:Set(demoStat.value + 5) end })

    local handleActions2 = lab:CreateGroup({ direction = "row" })
    handleActions2:CreateButton({
        name = "Add option",
        icon = "list-plus",
        callback = function()
            local name = "Option-" .. tostring(math.random(10, 99))
            demoDropdown:Add(name)
            demoText:Set("Added " .. name .. " to the dropdown.")
        end,
    })
    handleActions2:CreateButton({
        name = "Remove option",
        icon = "list-minus",
        callback = function()
            demoDropdown:Remove("Gamma")
            demoText:Set("Removed Gamma from the dropdown.")
        end,
    })
    handleActions2:CreateButton({
        name = "Rewrite list",
        icon = "list-restart",
        callback = function()
            demoDropdown:Refresh({ "One", "Two", "Three", "Four" })
            demoText:Set("Dropdown rebuilt with four options.")
        end,
    })

    local handleActions3 = lab:CreateGroup({ direction = "row" })
    handleActions3:CreateButton({ name = "Prefill input", icon = "text-cursor-input", callback = function() demoInput:Set("Prefilled at " .. os.date("%H:%M:%S")) end })
    handleActions3:CreateButton({ name = "Keybind to P", icon = "keyboard", callback = function() demoKeybind:Set("p") end })
    handleActions3:CreateButton({ name = "Capture key", icon = "scan", callback = function() demoKeybind:Capture() end })
    handleActions3:CreateButton({ name = "Reset baseline", icon = "rotate-ccw", callback = function() demoStat:ResetBaseline(0) end })

    lab:CreateDivider({ text = "Move & lock" })

    local movableA = lab:CreateButton({ name = "Movable A", icon = "arrow-up" })
    local movableB = lab:CreateButton({ name = "Movable B", icon = "arrow-down" })
    local movableC = lab:CreateButton({ name = "Movable C", icon = "lock" })

    local moveActions = lab:CreateGroup({ direction = "row" })
    moveActions:CreateButton({ name = "A to top", icon = "chevrons-up", callback = function() movableA:MoveToTop() end })
    moveActions:CreateButton({ name = "A down", icon = "chevron-down", callback = function() movableA:MoveDown() end })
    moveActions:CreateButton({ name = "A up", icon = "chevron-up", callback = function() movableA:MoveUp() end })
    moveActions:CreateButton({ name = "A to bottom", icon = "chevrons-down", callback = function() movableA:MoveToBottom() end })

    local lockActions = lab:CreateGroup({ direction = "row" })
    lockActions:CreateButton({
        name = "Lock B",
        icon = "lock",
        callback = function()
            movableB:Lock("Locked from the lab")
            demoText:Set("Movable B locked: " .. tostring(movableB:IsLocked()))
        end,
    })
    lockActions:CreateButton({
        name = "Unlock B",
        icon = "lock-open",
        callback = function()
            movableB:Unlock()
            demoText:Set("Movable B locked: " .. tostring(movableB:IsLocked()))
        end,
    })
    lockActions:CreateButton({
        name = "Lock C",
        icon = "shield",
        callback = function()
            movableC:Lock()
            demoText:Set("Movable C locked: " .. tostring(movableC:IsLocked()))
        end,
    })

    lab:CreateDivider({ text = "Tooltip" })

    local tooltipActions = lab:CreateGroup({ direction = "row" })
    tooltipActions:CreateButton({
        name = "Show tooltip",
        icon = "message-square",
        callback = function()
            window:ShowTooltip(movableC.main, "A pinned tooltip, placed by the window over any instance.")
        end,
    })
    tooltipActions:CreateButton({ name = "Hide tooltip", icon = "message-square-off", callback = function() window:HideTooltip() end })

    lab:CreateCollapsibleGroup({
        name = "Declarative builder",
        icon = "braces",
        description = "A whole tree from one props table.",
        elements = {
            { type = "Text", name = "Built from one call", text = "Every entry below is a real element with a real handle." },
            { type = "Stat", name = "Children here", value = 4 },
            { type = "Keybind", name = "Nested keybind", value = "N" },
            { type = "Group", elements = {
                { type = "Button", name = "Nested button", icon = "corner-down-right" },
                { type = "Toggle", name = "Nested toggle", value = true },
            } },
        },
    })

    -- ===========================================================================
    -- 8. Configs — the persistence API
    -- ===========================================================================

    local configs = window:CreateTab({ name = "Configs", icon = "save" })

    configs:CreateSection({ name = "Slots", icon = "folder-open" })

    local slotName = configs:CreateInput({
        name = "Slot name",
        placeholder = "e.g. Slot2",
        value = "Slot1",
        clearOnFocus = false,
    })

    local slotList = configs:CreateDropdown({
        name = "Saved slots",
        options = { "No slots saved yet" },
        placeholder = "Pick a slot",
        description = "Rebuilt from window:ListConfigs() by the refresh button.",
    })

    local flagDumpText
    local slotCount = configs:CreateStat({ name = "Saved slots", value = 0 })
    local flagCount = configs:CreateStat({ name = "Flags tracked", value = 0, description = "Every flagged control on every tab." })

    local function countFlags()
        local total = 0
        for _ in window.Flags do
            total += 1
        end
        return total
    end

    local function refreshSlots()
        local names = window:ListConfigs() or {}
        if #names == 0 then
            slotList:Refresh({ "No slots saved yet" })
        else
            slotList:Refresh(names)
        end
        slotCount:Set(#names)
        flagCount:Set(countFlags())
        return #names
    end

    local configActions = configs:CreateGroup({ direction = "row" })
    configActions:CreateButton({
        name = "Save",
        icon = "save",
        callback = function()
            local name = slotName.value
            if window:Save(name) then
                tell("Saved", "Wrote slot " .. tostring(name) .. ".", "check")
                logEvent("Saved configuration " .. tostring(name) .. ".", "+", "Configs")
            else
                tell("Save failed", "This runtime has no writable storage.", "triangle-alert")
            end
            refreshSlots()
        end,
    })
    configActions:CreateButton({
        name = "Load",
        icon = "folder-down",
        callback = function()
            local name = slotName.value
            if window:Load(name) then
                tell("Loaded", "Restored slot " .. tostring(name) .. ".", "check")
                logEvent("Loaded configuration " .. tostring(name) .. ".", "~", "Configs")
            else
                tell("Load failed", "No slot called " .. tostring(name) .. ".", "triangle-alert")
            end
        end,
    })
    configActions:CreateButton({
        name = "Delete",
        icon = "trash-2",
        callback = function()
            local name = slotName.value
            if window:DeleteConfig(name) then
                tell("Deleted", "Removed slot " .. tostring(name) .. ".", "check")
                logEvent("Deleted configuration " .. tostring(name) .. ".", "-", "Configs")
            else
                tell("Delete failed", "No slot called " .. tostring(name) .. ".", "triangle-alert")
            end
            refreshSlots()
        end,
    })
    configActions:CreateButton({ name = "Refresh list", icon = "refresh-cw", callback = function() refreshSlots() end })

    configs:CreateDivider({ text = "Storage" })

    local folder, file = window:GetPath()
    configs:CreateText({
        name = "Persistence path",
        text = tostring(folder or "no writable storage") .. "  →  " .. tostring(file or "none"),
        icon = "hard-drive",
    })

    configs:CreateButton({
        name = "Dump flags",
        icon = "list",
        description = "Prints every flag to the console and summarises it here.",
        callback = function()
            local lines = {}
            for flag, value in window.Flags do
                local rendered
                if type(value) == "table" then
                    rendered = "{" .. table.concat(value, ", ") .. "}"
                else
                    rendered = tostring(value)
                end
                table.insert(lines, flag .. " = " .. rendered)
                print("[Astra] " .. flag .. " = " .. rendered)
            end
            table.sort(lines)
            flagDumpText:Set(#lines > 0 and table.concat(lines, "\n") or "No flagged controls registered.")
            flagCount:Set(#lines)
            tell("Flags dumped", #lines .. " flag(s) printed to the console.", "list")
        end,
    })

    configs:CreateCollapsibleGroup({
        name = "Flag inspector",
        icon = "search-code",
        description = "The dump button above writes into this group.",
        elements = {
            { type = "Text", name = "Current values", text = "Press “Dump flags” to fill this in." },
            { type = "Stat", name = "Auto save", value = "On", letter = false },
        },
    })

    local flagPanel = configs.elements[#configs.elements]
    flagDumpText = flagPanel.elements[1]

    configs:CreateDivider()
    configs:CreateText({
        name = "Automatic saving",
        text = "Auto Save Config and Auto Load Config live in the built-in Settings → Persistence page, together with the same slot controls. Values are stored separately from control values, so turning either off never deletes a slot.",
        icon = "settings",
    })

    refreshSlots()

    -- ===========================================================================
    -- 9. Window — theme, motion, visibility, overlays, diagnostics
    -- ===========================================================================

    -- [[Built after this tab, but its unlock button closes over it.]]
    local premium

    local windowTab = window:CreateTab({ name = "Window", icon = "app-window" })

    windowTab:CreateSection({ name = "Theme", icon = "palette" })

    local accentSwatches = windowTab:CreateGroup({ direction = "row" })
    local accents = {
        { name = "Teal", color = Color3.fromRGB(23, 153, 110) },
        { name = "Indigo", color = Color3.fromRGB(99, 102, 241) },
        { name = "Amber", color = Color3.fromRGB(224, 166, 74) },
        { name = "Rose", color = Color3.fromRGB(225, 80, 110) },
    }
    for _, accent in accents do
        accentSwatches:CreateButton({
            name = accent.name,
            icon = "droplet",
            callback = function()
                window:ChangeTheme({
                    Accent = accent.color,
                    AccentHover = accent.color,
                    AccentPressed = accent.color,
                    TabSelected = accent.color,
                })
                logEvent("Accent set to " .. accent.name .. ".", "~", "Theme")
            end,
        })
    end

    windowTab:CreateButton({
        name = "Reset theme",
        icon = "rotate-ccw",
        callback = function()
            window:ChangeTheme("default")
            logEvent("Theme reset to default.", "-", "Theme")
        end,
    })

    windowTab:CreateSlider({
        name = "Shell radius",
        flag = "demo.shellRadius",
        range = { 0, 24 },
        value = 12,
        suffix = "px",
        description = "CornerRoundness — the window silhouette and its bands.",
        callback = function(value)
            window:ChangeTheme({ CornerRoundness = UDim.new(0, value) })
        end,
    })
    windowTab:CreateSlider({
        name = "Element radius",
        flag = "demo.elementRadius",
        range = { 0, 16 },
        value = 8,
        suffix = "px",
        description = "ElementCornerRadius — cards, fields, rows and panels.",
        callback = function(value)
            window:ChangeTheme({ ElementCornerRadius = UDim.new(0, value) })
        end,
    })

    windowTab:CreateDivider({ text = "Motion" })

    windowTab:CreateDropdown({
        name = "Motion profile",
        flag = "demo.motionProfile",
        options = { "instant", "snappy", "normal", "relaxed" },
        value = "normal",
        callback = function(profile)
            Astra.Motion.setProfile(profile)
            logEvent("Motion profile set to " .. tostring(profile) .. ".", "~", "Motion")
        end,
    })
    windowTab:CreateSlider({
        name = "Time scale",
        flag = "demo.timeScale",
        range = { 25, 200 },
        value = 100,
        increment = 5,
        suffix = "%",
        callback = function(value)
            Astra.Motion.setTimeScale(value / 100)
        end,
    })
    windowTab:CreateToggle({
        name = "Animations enabled",
        flag = "demo.animations",
        value = true,
        description = "Off applies every target immediately, with no tweens.",
        callback = function(enabled)
            Astra.Motion.setEnabled(enabled)
        end,
    })

    windowTab:CreateDivider({ text = "Visibility" })

    local visibilityActions = windowTab:CreateGroup({ direction = "row" })
    visibilityActions:CreateButton({
        name = "Hide to capsule",
        icon = "minus",
        callback = function()
            window:Hide()
        end,
    })
    visibilityActions:CreateButton({ name = "Toggle hide", icon = "eye-off", callback = function() window:ToggleHide() end })
    visibilityActions:CreateButton({ name = "Minimise rail", icon = "panel-left-close", callback = function() window:ToggleMinimise() end })
    visibilityActions:CreateButton({ name = "Go to Overview", icon = "house", callback = function() window:Navigate(overview) end })

    windowTab:CreateDivider({ text = "Overlays" })

    local overlayActions = windowTab:CreateGroup({ direction = "row" })
    overlayActions:CreateButton({
        name = "Notification",
        icon = "bell",
        callback = function()
            tell("Notification", "Icon, duration and queueing all come from the props.", "sparkles", 5)
        end,
    })
    overlayActions:CreateButton({
        name = "Same again",
        icon = "copy",
        description = "Exact title+content pairs replace the live card instead of stacking.",
        callback = function()
            tell("Dedupe demo", "Fire this twice — the card is replaced, not duplicated.")
        end,
    })
    overlayActions:CreateButton({
        name = "Popup",
        icon = "message-square",
        callback = function()
            window:Popup({
                title = "Modal popup",
                subtitle = "Boxes, options and styles",
                icon = "layout-panel-top",
                content = "Popups own their own ScreenGui, so their content always draws above the window.",
                boxes = {
                    { icon = "layers", title = "Boxes", description = "Icon, title and description rows." },
                    { icon = "mouse-pointer-click", title = "Options", description = "Neutral, primary and danger buttons." },
                },
                options = {
                    { text = "Cancel" },
                    { text = "Danger", style = "danger", callback = function() tell("Danger", "The danger option ran.", "flame") end },
                    { text = "Confirm", style = "primary", callback = function() tell("Confirmed", "The primary option ran.", "check") end },
                },
            })
        end,
    })

    windowTab:CreateDivider({ text = "Diagnostics" })

    local diagnosticActions = windowTab:CreateGroup({ direction = "row" })
    diagnosticActions:CreateButton({
        name = "Icon catalog",
        icon = "icons",
        callback = function()
            local packs = Astra.Icons.packs()
            local summary = string.format(
                "%s names across %d packs (%s). Loaded so far: %s.",
                commas(Astra.Icons.count()),
                #packs,
                table.concat(Astra.Icons.priority(), ", "),
                table.concat(Astra.Icons.loaded(), ", ")
            )
            tell("Icons", summary, "icons", 6)
            logEvent("Icon catalog: " .. commas(Astra.Icons.count()) .. " names.", "+", "Diagnostics")
        end,
    })
    diagnosticActions:CreateButton({
        name = "Hardware",
        icon = "cpu",
        callback = function()
            local performance = Astra.Performance
            tell(
                "Hardware",
                string.format(
                    "Low-end: %s • struggling: %s • average %s fps",
                    tostring(performance.isLowEnd()),
                    tostring(performance.isStruggling()),
                    tostring(round(performance.getAverageFps()))
                ),
                "cpu",
                6
            )
        end,
    })
    diagnosticActions:CreateButton({
        name = "Resolve an icon",
        icon = "search",
        callback = function()
            tell("ResolveIcon", "house → " .. tostring(window:ResolveIcon("house")), "search", 6)
        end,
    })

    windowTab:CreateDivider({ text = "Gated tab" })

    windowTab:CreateButton({
        name = "Unlock Premium",
        icon = "unlock",
        description = "tab:SetLocked(false) is the only switch — locking is host-controlled.",
        callback = function()
            premium:SetLocked(false)
            window:Navigate(premium)
            tell("Premium unlocked", "The tab is open and its contents are now searchable.", "unlock")
            logEvent("Premium tab unlocked.", "+", "Window")
        end,
    })

    windowTab:CreateButton({
        name = "Unload window",
        icon = "power",
        description = "Asks first, then destroys every instance the window owns.",
        callback = function()
            window:Popup({
                title = "Unload Astra?",
                content = "Every element, listener and instance this window created is destroyed.",
                icon = "power",
                options = {
                    { text = "Keep it" },
                    { text = "Unload", style = "danger", callback = function()
                        logEvent("Window unloaded.", "-", "Window")
                        window:Unload()
                    end },
                },
            })
        end,
    })

    -- ===========================================================================
    -- 10. Premium — starts locked, unlocked from the Window tab
    -- ===========================================================================

    premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })

    premium:CreateSection({ name = "Gated", icon = "crown" })
    premium:CreateText({
        name = "You unlocked this tab",
        text = "While a tab is locked its elements are never built visible and search never indexes them, so nothing inside can be found from the search box. Locking is a UI gate, not a security boundary.",
        icon = "sparkles",
    })
    premium:CreateStat({ name = "Status", value = "Unlocked", letter = false })
    premium:CreateToggle({
        name = "Premium feature",
        flag = "demo.premiumFeature",
        value = false,
        callback = function(enabled)
            logEvent("Premium feature " .. (if enabled then "enabled." else "disabled."), "~", "Premium")
        end,
    })
    premium:CreateButton({
        name = "Re-lock this tab",
        icon = "lock",
        description = "Locking the open tab moves the selection to another unlocked tab.",
        callback = function()
            premium:SetLocked(true)
        end,
    })

    -- ===========================================================================
    -- Wiring that needs every tab to exist
    -- ===========================================================================

    -- [[Keep the walk-speed stat honest when the character respawns mid-session.]]
    if localPlayer and member(localPlayer, "CharacterAdded") then
        window:Connect(localPlayer.CharacterAdded, function()
            task.wait(0.5)
            readCharacter()
            logEvent("Character respawned; stats re-read.", "~", "Player")
        end)
    end

    overview:Select()
    studioReady = true
end

-- ===========================================================================
-- Open the gate
-- ===========================================================================

keyGate = Astra:CreateKeySystem({
    title = "Astra Element Studio",
    subtitle = "Key System",
    icon = "sirius",
    note = "Demo key: ASTRA-STUDIO-2026 — paste it below, or tap this line to copy the source link.",
    keys = { "ASTRA-STUDIO-2026" },
    getKeyUrl = "https://github.com/Kira762/astra-version-1/blob/main/example.client.luau",
    saveKey = true,
    fileName = "Astra-Example",
    maxAttempts = 5,
    onSuccess = buildStudio,
    onClose = function()
        print("[Astra] Key gate dismissed — the studio was not loaded.")
    end,
    onMaxAttempts = function()
        print("[Astra] Key gate locked after five wrong keys — rejoin to try again.")
    end,
})
