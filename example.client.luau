--[[
Astra Element Studio — a compact, working tour of the public API.

Opens through the key gate (demo key: ASTRA-STUDIO-2026) and builds the
whole studio inside `onSuccess`. In Studio/Rojo, require
ReplicatedStorage.Astra instead of the loadstring line below. The same
script runs under scripts/example_test.luau, which drives the gate through
the file-scope `keyGate` / `window` / `overview` / `studioReady` handles.
]]
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

-- Environment (nil-safe, so the script runs anywhere)
local function service(name)
    local ok, result = pcall(function()
        return game:GetService(name)
    end)
    return if ok then result else nil
end

local function member(object, name)
    if not object then
        return nil
    end
    local ok, result = pcall(function()
        return object[name]
    end)
    return if ok then result else nil
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
    return if ok then result else nil
end

local function rootPart()
    local model = character()
    if not model then
        return nil
    end
    local ok, result = pcall(function()
        return model:FindFirstChild("HumanoidRootPart")
    end)
    return if ok then result else nil
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
    return text:gsub("^(-?%d+)(%d*)", function(head, tail)
        return head .. (tail:reverse():gsub("(%d%d%d)", "%1,"):reverse())
    end)
end

-- Harness handles: the test drives the gate through these.
local keyGate
local window
local overview
local studioReady

