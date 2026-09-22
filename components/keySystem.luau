-- [[Standalone key gate: the Rayfield-style "enter your key" modal, drawn in
-- Astra's own shell language so it reads as one family with the window that
-- follows it — the 12px shell corner and WindowColor gradient card, the 8px
-- field and button corners, the SurfaceStroke hairline, the accent Continue.
--
-- Unlike the popup it gates *before* any window exists: hosts call
-- `Astra:CreateKeySystem` first and create their window inside `onSuccess`.
-- There is no window to bind theme tokens to, so the theme is resolved once
-- at creation (the same value `CreateWindow` accepts) and baked in — a
-- transient modal that is usually gone before any `ChangeTheme` could move
-- it. Saved keys live beside the other Astra files at
-- `Astra/keys/<fileName>.txt`, and a matching file skips the UI entirely
-- (Rayfield's passthrough) straight into `onSuccess`.]]

local KeySystem = {}
KeySystem.__index = KeySystem
KeySystem.__type = "KeySystem"

local utilities = script.Parent.Parent.utilities
local motion = require(utilities.motion)
local state = require(utilities.Parent.core.state)
local functions = require(script.Parent.Parent.functions)
local constants = require(utilities.constants)
local locale = require(utilities.locale)
local log = require(utilities.log)
local haptic = require(utilities.HapticEngine)
local filesystem = require(utilities.filesystem)
local pathUtil = require(utilities.path)
local themes = require(script.Parent.Parent.themes)
local Icons = require(script.Parent.Parent.icons)

-- [[The gate arrives on the shared vocabulary: the card glides the last few
-- pixels to centre on `modal`, grows from its 93% entrance size on
-- `emphasized` (Rayfield's 0.6s Exponential pop, re-cut as a named spec),
-- surfaces fade on `normal`, copy and controls on `snappy`, the backdrop
-- dims quickest of all so focus lands on the card. A wrong key shakes the
-- card on `micro`/`snappy` — the motion service has no Elastic curve, so the
-- wobble is three chained lateral tweens instead of one spring. Closing
-- plays everything in reverse on `dropdownClose`: a gate leaves quicker
-- than it came.]]
local backdropTransparency = 0.5
local entranceScale = 0.93
local shakeOffset = 8

-- [[Geometry. The 400px card is the popup's width, so a gate and a dialog
-- read as one system; the height is measured from the note text (one or two
-- lines) and lands around 150-165px — the short wide card Rayfield's 500x187
-- gate made familiar, re-cut for Astra's 600px window. Narrow viewports
-- clamp the width instead of clipping: the Continue button keeps its fixed
-- width and the field absorbs the shrink.]]
local cardWidth = 400
local minCardWidth = 280
local viewportMargin = 48
local cardPadX = 22
local cardPadTop = 16
local cardPadBottom = 16
local sectionGap = 10
local headerGap = 8
local titleFontSize = 18
local titleHeight = 22
local titleSubGap = 3
local subtitleFontSize = 14
local subtitleHeight = 17
local iconSize = 16
local closeSize = 16
local fieldHeight = 36
local fieldPadX = 12
local continueWidth = 104
local fieldGap = 8
local fieldFontSize = 15
local noteFontSize = 13
local noteIconSize = 14
local noteIconGap = 6
local noteMaxLines = 2

-- [[One gate at a time: creating a second gate (a spam-executed loader, a
-- host that re-arms) retires the first instead of stacking cards. The
-- retired gate closes silently — `onClose` belongs to the user dismissing
-- the card, not to being superseded.]]
local activeGate = nil

local clipboardGlobals = { "setclipboard", "toclipboard", "setrbxclipboard", "set_clipboard" }
local clipboardMethods = { "set", "Set", "copy", "Copy" }

local headerIconCandidates = { "key-round", "key-square", "key", "lock" }
local copyIconCandidates = { "copy", "clipboard", "clipboard-copy" }
local closeIconCandidates = { "x" }

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function environment()
    return (getfenv and getfenv()) or _G
end

-- [[There is no clipboard in the Roblox API surface the library targets, so
-- the get-key link asks the host for one: every executor spells it
-- differently, and Studio/Rojo spells it differently again. The lookup runs
-- per tap rather than being cached at load, so a host that installs its
-- clipboard API after Astra loads is still found. Mirrors the Link
-- element's resolver.]]
local function clipboardWriter()
    local env = environment()
    if type(env) == "table" then
        for _, name in clipboardGlobals do
            local candidate = env[name]
            if typeof(candidate) == "function" then
                return function(text)
                    return candidate(text)
                end
            end
        end

        -- [[Some hosts expose a `Clipboard` object instead of a global function.]]
        local clipboard = env.Clipboard
        if typeof(clipboard) == "table" then
            for _, name in clipboardMethods do
                local method = clipboard[name]
                if typeof(method) == "function" then
                    return function(text)
                        return method(clipboard, text)
                    end
                end
            end
        end
    end

    -- [[Studio and Rojo: the only clipboard on the non-executor path.]]
    local ok, studioService = pcall(function()
        return game:GetService("StudioService")
    end)
    if ok and studioService and typeof(studioService.CopyToClipboard) == "function" then
        return function(text)
            return studioService:CopyToClipboard(text)
        end
    end

    return nil
end

local function resolveGlyph(candidates)
    for _, name in candidates do
        local resolved = Icons.resolve(name)
        if resolved ~= nil and resolved ~= name and resolved ~= "" then
            return resolved
        end
    end
    return nil
end

local function keyFilePath(fileName)
    local folder = state.fileSystemManager:getPath("keys")
    local base = pathUtil.sanitizeFile(fileName)
    if base == "" then
        base = "Key"
    end
    return folder, pathUtil.join(folder, base .. ".txt")
end

function KeySystem.new(props)
    props = if typeof(props) == "table" then props else {}

    local title = tostring(props.title or props.Title or "Astra")
    local keys = props.keys or props.Keys or props.key or props.Key
    if typeof(keys) == "string" then
        keys = { keys }
    end
    if typeof(keys) ~= "table" then
        keys = {}
    end

    local getKeyUrl = props.getKeyUrl or props.GetKeyUrl or props.getKey or props.GetKey
    if getKeyUrl ~= nil then
        getKeyUrl = tostring(getKeyUrl)
    end

    local self = setmetatable({
        title = title,
        subtitle = tostring(props.subtitle or props.Subtitle or "Key System"),
        icon = props.icon or props.Icon,
        note = tostring(props.note or props.Note or "Enter your key to continue."),
        placeholder = tostring(props.placeholder or props.Placeholder or "Enter key"),
        getKeyUrl = if getKeyUrl == "" then nil else getKeyUrl,
        maxAttempts = tonumber(props.maxAttempts or props.MaxAttempts),
        saveKey = if props.saveKey ~= nil
            then props.saveKey
            elseif props.SaveKey ~= nil then props.SaveKey
            else true,
        fileName = tostring(props.fileName or props.FileName or title),
        dismissable = if props.dismissable ~= nil
            then props.dismissable
            elseif props.Dismissable ~= nil then props.Dismissable
            else true,
        onSuccess = props.onSuccess or props.OnSuccess,
        onClose = props.onClose or props.OnClose,
        onMaxAttempts = props.onMaxAttempts or props.OnMaxAttempts,
        theme = themes.resolve(props.theme or props.Theme),
        passed = false,
        closed = false,
        locked = false,
        attempts = 0,
        _expected = {},
        _connections = {},
        _reveal = {},
        _copyToken = 0,
    }, KeySystem)

    -- [[Remote keys are fetched once, up front, so submitting never yields on
    -- the network: each entry is treated as a raw URL and its trimmed body
    -- becomes the expected key. A URL that fails to fetch warns and is
    -- dropped — it can never match, so a dead link fails closed, not open.]]
    local grabFromSite = props.grabKeyFromSite or props.GrabKeyFromSite or false
    for _, key in keys do
        key = tostring(key)
        if grabFromSite then
            local ok, body = pcall(function()
                return game:HttpGet(key)
            end)
            if ok and typeof(body) == "string" and trim(body) ~= "" then
                table.insert(self._expected, trim(body))
            else
                log.warn("Astra: key system could not fetch a key from " .. key)
            end
        elseif trim(key) ~= "" then
            table.insert(self._expected, trim(key))
        end
    end

    -- [[No keys to check against fails open with a loud warning (Rayfield's
    -- passthrough): a host that misconfigured the gate still gets its `onSuccess`
    -- instead of an unopenable card, and the warning says why.]]
    if #self._expected == 0 then
        log.warn("Astra: key system has no keys to check against, passing through.")
        self.passed = true
        self.closed = true
        self:_runCallback(self.onSuccess, "")
        return self
    end

    -- [[The saved-key passthrough: a file whose trimmed contents equal an
    -- expected key skips the UI entirely, straight into `onSuccess`.]]
    if self.saveKey then
        local _, file = keyFilePath(self.fileName)
        local savedOk, saved = pcall(function()
            if filesystem.isfile(file) then
                return filesystem.readfile(file)
            end
            return nil
        end)
        if savedOk and typeof(saved) == "string" then
            local cleaned = trim(saved)
            for _, key in self._expected do
                if cleaned == key then
                    self.passed = true
                    self.closed = true
                    self:_runCallback(self.onSuccess, cleaned)
                    return self
                end
            end
        end
    end

    if activeGate ~= nil and not activeGate.closed then
        activeGate:Close()
    end
    activeGate = self

    self:_build()
    task.spawn(function()
        self:_show()
    end)

    return self
end

function KeySystem:_runCallback(callback, ...)
    if typeof(callback) ~= "function" then
        return
    end
    local args = { ... }
    task.spawn(function()
        local ok, err = pcall(callback, table.unpack(args))
        if not ok then
            log.warn("Astra: key system callback errored:")
            log.print(err)
        end
    end)
end

function KeySystem:_fade(instance, prop, to, spec)
    table.insert(self._reveal, { instance = instance, prop = prop, to = to, spec = spec })
    return instance
end

-- [[Instance creation without a window: plain `Instance.new` plus the one
-- `Window:Create` behaviour the gate needs — locale tokens resolve to their
-- translated string immediately. There is no live rebinding (the gate has no
-- `SetLocale` and rarely outlives the second it was dismissed in), only the
-- same initial value a window-built card would show.]]
function KeySystem:_create(className, props)
    local instance = Instance.new(className)
    for key, value in props do
        if key ~= "Parent" then
            if locale.isToken(value) then
                value = locale.resolve(locale.sourceOf(value))
            end
            instance[key] = value
        end
    end
    instance.Parent = props.Parent
    return instance
end

function KeySystem:_connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(self._connections, connection)
    return connection
end

function KeySystem:_build()
    local theme = self.theme

    local cardW = cardWidth
    local camera = state.workspace and state.workspace.CurrentCamera or nil
    local viewport = camera and camera.ViewportSize or nil
    local viewportX = viewport and tonumber(viewport.X) or nil
    if viewportX and viewportX < cardWidth + viewportMargin then
        cardW = math.max(minCardWidth, math.floor(viewportX - viewportMargin))
    end

    local hasIcon = self.icon ~= nil and self.icon ~= 0 and self.icon ~= ""
    local headerIcon = if hasIcon then Icons.resolve(self.icon) else resolveGlyph(headerIconCandidates)
    if headerIcon == "" then
        headerIcon = nil
    end
    hasIcon = headerIcon ~= nil

    local innerW = cardW - cardPadX * 2
    local hasSubtitle = self.subtitle ~= ""
    local headerH = titleHeight + (if hasSubtitle then titleSubGap + subtitleHeight else 0)

    local noteTextW = innerW - (if self.getKeyUrl then noteIconSize + noteIconGap else 0)
    local noteH = 0
    if self.note ~= "" then
        local lineH = functions.textHeight(theme.Font, noteFontSize, "Ag", noteTextW)
        noteH = math.min(
            functions.textHeight(theme.Font, noteFontSize, locale.resolve(self.note), noteTextW),
            lineH * noteMaxLines
        )
    end

    local totalH = cardPadTop
        + headerH
        + sectionGap
        + fieldHeight
        + (if noteH > 0 then sectionGap + noteH else 0)
        + cardPadBottom

    self._restSize = UDim2.fromOffset(cardW, totalH)
    self._enterSize =
        UDim2.fromOffset(math.floor(cardW * entranceScale), math.floor(totalH * entranceScale))

    -- [[The gate keeps its own ScreenGui, like the popup: a dedicated root at
    -- the popup DisplayOrder lifts the whole card above any window the host
    -- already built, and there is no window to own the root — `Close` tracks
    -- every connection and destroys the tree itself.]]
    self._screenGui = self:_create("ScreenGui", {
        Name = state.httpService:GenerateGUID(false),
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = constants.displayOrder.popup,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        Parent = state.guiContainer,
    })

    -- [[The backdrop swallows clicks but never dismisses: a key gate that
    -- closes on a misclick is a gate the user did not mean to pass.]]
    self._backdrop = self:_fade(self:_create("Frame", {
        Name = "Backdrop",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Active = true,
        BackgroundTransparency = 1,
        ZIndex = 1,
        Parent = self._screenGui,
    }), "BackgroundTransparency", backdropTransparency, "fast")

    self._card = self:_fade(self:_create("Frame", {
        Name = "Card",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = self._enterSize,
        Active = true,
        BorderSizePixel = 0,
        ZIndex = 1,
        BackgroundTransparency = 1,
        Parent = self._screenGui,
    }), "BackgroundTransparency", 0, "normal")

    self:_create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),
        Color = functions.toColorSequence(theme.WindowColor),
        Parent = self._card,
    })

    self:_create("UICorner", {
        CornerRadius = theme.CornerRoundness,
        Parent = self._card,
    })

    self:_fade(self:_create("UIStroke", {
        Color = theme.SurfaceStroke,
        Transparency = 1,
        Parent = self._card,
    }), "Transparency", 0.95, "normal")

    local shadowColor = theme.ShadowColor
    if typeof(shadowColor) == "ColorSequence" then
        shadowColor = shadowColor.Keypoints[1].Value
    end
    self:_fade(self:_create("UIShadow", {
        BlurRadius = UDim.new(0, 26),
        Color = shadowColor,
        Transparency = 1,
        ZIndex = -1,
        Parent = self._card,
    }), "Transparency", 0.55, "normal")

    self:_create("UIPadding", {
        PaddingLeft = UDim.new(0, cardPadX),
        PaddingRight = UDim.new(0, cardPadX),
        PaddingTop = UDim.new(0, cardPadTop),
        PaddingBottom = UDim.new(0, cardPadBottom),
        Parent = self._card,
    })

    self:_create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, sectionGap),
        Parent = self._card,
    })

    self:_buildHeader(headerIcon, hasIcon, headerH, hasSubtitle)
    self:_buildFieldRow(theme)
    if noteH > 0 then
        self:_buildNote(theme, noteH)
    end

    if self.dismissable then
        self:_connect(state.userInputService.InputBegan, function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
                self:_userClose()
            end
        end)
    end
