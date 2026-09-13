local utilities = script.Parent.Parent.utilities
local state = require(utilities.Parent.core.state)
local services = require(utilities.services)
local image = require(script.Parent.Parent.images.image)
local functions = require(script.Parent.Parent.functions)
local locale = require(utilities.locale)
local sidebar = require(script.Parent.sidebar)
local network = require(utilities.network)

-- [[The profile panel lives OUTSIDE the window frame, beside it: a companion]]
-- [[card whose height always matches the current window height. The window and]]
-- [[the panel are centred on screen as a single unit, so the window sits half a]]
-- [[panel (width + gap) away from the screen centre, on the opposite side of]]
-- [[the panel.]]
-- [[
--   Visual language: the card is the window, in miniature. Its surface is the
--   window frame's own (WindowColor gradient, CornerRoundness, hairline
--   SurfaceStroke, ShadowColor glow); every section plate is a window element
--   body (Window:StyleElementBody — ElementGradient over ElementTransparency,
--   ElementCornerRadius, ElementStroke at ElementStrokeTransparency); every
--   heading is a window Section title (16px ContentColor icon at 0.65 beside
--   a 15px ContentColor label at 0.6); every row reuses the element row
--   colours (ContentColor icons and values, muted ContentColor labels) and
--   the brand Font. Nothing here introduces a colour, radius, gradient or
--   shadow the rest of Astra does not already use.
--
--   Layout, top to bottom:
--     header   avatar (with its presence dot) on the left; display name,
--              @username and the tier pill (PREMIUM / FREEMIUM, or the host's
--              own word) beside it. The header is pinned — it never scrolls.
--     divider  one hairline rule, inset by the card padding.
--     details  a vertically scrolling column of sections, each a window-style
--              section heading above an element-style plate of compact
--              label/value rows:
--                Account       user ID (+ COPY), join date, account age,
--                              key (+ COPY), whitelist
--                Current Game  thumbnail, game name, place ID (+ COPY)
--                Server        players, job ID (+ COPY)
--                User Session  time in server
--
--   Every plate, heading, row and pill on the card is styled with the very
--   same theme tokens the window and its elements use — nothing here
--   introduces a colour, radius, gradient or transparency of its own.
--
--   Every value is bound to a real source (see the DATA section below) and
--   falls back to a neutral "—" when the source is unavailable. Nothing on the
--   card is fabricated, and values the app treats as identifying stay masked
--   until "Reveal profile details" is on. The game name comes from Roblox's
--   official two-step API (place id -> universe id -> games list), falling
--   back to the DataModel's own name while the request is in flight or when
--   the executor exposes no request function.
-- ]]

local profilePanel = {}

profilePanel.width = 260
profilePanel.gap = 12