local function buildStudio(unlockedKey)
    window = Astra:CreateWindow({
        name = "Astra Element Studio",
        subtitle = "Every element, working",
        icon = "sirius",
        configuration = { fileName = "Astra-Example", customFolder = "AstraExamples", autoSave = true, autoLoad = true },
    })

    local function tell(title, content, icon, duration)
        window:Notify({ title = title, content = content, icon = icon or "info", duration = duration or 4 })
    end

    -- 1. Overview — information lives here and only here
    overview = window:CreateTab({ name = "Overview", icon = "house" })
    local releaseHistory

    overview:CreateAboutCard({
        name = "Astra",
        subtitle = "A live testbed for the whole API.",
        icon = 80387863064905,
        rows = {
            { icon = "code", label = "Version", value = "1.4.0" },
            { icon = "layers", label = "Tabs", value = "13" },
            { icon = "user", label = "Author", value = "Astra Team" },
        },
        action = {
            icon = "file-text",
            name = "Release history",
            callback = function()
                overview:Select()
                if releaseHistory then
                    releaseHistory:Expand()
                end
            end,
        },
    })

    overview:CreateText({
        name = "Start here",
        text = "Every tab drives something real: Player edits the character, Live Stats samples the frame loop, Elements drives every handle, Steppers is a pure UI test (no callbacks). New Elements collects the newest APIs in one place.",
    })

    local actionsRun = overview:CreateStat({
        name = "Actions run",
        value = 0,
        changeMode = "delta",
        changeBaseline = "initial",
    })

    -- The changelog doubles as a live activity log the other tabs write into.
    local eventLog = overview:CreateChangelog({
        name = "Activity",
        emptyText = "Nothing has run yet.",
        entries = {
            { version = "Session", date = os.date("%Y-%m-%d"), title = "Studio opened", changes = {
                { symbol = "+", text = "Key gate passed: " .. tostring(unlockedKey) .. "." },
            } },
        },
    })

    local logged = 0
    local function logEvent(text, symbol)
        logged += 1
        actionsRun:Set(logged)
        eventLog:Add({
            version = "Event " .. tostring(logged),
            date = os.date("%H:%M:%S"),
            changes = { { symbol = symbol or "~", text = text } },
        })
    end

    overview:CreateLink({
        name = "Repository",
        subtitle = "Copy the project link",
        icon = "code",
        link = "https://github.com/Kira762/astra-version-1",
        callback = function(link)
            logEvent("Copied the repository link.", "+")
            tell("Copied", link, "check")
        end,
    })

    releaseHistory = overview:CreateIsolated({
        name = "Release history",
        subtitle = "Library milestones",
        icon = "history",
        elements = {
            { type = "Changelog", name = "Recent releases", entries = {
                { version = "1.4.0", date = "2026-09-12", changes = {
                    { symbol = "+", text = "About cards, links and richer grouped controls." },
                } },
            } },
        },
    })

    overview:CreateDivider()
    overview:CreateFooter({ parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" } } })

    -- 2. New Elements — recently added APIs in one place so they are easy
    -- to find when you come back to the studio. The Stepper redesign (the
    -- [−] [value] [+] counter as one pill capsule) is the headline here.
    -- All Elements already showcases every constructor, so this tab stays
    -- focused on the new look.
    local newElements = window:CreateTab({ name = "New Elements", icon = "sparkles" })

    newElements:CreateSection({ name = "Stepper (pill capsule)", icon = "hash" })

    newElements:CreateText({
        name = "What changed",
        text = "The [−] [value] [+] counter is now one pill capsule on the right of the card: both buttons and the value field wear the same neutral surface and hairline stroke, and the larger number carries the focus instead of an accent ring. Behaviour contract is unchanged: clamp, typed commits, focus ring and the lock tier all keep working.",
    })

    local pillStat = newElements:CreateStat({ name = "Pill value", value = 1, changeMode = "delta", changeBaseline = "initial", suffix = " units" })
    newElements:CreateStepper({
        name = "Counter",
        icon = "hash",
        flag = "demo.new.counter",
        value = 1, min = 0, max = 10, step = 1,
        callback = function(value) pillStat:Set(value) end,
    })

    newElements:CreateStepper({
        name = "Bounded range",
        icon = "hash",
        flag = "demo.new.bounded",
        value = 0, min = 0, max = 100, step = 5,
    })

    newElements:CreateStepper({
        name = "Fractional step",
        icon = "hash",
        flag = "demo.new.frac",
        value = 0, min = 0, max = 1, step = 0.25,
    })

    newElements:CreateStepper({
        name = "Negative range",
        icon = "hash",
        flag = "demo.new.negative",
        value = 0, min = -5, max = 5, step = 1,
    })

    -- 3. Player — real character edits
    local player = window:CreateTab({ name = "Player", icon = "user-round" })

    player:CreateSection({ name = "Movement", icon = "footprints" })

    local walkStat = player:CreateStat({ name = "Walk speed", value = 16, suffix = " studs/s" })
    local jumpStat = player:CreateStat({ name = "Jump power", value = 50, suffix = " force" })
    local healthStat = player:CreateStat({ name = "Health", value = 100, suffix = " hp" })

    local walkDefault, jumpDefault, frozenSpeed = 16, 50
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
            "%s (@%s) — health %s",
            tostring(member(localPlayer, "Name") or "Unknown"),
            tostring(member(localPlayer, "DisplayName") or "?"),
            tostring(round(hum.Health or 0))
        ))
        return hum
    end

    local walkSlider = player:CreateSlider({
        name = "Walk speed",
        flag = "demo.walkSpeed",
        range = { 0, 250 },
        value = 16,
        suffix = " studs/s",
        callback = function(value)
            local hum = humanoid()
            if hum then
                hum.WalkSpeed = value
                walkStat:Set(value)
            end
        end,
    })

    local jumpSlider = player:CreateSlider({
        name = "Jump power",
        flag = "demo.jumpPower",
        range = { 0, 200 },
        value = 50,
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
        callback = function(enabled)
            local signal = member(UserInputService, "JumpRequest")
            if enabled and not signal then
                tell("Unavailable", "No JumpRequest signal here.", "triangle-alert")
                infiniteJump:Set(false, true)
                return
            end
            if enabled then
                infiniteJump._connection = window:Connect(signal, function()
                    local hum = humanoid()
                    if hum then
                        pcall(function()
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end)
                    end
                end)
                logEvent("Infinite jump armed.", "+")
            elseif infiniteJump._connection then
                window:Disconnect(infiniteJump._connection)
                infiniteJump._connection = nil
                logEvent("Infinite jump released.", "-")
            end
        end,
    })

    local freezeToggle
    freezeToggle = player:CreateToggle({
        name = "Freeze in place",
        flag = "demo.freeze",
        value = false,
        callback = function(enabled)
            local hum = humanoid()
            if not hum then
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
        callback = function(letter)
            local hum = humanoid()
            if hum then
                hum.Health = 0
                logEvent("Respawn requested on key " .. letter .. ".")
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
            logEvent("Movement restored.")
        end,
    })

    identityText = player:CreateText({
        name = "Identity",
        text = "Press Read character to load live values.",
    })

    player:CreateCollapsibleGroup({
        name = "Character details",
        icon = "info",
        description = "Live values, refreshed by the button above.",
        elements = {
            { type = "Stat", name = "State", value = "Idle", letter = false },
            { type = "Stat", name = "Ground speed", value = 0, suffix = " s/s" },
        },
    })

    -- 4. Combat — target list and live counters
    local combat = window:CreateTab({ name = "Combat", icon = "sword" })

    combat:CreateSection({ name = "Targeting", icon = "crosshair" })

    local function roster()
        local names = {}
        if Players then
            for _, entry in Players:GetPlayers() do
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

    local targetText = combat:CreateText({ name = "Current target", text = "None selected." })

    local targetList = combat:CreateDropdown({
        name = "Target player",
        flag = "demo.target",
        options = roster(),
        placeholder = "Pick a player",
        callback = function(selected)
            targetText:Set("Locked on " .. tostring(selected) .. ".")
            logEvent("Target set to " .. tostring(selected) .. ".")
        end,
    })

    local rosterActions = combat:CreateGroup({ direction = "row" })
    rosterActions:CreateButton({
        name = "Refresh roster",
        icon = "refresh-cw",
        callback = function()
            targetList:Refresh(roster())
        end,
    })
    rosterActions:CreateButton({
        name = "Add dummy",
        icon = "user-plus",
        callback = function()
            targetList:Add("Dummy-" .. tostring(math.random(100, 999)))
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
    combat:CreateDropdown({
        name = "Hitbox part",
        flag = "demo.hitbox",
        options = { "Head", "UpperTorso", "HumanoidRootPart" },
        value = "Head",
    })

    local engagements = combat:CreateStat({ name = "Engagements", value = 0, changeMode = "delta", changeBaseline = "initial" })
    local accuracy = combat:CreateStat({ name = "Accuracy", value = 0, suffix = "%" })
    local gradeBadge = combat:CreateStat({ name = "Grade", value = "C", letter = true })

    combat:CreateButton({
        name = "Simulate engagement",
        icon = "zap",
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
            logEvent(string.format("%d/%d hits (%d%%).", hits, shots, percent), "+")
        end,
    })

    combat:CreateCollapsibleGroup({
        name = "Automation",
        icon = "bot",
        elements = {
            { type = "Toggle", name = "Auto fire", flag = "demo.autoFire", value = false },
            { type = "Toggle", name = "Target closest", flag = "demo.closest", value = true },
            { type = "Slider", name = "Fire rate", flag = "demo.fireRate", range = { 1, 20 }, value = 8, suffix = " rps" },
        },
    })

    -- 5. Visuals — real Lighting and Camera edits
    local visuals = window:CreateTab({ name = "Visuals", icon = "eye" })

    if not Lighting then
        visuals:CreateText({ name = "Lighting unavailable", text = "Lighting controls report back instead of throwing." })
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
        callback = function(enabled)
            if not Lighting then
                return
            end
            if enabled then
                if not colorCorrection then
                    colorCorrection = Instance.new("ColorCorrectionEffect")
                    colorCorrection.Name = "AstraGrade"
                    colorCorrection.Saturation = 0.25
                    colorCorrection.Parent = Lighting
                end
                colorCorrection.Enabled = true
                logEvent("Colour grade enabled.", "+")
            elseif colorCorrection then
                colorCorrection.Enabled = false
                logEvent("Colour grade disabled.", "-")
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

    local visualPresets = visuals:CreateGroup({ direction = "row" })
    visualPresets:CreateButton({
        name = "Golden hour",
        icon = "sunrise",
        callback = function()
            if Lighting then
                Lighting.ClockTime = 17.5
                Lighting.Brightness = 2.5
            end
            logEvent("Golden hour preset applied.")
        end,
    })
    visualPresets:CreateButton({
        name = "Reset",
        icon = "rotate-ccw",
        callback = function()
            if Lighting then
                Lighting.ClockTime = 14
                Lighting.Brightness = 2
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
            logEvent("Visuals reset.", "-")
        end,
    })

    -- 6. World — coordinates and teleporting
    local world = window:CreateTab({ name = "World", icon = "map" })

    world:CreateSection({ name = "Coordinates", icon = "move-3d" })

    local posX = world:CreateInput({ name = "X", placeholder = "0", numeric = true, value = "0", flag = "demo.posX" })
    local posY = world:CreateInput({ name = "Y", placeholder = "0", numeric = true, value = "0", flag = "demo.posY" })
    local posZ = world:CreateInput({ name = "Z", placeholder = "0", numeric = true, value = "0", flag = "demo.posZ" })

    local travelled = world:CreateStat({ name = "Distance teleported", value = 0, suffix = " studs", numberEasing = true })

    local function currentPosition()
        local part = rootPart()
        if not part then
            return nil
        end
        local ok, position = pcall(function()
            return part.Position
        end)
        return if ok then position else nil
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
        end,
    })
    coordActions:CreateButton({
        name = "Teleport",
        icon = "send",
        callback = function()
            local part = rootPart()
            if not part then
                tell("No character", "Nothing to move.", "triangle-alert")
                return
            end
            local target = Vector3.new(tonumber(posX.value) or 0, tonumber(posY.value) or 0, tonumber(posZ.value) or 0)
            local before = currentPosition()
            part.CFrame = CFrame.new(target)
            if before then
                travelled:Set(travelled.value + round((before - target).Magnitude))
            end
            logEvent("Teleported.", "~")
        end,
    })

    world:CreateDivider({ text = "Landmarks" })

    local landmarkList = world:CreateDropdown({
        name = "Landmark",
        flag = "demo.landmark",
        options = { "Origin", "Sky", "Underground" },
        value = "Origin",
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
            local target = landmarkTargets[window:Get("demo.landmark") or "Origin"]
            if not target then
                return
            end
            posX:Set(tostring(target.X))
            posY:Set(tostring(target.Y))
            posZ:Set(tostring(target.Z))
            local part = rootPart()
            if part then
                part.CFrame = CFrame.new(target)
                logEvent("Jumped to landmark.")
            end
        end,
    })

    world:CreateCollapsibleGroup({
        name = "Waypoints",
        icon = "bookmark",
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
            return
        end
        local name = "Waypoint " .. tostring(#waypoints + 1)
        waypoints[name] = position
        landmarkTargets[name] = position
        landmarkList:Add(name)
        waypointText:Set(name .. " saved.")
        logEvent("Saved " .. name .. ".", "+")
    end

    waypointPanel.elements[2].elements[2].callback = function()
        for name in waypoints do
            landmarkTargets[name] = nil
            landmarkList:Remove(name)
            waypoints[name] = nil
        end
        landmarkList:Refresh({ "Origin", "Sky", "Underground" })
        waypointText:Set("No waypoints saved yet.")
        logEvent("Waypoints cleared.", "-")
    end

    -- 7. Live Stats — a real sampler on the frame loop
    local stats = window:CreateTab({ name = "Live Stats", icon = "activity" })

    stats:CreateSection({ name = "Sampler", icon = "gauge" })

    local fpsStat = stats:CreateStat({ name = "Frame rate", value = 0, suffix = " fps", numberEasing = true })
    local frameStat = stats:CreateStat({ name = "Frame time", value = 0, suffix = " ms" })
    local memoryStat = stats:CreateStat({ name = "Lua memory", value = 0, suffix = " KB" })
    local uptimeStat = stats:CreateStat({ name = "Session", value = 0, suffix = " s" })
    local pingStat = stats:CreateStat({ name = "Ping", value = 0, suffix = " ms" })
    local samplerState = stats:CreateStat({ name = "Sampler", value = "Idle", letter = false })

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
        if now - lastSample < 1 / math.clamp(sampleRate.value or 2, 1, 10) then
            return
        end
        local dt = now - lastSample
        lastSample = now

        local fps = 1 / math.max(dt, 0.0001)
        smoothedFps = if smoothedFps == 0 then fps else smoothedFps * 0.7 + fps * 0.3
        fpsStat:Set(round(math.clamp(smoothedFps, 0, 999)))
        frameStat:Set(round(dt * 1000, 1))
        memoryStat:Set(round(collectgarbage("count")))
        uptimeStat:Set(round(now - startedAt))

        local network = member(Stats, "Network")
        local pingItem = network and member(network, "ServerStatsItem")
        if type(pingItem) == "table" and pingItem["Data Ping"] then
            pingStat:Set(round(pingItem["Data Ping"]:GetValue(), 1))
        end
    end

    stats:CreateToggle({
        name = "Live updates",
        flag = "demo.sampler",
        value = false,
        callback = function(enabled)
            if enabled then
                if not samplerConnection and RunService and member(RunService, "Heartbeat") then
                    lastSample = os.clock()
                    samplerConnection = window:Connect(RunService.Heartbeat, sample)
                    samplerState:SetText("Sampling")
                    logEvent("Sampler connected to Heartbeat.", "+")
                end
            elseif samplerConnection then
                window:Disconnect(samplerConnection)
                samplerConnection = nil
                samplerState:SetText("Idle")
                logEvent("Sampler disconnected.", "-")
            end
        end,
    })

    stats:CreateButton({
        name = "Take a snapshot",
        icon = "camera",
        callback = function()
            lastSample = os.clock() - 1
            sample()
            tell("Snapshot", string.format(
                "%s fps, %s ms frame, %s KB Lua",
                tostring(fpsStat.value), tostring(frameStat.value), commas(memoryStat.value)
            ), "camera")
            logEvent("Snapshot taken.", "+")
        end,
    })

    stats:CreateCollapsibleGroup({
        name = "Hardware report",
        icon = "cpu",
        description = "What the library's own performance module decided.",
        elements = {
            { type = "Text", name = "Profile", text = "Press Refresh to read the hardware module." },
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
        local average = round(performance.getAverageFps())
        hardwareFps:Set(average)
        hardwareText:Set(string.format(
            "%s • %s • budgets %s ms / %s instances",
            if performance.isLowEnd() then "Low-end" else "Standard",
            if performance.isStruggling() then "struggling" else "steady",
            tostring(round(performance.getBudgets(120, 10) * 1000, 1)),
            "—"
        ))
    end

    -- 8. Elements — every handle, driven
    local lab = window:CreateTab({ name = "Elements", icon = "flask-conical" })

    lab:CreateSection({ name = "Handles", icon = "sliders-horizontal" })

    -- Declared first: every handle callback below writes into this readout.
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
            demoText:Set("Slider " .. tostring(value) .. "%, dragging = " .. tostring(dragging) .. ".")
        end,
    })
    local demoDropdown = lab:CreateDropdown({
        name = "Sample dropdown",
        flag = "demo.lab.dropdown",
        options = { "Alpha", "Beta", "Gamma" },
        value = "Alpha",
        multiSelect = true,
        callback = function(selected)
            demoText:Set("Dropdown: " .. table.concat(selected, ", "))
        end,
    })
    local demoInput = lab:CreateInput({
        name = "Sample input",
        flag = "demo.lab.input",
        placeholder = "Type something",
        value = "Hello",
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
    local demoStat = lab:CreateStat({ name = "Sample stat", value = 10, changeMode = "delta", changeBaseline = "initial" })
    demoText = lab:CreateText({ name = "Readout", text = "Use the buttons below to drive each handle." })

    local handleActions = lab:CreateGroup({ direction = "row" })
    handleActions:CreateButton({ name = "Toggle off", icon = "power-off", callback = function() demoToggle:Set(false) end })
    handleActions:CreateButton({ name = "Slider to 75", icon = "gauge", callback = function() demoSlider:Set(75) end })
    handleActions:CreateButton({ name = "Stat +5", icon = "plus", callback = function() demoStat:Set(demoStat.value + 5) end })
    handleActions:CreateButton({
        name = "Add option",
        icon = "list-plus",
        callback = function()
            demoDropdown:Add("Option-" .. tostring(math.random(10, 99)))
        end,
    })
    handleActions:CreateButton({ name = "Prefill input", icon = "text-cursor-input", callback = function() demoInput:Set("Prefilled") end })
    handleActions:CreateButton({ name = "Capture key", icon = "scan", callback = function() demoKeybind:Capture() end })

    lab:CreateDivider({ text = "Move & lock" })

    local movableA = lab:CreateButton({ name = "Movable A", icon = "arrow-up" })
    local movableB = lab:CreateButton({
        name = "Movable B",
        icon = "arrow-down",
        callback = function()
            demoText:Set("Movable B clicked.")
        end,
    })

    local moveActions = lab:CreateGroup({ direction = "row" })
    moveActions:CreateButton({ name = "A to top", icon = "chevrons-up", callback = function() movableA:MoveToTop() end })
    moveActions:CreateButton({ name = "A up", icon = "chevron-up", callback = function() movableA:MoveUp() end })
    moveActions:CreateButton({
        name = "Lock B",
        icon = "lock",
        callback = function()
            movableB:Lock("Locked from the lab")
            demoText:Set("B locked: " .. tostring(movableB:IsLocked()))
        end,
    })
    moveActions:CreateButton({
        name = "Unlock B",
        icon = "lock-open",
        callback = function()
            movableB:Unlock()
            demoText:Set("B locked: " .. tostring(movableB:IsLocked()))
        end,
    })

    lab:CreateDivider({ text = "Tooltip" })

    local tooltipActions = lab:CreateGroup({ direction = "row" })
    tooltipActions:CreateButton({
        name = "Show tooltip",
        icon = "message-square",
        callback = function()
            window:ShowTooltip(movableB.main, "A pinned tooltip over any instance.")
        end,
    })
    tooltipActions:CreateButton({ name = "Hide tooltip", icon = "message-square-off", callback = function() window:HideTooltip() end })

    lab:CreateCollapsibleGroup({
        name = "Declarative builder",
        icon = "braces",
        description = "A whole tree from one props table.",
        elements = {
            { type = "Text", name = "Built from one call", text = "Every entry here is a real element." },
            { type = "Keybind", name = "Nested keybind", value = "N" },
            { type = "Group", elements = {
                { type = "Button", name = "Nested button", icon = "corner-down-right" },
                { type = "Toggle", name = "Nested toggle", value = true },
            } },
        },
    })

    lab:CreateDivider({ text = "Mode Picker" })

    local demoModePicker = lab:CreateModePicker({
        title = "Mode Picker",
        subtitle = "Astra demo",
        left_icon = "zap",
        right_icon = "rotate-ccw",
        flag = "demo.lab.modePicker",
        modes = {
            { label = "Normal", type = "default" },
            { label = "Fast", type = "dot" },
            { label = "Balanced", type = "dot" },
        },
        callback = function(index, label)
            demoText:Set("Mode: " .. label .. " (" .. tostring(index) .. ").")
        end,
        onReset = function()
            demoText:Set("Mode picker reset.")
        end,
    })

    local modeActions = lab:CreateGroup({ direction = "row" })
    modeActions:CreateButton({ name = "Mode 2", icon = "arrow-right", callback = function() demoModePicker:Set(2) end })
    modeActions:CreateButton({ name = "Reset", icon = "rotate-ccw", callback = function() demoModePicker:Reset() end })

    -- 9. All Elements — one tab with every public element constructor.
    -- The visible names intentionally match the element names so this tab is
    -- also a quick visual smoke test when a new build is loaded.
    local allElements = window:CreateTab({ name = "All Elements", icon = "layout-grid" })
    allElements:CreateSection({ name = "Section", icon = "list" })
    local allText = allElements:CreateText({ name = "Text", text = "Text" })
    allElements:CreateButton({
        name = "Button", icon = "mouse-pointer-click",
        callback = function() allText:Set("Button") end,
    })
    allElements:CreateToggle({ name = "Toggle", icon = "toggle-right", value = true })
    allElements:CreateSlider({
        name = "Slider", icon = "sliders-horizontal", range = { 0, 100 }, value = 50,
    })
    allElements:CreateStepper({
        name = "Stepper", icon = "hash", flag = "demo.stepper",
        value = 0, min = 0, step = 1,
    })
    allElements:CreateDropdown({
        name = "Dropdown", icon = "list-filter", options = { "One", "Two" }, value = "One",
    })
    allElements:CreateInput({ name = "Input", icon = "text-cursor-input", value = "Input" })
    allElements:CreateKeybind({ name = "Keybind", icon = "keyboard", value = "K" })
    allElements:CreateStat({ name = "Stat", value = 42, suffix = " points" })
    allElements:CreateLink({
        name = "Link", subtitle = "Copy this example URL", icon = "link",
        link = "https://github.com/Kira762/astra-version-1",
    })
    allElements:CreateAboutCard({
        name = "AboutCard", subtitle = "AboutCard with all icon slots restored", icon = "info",
        rows = {
            { icon = "code", label = "Version", value = "1.4.0" },
            { icon = "package", label = "Build", value = "All elements" },
            { icon = "user", label = "Author", value = "Astra Team" },
        },
        action = { icon = "file-text", name = "AboutCard action", subtitle = "The band is tappable" },
    })
    allElements:CreateFooter({ parts = { { text = "Footer" }, { icon = "zap" } } })
    allElements:CreateChangelog({
        name = "Changelog",
        entries = { { version = "Demo", title = "Changelog", changes = { { symbol = "+", text = "Changelog" } } } },
    })
    allElements:CreateDivider({ text = "Divider" })

    -- Group has no visible name property; its child is named Group so the
    -- constructor is still obvious in the all-elements smoke-test tab.
    local allGroup = allElements:CreateGroup({ direction = "column" })
    allGroup:CreateText({ name = "Group", text = "Group" })

    allElements:CreateCollapsibleGroup({
        name = "CollapsibleGroup", icon = "chevrons-up-down", description = "CollapsibleGroup",
        elements = {
            { type = "Text", name = "Text", text = "CollapsibleGroup contents" },
            { type = "Button", name = "Button" },
        },
    })
    allElements:CreateModePicker({
        title = "ModePicker", subtitle = "ModePicker", left_icon = "zap", right_icon = "rotate-ccw",
        modes = {
            { label = "One", type = "default" },
            { label = "Two", type = "dot" },
            { label = "Three", type = "dot" },
        },
    })
    allElements:CreateIsolated({
        name = "Isolated", subtitle = "Isolated", icon = "archive",
        elements = { { type = "Changelog", name = "Changelog", entries = {
            { version = "Demo", title = "Isolated", changes = { { symbol = "+", text = "Isolated" } } },
        } } },
    })

    -- 10. Steppers — pure UI test of the Stepper element (no callbacks, no wiring)
    local steppers = window:CreateTab({ name = "Steppers", icon = "hash" })
    steppers:CreateSection({ name = "Stepper UI test", icon = "hash" })
    steppers:CreateStepper({ name = "Value Configuration", icon = "hash", value = 0, min = 0, step = 1 })
    steppers:CreateStepper({ name = "Party size", icon = "hash", value = 1, min = 1, max = 8, step = 1 })
    steppers:CreateStepper({ name = "Wager", icon = "hash", value = 0, min = 0, max = 500, step = 25 })
    steppers:CreateStepper({ name = "Opacity", icon = "hash", value = 1, min = 0, max = 1, step = 0.1 })
    steppers:CreateStepper({ name = "Bias", icon = "hash", value = 0, min = -5, max = 5, step = 1 })
    steppers:CreateText({ name = "UI test only — no callbacks, no game wiring", text = "Tap [-] / [+], type values, test clamping. Boundaries: Value (0 floor), Party (max 8), Wager (step 25, cap 500), Opacity (fractional 0–1), Bias (min -5)." })

    -- 11. Configs — the persistence API
    local configs = window:CreateTab({ name = "Configs", icon = "save" })

    configs:CreateSection({ name = "Slots", icon = "folder-open" })

    local slotName = configs:CreateInput({ name = "Slot name", placeholder = "e.g. Slot2", value = "Slot1" })

    local slotList = configs:CreateDropdown({
        name = "Saved slots",
        options = { "No slots saved yet" },
        placeholder = "Pick a slot",
    })

    local flagDumpText
    local slotCount = configs:CreateStat({ name = "Saved slots", value = 0 })
    local flagCount = configs:CreateStat({ name = "Flags tracked", value = 0, description = "Every flagged control on every tab." })

    local function refreshSlots()
        local names = window:ListConfigs() or {}
        slotList:Refresh(if #names > 0 then names else { "No slots saved yet" })
        slotCount:Set(#names)
        local total = 0
        for _ in window.Flags do
            total += 1
        end
        flagCount:Set(total)
    end

    local configActions = configs:CreateGroup({ direction = "row" })
    configActions:CreateButton({
        name = "Save",
        icon = "save",
        callback = function()
            if window:Save(slotName.value) then
                tell("Saved", "Wrote slot " .. slotName.value .. ".", "check")
                logEvent("Saved configuration " .. slotName.value .. ".", "+")
            else
                tell("Save failed", "No writable storage here.", "triangle-alert")
            end
            refreshSlots()
        end,
    })
    configActions:CreateButton({
        name = "Load",
        icon = "folder-down",
        callback = function()
            if window:Load(slotName.value) then
                tell("Loaded", "Restored slot " .. slotName.value .. ".", "check")
                logEvent("Loaded configuration " .. slotName.value .. ".")
            else
                tell("Load failed", "No slot called " .. slotName.value .. ".", "triangle-alert")
            end
        end,
    })
    configActions:CreateButton({
        name = "Delete",
        icon = "trash-2",
        callback = function()
            if window:DeleteConfig(slotName.value) then
                logEvent("Deleted configuration " .. slotName.value .. ".", "-")
            end
            refreshSlots()
        end,
    })

    configs:CreateDivider({ text = "Storage" })

    local folder, file = window:GetPath()
    configs:CreateText({
        name = "Persistence path",
        text = tostring(folder or "no writable storage") .. " → " .. tostring(file or "none"),
    })

    configs:CreateButton({
        name = "Dump flags",
        icon = "list",
        callback = function()
            local lines = {}
            for flagName, value in window.Flags do
                local rendered = if type(value) == "table" then "{" .. table.concat(value, ", ") .. "}" else tostring(value)
                table.insert(lines, flagName .. " = " .. rendered)
            end
            table.sort(lines)
            flagDumpText:Set(if #lines > 0 then table.concat(lines, "\n") else "No flagged controls registered.")
            flagCount:Set(#lines)
            tell("Flags dumped", #lines .. " flag(s).", "list")
        end,
    })

    configs:CreateCollapsibleGroup({
        name = "Flag inspector",
        icon = "search-code",
        elements = {
            { type = "Text", name = "Current values", text = "Press Dump flags to fill this in." },
            { type = "Stat", name = "Auto save", value = "On", letter = false },
        },
    })

    flagDumpText = configs.elements[#configs.elements].elements[1]

    -- The slot list is live: autosaved configs appear without a manual Save.
    window:OnConfigsChanged(refreshSlots)
    refreshSlots()

    -- 12. Window — theme, motion, visibility, overlays, diagnostics
    -- Built after this tab, but its unlock button closes over it.
    local premium

    local windowTab = window:CreateTab({ name = "Window", icon = "app-window" })

    windowTab:CreateSection({ name = "Theme", icon = "palette" })

    local accentSwatches = windowTab:CreateGroup({ direction = "row" })
    for _, accent in {
        { name = "Teal", color = Color3.fromRGB(23, 153, 110) },
        { name = "Indigo", color = Color3.fromRGB(99, 102, 241) },
        { name = "Rose", color = Color3.fromRGB(225, 80, 110) },
    } do
        accentSwatches:CreateButton({
            name = accent.name,
            icon = "droplet",
            callback = function()
                window:ChangeTheme({ Accent = accent.color, AccentHover = accent.color, TabSelected = accent.color })
                logEvent("Accent set to " .. accent.name .. ".")
            end,
        })
    end

    windowTab:CreateButton({
        name = "Reset theme",
        icon = "rotate-ccw",
        callback = function()
            window:ChangeTheme("default")
            logEvent("Theme reset.", "-")
        end,
    })

    windowTab:CreateSlider({
        name = "Corner radius",
        flag = "demo.shellRadius",
        range = { 0, 24 },
        value = 12,
        suffix = "px",
        callback = function(value)
            window:ChangeTheme({ CornerRoundness = UDim.new(0, value) })
        end,
    })

    windowTab:CreateDivider({ text = "Motion" })

    --[[
    The animation-speed picker is gone: the library plays at its built-in
    motion (normal, faster, never instant). Hosts that want to rescale it
    still can, through Astra.Motion.setProfile.
    ]]
    windowTab:CreateToggle({
        name = "Animations enabled",
        flag = "demo.animations",
        value = true,
        callback = function(enabled)
            Astra.Motion.setEnabled(enabled)
        end,
    })

    windowTab:CreateDivider({ text = "Visibility & overlays" })

    local windowActions = windowTab:CreateGroup({ direction = "row" })
    windowActions:CreateButton({ name = "Hide to capsule", icon = "minus", callback = function() window:Hide() end })
    windowActions:CreateButton({ name = "Toggle hide", icon = "eye-off", callback = function() window:ToggleHide() end })
    windowActions:CreateButton({ name = "Minimise rail", icon = "panel-left-close", callback = function() window:ToggleMinimise() end })
    windowActions:CreateButton({ name = "Go to Overview", icon = "house", callback = function() window:Navigate(overview) end })
    windowActions:CreateButton({
        name = "Notification",
        icon = "bell",
        callback = function()
            tell("Notification", "Dedupe demo — fire twice, the card is replaced.", "sparkles", 5)
        end,
    })
    windowActions:CreateButton({
        name = "Popup",
        icon = "message-square",
        callback = function()
            window:Popup({
                title = "Modal popup",
                subtitle = "Boxes and options",
                icon = "layout-panel-top",
                content = "Popups draw above the window.",
                boxes = {
                    { icon = "layers", title = "Boxes", description = "Icon, title and description rows." },
                },
                options = {
                    { text = "Cancel" },
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
            tell("Icons", commas(Astra.Icons.count()) .. " names across " .. tostring(#Astra.Icons.packs()) .. " packs.", "icons", 6)
            logEvent("Icon catalog read.", "+")
        end,
    })
    diagnosticActions:CreateButton({
        name = "Hardware",
        icon = "cpu",
        callback = function()
            local performance = Astra.Performance
            tell("Hardware", string.format(
                "Low-end: %s • average %s fps",
                tostring(performance.isLowEnd()), tostring(round(performance.getAverageFps()))
            ), "cpu", 6)
        end,
    })

    windowTab:CreateDivider({ text = "Gated tab" })

    windowTab:CreateButton({
        name = "Unlock Premium",
        icon = "unlock",
        callback = function()
            premium:SetLocked(false)
            window:Navigate(premium)
            logEvent("Premium tab unlocked.", "+")
        end,
    })

    windowTab:CreateButton({
        name = "Unload window",
        icon = "power",
        callback = function()
            window:Popup({
                title = "Unload Astra?",
                content = "Everything this window created is destroyed.",
                icon = "power",
                options = {
                    { text = "Keep it" },
                    { text = "Unload", style = "danger", callback = function()
                        window:Unload()
                    end },
                },
            })
        end,
    })

    -- 13. Premium — starts locked, unlocked from the Window tab
    premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })

    premium:CreateSection({ name = "Gated", icon = "crown" })
    premium:CreateText({
        name = "You unlocked this tab",
        text = "Locked tabs are never built visible and search never indexes them.",
    })
    premium:CreateStat({ name = "Status", value = "Unlocked", letter = false })
    premium:CreateButton({
        name = "Re-lock this tab",
        icon = "lock",
        callback = function()
            premium:SetLocked(true)
        end,
    })

    -- Wiring that needs every tab to exist
    if localPlayer and member(localPlayer, "CharacterAdded") then
        window:Connect(localPlayer.CharacterAdded, function()
            task.wait(0.5)
            readCharacter()
            logEvent("Character respawned; stats re-read.")
        end)
    end

    overview:Select()
    studioReady = true
end

keyGate = Astra:CreateKeySystem({
    title = "Astra Element Studio",
    subtitle = "Key System",
    note = "Demo key: ASTRA-STUDIO-2026.",
    keys = { "ASTRA-STUDIO-2026" },
    getKeyUrl = "https://github.com/Kira762/astra-version-1/blob/main/example.client.luau",
    links = {
        { name = "Repository", icon = "external-link", link = "https://github.com/Kira762/astra-version-1" },
    },
    saveKey = true,
    fileName = "Astra-Example",
    maxAttempts = 5,
    onSuccess = buildStudio,
    onClose = function()
        print("[Astra] Key gate dismissed.")
    end,
    onMaxAttempts = function()
        print("[Astra] Key gate locked after five wrong keys.")
    end,
})