end

function KeySystem:_buildHeader(headerIcon, hasIcon, headerH, hasSubtitle)
    local theme = self.theme

    local headerFrame = self:_create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, headerH),
        LayoutOrder = 1,
        Parent = self._card,
    })

    self:_create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, headerGap),
        Parent = headerFrame,
    })

    if hasIcon then
        self:_fade(self:_create("ImageLabel", {
            Image = headerIcon,
            Size = UDim2.fromOffset(iconSize, iconSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ImageTransparency = 1,
            ImageColor3 = theme.TitlingColor,
            Parent = headerFrame,
        }), "ImageTransparency", 0)
    end

    local reserved = (if hasIcon then iconSize + headerGap else 0)
        + (if self.dismissable then closeSize + headerGap else 0)
    local textFrame = self:_create("Frame", {
        Name = "Text",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -reserved, 0, headerH),
        LayoutOrder = 2,
        Parent = headerFrame,
    })

    self:_create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, titleSubGap),
        Parent = textFrame,
    })

    self:_fade(self:_create("TextLabel", {
        Text = locale.t(self.title),
        Size = UDim2.new(1, 0, 0, titleHeight),
        BackgroundTransparency = 1,
        TextSize = titleFontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        TextColor3 = theme.TitlingColor,
        FontFace = theme.Font,
        Parent = textFrame,
    }), "TextTransparency", 0)

    if hasSubtitle then
        self:_fade(self:_create("TextLabel", {
            Text = locale.t(self.subtitle),
            Size = UDim2.new(1, 0, 0, subtitleHeight),
            BackgroundTransparency = 1,
            TextSize = subtitleFontSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = 2,
            TextTransparency = 1,
            TextColor3 = theme.TitlingColor,
            FontFace = theme.Font,
            Parent = textFrame,
        }), "TextTransparency", 0.55)
    end

    if self.dismissable then
        local closeButton = self:_fade(self:_create("ImageButton", {
            Image = resolveGlyph(closeIconCandidates),
            Size = UDim2.fromOffset(closeSize, closeSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = 3,
            ImageTransparency = 1,
            ImageColor3 = theme.TitlingColor,
            Parent = headerFrame,
        }), "ImageTransparency", 0.5)
        self._closeButton = closeButton

        self:_connect(closeButton.MouseEnter, function()
            if self.closed then
                return
            end
            motion.tween(closeButton, { ImageTransparency = 0 }, "snappy")
        end)
        self:_connect(closeButton.MouseLeave, function()
            motion.tween(closeButton, { ImageTransparency = 0.5 }, "snappy")
        end)
        self:_connect(closeButton.MouseButton1Click, function()
            if self.closed then
                return
            end
            haptic.click()
            self:_userClose()
        end)
    end
end

-- [[The field and its Continue ride one row, like a search bar with its
-- action attached: the fixed-width button never moves, the field absorbs
-- narrow viewports, and the whole gate keeps its short-card silhouette
-- instead of growing a footer. Enter submits from the keyboard too.]]
function KeySystem:_buildFieldRow(theme)
    local row = self:_create("Frame", {
        Name = "FieldRow",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, fieldHeight),
        LayoutOrder = 2,
        Parent = self._card,
    })

    self:_create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, fieldGap),
        Parent = row,
    })

    local fieldBox = self:_fade(self:_create("Frame", {
        Name = "Field",
        BackgroundColor3 = theme.FieldBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -(continueWidth + fieldGap), 0, fieldHeight),
        LayoutOrder = 1,
        BackgroundTransparency = 1,
        Parent = row,
    }), "BackgroundTransparency", theme.FieldTransparency)
    self._fieldBox = fieldBox

    self:_create("UICorner", {
        CornerRadius = theme.ElementCornerRadius,
        Parent = fieldBox,
    })

    self._fieldStroke = self:_fade(self:_create("UIStroke", {
        Color = theme.SurfaceStroke,
        Transparency = 1,
        Parent = fieldBox,
    }), "Transparency", 0.85)

    self:_create("UIPadding", {
        PaddingLeft = UDim.new(0, fieldPadX),
        PaddingRight = UDim.new(0, fieldPadX),
        Parent = fieldBox,
    })

    self._input = self:_fade(self:_create("TextBox", {
        Text = "",
        PlaceholderText = locale.t(self.placeholder),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = fieldFontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        TextTransparency = 1,
        TextColor3 = theme.ContentColor,
        FontFace = theme.Font,
        PlaceholderColor3 = theme.PlaceholderColor,
        Parent = fieldBox,
    }), "TextTransparency", 0.6)

    self:_connect(self._input.Focused, function()
        motion.tween(self._input, { TextTransparency = 0 }, "fast")
    end)
    -- [[Enter submits; any other focus loss (tapping Continue also
    -- defocuses) stays silent, so one press can never submit twice.]]
    self:_connect(self._input.FocusLost, function(enterPressed)
        motion.tween(self._input, { TextTransparency = 0.6 }, "fast")
        if enterPressed then
            haptic.click()
            self:_submit(self._input.Text)
        end
    end)

    local continueButton = self:_fade(self:_create("Frame", {
        Name = "Continue",
        BackgroundColor3 = theme.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, continueWidth, 0, fieldHeight),
        LayoutOrder = 2,
        BackgroundTransparency = 1,
        Parent = row,
    }), "BackgroundTransparency", 0)
    self._continue = continueButton

    self:_create("UICorner", {
        CornerRadius = theme.ElementCornerRadius,
        Parent = continueButton,
    })

    self:_fade(self:_create("UIStroke", {
        Color = theme.AccentStroke,
        Transparency = 1,
        Parent = continueButton,
    }), "Transparency", 0.1)

    self:_fade(self:_create("TextLabel", {
        Text = locale.t("Continue"),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        TextSize = fieldFontSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = functions.contrastText(theme.AccentColor),
        TextTransparency = 1,
        FontFace = theme.Font,
        Parent = continueButton,
    }), "TextTransparency", 0)

    local interact = self:_create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Parent = continueButton,
    })
    self._continueInteract = interact

    self:_connect(interact.MouseEnter, function()
        if self.closed or self.locked then
            return
        end
        motion.tween(continueButton, { BackgroundColor3 = theme.AccentHover }, "snappy")
    end)
    self:_connect(interact.MouseLeave, function()
        motion.tween(continueButton, { BackgroundColor3 = theme.AccentColor }, "snappy")
    end)
    self:_connect(interact.MouseButton1Click, function()
        if self.closed or self.locked then
            return
        end
        haptic.click()
        self:_submit(self._input.Text)
    end)