-- [[Card metrics. Kept in lockstep with the layout code below; the scroll
-- [[region is the only part of the card that grows with content.]]
local avatarSize = 48
local avatarTop = 12
local paddingX = 12
local headerHeight = 74
local dividerHeight = 1
local scrollPaddingTop = 12
local scrollPaddingBottom = 16
local sectionGap = 12
-- [[Heading metrics mirror the window's Section element: a 16px icon beside a]]
-- [[16px-tall title row, both in ContentColor at the section's own]]
-- [[transparencies (title 0.6, icon 0.65).]]
local headingHeight = 16
local headingGap = 8
local headingIconSize = 16
local headingIconGap = 6
local cardPaddingX = 10
local cardPaddingY = 10
local rowHeight = 18
local rowGap = 6
local rowIconSize = 14
local labelWidth = 92
local actionSize = 16
local actionInset = actionSize + 6
local gameThumbnailSize = 40
local tooltipHeight = 32
local scrollBarThickness = 6
local scrollBarTransparency = 0.8
local refreshInterval = 1
-- [[How long a copy action keeps its green check before the copy icon]]
-- [[returns.]]
local copyFlashDuration = 1.2
-- [[Copy button wording: the idle label is built from the row's own name]]
-- [[("Copy " .. "Job ID"), the confirmation stands alone ("Copied"). Both go]]
-- [[through locale.resolve, so a host can translate them by their source]]
-- [[strings like every other line on the card.]]
local copyLabelPrefix = "Copy "
local copiedLabel = "Copied"
-- [[Tier pill box: measured from its own label so any tier word fits.]]
local tierHeight = 16
local tierPaddingLeft = 6
local tierPaddingRight = 7
local tierIconSize = 10
local tierGap = 4

-- [[Neutral placeholder for a value the application cannot supply. Never a
-- [[made-up number: "—" reads as "no data" in every locale.]]
local fallbackValue = "—"

-- [[Placeholder shown in place of an identifier while the reveal toggle is
-- [[off: a fixed-width block, so neither the value nor its length leaks. Names
-- [[keep the sidebar mask ("Tes****") instead.]]
local maskedId = "••••••"
local maskedKey = "••••••••"

local nameTransparency = 0
-- [[The window's own secondary-text transparency (the topbar subtitle fades]]
-- [[to 0.7), reused for the card's @username line.]]
local subtitleTransparency = 0.7
local labelTransparency = 0.45
-- [[Section title / icon transparencies, taken from the Section element's]]
-- [[reveal values so headings read exactly like the window's own.]]
local headingTransparency = 0.6
local iconTransparency = 0.65
local avatarBgTransparency = 0.95
local idleStrokeTransparency = 0.95
local glowTransparency = 0.6

local settleTween = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local hoverTween = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local fallbackUri = "rbxassetid://0"

profilePanel.settleInfo = settleTween

local buildGeneration = 0

local avatarGenerations = setmetatable({}, { __mode = "k" })
local avatarReady = setmetatable({}, { __mode = "k" })
local gameThumbnailGenerations = setmetatable({}, { __mode = "k" })

local edgeMargin = 8

-- [[Effective card height: derived from the current window height so the]]
-- [[card never exceeds the window. At the default 420px window height the]]
-- [[card is exactly 420px; at other responsive sizes it matches the window.]]
function profilePanel.effectiveHeight(window): number
    if not window or not window.size then
        return 420
    end
    local windowH = window.size.Y.Offset
    if type(windowH) ~= "number" or windowH <= 0 then
        return 420
    end
    return windowH
end

local function currentCardHeight(window): number
    return profilePanel.effectiveHeight(window)
end

local function hasRoom(window): boolean
    local camera = state.workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if not viewport then
        return true
    end
    if viewport.X < window.size.X.Offset + profilePanel.gap + profilePanel.width + edgeMargin * 2 then
        return false
    end
    local cardH = currentCardHeight(window)
    return viewport.Y >= cardH + edgeMargin * 2
end

-- [[The panel is "enabled" when its content should exist at all: the user]]
-- [[toggled it on, the player is known, and the screen has room. Window]]
-- [[visibility (hidden/minimised) layers on top in setShown.]]
function profilePanel.isEnabled(window): boolean
    return window.settings.showProfile
        and state.localPlayer ~= nil
        and hasRoom(window)
end

-- [[How far the window rests off the screen centre so that the]]
-- [[window + gap + panel pair is centred (0 while the panel is off).]]
function profilePanel.shiftFor(window): number
    if not profilePanel.isEnabled(window) then
        return 0
    end
    return (profilePanel.width + profilePanel.gap) / 2
end

-- [[Is the card on screen right now? `isEnabled` answers "should its]]
-- [[content exist" (setting + player + room); this adds the window's own]]
-- [[visibility, which is what the on-screen clamp cares about — a]]
-- [[minimised capsule must not be shoved around by a card that is not]]
-- [[there.]]
function profilePanel.isShown(window): boolean
    local panel = window.profilePanel
    return panel ~= nil and panel.Visible == true
end

-- [[Half-extents of the window + card pair, measured from the window's]]
-- [[centre: how far the pair reaches left, right and up/down. The card]]
-- [[height matches the window height, so vertical half-extent is simply]]
-- [[the window half. Returns the plain window halves while the card is not shown.]]
-- [[`width` / `height` override the window size for callers mid-animation (the drag]]
-- [[path measures the frame, which is smaller while minimised).]]
function profilePanel.pairHalfSize(window, width: number?, height: number?)
    local size = window.size
    local halfW = (width or size.X.Offset) / 2
    local halfH = (height or size.Y.Offset) / 2
    if not profilePanel.isShown(window) then
        return halfW, halfW, halfH
    end
    local extra = profilePanel.width + profilePanel.gap
    local left = (window.settings.profileSide or "right") == "left"
    local cardH = if height then height else currentCardHeight(window)
    local pairHalfH = math.max(halfH, cardH / 2)
    if left then
        return halfW + extra, halfW, pairHalfH
    end
    return halfW, halfW + extra, pairHalfH
end

-- [[The "Reveal profile details" toggle (persisted under the legacy]]
-- [[`showFullUsername` key). Off = every identifying value on the card is]]
-- [[masked; on = display name, username, user ID, place ID, job ID and]]
-- [[license key show in full.]]
function profilePanel.revealEnabled(window): boolean
    return window.settings.showFullUsername == true
end

-- [[The reveal toggle's prerequisite: it unmasks values that live ON the]]
-- [[card, so it is only meaningful while "Show profile" is on. Leaving it]]
-- [[active with the card off would silently unmask identity data the moment]]
-- [[the card came back, so the dependency is enforced rather than implied.]]
function profilePanel.revealAllowed(window): boolean
    return window.settings.showProfile == true
end

-- [[Driver for the "Reveal profile details" toggle. Refuses the on state]]
-- [[while "Show profile" is off: the setting stays off, the card stays]]
-- [[masked, and a notification says what is required first. Returns whether]]
-- [[the requested value was accepted, so the caller can roll its own switch]]
-- [[back to match.]]
function profilePanel.setReveal(window, enabled): boolean
    local want = enabled == true
    if want and not profilePanel.revealAllowed(window) then
        window.settings.showFullUsername = false
        profilePanel.applyIdentity(window)
        profilePanel.applyLive(window)
        window:Notify({
            title = locale.resolve("Show profile is required"),
            content = locale.resolve(
                "Turn on \"Show profile\" first. Profile details can only be revealed while the profile card is visible."
            ),
        })
        return false
    end
    window.settings.showFullUsername = want
    profilePanel.applyIdentity(window)
    profilePanel.applyLive(window)
    return true
end

-- [[Dependency normalisation for settings that arrive from somewhere other]]
-- [[than the toggle: a config saved before the rule existed (or edited by]]
-- [[hand) can carry reveal = on with the card off. Returns true when]]
-- [[something had to be corrected, so callers can resync a switch.]]
function profilePanel.syncReveal(window): boolean
    if window.settings.showFullUsername ~= true or profilePanel.revealAllowed(window) then
        return false
    end
    window.settings.showFullUsername = false
    profilePanel.applyIdentity(window)
    return true
end

-- =========================================================================
-- Formatting helpers
-- =========================================================================

-- [[Write a label's text only when it actually changes: the live refresh runs
-- [[every second, and touching a Text property repaints the tree.]]
local function setText(label, text)
    if label and label.Text ~= text then
        label.Text = text
    end
end

-- [[Compact duration notation: "8s", "47m 12s", "2h 34m", "3d 4h". Used for]]
-- [[the current session; a missing/negative source is the neutral]]
-- [[placeholder, never a zero that would read as real.]]
local function formatDuration(seconds: number?): string
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
        return fallbackValue
    end
    local total = math.floor(seconds)
    local days = math.floor(total / 86400)
    local hours = math.floor(total % 86400 / 3600)
    local minutes = math.floor(total % 3600 / 60)
    local secs = total % 60
    if days > 0 then
        return `{days}d {hours}h`
    end
    if hours > 0 then
        return `{hours}h {minutes}m`
    end
    if minutes > 0 then
        return `{minutes}m {secs}s`
    end
    return `{secs}s`
end

local monthNames = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- [[Civil date from a Unix timestamp without relying on os.date, which some
-- [[executor sandboxes strip (Howard Hinnant's days-from-civil algorithm).]]
local function civilDate(daysSinceEpoch: number): (number, number, number)
    local z = daysSinceEpoch + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp + (if mp < 10 then 3 else -9)
    y += (if m <= 2 then 1 else 0)
    return y, m, d
end

local function formatDate(unixSeconds: number?): string
    if type(unixSeconds) ~= "number" or unixSeconds <= 0 then
        return fallbackValue
    end
    local ok, y, m, d = pcall(function()
        return civilDate(math.floor(unixSeconds / 86400))
    end)
    if not ok or type(y) ~= "number" then
        return fallbackValue
    end
    local month = monthNames[m]
    if not month then
        return fallbackValue
    end
    return `{d} {month} {y}`
end

-- [[Account age in days -> the card's short readable form.]]
local function formatAccountAge(days: number?): string
    if type(days) ~= "number" or days ~= days or days < 0 then
        return fallbackValue
    end
    local total = math.floor(days)
    if total < 1 then
        return "Today"
    end
    if total < 31 then
        return if total == 1 then "1 day" else `{total} days`
    end
    local years = math.floor(total / 365.25)
    if years < 1 then
        local months = math.floor(total / 30.44)
        return if months <= 1 then "1 month" else `{months} months`
    end
    local remainder = math.floor((total - years * 365.25) / 30.44)
    local yearText = if years == 1 then "1 year" else `{years} years`
    if remainder < 1 then
        return yearText
    end
    return `{yearText} {remainder}mo`
end

local function nowSeconds(): number?
    local ok, value = pcall(function()
        return os.time()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

-- =========================================================================
-- Card icons
-- =========================================================================
-- [[Every icon the card draws, written as the lucide name (the library's
-- [[default pack) followed by the names the other packs ship for the same
-- [[idea. A window created with tabler / phosphor / heroicons / feather /
-- [[material therefore draws the card's icons as well, instead of leaving an
-- [[empty square wherever the backend pack does not carry the lucide name —
-- [[which is exactly what the tier pill used to do: its badge is a lucide-only
-- [[name, so FREEMIUM showed a word with no icon beside it and the pill's
-- [[crown vanished the same way on the packs without one.
-- [[The first name the active pack really has wins, and because every list
-- [[starts with the lucide name the default pack keeps the exact icon it had
-- [[before this table existed.]]
local iconAliases = {
    ["id-card"] = {
        "id-card",
        "id-badge",
        "identification-card",
        "identification-badge",
        "identification",
        "credit-card",
        "account_box",
        "user-square",
    },
    ["calendar-days"] = { "calendar-days", "calendar", "date_range", "calendar_month", "calendar-today" },
    hourglass = { "hourglass", "hourglass-empty", "hourglass_empty", "timer", "clock" },
    ["key-round"] = { "key-round", "key", "vpn_key", "keyhole", "lock" },
    ["shield-check"] = { "shield-check", "verified_user", "security", "shield" },
    ["user-round"] = { "user-round", "user", "person", "account_circle", "account-box" },
    ["gamepad-2"] = {
        "gamepad-2",
        "gamepad",
        "device-gamepad-2",
        "device-gamepad",
        "game-controller",
        "sports_esports",
        "cube",
        "globe",
    },
    users = { "users", "users-alt", "user-group", "group", "people", "person" },
    server = { "server", "dns", "database", "storage", "hard-drive", "cloud" },
    activity = { "activity", "pulse", "bolt", "timeline", "show_chart", "history" },
    clock = { "clock", "access_time", "schedule", "timer" },
    -- [[Tier pill: the crown for a paid membership, a badge for a free one.]]
    crown = { "crown", "star", "award", "medal" },
    ["badge-check"] = {
        "badge-check",
        "check-badge",
        "seal-check",
        "verified_user",
        "badge",
        "award",
        "star",
    },
    -- [[Copy actions: the copy glyph and the check it flashes on success.]]
    copy = { "copy", "content_copy", "clipboard", "clipboard-copy", "file_copy", "document-duplicate" },
    check = { "check", "done", "circle-check", "check-circle" },
}

-- [[Resolve one of those names against the window's active pack. The resolver
-- [[hands an unknown name straight back, so the first candidate that comes
-- [[back changed is the one the pack actually ships; the answer is cached per
-- [[window because a window's pack never changes.]]
local function cardIcon(window, name: string): string?
    local cache = window.profileIconCache
    if not cache then
        cache = {}
        window.profileIconCache = cache
    end
    local cached = cache[name]
    if cached ~= nil then
        return cached
    end
    local resolved = nil
    for _, candidate in iconAliases[name] or { name } do
        local value = window:ResolveIcon(candidate)
        if type(value) == "string" and value ~= "" and value ~= candidate then
            resolved = value
            break
        end
    end
    resolved = resolved or window:ResolveIcon(name)
    cache[name] = resolved
    return resolved
end

-- =========================================================================
-- Data sources
-- =========================================================================
-- [[Every value on the card comes from one of these, with a neutral fallback]]
-- [[when the source is unavailable.
--
--   display name / username / user ID  Players.LocalPlayer
--   tier pill                          the host's `tier` from
--                                      Window:SetProfile, else
--                                      LocalPlayer.MembershipType
--                                      (PREMIUM / FREEMIUM)
--   join date / account age            LocalPlayer.AccountAge (days)
--   game name                          Roblox's official two-step API:
--                                      place id -> universe id -> the games
--                                      list's "name" (DataModel.Name until
--                                      the request answers)
--   place ID                           DataModel.PlaceId
--   game thumbnail                     thumbnails.roblox.com (universe id)
--   players                            Players:GetPlayers() / Players.MaxPlayers
--   job ID                             DataModel.JobId
--   session time                       os.clock() since the client loaded
--   key / whitelist                    supplied by the host through
--                                      Window:SetProfile — no built-in store
-- ]]

local function sessionStartedAt(): number?
    local ok, value = pcall(function()
        return os.clock()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local clientSessionStart = sessionStartedAt()

local function sessionSeconds(): number?
    if clientSessionStart == nil then
        return nil
    end
    local now = sessionStartedAt()
    if now == nil then
        return nil
    end
    return math.max(0, now - clientSessionStart)
end

local function getJobId(): string?
    local ok, value = pcall(function()
        return (game :: any).JobId
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function isStudio(): boolean
    local ok, value = pcall(function()
        return state.runService:IsStudio()
    end)
    return ok and value == true
end

local function playerCounts(): (number?, number?)
    local ok, players = pcall(function()
        return services.getService("Players")
    end)
    if not ok or players == nil then
        return nil, nil
    end
    local listOk, list = pcall(function()
        return players:GetPlayers()
    end)
    local maxOk, maxPlayers = pcall(function()
        return players.MaxPlayers
    end)
    local current = if listOk and type(list) == "table" then #list else nil
    local capacity = if maxOk and type(maxPlayers) == "number" and maxPlayers > 0 then maxPlayers else nil
    return current, capacity
end

-- [[MembershipType is the real Roblox source for the premium pill: legacy
-- [[Builders Club tiers count, Free/None do not. When the platform cannot be
-- [[read the pill stays hidden rather than claiming a status.]]
local function isPremium(player): boolean
    if not player then
        return false
    end
    local ok, membership = pcall(function()
        return player.MembershipType
    end)
    if not ok or membership == nil or typeof(membership) ~= "EnumItem" then
        return false
    end
    return membership ~= Enum.MembershipType.None and membership ~= Enum.MembershipType.Free
end

-- =========================================================================
-- Remote data: universe id, game name, game thumbnail
-- =========================================================================

local resolvedGameIcons: { [number]: string? } = {}
local pendingGameIconRequests: { [number]: { (string?) -> () } } = {}
local resolvedUniverseIds: { [number]: number? } = {}
local pendingUniverseRequests: { [number]: { (number?) -> () } } = {}
local resolvedGameNames: { [number]: string? } = {}
local pendingGameNameRequests: { [number]: { (string?) -> () } } = {}

local function toValidNumber(value: any): number?
    if type(value) == "number" and value > 0 then
        return value
    end
    if type(value) == "string" then
        local n = tonumber(value)
        if n and n > 0 then
            return n
        end
    end
    return nil
end

-- [[One shared JSON GET helper over the executor's request function — the
-- [[same `network.getRequestFn()` the rest of Astra uses. Missing request
-- [[function or a failed call hands the callback nil so every caller can fall
-- [[back to the neutral placeholder instead of inventing data.]]
local function requestJson(url: string, callback: (any?) -> ())
    local requestFn = network.getRequestFn()
    if not requestFn then
        callback(nil)
        return
    end
    task.spawn(function()
        local decoded = nil
        local ok, result = pcall(requestFn, {
            Url = url,
            Method = "GET",
        })
        if ok and type(result) == "table" then
            local body = (result :: any).Body
            local success = false
            if type((result :: any).StatusCode) == "number" then
                local code = (result :: any).StatusCode :: number
                success = code >= 200 and code < 300
            elseif type((result :: any).Success) == "boolean" then
                success = (result :: any).Success == true
            else
                success = type(body) == "string" and #body > 0
            end
            if success and type(body) == "string" and #body > 0 then
                local decodeOk, parsed = pcall(function()
                    return state.httpService:JSONDecode(body)
                end)
                if decodeOk then
                    decoded = parsed
                end
            end
        end
        callback(decoded)
    end)
end

local function getUniverseId(): number?
    local ok, result = pcall(function()
        return (game :: any).GameId
    end)
    if ok then
        return toValidNumber(result)
    end
    return nil
end

local function getPlaceId(): number?
    local ok, result = pcall(function()
        return (game :: any).PlaceId
    end)
    if ok then
        return toValidNumber(result)
    end
    return nil
end

local function buildFallbackUrl(placeId: number?): string
    if not placeId then
        return ""
    end
    -- [[Legacy rbxthumb GameIcon fallback: uses PlaceId in this runtime.]]
    return `rbxthumb://type=GameIcon&id={placeId}&w=150&h=150`
end

-- [[Roblox's official thumbnails endpoint expects the *universe* id
-- [[(game.GameId), not the place id. The displayed "Place ID" row still uses
-- [[game.PlaceId; the legacy rbxthumb fallback uses it as well, which is the
-- [[documented convention for that URI.]]
local function fetchOfficialGameIcon(universeId: number, callback: (string?) -> ())
    local cached = resolvedGameIcons[universeId]
    if cached ~= nil then
        callback(if type(cached) == "string" and cached ~= "" then cached else nil)
        return
    end

    local pending = pendingGameIconRequests[universeId]
    if pending then
        table.insert(pending, callback)
        return
    end

    pendingGameIconRequests[universeId] = { callback }

    task.spawn(function()
        local finalImageUrl: string? = nil
        local url = `https://thumbnails.roblox.com/v1/games/icons?universeIds={universeId}&size=512x512&format=Png&isCircular=false`
        requestJson(url, function(parsed)
            if type(parsed) == "table" then
                local data = (parsed :: any).data
                if type(data) == "table" then
                    -- [[Match by targetId; the response order is not guaranteed.]]
                    for _, entry in ipairs(data) do
                        if type(entry) == "table" then
                            local tid = (entry :: any).targetId or (entry :: any).targetID or (entry :: any).id
                            local stateName = (entry :: any).state
                            local matches = tonumber(tid) == universeId
                            if matches and (stateName == "Completed" or stateName == nil) then
                                local img = (entry :: any).imageUrl or (entry :: any).contentUrl or (entry :: any).url
                                if type(img) == "string" and #img > 0 then
                                    finalImageUrl = img
                                    break
                                end
                            end
                        end
                    end
                    -- [[Fallback: first completed entry, still real response data.]]
                    if not finalImageUrl then
                        for _, entry in ipairs(data) do
                            if type(entry) == "table" then
                                local stateName = (entry :: any).state
                                if stateName == "Completed" or stateName == nil then
                                    local img = (entry :: any).imageUrl or (entry :: any).contentUrl
                                    if type(img) == "string" and #img > 0 then
                                        finalImageUrl = img
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if finalImageUrl and #finalImageUrl > 0 then
                resolvedGameIcons[universeId] = finalImageUrl
            end

            local callbacks = pendingGameIconRequests[universeId]
            pendingGameIconRequests[universeId] = nil
            for _, cb in ipairs(callbacks or {}) do
                pcall(cb, finalImageUrl)
            end
        end)
    end)
end

-- [[Step 1 of the official game-name flow: the universes endpoint converts a]]
-- [[place id into the universe that owns it. Cached per place and queued]]
-- [[while a request is in flight, exactly like the icon fetch above.]]
local function fetchUniverseId(placeId: number, callback: (number?) -> ())
    local cached = resolvedUniverseIds[placeId]
    if cached ~= nil then
        callback(cached)
        return
    end

    local pending = pendingUniverseRequests[placeId]
    if pending then
        table.insert(pending, callback)
        return
    end

    pendingUniverseRequests[placeId] = { callback }

    requestJson(`https://apis.roblox.com/universes/v1/places/{placeId}/universe`, function(parsed)
        local universeId: number? = nil
        if type(parsed) == "table" then
            universeId = toValidNumber(
                (parsed :: any).universeId
                    or (parsed :: any).universeID
                    or (parsed :: any).universe_id
                    or (parsed :: any).id
            )
        end
        if universeId then
            resolvedUniverseIds[placeId] = universeId
        end
        local callbacks = pendingUniverseRequests[placeId]
        pendingUniverseRequests[placeId] = nil
        for _, cb in ipairs(callbacks or {}) do
            pcall(cb, universeId)
        end
    end)
end

-- [[The universe id the thumbnail and the name flow need: DataModel.GameId]]
-- [[when the runtime supplies one, otherwise the official place -> universe]]
-- [[lookup (step 1).]]
local function resolveUniverseId(callback: (number?) -> ())
    local direct = getUniverseId()
    if direct then
        callback(direct)
        return
    end
    local placeId = getPlaceId()
    if placeId then
        fetchUniverseId(placeId, callback)
    else
        callback(nil)
    end
end

-- [[Step 2 of the official game-name flow: the games endpoint answers the]]
-- [[game's detail list for a universe, and the matching entry's "name" field]]
-- [[IS the game name (DataModel.Name only carries the current place's title,]]
-- [[which is why the card asks the platform instead). The DataModel name]]
-- [[stays on the label until this answers, so the row is never empty.]]
local function fetchGameName(placeId: number, callback: (string?) -> ())
    local cached = resolvedGameNames[placeId]
    if cached ~= nil then
        callback(if type(cached) == "string" and cached ~= "" then cached else nil)
        return
    end

    local pending = pendingGameNameRequests[placeId]
    if pending then
        table.insert(pending, callback)
        return
    end

    pendingGameNameRequests[placeId] = { callback }

    local function finish(name: string?)
        if type(name) == "string" and name ~= "" then
            resolvedGameNames[placeId] = name
        end
        local callbacks = pendingGameNameRequests[placeId]
        pendingGameNameRequests[placeId] = nil
        for _, cb in ipairs(callbacks or {}) do
            pcall(cb, name)
        end
    end

    fetchUniverseId(placeId, function(universeId: number?)
        if not universeId then
            finish(nil)
            return
        end
        requestJson(`https://games.roblox.com/v1/games?universeIds={universeId}`, function(parsed)
            local name: string? = nil
            if type(parsed) == "table" then
                local data = (parsed :: any).data
                if type(data) == "table" then
                    -- [[Match by the universe id when the entry carries one;]]
                    -- [[the response order is not guaranteed.]]
                    for _, entry in ipairs(data) do
                        if type(entry) == "table" then
                            local entryId = tonumber((entry :: any).id or (entry :: any).universeId)
                            local entryName = (entry :: any).name
                            if
                                type(entryName) == "string"
                                and #entryName > 0
                                and (entryId == nil or entryId == universeId)
                            then
                                name = entryName
                                break
                            end
                        end
                    end
                end
            end
            finish(name)
        end)
    end)
end

-- =========================================================================
-- Card writers
-- =========================================================================

local function licenseDaysLeft(data, now: number?): number?
    local whitelist = data.whitelist
    if not whitelist then
        return nil
    end
    if type(whitelist.daysLeft) == "number" then
        return whitelist.daysLeft
    end
    if type(whitelist.expiresAt) == "number" and now then
        return math.ceil((whitelist.expiresAt - now) / 86400)
    end
    return nil
end

-- [[License + whitelist rows. Astra ships no key store of its own, so these
-- [[come from what the host handed to Window:SetProfile; with nothing supplied
-- [[the rows read "—" rather than showing a made-up key.]]
function profilePanel.applyLicense(window)
    local data = window.profileData or {}
    local reveal = profilePanel.revealEnabled(window)

    local key = data.key
    setText(window.profileKeyValue, if type(key) == "string" and key ~= ""
        then (if reveal then key else maskedKey)
        else fallbackValue)

    local days = licenseDaysLeft(data, nowSeconds())
    local status = if data.whitelist and type(data.whitelist.status) == "string" then data.whitelist.status else nil
    -- [[Compact, reference-shaped value: a countdown when one is known, the
    -- [[word "Expired" once it lapses, the host's own word when there is no
    -- [[expiry to count, and the neutral placeholder when there is neither.
    -- [[An unusual status ("Trial") is still spelled out, since dropping it
    -- [[would hide real information.]]
    local whitelistText
    if days == nil then
        whitelistText = status or fallbackValue
    elseif days < 0 then
        whitelistText = "Expired"
    else
        local dayText = if days == 1 then "1 day left" else `{days} days left`
        whitelistText = if status and string.lower(status) ~= "active" then `{status} · {dayText}` else dayText
    end
    setText(window.profileWhitelistValue, whitelistText)
end

-- [[The tier word the header pill shows. A host-supplied `tier` (through]]
-- [[Window:SetProfile) wins — uppercased, so "premium" and "PREMIUM" read the]]
-- [[same; without one the platform's own membership decides between PREMIUM]]
-- [[and FREEMIUM. The pill therefore always states a real tier instead of]]
-- [[vanishing for free accounts.]]
function profilePanel.tierText(window): string
    local data = window.profileData or {}
    local custom = data.tier
    if type(custom) == "string" and custom ~= "" then
        return string.upper(custom)
    end
    return if isPremium(state.localPlayer) then "PREMIUM" else "FREEMIUM"
end

-- [[Write the tier pill: word, icon, colour and width. PREMIUM keeps the]]
-- [[accent crown; every other tier reads in the muted placeholder colour]]
-- [[with a plain badge icon, so a free account is labelled, not decorated.]]
function profilePanel.applyTier(window)
    local badge = window.profilePremium
    local label = window.profileTierLabel
    local icon = window.profileTierIcon
    if not (badge and label and icon) then
        return
    end
    local text = profilePanel.tierText(window)
    setText(label, text)
    local premium = text == "PREMIUM"
    local color = if premium then window.theme.AccentColor else window.theme.PlaceholderColor
    if label.TextColor3 ~= color then
        label.TextColor3 = color
    end
    if icon.ImageColor3 ~= color then
        icon.ImageColor3 = color
    end
    -- [[Both tier states get an icon the active pack really ships: the pill
    -- [[states a tier, so it must never render as a word with a blank square
    -- [[beside it.]]
    local wantedIcon = cardIcon(window, if premium then "crown" else "badge-check")
    if icon.Image ~= wantedIcon then
        icon.Image = wantedIcon
    end
    -- [[A fixed box measured from its own label, so the pill only ever grows]]
    -- [[as wide as its word needs.]]
    local textWidth = functions.textWidth(window.theme.Font, label.TextSize, text)
    local width = tierPaddingLeft + tierIconSize + tierGap + textWidth + tierPaddingRight
    badge.Size = UDim2.fromOffset(width, tierHeight)
    label.Size = UDim2.fromOffset(textWidth, tierHeight)
    profilePanel.layoutPremium(window)
end

-- [[The executor's clipboard entry point. `setclipboard` is the common name;]]
-- [[the other spellings (and a Clipboard table) cover the remaining]]
-- [[executors. A missing or failing function means "copied nowhere", so the]]
-- [[icon gives no false success feedback.]]
local function getClipboardFn(): ((string) -> ())?
    local env = getfenv()
    for _, candidate in ipairs({ "setclipboard", "set_clipboard", "toclipboard", "to_clipboard" }) do
        local fn = env[candidate]
        if type(fn) == "function" then
            return fn
        end
    end
    local clipboard = env.Clipboard
    if type(clipboard) == "table" and type(clipboard.set) == "function" then
        return function(text: string)
            clipboard.set(clipboard, text)
        end
    end
    return nil
end

local function clipboardSet(text: string): boolean
    local fn = getClipboardFn()
    if not fn then
        return false
    end
    local ok = pcall(fn, text)
    return ok
end

-- [[Drop a scheduled timeout that is still waiting. Executors without
-- [[`task.cancel` (and the offline test harness) simply skip this: the stamp
-- [[check below already makes a superseded timer a no-op, so the cancel is
-- [[belt-and-braces rather than the thing correctness rests on.]]
local function cancelTimer(thread)
    if type(thread) ~= "thread" or type(task.cancel) ~= "function" then
        return
    end
    if coroutine.status(thread) == "suspended" then
        task.cancel(thread)
    end
end

-- [[The words a copy button owns: what it will copy while idle ("Copy Job
-- [[ID"), or the confirmation after a successful press ("Copied"). The button
-- [[is glyph-only, so the line is never drawn: it is the button's accessible
-- [[label, and the hover tooltip shows the very same string (read back off the
-- [[button), so the two can never disagree. It is written through the window's
-- [[own locale binding, so a host translating "Copy Place ID" / "Copied" gets
-- [[both, and Window:SetLocale re-states whichever wording is on screen.]]
function profilePanel.setCopyStatus(window, name: string, copied: boolean)
    local entry = (window.profileCopyButtons or {})[name]
    if not entry then
        return
    end
    -- [[The binding stores the *source* wording ("Copy Job ID", "Copied"), so
    -- [[a locale switch re-resolves the current state instead of freezing the
    -- [[old language into it; _bindLocale writes the resolved text for us.]]
    local source = if copied then copiedLabel else copyLabelPrefix .. (entry.label or name)
    if entry.button and entry.button.Parent and entry.button.Text ~= locale.resolve(source) then
        window:_bindLocale(entry.button, "Text", source)
        if entry.hovering then
            profilePanel.showTooltip(window, entry.button.Text, entry.tooltipY or 0)
        end
    end
end

-- [[Copy feedback: the row's copy icon turns into a green check for a moment]]
-- [[and then the copy icon returns, with the button's status word following]]
-- [[("Copied" while the check is up, the action's own name after it). Only one
-- [[restore is ever outstanding per button: a repeat click cancels the pending
-- [[timer and restarts the window, and a rebuilt card (stale entry) is simply
-- [[ignored by the timer.]]
function profilePanel.flashCopied(window, name: string)
    local entry = (window.profileCopyButtons or {})[name]
    if not entry or not entry.icon or not entry.icon.Parent then
        return
    end
    entry.icon.Image = cardIcon(window, "check")
    entry.icon.ImageColor3 = window.theme.Success
    cancelTimer(entry.flashThread)
    entry.flashStamp = (entry.flashStamp or 0) + 1
    local stamp = entry.flashStamp
    entry.flashThread = task.delay(copyFlashDuration, function()
        if entry.flashStamp ~= stamp or not entry.icon or not entry.icon.Parent then
            return
        end
        entry.flashThread = nil
        entry.icon.Image = cardIcon(window, "copy")
        entry.icon.ImageColor3 = window.theme.ActionColor
        profilePanel.setCopyStatus(window, name, false)
    end)
    profilePanel.setCopyStatus(window, name, true)
end

-- [[Tier pill placement. The reference keeps the pill on the handle row, so
-- [[it rides just after the subtitle text; it only drops under the headline
-- [[when there is no subtitle, or when the pair would not fit before the
-- [[card's right edge. Re-run whenever the headline, subtitle or tier text
-- [[changes (the pill's width is measured from its own label).]]
function profilePanel.layoutPremium(window)
    local badge = window.profilePremium
    local subtitle = window.profileSubtitle
    if not badge or not subtitle then
        return
    end
    local width = badge.Size.X.Offset
    if width <= 0 then
        return
    end
    local nameX = paddingX + avatarSize + 10
    local limit = profilePanel.width - paddingX - 8
    local belowY = 49
    local function inlineAfter(instance, y)
        local text = instance.Text
        local measured = if text == "" then 0 else functions.textWidth(window.theme.Font, instance.TextSize, text)
        local x = nameX + measured + 8
        if measured <= instance.Size.X.Offset and x + width <= limit then
            badge.Position = UDim2.fromOffset(x, y)
            return true
        end
        return false
    end
    if subtitle.Visible and subtitle.Text ~= "" then
        if inlineAfter(subtitle, subtitle.Position.Y.Offset - 0.5) then
            return
        end
        badge.Position = UDim2.fromOffset(nameX, belowY)
        return
    end
    if not inlineAfter(window.profileName, 13) then
        badge.Position = UDim2.fromOffset(nameX, belowY)
    end
end

-- [[Write every identity field on the card from the current player and the]]
-- [[reveal toggle: display name, @username, premium pill, user ID (with its]]
-- [[COPY action), place ID, job ID and the license rows. nil-safe on both]]
-- [[the instances and the player, so a missing player leaves placeholders]]
-- [[rather than erroring.]]
function profilePanel.applyIdentity(window)
    local player = state.localPlayer
    local reveal = profilePanel.revealEnabled(window)
    local data = window.profileData or {}

    local username = ""
    local displayName = ""
    if player then
        username = tostring(player.Name or "")
        displayName = tostring(player.DisplayName or "")
        if displayName == "" then
            displayName = username
        end
    end

    local name = window.profileName
    if name then
        setText(
            name,
            if displayName == "" then ""
                elseif reveal then displayName
                else sidebar.maskUsername(displayName)
        )
    end

    local subtitle = window.profileSubtitle
    if subtitle then
        -- [[An explicit Window:SetProfile subtitle wins over the generated
        -- [[@username: it is the developer's own copy, not identity data, so
        -- [[the reveal toggle leaves it untouched.]]
        local custom = if type(data.subtitle) == "string" and data.subtitle ~= "" then data.subtitle else nil
        local text = if custom then locale.resolve(custom) else nil
        if text == nil and username ~= "" then
            text = "@" .. (if reveal then username else sidebar.maskUsername(username))
        end
        setText(subtitle, text or "")
        subtitle.Visible = subtitle.Text ~= ""
    end
    profilePanel.applyTier(window)

    local userId = window.profileUserIdValue
    if userId then
        local id = if player and player.UserId then tostring(player.UserId) else ""
        setText(userId, if id == "" then fallbackValue elseif reveal then id else maskedId)
    end

    -- [[Copy actions ride only on values the reveal toggle unmasks: with the]]
    -- [[detail masked there is nothing meaningful to copy, so the buttons]]
    -- [[hide with it.]]
    for name, entry in pairs(window.profileCopyButtons or {}) do
        local shown = false
        if reveal then
            if name == "UserId" then
                shown = player ~= nil
            elseif name == "PlaceId" then
                shown = getPlaceId() ~= nil
            elseif name == "ServerId" then
                shown = getJobId() ~= nil and not isStudio()
            elseif name == "Key" then
                local key = (window.profileData or {}).key
                shown = type(key) == "string" and key ~= ""
            end
        end
        if entry.button then
            entry.button.Visible = shown
        end
    end

    local placeId = window.profilePlaceId
    if placeId then
        local id = getPlaceId()
        setText(placeId, if not id then fallbackValue elseif reveal then tostring(id) else maskedId)
    end

    local serverId = window.profileServerIdValue
    if serverId then
        local jobId = getJobId()
        if not jobId then
            -- [[Studio / local test servers have no JobId: say so instead of
            -- [[showing a stale or invented server.]]
            setText(serverId, if isStudio() then "Studio" else fallbackValue)
        else
            setText(serverId, if reveal then jobId else maskedId)
        end
    end

    if window.profileJoinDateValue then
        local accountAge = if player and type(player.AccountAge) == "number" then player.AccountAge else nil
        local now = nowSeconds()
        setText(
            window.profileJoinDateValue,
            if accountAge and now then formatDate(now - accountAge * 86400) else fallbackValue
        )
        setText(window.profileAccountAgeValue, formatAccountAge(accountAge))
    end

    profilePanel.applyLicense(window)
end

-- [[Live values: player count and the current session. Called by the refresh
-- [[loop, by reveal changes and whenever the card comes back.]]
function profilePanel.applyLive(window)
    if window.unloaded or not window.profileDetails then
        return
    end

    local current, capacity = playerCounts()
    setText(
        window.profilePlayersValue,
        if current ~= nil and capacity ~= nil then `{current} / {capacity}` else fallbackValue
    )

    setText(window.profileSessionValue, formatDuration(sessionSeconds()))

    -- [[A whitelist entry that expires at a timestamp counts down here too.]]
    profilePanel.applyLicense(window)
end

-- =========================================================================
-- Card construction
-- =========================================================================

local function sectionHeight(rowCount: number): number
    if rowCount <= 0 then
        return cardPaddingY * 2
    end
    return cardPaddingY * 2 + rowCount * rowHeight + (rowCount - 1) * rowGap
end

local function addRow(window, card, spec)
    local fade = function(instance, prop, shown)
        table.insert(window.profileFadeTargets, { instance = instance, prop = prop, shown = shown })
    end

    local y = spec.y
    local x = spec.x or cardPaddingX
    local textX = x
    local rowLabelWidth = spec.labelWidth or labelWidth
    -- [[Row icons follow the window's element icons: ContentColor, revealed]]
    -- [[to the section icon's transparency so a compact row reads like a]]
    -- [[small element line.]]
    if spec.icon then
        local icon = window:Create("ImageLabel", {
            Name = spec.name .. "Icon",
            Image = cardIcon(window, spec.icon),
            Position = UDim2.fromOffset(x, y + (rowHeight - rowIconSize) / 2),
            Size = UDim2.fromOffset(rowIconSize, rowIconSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ImageTransparency = 1,
            Parent = card,
        }, { ImageColor3 = spec.iconColor or "ContentColor" })
        fade(icon, "ImageTransparency", iconTransparency)
        textX = x + rowIconSize + 5
    end

    local label = window:Create("TextLabel", {
        Name = spec.name .. "Label",
        Text = spec.label,
        Position = UDim2.fromOffset(textX, y),
        Size = UDim2.fromOffset(rowLabelWidth, rowHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        Parent = card,
    }, { TextColor3 = spec.labelColor or "ContentColor", FontFace = "Font" })
    fade(label, "TextTransparency", labelTransparency)

    local inset = if spec.action then actionInset else 0
    local value = window:Create("TextLabel", {
        Name = spec.instanceName or (spec.name .. "Value"),
        Text = fallbackValue,
        Position = UDim2.fromOffset(textX + rowLabelWidth, y),
        Size = UDim2.new(1, -(textX + rowLabelWidth + cardPaddingX + inset), 0, rowHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = spec.valueSize or 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        Parent = card,
    }, { TextColor3 = spec.valueColor or "ContentColor", FontFace = "Font" })
    fade(value, "TextTransparency", nameTransparency)

    if spec.action == "copy" then
        local button = window:Create("TextButton", {
            Name = "Copy" .. spec.name,
            -- [[The button is glyph-only: its Text is never drawn (the
            -- [[transparency above stays 1) and carries the button's own
            -- [[accessible label instead — "Copy Job ID" while idle, "Copied"
            -- [[after a successful press. setCopyStatus keeps it in step with
            -- [[the tooltip.
            Text = "",
            Position = UDim2.new(1, -(cardPaddingX + actionSize), 0, y + (rowHeight - actionSize) / 2),
            Size = UDim2.fromOffset(actionSize, actionSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            TextTransparency = 1,
            Visible = false,
            Parent = card,
        })
        local iconLabel = window:Create("ImageLabel", {
            Name = "Icon",
            Image = cardIcon(window, "copy"),
            Size = UDim2.fromOffset(13, 13),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            Parent = button,
        }, { ImageColor3 = "ActionColor" })
        fade(iconLabel, "ImageTransparency", 0.15)
        window.profileCopyButtons = window.profileCopyButtons or {}
        window.profileCopyButtons[spec.name] = {
            button = button,
            icon = iconLabel,
            -- [[What this press copies, for the label and the tooltip.]]
            label = spec.label,
            tooltipY = (spec.cardY or 0) + y,
        }
        profilePanel.setCopyStatus(window, spec.name, false)
        if spec.name == "UserId" then
            -- [[Legacy handle, kept so hosts and tests that grabbed the]]
            -- [[user ID's copy button still find it.]]
            window.profileCopyUserId = button
        end
        -- [[Hover help, on the same surface the rows use: the button says what
        -- [[it will copy, and swaps to "Copied" for as long as the green check
        -- [[is up (setCopyStatus refreshes the tooltip while it is hovered).]]
        window:Connect(button.MouseEnter, function()
            local entry = (window.profileCopyButtons or {})[spec.name]
            if not entry then
                return
            end
            entry.hovering = true
            profilePanel.showTooltip(window, entry.button.Text or "", entry.tooltipY or 0)
        end)
        window:Connect(button.MouseLeave, function()
            local entry = (window.profileCopyButtons or {})[spec.name]
            if entry then
                entry.hovering = false
            end
            profilePanel.hideTooltip(window)
        end)
        window:Connect(button.Activated, function()
            -- [[The action only exists while the value is revealed: with the]]
            -- [[detail hidden there is nothing meaningful to copy, and the]]
            -- [[button is hidden too (applyIdentity). A successful copy runs]]
            -- [[through the executor's clipboard and flashes the green check.]]
            if not profilePanel.revealEnabled(window) then
                return
            end
            local text = if spec.copy then spec.copy() else nil
            if type(text) ~= "string" or text == "" then
                return
            end
            if clipboardSet(text) then
                profilePanel.flashCopied(window, spec.name)
            end
        end)
    end

    -- [[Hover-help for values that do not fit: the row's full text is shown in
    -- [[a small themed tooltip above (or below) the row.]]
    local tooltipY = (spec.cardY or 0) + y
    window:Connect(value.MouseEnter, function()
        local text = value.Text
        if text == "" or text == fallbackValue then
            return
        end
        local available = value.AbsoluteSize.X
        local measured = functions.textWidth(window.theme.Font, value.TextSize, text)
        if available <= 0 or measured <= available then
            return
        end
        profilePanel.showTooltip(window, text, tooltipY)
    end)
    window:Connect(value.MouseLeave, function()
        profilePanel.hideTooltip(window)
    end)

    return value
end

-- [[Position and reveal the hover tooltip. It lives on the card surface (not
-- [[inside the scroll region) so it is never clipped by the scrolling area;
-- [[`detailsY` is the row's offset from the top of the card's content.]]
function profilePanel.showTooltip(window, text, contentY: number)
    local tip = window.profileTooltip
    if not tip or not window.profileTooltipLabel then
        return
    end
    local details = window.profileDetails
    local scrollY = 0
    if details then
        local ok, canvasPosition = pcall(function()
            return details.CanvasPosition
        end)
        if ok and canvasPosition and typeof(canvasPosition) ~= "number" then
            scrollY = canvasPosition.Y or 0
        end
    end
    local cardH = currentCardHeight(window)
    local y = headerHeight + dividerHeight + (contentY - scrollY) - tooltipHeight - 6
    y = math.clamp(y, 4, math.max(4, cardH - tooltipHeight - 4))
    setText(window.profileTooltipLabel, text)
    tip.Position = UDim2.fromOffset(paddingX + cardPaddingX, y)
    tip.Visible = true
    state.tweenService:Create(tip, hoverTween, { BackgroundTransparency = 0 }):Play()
    state.tweenService:Create(window.profileTooltipLabel, hoverTween, { TextTransparency = 0 }):Play()
end

function profilePanel.hideTooltip(window)
    local tip = window.profileTooltip
    if not tip or not tip.Visible then
        return
    end
    state.tweenService:Create(tip, hoverTween, { BackgroundTransparency = 1 }):Play()
    if window.profileTooltipLabel then
        state.tweenService:Create(window.profileTooltipLabel, hoverTween, { TextTransparency = 1 }):Play()
    end
    task.delay(hoverTween.Time, function()
        if tip.Parent and tip.BackgroundTransparency >= 1 then
            tip.Visible = false
        end
    end)
end

function profilePanel.build(window)
    if window.profilePanel then
        window:DestroySubtree(window.profilePanel)
        window.profilePanel = nil
    end

    local player = state.localPlayer
    local cardHeight = currentCardHeight(window)
    profilePanel.height = cardHeight
    window.profileFadeTargets = {}

    window.profilePanel = window:Create("Frame", {
        Name = "ProfilePanel",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(profilePanel.width, cardHeight),
        BackgroundTransparency = 1,
        ZIndex = 1,
        Visible = false,

        Parent = window.screenGui,
    })

    -- [[The card surface: the window's own background, not a lookalike. It is
    -- [[built by Window:StyleWindowSurface — the very call that builds the
    -- [[window frame's background — so the card takes the same base colour, the
    -- [[same WindowColor theme token, the same gradient rotation/offset and the
    -- [[same opacity the window shows, and a theme change moves both together
    -- [[(both gradients are registered theme bindings). The card is centred on
    -- [[the window's own height, so the shared gradient also lands on the same
    -- [[shade at the same screen row: the two read as one surface, never as a
    -- [[panel that is nearly the window's colour.]]
    window.profilePanelSurface = window:Create("Frame", {
        Name = "Surface",
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundTransparency = window:WindowSurfaceTransparency(),
        Parent = window.profilePanel,
    })

    -- [[Kept on the window so the window's live gradient animation can carry
    -- [[the card with it (see Window:_syncLiveAnimation). A card rebuilt in the
    -- [[middle of that animation starts from the window's current gradient
    -- [[state rather than from the resting one, so a rebuild cannot leave the
    -- [[pair mismatched until the next cycle.]]
    window.profilePanelGradient = window:StyleWindowSurface(window.profilePanelSurface)
    local liveGradient = window.windowGradient
    if liveGradient then
        window.profilePanelGradient.Rotation = liveGradient.Rotation
        window.profilePanelGradient.Offset = liveGradient.Offset
    end

    window.profilePanelCorner = window:Create("UICorner", {
        Parent = window.profilePanelSurface,
    }, { CornerRadius = "CornerRoundness" })

    window.profilePanelStroke = window:Create("UIStroke", {
        Transparency = 1,
        Parent = window.profilePanelSurface,
    }, { Color = "SurfaceStroke" })

    window.profilePanelGlow = window:CreateGlow(window.profilePanelSurface, "ShadowColor", 20, 1)

    -- [[Everything the card fades in/out as a unit registers here once: the
    -- [[panel show/hide pass then just walks the list.]]
    local function fade(instance, prop, shown)
        table.insert(window.profileFadeTargets, { instance = instance, prop = prop, shown = shown })
    end

    -- ===== header: avatar + presence, name / username / premium, gear =====

    window.profileAvatar = window:Create("ImageLabel", {
        Name = "Avatar",
        Position = UDim2.fromOffset(paddingX, avatarTop),
        Size = UDim2.fromOffset(avatarSize, avatarSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Parent = window.profilePanelSurface,
    }, { BackgroundColor3 = "ContentColor" })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = window.profileAvatar,
    })
    window:Create("UIStroke", {
        Thickness = 1,
        Transparency = 0.4,
        Parent = window.profileAvatar,
    }, { Color = "SurfaceStroke" })

    local onlineDot = window:Create("Frame", {
        Name = "Online",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromOffset(paddingX + avatarSize, avatarTop + avatarSize),
        Size = UDim2.fromOffset(12, 12),
        BorderSizePixel = 0,
        Parent = window.profilePanelSurface,
    }, { BackgroundColor3 = "Success" })
    window:Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = onlineDot })
    window:Create("UIStroke", {
        Thickness = 2,
        Transparency = 0,
        Parent = onlineDot,
    }, { Color = "Background" })

    local nameX = paddingX + avatarSize + 10
    -- [[No gear occupies the header's right edge any more, so the handle]]
    -- [[text may run to the card's own padding.]]
    local nameWidth = profilePanel.width - nameX - paddingX

    -- [[The headline/subtitle are filled by applyIdentity at the end of the
    -- [[build, so the card never flashes an unmasked display name first.]]
    window.profileName = window:Create("TextLabel", {
        Name = "Name",
        Text = "",
        Position = UDim2.fromOffset(nameX, 12),
        Size = UDim2.fromOffset(nameWidth, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        Parent = window.profilePanelSurface,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    fade(window.profileName, "TextTransparency", nameTransparency)

    window.profileSubtitle = window:Create("TextLabel", {
        Name = "Subtitle",
        Text = "",
        Position = UDim2.fromOffset(nameX, 31),
        Size = UDim2.fromOffset(nameWidth, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = false,
        TextTransparency = 1,
        Parent = window.profilePanelSurface,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    fade(window.profileSubtitle, "TextTransparency", subtitleTransparency)

    -- [[Tier pill: always present, because a tier always exists — the host's]]
    -- [[own word from Window:SetProfile, else PREMIUM / FREEMIUM from the]]
    -- [[platform membership (applyTier writes word, icon, colour and width).]]
    -- [[The pill width is measured from its own label, so it only ever grows]]
    -- [[as wide as its word needs.]]
    local premium = window:Create("Frame", {
        Name = "TierBadge",
        Position = UDim2.fromOffset(nameX, 49),
        Size = UDim2.fromOffset(tierPaddingLeft + tierIconSize + tierGap + tierPaddingRight, tierHeight),
        BorderSizePixel = 0,
        Visible = true,
        Parent = window.profilePanelSurface,
    }, { BackgroundColor3 = "ElementSurface", BackgroundTransparency = "ElementTransparency" })
    window.profilePremium = premium
    window:Create("UICorner", {
        Parent = premium,
    }, { CornerRadius = "PillCornerRadius" })
    window:Create("UIStroke", {
        Transparency = 0.35,
        Parent = premium,
    }, { Color = "ElementStroke" })
    local premiumIcon = window:Create("ImageLabel", {
        Name = "Crown",
        Image = window:ResolveIcon("crown"),
        Position = UDim2.fromOffset(tierPaddingLeft, (tierHeight - tierIconSize) / 2),
        Size = UDim2.fromOffset(tierIconSize, tierIconSize),
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Parent = premium,
    }, { ImageColor3 = "AccentColor" })
    local premiumLabel = window:Create("TextLabel", {
        Name = "Label",
        Text = "",
        Position = UDim2.fromOffset(tierPaddingLeft + tierIconSize + tierGap, 0),
        Size = UDim2.fromOffset(0, tierHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        Parent = premium,
    }, { TextColor3 = "AccentColor", FontFace = "Font" })
    window.profileTierIcon = premiumIcon
    window.profileTierLabel = premiumLabel
    fade(premiumIcon, "ImageTransparency", 0)
    fade(premium, "BackgroundTransparency", 0)
    fade(premiumLabel, "TextTransparency", 0)

    -- [[Header hover-help for a truncated display name.]]
    window:Connect(window.profileName.MouseEnter, function()
        local text = window.profileName.Text
        if text == "" then
            return
        end
        local available = window.profileName.AbsoluteSize.X
        if available <= 0 or functions.textWidth(window.theme.Font, window.profileName.TextSize, text) <= available then
            return
        end
        profilePanel.showTooltip(window, text, 12)
    end)
    window:Connect(window.profileName.MouseLeave, function()
        profilePanel.hideTooltip(window)
    end)

    -- [[Divider under the pinned header.]]
    window.profileDivider = window:Create("Frame", {
        Name = "Divider",
        Position = UDim2.fromOffset(paddingX, headerHeight),
        Size = UDim2.new(1, -paddingX * 2, 0, dividerHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = window.profilePanelSurface,
    }, { BackgroundColor3 = "ElementStroke" })
    table.insert(window.profileFadeTargets, {
        instance = window.profileDivider,
        prop = "BackgroundTransparency",
        shown = 0.5,
    })

    local function label(parent, name, text, position, size, textSize, color, align, transparency)
        local instance = window:Create("TextLabel", {
            Name = name,
            Text = text,
            Position = position,
            Size = size,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            TextSize = textSize,
            TextXAlignment = align or Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 1,
            Parent = parent,
        }, { TextColor3 = color, FontFace = "Font" })
        fade(instance, "TextTransparency", transparency or nameTransparency)
        return instance
    end

    -- ===== scrollable details =====

    window.profileDetails = window:Create("ScrollingFrame", {
        Name = "Details",
        Position = UDim2.fromOffset(0, headerHeight + dividerHeight),
        Size = UDim2.new(1, 0, 1, -(headerHeight + dividerHeight)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
        ScrollBarImageTransparency = scrollBarTransparency,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Parent = window.profilePanelSurface,
    })

    local content = window:Create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(0, scrollPaddingTop),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = window.profileDetails,
    })
    window.profileDetailsContent = content

    -- [[Section heading: the window's Section element, verbatim — a 16px]]
    -- [[ContentColor icon beside a 15px ContentColor title at the section's]]
    -- [[own transparencies, so the card titles its groups exactly the way]]
    -- [[the window titles its tabs' sections.]]
    local function heading(y: number, title: string, iconName: string): number
        local icon = window:Create("ImageLabel", {
            Name = title .. "Icon",
            Image = cardIcon(window, iconName),
            Position = UDim2.fromOffset(paddingX, y + (headingHeight - headingIconSize) / 2),
            Size = UDim2.fromOffset(headingIconSize, headingIconSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ImageTransparency = 1,
            Parent = content,
        }, { ImageColor3 = "ContentColor" })
        fade(icon, "ImageTransparency", iconTransparency)

        label(
            content,
            title,
            title,
            UDim2.fromOffset(paddingX + headingIconSize + headingIconGap, y),
            UDim2.new(1, -(paddingX * 2 + headingIconSize + headingIconGap), 0, headingHeight),
            15,
            "ContentColor",
            Enum.TextXAlignment.Left,
            headingTransparency
        )
        return y + headingHeight + headingGap
    end

    -- [[A section's plate: Window:StyleElementBody, verbatim — the element]]
    -- [[gradient over a white body at ElementTransparency, the element]]
    -- [[corner, and the element stroke at the theme's own transparency, so]]
    -- [[every container on the card IS one of the window's element bodies.]]
    local function card(y: number, name: string, height: number)
        local frame = window:Create("Frame", {
            Name = name,
            Position = UDim2.fromOffset(paddingX, y),
            Size = UDim2.new(1, -paddingX * 2, 0, height),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            Parent = content,
        }, { BackgroundTransparency = "ElementTransparency" })
        local stroke = window:StyleElementBody(frame)
        fade(frame, "BackgroundTransparency", 0)
        fade(stroke, "Transparency", window.theme.ElementStrokeTransparency or 0)
        return frame
    end

    local y = 0

    -- ===== ACCOUNT =====

    local accountRows = {
        {
            name = "UserId",
            label = "User ID",
            icon = "id-card",
            action = "copy",
            copy = function()
                local current = state.localPlayer
                return if current and current.UserId then tostring(current.UserId) else nil
            end,
        },
        { name = "JoinDate", label = "Join date", icon = "calendar-days" },
        { name = "AccountAge", label = "Account age", icon = "hourglass" },
        {
            name = "Key",
            label = "Key",
            icon = "key-round",
            labelWidth = 62,
            valueSize = 12,
            action = "copy",
            copy = function()
                local key = (window.profileData or {}).key
                return if type(key) == "string" and key ~= "" then key else nil
            end,
        },
        { name = "Whitelist", label = "Whitelist", icon = "shield-check", labelWidth = 62, valueSize = 12 },
    }

    y = heading(y, "Account", "user-round")
    local accountCardY = y
    local accountCard = card(y, "AccountCard", sectionHeight(#accountRows))
    for index, row in ipairs(accountRows) do
        local value = addRow(window, accountCard, {
            name = row.name,
            label = row.label,
            icon = row.icon,
            action = row.action,
            copy = row.copy,
            instanceName = row.instanceName,
            labelWidth = row.labelWidth,
            valueSize = row.valueSize,
            y = cardPaddingY + (index - 1) * (rowHeight + rowGap),
            cardY = accountCardY,
        })
        if row.name == "UserId" then
            window.profileUserIdValue = value
        elseif row.name == "JoinDate" then
            window.profileJoinDateValue = value
        elseif row.name == "AccountAge" then
            window.profileAccountAgeValue = value
        elseif row.name == "Key" then
            window.profileKeyValue = value
        elseif row.name == "Whitelist" then
            window.profileWhitelistValue = value
        end
    end
    y = accountCardY + sectionHeight(#accountRows) + sectionGap

    -- ===== CURRENT GAME =====

    y = heading(y, "Current Game", "gamepad-2")
    local gameCardY = y
    local gameCardHeight = cardPaddingY * 2 + gameThumbnailSize
    local gameCard = card(y, "CurrentGame", gameCardHeight)

    local gameThumbnail = window:Create("ImageLabel", {
        Name = "GameThumbnail",
        Image = "",
        Position = UDim2.fromOffset(cardPaddingX, cardPaddingY),
        Size = UDim2.fromOffset(gameThumbnailSize, gameThumbnailSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 0,
        Parent = gameCard,
    }, { BackgroundColor3 = "ElementSurface" })
    window:Create("UICorner", { Parent = gameThumbnail }, { CornerRadius = "ElementCornerRadius" })
    window:Create("UIStroke", {
        Parent = gameThumbnail,
    }, { Color = "ElementStroke", Transparency = "ElementStrokeTransparency" })

    local gameNameX = cardPaddingX + gameThumbnailSize + 10
    -- [[The DataModel's own name fills the row immediately; the official]]
    -- [[two-step lookup (place -> universe -> games list) replaces it with]]
    -- [[the real game name as soon as the platform answers.]]
    local gameName = label(
        gameCard,
        "GameName",
        tostring(game.Name or fallbackValue),
        UDim2.fromOffset(gameNameX, cardPaddingY),
        UDim2.new(1, -(gameNameX + cardPaddingX), 0, 17),
        13,
        "TitlingColor"
    )
    window.profileGameName = gameName
    window.profilePlaceId = addRow(window, gameCard, {
        name = "PlaceId",
        label = "Place ID",
        instanceName = "GameBy",
        y = cardPaddingY + 22,
        x = gameNameX,
        labelWidth = 52,
        cardY = gameCardY,
        action = "copy",
        copy = function()
            local id = getPlaceId()
            return if id then tostring(id) else nil
        end,
    })

    window:Connect(gameName.MouseEnter, function()
        local text = gameName.Text
        if text == "" or text == fallbackValue then
            return
        end
        local available = gameName.AbsoluteSize.X
        if available <= 0 or functions.textWidth(window.theme.Font, gameName.TextSize, text) <= available then
            return
        end
        profilePanel.showTooltip(window, text, gameCardY + cardPaddingY)
    end)
    window:Connect(gameName.MouseLeave, function()
        profilePanel.hideTooltip(window)
    end)

    y = gameCardY + gameCardHeight + sectionGap

    -- ===== SERVER =====

    local serverRows = {
        { name = "Players", label = "Players", icon = "users" },
        {
            -- [[The value is DataModel.JobId, so the row says so: "Job ID".
            -- [[(The row's internal name stays ServerId — hosts, saved state
            -- [[and the tests reach it as window.profileServerIdValue.)]]
            name = "ServerId",
            label = "Job ID",
            icon = "server",
            labelWidth = 64,
            action = "copy",
            copy = function()
                local jobId = getJobId()
                return if jobId and not isStudio() then jobId else nil
            end,
        },
    }

    y = heading(y, "Server", "server")
    local serverCardY = y
    local serverCard = card(y, "ServerCard", sectionHeight(#serverRows))
    for index, row in ipairs(serverRows) do
        local value = addRow(window, serverCard, {
            name = row.name,
            label = row.label,
            icon = row.icon,
            action = row.action,
            copy = row.copy,
            y = cardPaddingY + (index - 1) * (rowHeight + rowGap),
            cardY = serverCardY,
        })
        if row.name == "Players" then
            window.profilePlayersValue = value
        elseif row.name == "ServerId" then
            window.profileServerIdValue = value
        end
    end
    y = serverCardY + sectionHeight(#serverRows) + sectionGap

    -- ===== USER SESSION =====

    y = heading(y, "User Session", "clock")
    local sessionCardY = y
    local sessionCard = card(y, "SessionCard", sectionHeight(1))
    window.profileSessionValue = addRow(window, sessionCard, {
        name = "Session",
        label = "Time in server",
        icon = "activity",
        y = cardPaddingY,
        cardY = sessionCardY,
    })
    y = sessionCardY + sectionHeight(1) + sectionGap

    content.Size = UDim2.new(1, 0, 0, y)
    window.profileDetails.CanvasSize = UDim2.fromOffset(0, scrollPaddingTop + y + scrollPaddingBottom)

    -- [[Hover tooltip surface. Parented to the card (not the scroll region) so
    -- [[it is never clipped by the scrolling area.]]
    local tooltip = window:Create("Frame", {
        Name = "Tooltip",
        Position = UDim2.fromOffset(paddingX + cardPaddingX, 40),
        Size = UDim2.new(1, -(paddingX * 2 + cardPaddingX * 2), 0, tooltipHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
        Parent = window.profilePanelSurface,
    }, { BackgroundColor3 = "PopupSurface" })
    window.profileTooltip = tooltip
    window:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = tooltip })
    window:Create("UIStroke", {
        Transparency = 0.25,
        Parent = tooltip,
    }, { Color = "ElementStroke" })
    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        Parent = tooltip,
    })
    window.profileTooltipLabel = window:Create("TextLabel", {
        Name = "Label",
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        Parent = tooltip,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- [[The panel is a sibling of the window frame: mirroring the frame's]]
    -- [[position keeps it following drags, restores and resizes without a]]
    -- [[per-frame loop.]]
    window:Connect(window.main:GetPropertyChangedSignal("Position"), function()
        profilePanel.layout(window)
    end)
    window:Connect(window.main:GetPropertyChangedSignal("Size"), function()
        profilePanel.layout(window)
    end)

    -- [[Live values (player count, uptime, session) refresh on a slow tick
    -- [[while the card is on screen; the connection is created once per window
    -- [[so rebuilds cannot stack loops.]]
    if not window.profileRefreshConnection then
        local elapsed = 0
        window.profileRefreshConnection = window:Connect(state.runService.Heartbeat, function(dt: number)
            if window.unloaded then
                return
            end
            elapsed += dt
            if elapsed < refreshInterval then
                return
            end
            elapsed = 0
            if profilePanel.isShown(window) then
                profilePanel.applyLive(window)
            end
        end)
    end

    -- [[Avatar: same generation guard as the rest of the card so a rebuilt or
    -- [[unloaded panel never receives a stale image.]]
    buildGeneration += 1
    local generation = buildGeneration
    window.profileBuildGeneration = generation
    gameThumbnailGenerations[gameThumbnail] = generation

    local function safeAssign(url: string)
        if window.unloaded or gameThumbnailGenerations[gameThumbnail] ~= generation then
            return
        end
        if not gameThumbnail.Parent then
            return
        end
        image.assign(gameThumbnail, "Image", url)
    end

    -- [[Game thumbnail: the universe id comes from DataModel.GameId when the]]
    -- [[runtime supplies one, otherwise from the official place -> universe]]
    -- [[lookup; the legacy rbxthumb URI is the last-resort fallback.]]
    local fallbackUrl = buildFallbackUrl(getPlaceId())
    resolveUniverseId(function(universeId: number?)
        if not universeId then
            if fallbackUrl ~= "" then
                safeAssign(fallbackUrl)
            end
            return
        end
        local cachedIcon = resolvedGameIcons[universeId]
        if type(cachedIcon) == "string" and cachedIcon ~= "" then
            safeAssign(cachedIcon)
        else
            fetchOfficialGameIcon(universeId, function(officialUrl: string?)
                if officialUrl and officialUrl ~= "" then
                    safeAssign(officialUrl)
                elseif fallbackUrl ~= "" then
                    safeAssign(fallbackUrl)
                end
            end)
        end
    end)

    -- [[The official game name (place -> universe -> games list). The label]]
    -- [[keeps the DataModel's own name until the platform answers, and a]]
    -- [[cached answer lands immediately on the next build.]]
    local placeId = getPlaceId()
    if placeId then
        local cachedName = resolvedGameNames[placeId]
        if type(cachedName) == "string" and cachedName ~= "" then
            setText(gameName, cachedName)
        else
            fetchGameName(placeId, function(officialName: string?)
                if window.unloaded or gameThumbnailGenerations[gameThumbnail] ~= generation then
                    return
                end
                if type(officialName) == "string" and officialName ~= "" then
                    setText(gameName, officialName)
                end
            end)
        end
    end

    if player then
        local avatarGeneration = generation
        avatarGenerations[window.profileAvatar] = avatarGeneration

        local function applyAvatar(avatarLabel, uri)
            if avatarGenerations[avatarLabel] ~= avatarGeneration then
                return
            end
            if uri ~= nil and uri ~= "" then
                avatarReady[avatarLabel] = true
                image.assign(avatarLabel, "Image", uri)
                -- [[The avatar may finish loading after the panel already
                -- [[faded in: reveal it now instead of waiting for the
                -- [[next show/hide cycle.]]
                if window.profilePanel and window.profilePanel.Visible then
                    state.tweenService:Create(avatarLabel, settleTween, { ImageTransparency = 0 }):Play()
                end
            else
                avatarReady[avatarLabel] = nil
                image.assign(avatarLabel, "Image", fallbackUri)
            end
        end

        local cachedUri = image.avatar(player.UserId, function(uri)
            if window.unloaded then
                return
            end
            local avatar = window.profileAvatar
            if not avatar then
                return
            end
            applyAvatar(avatar, uri)
        end)

        if cachedUri ~= "" then
            applyAvatar(window.profileAvatar, cachedUri)
        end

    end

    profilePanel.applyIdentity(window)
    profilePanel.applyLive(window)
    profilePanel.layout(window)
    return window.profilePanel
end

-- [[Place the card beside the window frame, vertically centred on the]]
-- [[window's centre. The frame's position may carry scale (the centred]]
-- [[resting position) or be pure offset after a drag: the scale passes]]
-- [[through untouched, the offset gets the half-window + gap edge. The]]
-- [[card's height is derived from window.size.Y.Offset so it never exceeds]]
-- [[the window and aligns top/bottom edges with the window at default size.]]
function profilePanel.layout(window)
    local panel = window.profilePanel
    if not panel then
        return
    end

    local main = window.main
    local pos = main.Position
    local width = main.Size.X.Offset
    local left = (window.settings.profileSide or "right") == "left"
    local edge = width / 2 + profilePanel.gap
    local cardH = currentCardHeight(window)
    profilePanel.height = cardH

    panel.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
    panel.Position = UDim2.new(
        pos.X.Scale,
        pos.X.Offset + (if left then -edge else edge),
        pos.Y.Scale,
        pos.Y.Offset - cardH / 2
    )
    panel.Size = UDim2.fromOffset(profilePanel.width, cardH)

    -- [[The details region takes whatever the pinned header leaves. The
    -- [[scrollbar only appears when the sections are taller than that region,
    -- [[and the content narrows by its width so nothing slides underneath.]]
    local details = window.profileDetails
    local content = window.profileDetailsContent
    if not (details and content) then
        return
    end
    local regionHeight = math.max(0, cardH - headerHeight - dividerHeight)
    details.Size = UDim2.new(1, 0, 0, regionHeight)
    local scrollable = content.Size.Y.Offset > math.max(0, regionHeight - scrollPaddingTop - scrollPaddingBottom)
    details.ScrollBarThickness = if scrollable then scrollBarThickness else 0
    content.Size = UDim2.new(1, if scrollable then -scrollBarThickness else 0, 0, content.Size.Y.Offset)
end

function profilePanel.setShown(window, shown, tweenInfo)
    local panel = window.profilePanel
    if not panel then
        return
    end

    -- [[Window visibility wins over the requested state: never fade the]]
    -- [[panel in while the window is hidden or minimised.]]
    shown = shown == true
        and profilePanel.isEnabled(window)
        and not window.hidden
        and not window.minimised

    local avatar = window.profileAvatar
    local stroke = window.profilePanelStroke
    local glow = window.profilePanelGlow

    panel.Visible = shown

    if not (avatar and stroke) then
        return
    end

    if shown then
        -- [[Fresh values the moment the card (re)appears.]]
        profilePanel.applyLive(window)
    end

    local hasImage = avatarReady[avatar] == true
        or (type(avatar.Image) == "string" and avatar.Image ~= "" and avatar.Image ~= fallbackUri)

    local targets: { [Instance]: { [string]: any } } = {
        [avatar] = {
            ImageTransparency = if shown and hasImage then 0 else 1,
            BackgroundTransparency = if shown then avatarBgTransparency else 1,
        },
        [stroke] = { Transparency = if shown then idleStrokeTransparency else 1 },
    }

    -- [[The card's own plate fades with the window's: while the window is]]
    -- [[still fading in its background is part-transparent, so the card beside]]
    -- [[it must be too — otherwise the card reads as a solid panel floating]]
    -- [[next to a half-faded window.]]
    local surface = window.profilePanelSurface
    if surface then
        targets[surface] = {
            BackgroundTransparency = if shown then window:WindowSurfaceTransparency() else 1,
        }
    end

    if glow then
        targets[glow] = { Transparency = if shown then glowTransparency else 1 }
    end

    for _, entry in ipairs(window.profileFadeTargets or {}) do
        local props = targets[entry.instance]
        if not props then
            props = {}
            targets[entry.instance] = props
        end
        props[entry.prop] = if shown then entry.shown else 1
    end

    for instance, props in targets do
        local needsUpdate = false
        for prop, value in props do
            if instance[prop] ~= value then
                needsUpdate = true
                break
            end
        end
        if not needsUpdate then
            continue
        end
        if tweenInfo then
            state.tweenService:Create(instance, tweenInfo, props):Play()
        else
            for prop, value in props do
                instance[prop] = value
            end
        end
    end
end

function profilePanel.setEnabled(window, enabled)
    window.settings.showProfile = enabled == true

    -- [[The reveal toggle depends on the card, so switching the card off]]
    -- [[switches the reveal off with it: it can never sit active while]]
    -- [[there is nothing on screen to reveal. The caller (the settings UI)]]
    -- [[rolls its own switch back from the return value.]]
    local revealCleared = false
    if not window.settings.showProfile and window.settings.showFullUsername then
        window.settings.showFullUsername = false
        revealCleared = true
    end
    profilePanel.applyIdentity(window)

    profilePanel.setShown(window, window.settings.showProfile, settleTween)
    window:_recenterForProfile(window.settings.showProfile)

    if revealCleared then
        window:Notify({
            title = locale.resolve("Reveal profile details"),
            content = locale.resolve(
                "Turned off with the profile card: it unmasks the values on that card, so it needs \"Show profile\" to be on."
            ),
        })
    end

    -- [[The toggle is only half the story: the card also needs a player and]]
    -- [[room on screen (260px beside the window, window-height tall). A missing]]
    -- [[player resolves itself through the late-player waiter in Window.new,]]
    -- [[but a small viewport would otherwise leave the user looking at an]]
    -- [[active toggle and no card — so say why.]]
    if window.settings.showProfile and state.localPlayer and not hasRoom(window) then
        window:Notify({
            title = locale.resolve("Profile card"),
            content = locale.resolve(
                "This screen has no room for the profile card, so it stays hidden. It needs 260px beside the window and enough height for the window — enlarge the window or rotate the device and it appears."
            ),
        })
    end

    return revealCleared
end

function profilePanel.setSide(window, side)
    window.settings.profileSide = if side == "left" then "left" else "right"
    profilePanel.layout(window)
    window:_recenterForProfile(true)
end

-- [[Window:SetProfile accepts either the legacy subtitle string / nil or a
-- [[table carrying everything the card's host-owned rows show:
-- [[  { subtitle = "…", key = "…", tier = "PREMIUM",
-- [[    whitelist = { status = "Active", daysLeft = 14 } }
-- [[`tier` drives the header pill (any word, uppercased on the card); with
-- [[none supplied the pill falls back to PREMIUM / FREEMIUM from the
-- [[platform membership.
-- [[`whitelist.expiresAt` (unix seconds) is accepted instead of `daysLeft` and
-- [[counted down live. Anything not supplied reads "—".]]
function profilePanel.setProfile(window, props)
    if type(props) ~= "table" then
        -- [[Legacy call shape: a subtitle string (or nil to clear it). The
        -- [[host's key / whitelist rows are left exactly as they were.]]
        return profilePanel.setSubtitle(window, props)
    end

    local data = {}
    if type(props) == "table" then
        local subtitle = props.subtitle or props.Subtitle
        if type(subtitle) == "string" and subtitle ~= "" then
            data.subtitle = subtitle
        end
        local key = props.key or props.Key
        if type(key) == "string" and key ~= "" then
            data.key = key
        end
        local tier = props.tier or props.Tier
        if type(tier) == "string" and tier ~= "" then
            data.tier = tier
        end
        local whitelist = props.whitelist or props.Whitelist
        if type(whitelist) == "table" then
            local status = whitelist.status or whitelist.Status
            local daysLeft = whitelist.daysLeft or whitelist.DaysLeft
            local expiresAt = whitelist.expiresAt or whitelist.ExpiresAt
            data.whitelist = {
                status = if type(status) == "string" and status ~= "" then status else nil,
                daysLeft = if type(daysLeft) == "number" then daysLeft else nil,
                expiresAt = if type(expiresAt) == "number" then expiresAt else nil,
            }
        end
    end
    window.profileData = data
    window.profileText = data.subtitle
    profilePanel.applyIdentity(window)
    profilePanel.applyLive(window)
    return data
end

-- [[Legacy setter (string / nil): swaps the subtitle while leaving any key,
-- [[tier or whitelist the host supplied in place.]]
function profilePanel.setSubtitle(window, text)
    if type(text) == "table" then
        return profilePanel.setProfile(window, text)
    end
    local data = window.profileData or {}
    -- [[Copy before mutating: the caller may still hold the table it passed.]]
    data = { subtitle = data.subtitle, key = data.key, tier = data.tier, whitelist = data.whitelist }
    data.subtitle = if type(text) == "string" and text ~= "" then text else nil
    window.profileData = data
    window.profileText = data.subtitle
    profilePanel.applyIdentity(window)
end

-- [[Kept as an alias: the reveal toggle no longer drives the name alone, so]]
-- [[refreshing the name refreshes the whole identity block.]]
function profilePanel.refreshName(window)
    profilePanel.applyIdentity(window)
end

return profilePanel