end

-- [[The note is the gate's instruction line — and, when the host passes
-- `getKeyUrl`, its get-key affordance for free: a copy mark plus a tap
-- target, with "copied" confirmation that restores itself. No extra row, no
-- taller card. Long notes truncate past two lines instead of growing the
-- shell: hosts with a paragraph to write should keep it under ~110
-- characters.]]
function KeySystem:_buildNote(theme, noteH)
    local noteRow = self:_create("Frame", {
        Name = "Note",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, noteH),
        LayoutOrder = 3,
        Parent = self._card,
    })

    local textSize = UDim2.new(1, 0, 0, noteH)
    if self.getKeyUrl then
        self:_create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, noteIconGap),
            Parent = noteRow,
        })

        self:_fade(self:_create("ImageLabel", {
            Image = resolveGlyph(copyIconCandidates),
            Size = UDim2.fromOffset(noteIconSize, noteIconSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ImageTransparency = 1,
            ImageColor3 = theme.ContentColor,
            Parent = noteRow,
        }), "ImageTransparency", 0.5)

        textSize = UDim2.new(1, -(noteIconSize + noteIconGap), 0, noteH)
        self._noteLabel = self:_fade(self:_create("TextButton", {
            Text = locale.t(self.note),
            Size = textSize,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            TextSize = noteFontSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = 2,
            TextTransparency = 1,
            TextColor3 = theme.ContentColor,
            FontFace = theme.Font,
            Parent = noteRow,
        }), "TextTransparency", 0.5)

        self:_connect(self._noteLabel.MouseButton1Click, function()
            if self.closed or self.locked then
                return
            end
            self:_copyGetKeyLink()
        end)
    else
        self._noteLabel = self:_fade(self:_create("TextLabel", {
            Text = locale.t(self.note),
            Size = textSize,
            BackgroundTransparency = 1,
            TextSize = noteFontSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 1,
            TextColor3 = theme.ContentColor,
            FontFace = theme.Font,
            Parent = noteRow,
        }), "TextTransparency", 0.5)
    end
end

function KeySystem:_setNote(text)
    if self._noteLabel then
        self._noteLabel.Text = locale.resolve(text)
    end
end

function KeySystem:_copyGetKeyLink()
    if self.closed or not self.getKeyUrl then
        return
    end
    local writer = clipboardWriter()
    if not writer then
        log.warn("Astra: no clipboard API was found in this environment, so the key gate cannot copy its get-key link.")
        return
    end
    local ok = pcall(writer, self.getKeyUrl)
    if not ok then
        return
    end
    haptic.click()

    -- [[The token retires stale restores: a second tap restarts the window
    -- instead of letting the first tap's timer wipe the fresh confirmation.]]
    self._copyToken += 1
    local token = self._copyToken
    self:_setNote("Link copied — paste it in your browser to get a key.")
    task.delay(2, function()
        if self.closed or token ~= self._copyToken then
            return
        end
        self:_setNote(self.note)
    end)
end

function KeySystem:_show()
    if self.closed or not (self._screenGui and self._screenGui.Parent) then
        return
    end

    haptic.notify()

    motion.tween(self._card, { Position = UDim2.new(0.5, 0, 0.5, 0) }, "modal")
    motion.tween(self._card, { Size = self._restSize }, "emphasized")

    for _, reveal in self._reveal do
        motion.tween(reveal.instance, { [reveal.prop] = reveal.to }, reveal.spec or "snappy")
    end
end

-- [[The one submit path: the button, Enter, and the tests all arrive here.
-- Comparison is strict after trimming — keys with significant surrounding
-- whitespace do not exist, but mobile keyboards that append a space do. An
-- empty submit is ignored without costing an attempt.]]
function KeySystem:_submit(text)
    if self.closed or self.locked then
        return
    end
    local cleaned = trim(text)
    if cleaned == "" then
        return
    end
    for _, key in self._expected do
        if cleaned == key then
            self:_succeed(cleaned)
            return
        end
    end
    self:_failAttempt()
end

function KeySystem:_succeed(key)
    self.passed = true
    if self.saveKey then
        local folder, file = keyFilePath(self.fileName)
        pcall(function()
            filesystem.ensureFolder(folder)
            filesystem.writefile(file, key)
        end)
    end
    local onSuccess = self.onSuccess
    self:Close()
    self:_runCallback(onSuccess, key)
end

function KeySystem:_failAttempt()
    self.attempts += 1
    if self._input then
        self._input.Text = ""
    end
    self:_shake()
    if self.maxAttempts and self.attempts >= self.maxAttempts then
        self:_lock()
    end
end

function KeySystem:_shake()
    local card = self._card
    if not card then
        return
    end
    local center = UDim2.new(0.5, 0, 0.5, 0)
    motion.tween(card, { Position = UDim2.new(0.5, -shakeOffset, 0.5, 0) }, "micro", function()
        if self.closed then
            return
        end
        motion.tween(card, { Position = UDim2.new(0.5, shakeOffset, 0.5, 0) }, "micro", function()
            if self.closed then
                return
            end
            motion.tween(card, { Position = center }, "snappy")
        end)
    end)

    local stroke = self._fieldStroke
    if stroke then
        motion.cancel(stroke)
        stroke.Color = self.theme.ErrorStrokeColor
        motion.set(stroke, { Transparency = 0 })
        task.delay(motion.step(0.6), function()
            if self.closed then
                return
            end
            stroke.Color = self.theme.SurfaceStroke
            motion.tween(stroke, { Transparency = 0.85 }, "snappy")
        end)
    end
end

-- [[The lock is permanent for the gate's life: the field stops editing, the
-- action dims, the note says why. The host decides what exceeding the budget
-- means (Rayfield kicks the player; Astra delegates through
-- `onMaxAttempts`) — the gate itself only stops accepting keys.]]
function KeySystem:_lock()
    self.locked = true
    self._copyToken += 1
    if self._input then
        self._input.TextEditable = false
        self._input.Active = false
    end
    if self._continue then
        motion.tween(self._continue, { BackgroundColor3 = self.theme.NeutralButton }, "snappy")
    end
    self:_setNote("No attempts remaining.")
    self:_runCallback(self.onMaxAttempts)
end

function KeySystem:_userClose()
    if self.closed or not self.dismissable then
        return
    end
    local onClose = self.onClose
    self:Close()
    self:_runCallback(onClose)
end

function KeySystem:Close()
    if self.closed then
        return
    end
    self.closed = true

    if activeGate == self then
        activeGate = nil
    end

    for _, connection in self._connections do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self._connections = {}

    local screenGui = self._screenGui
    self._screenGui = nil
    if not (screenGui and screenGui.Parent) then
        return
    end

    -- [[The exit tween is built raw, like the popup's: `motion.tween` skips
    -- work (and its completion) when motion is disabled or the values match,
    -- but the tree must be destroyed on every path. A zero-duration tween
    -- still completes, so the destroy runs even under the `instant`
    -- profile.]]
    local card = self._card
    if card then
        local closeTween = state.tweenService:Create(card, motion.spec("dropdownClose"), {
            Position = UDim2.new(0.5, 0, 0.5, 10),
            Size = self._enterSize,
        })
        closeTween.Completed:Connect(function()
            pcall(function()
                screenGui:Destroy()
            end)
        end)
        closeTween:Play()
    else
        pcall(function()
            screenGui:Destroy()
        end)
    end

    for _, reveal in self._reveal do
        motion.tween(reveal.instance, { [reveal.prop] = 1 }, "dropdownClose")
    end
end

return KeySystem
