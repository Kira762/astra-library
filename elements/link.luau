--[[
CreateLink: a card that carries a URL and copies it.

The card shows a leading icon, a title and a subtitle. The `link` itself is
a hidden value: it is stored on the element, never rendered as text, and is
only ever read by the trailing copy control. Tapping that control copies
the link, swaps the copy glyph for a check mark for a few seconds, then
puts the copy glyph back. Each card owns its own cycle, so two cards can be
in different states at once and a container (a Group, or a Collapsible
Group that collapses) never carries the feedback across: a card hidden
while it is showing the check mark is back on the copy glyph when it is
revealed again.

The build mirrors the Button: one full card for a tab or a column Group,
and a compact row for a horizontal Group, both ending in the same control
with the same tap behaviour.
]]

local state = {}
state.__index = state
state.__type = "Link"

local utilities = script.Parent.Parent.utilities

local functions = require(script.Parent.Parent.functions)
local coreState = require(script.Parent.Parent.core.state)
local image = require(script.Parent.Parent.images.image)
local description = require(script.Parent.description)
local haptic = require(utilities.HapticEngine)
local locale = require(utilities.locale)
local lockable = require(utilities.lockable)
local log = require(utilities.log)
local moveable = require(utilities.moveable)

--[[
Card metrics: one card, two lines. The title is the Text element's 16px
TitlingColor heading; the subtitle is the 14px muted body line every
element description in the library uses. Without a subtitle the card
collapses to the single-line height so it sits level with a Button.
]]
local cardHeight = 56
local cardHeightSingle = 43
local titleSize = 16
local subtitleSize = 14
local titleHeight = 19
local subtitleHeight = 16
local lineGap = 1
local iconSize = 16
local iconGap = 10
local gutter = 20
--[[
The tap target is deliberately larger than the 16px glyph it carries: the
copy control is the card's only interactive part and sits in the right
gutter, so a 26px square is the smallest target that reads as tappable
without pushing the text column off the card. `contentInset` is what the
text column reserves for it (gutter + target + breathing room).
]]
local tapTarget = 26
local contentInset = 70
--[[
Compact-row metrics, the same ones the row layout
(`Window:_buildCompactRow`) and this element's row build lay out with: the
row's horizontal padding and the gap its UIListLayout puts between
children. `_minWidth` measures against these rather than against
hard-coded stand-ins, so a wrapped row is never frozen narrower than the
content it actually renders.
]]
local rowPadding = 16
local rowGap = 6

--[[
Resting transparencies once the card has been revealed: the body line
matches every other muted 14px line in the library.
]]
local restingSubtitleTransparency = 0.45

--[[
The trailing glyph rests at the same half transparency the Button's tap
glyph used, and the Dropdown and Collapsible chevrons still do. The card
owns the fade itself: `Window:_revealCommon` only knows the shared parts
(stroke, title, body, leading icon, description), and the shared tap-glyph
reveal it used to read went out with the Button's trailing cursor — so
without this the glyph is built invisible and never appears.
]]
local restingGlyphTransparency = 0.5

-- How long a successful copy keeps the check mark on the card.
local confirmSeconds = 2

--[[
Glyph candidates, resolved through the icon catalog in order: the first
name that exists in the loaded packs wins, so a pack that is missing one
falls through to the next instead of rendering an empty square. `copy` is
the overlapping-rectangles mark; `check` is the confirmation. The
confirmation list runs deeper than the copy list on purpose: a pack that
carries `copy` but not `check` would otherwise leave a successful copy
with no feedback at all, so every affirmative shape the bundled packs
spell is a candidate here.
]]
local copyCandidates = { "copy", "clipboard", "clipboard-copy" }
local checkCandidates = {
    "check",
    "check-check",
    "clipboard-check",
    "circle-check",
    "check-circle",
    "badge-check",
}

--[[
Warn-once flags, kept at module scope rather than on the card. What they
guard is a fact about the host (it has no clipboard API) or about how a
card was built (it carries no link) — not about any one card — so ten
link cards in one host log one warning, not ten.
]]
local warned = {}

local function warnOnce(key: string, message: string)
    if warned[key] then
        return
    end
    warned[key] = true
    log.warn(message)
end

local function environment(): any
    --[[
    `getfenv` is neither guaranteed to exist nor guaranteed to work: a
    sandbox that ships a throwing one must not take the copy path down
    before it reaches the (properly pcall'd) StudioService fallback. The
    shared table is the answer for both cases. The lookup runs inside a
    closure so `getfenv(1)` still answers for the code doing the looking,
    the way the bare call it replaces did.
    ]]
    if getfenv then
        local ok, env = pcall(function()
            return getfenv(1)
        end)
        if ok and type(env) == "table" then
            return env
        end
    end
    return _G
end

local function resolveGlyph(window, candidates): string?
    for _, name in ipairs(candidates) do
        local resolved = window:ResolveIcon(name)
        if resolved ~= nil and resolved ~= name and resolved ~= "" then
            return resolved
        end
    end
    return nil
end

--[[
There is no clipboard in the Roblox API surface the library targets, so
the copy asks the host for one: every executor spells it differently, and
Studio/Rojo spells it differently again. The lookup runs per tap rather
than being cached at load, so a host that installs its clipboard API after
Astra loads is still found.
]]
local globalNames = { "setclipboard", "toclipboard", "setrbxclipboard", "set_clipboard" }
local objectMethods = { "set", "Set", "copy", "Copy" }

local function globalFunction(name: string): any
    local env = environment()
    if type(env) ~= "table" then
        return nil
    end
    local candidate = env[name]
    if typeof(candidate) == "function" then
        return candidate
    end
    return nil
end

local function clipboardWriter(): ((string) -> ())?
    for _, name in ipairs(globalNames) do
        local fn = globalFunction(name)
        if fn then
            return function(text: string)
                return fn(text)
            end
        end
    end

    -- Some hosts expose a `Clipboard` object instead of a global function.
    local env = environment()
    if type(env) == "table" then
        local clipboard = env.Clipboard
        if typeof(clipboard) == "table" then
            for _, name in ipairs(objectMethods) do
                local method = clipboard[name]
                if typeof(method) == "function" then
                    return function(text: string)
                        return method(clipboard, text)
                    end
                end
            end
        end
    end

    -- Studio and Rojo: the only clipboard on the non-executor path.
    local ok, studioService = pcall(function()
        return (game :: any):GetService("StudioService")
    end)
    if ok and studioService and typeof(studioService.CopyToClipboard) == "function" then
        return function(text: string)
            return studioService:CopyToClipboard(text)
        end
    end

    return nil
end

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = tostring(element.name or element.Name or "Link"),
        subtitle = tostring(element.subtitle or element.Subtitle or ""),
        -- The hidden value: stored on the element, never shown as text.
        link = tostring(element.link or element.Link or ""),
        icon = tab.window:ResolveIcon(element.icon or element.Icon),
        description = element.description or element.Description,
        callback = element.callback or element.Callback,
        compact = tab.compact or false,
        --[[
        Which mark the control carries. The card also *is* in its
        confirmation window whenever this reads "check", so the state is
        one field, not two that can disagree.
        ]]
        _glyph = "copy",
        _copyToken = 0,
        -- Snapshot of the tab page's canvas while the copy control is held.
        _pressCanvas = nil,
        -- The watcher that holds that snapshot in place for the hold.
        _pressGuard = nil,
    }, state)

    self.copyImage = resolveGlyph(self.window, copyCandidates)
    self.checkImage = resolveGlyph(self.window, checkCandidates)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    return self
end

function state:_contentHeight(): number
    return if self.subtitle ~= "" then titleHeight + lineGap + subtitleHeight else titleHeight
end

function state:_baseHeight(): number
    return if self.subtitle ~= "" then cardHeight else cardHeightSingle
end

--[[
Every writer of the card's shape goes through here: the height rides the
description's measured extra (elements/description.luau), so a wrapped
helper line grows the card instead of running under it, and the text
column and the copy control stay centred in the base region they belong
to. The compact row has no height to own - the row layout sizes it - so
only the two centred children are re-seated there.
]]
function state:_layoutContent()
    if self.compact then
        return
    end

    local base = self:_baseHeight()
    local centerScale, centerOffset = description.center(self, base)
    self.main.Size = UDim2.new(1, -20, 0, description.height(self, base))
    if self.container then
        self.container.Position = UDim2.new(0, gutter, centerScale, centerOffset)
    end
    if self.copyButton then
        self.copyButton.Position = UDim2.new(1, -gutter, centerScale, centerOffset)
    end
end

function state:_buildFull()
    local window = self.window

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = UDim2.new(1, -20, 0, self:_baseHeight()),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = window:StyleElementBody(self.main)
    self.hoverOverlay = window:CreateHoverOverlay(self.main)

    --[[
    A description grows the card before the rows are placed, exactly as it
    does for the Button and the Stat, so `description.center` below
    answers for the grown card.
    ]]
    description.attach(self)

    local centerScale, centerOffset = description.center(self, self:_baseHeight())

    self.container = window:Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -contentInset, 0, self:_contentHeight()),
        Position = UDim2.new(0, gutter, centerScale, centerOffset),
        AnchorPoint = Vector2.new(0, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = self.main,
    })

    --[[
    Icon first, text column second: the icon is centred against both
    lines, the way a leading mark reads on a card, not against the title
    alone.
    ]]
    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, iconGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Parent = self.container,
    })

    --[[
    The slot exists whether or not the card started with an icon, so
    `SetIcon` can add one later instead of silently doing nothing. Hidden,
    it is out of the list layout's flow; shown, it stays left of the text.
    ]]
    self.iconLabel = window:Create("ImageLabel", {
        Image = self.icon or "",
        Size = UDim2.fromOffset(iconSize, iconSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Visible = self.icon ~= nil,
        ImageTransparency = 1,
        Parent = self.container,
    }, { ImageColor3 = "ContentColor" })

    local textWidthOffset = if self.icon then -(iconSize + iconGap) else 0

    self.textColumn = window:Create("Frame", {
        Name = "Text",
        Size = UDim2.new(1, textWidthOffset, 0, self:_contentHeight()),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = self.container,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, lineGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = self.textColumn,
    })

    self.title = window:Create("TextLabel", {
        Text = locale.t(self.name),
        Size = UDim2.new(1, 0, 0, titleHeight),
        AutomaticSize = Enum.AutomaticSize.None,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = titleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = self.textColumn,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    self.subtitleLabel = window:Create("TextLabel", {
        Text = locale.t(self.subtitle),
        Size = UDim2.new(1, 0, 0, subtitleHeight),
        AutomaticSize = Enum.AutomaticSize.None,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = subtitleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        Visible = self.subtitle ~= "",
        TextTransparency = 1,
        Parent = self.textColumn,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self:_buildCopyControl(self.main, {
        Position = UDim2.new(1, -gutter, centerScale, centerOffset),
        AnchorPoint = Vector2.new(1, 0.5),
    })

    window:_wireElementHover(self, { titleRestKey = "TitlingColor" })
end

function state:_buildCompact()
    local window = self.window

    self.main, self.stroke, self.interact = window:_buildCompactRow(self.tab, self.name)
    self.hoverOverlay = self.interact

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
        Parent = self.interact,
    })

    window:Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = self.interact,
    })

    self.iconLabel = window:Create("ImageLabel", {
        Image = self.icon or "",
        Size = UDim2.fromOffset(iconSize, iconSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Visible = self.icon ~= nil,
        ImageTransparency = 1,
        Parent = self.interact,
    }, { ImageColor3 = "ContentColor" })

    self.title = window:Create("TextLabel", {
        Text = locale.t(self.name),
        Size = UDim2.fromOffset(0, titleHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = titleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = self.interact,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    --[[
    The subtitle rides the row as a muted second half of the title: one
    line, truncated, and dropped entirely when the card has none, so a row
    of bare links is no wider than a row of buttons.
    ]]
    self.subtitleLabel = window:Create("TextLabel", {
        Text = locale.t(self.subtitle),
        Size = UDim2.fromOffset(0, subtitleHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = subtitleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        Visible = self.subtitle ~= "",
        TextTransparency = 1,
        Parent = self.interact,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.subtitleLabel,
    })

    self:_buildCopyControl(self.interact, { LayoutOrder = 3 })

    window:_wireElementHover(self, { titleRestKey = "TitlingColor" })
end

--[[
One control, both builds: a transparent TextButton carrying the glyph, so
the hit target is the whole square and tapping the icon is tapping it.
The glyph starts invisible like every other card part and `_setShown`
fades it in with the rest of the card.
]]
function state:_buildCopyControl(parent, placement)
    local window = self.window

    --[[
    `placement` carries where the control sits: an anchored position in the
    card's right gutter (full card) or a layout order in the row (compact).
    It is merged into the props, because `Create`'s third argument is the
    theme-binding table, not more props.
    ]]
    local props = {
        Name = "Copy",
        Text = "",
        AutoButtonColor = false,
        --[[
        Not selectable: a selectable control inside the tab page's
        ScrollingFrame invites the engine and executor input paths to
        scroll the page to bring it into view on press — part of the copy
        icon "bouncing" the page. Nothing on the card needs keyboard
        navigation (the title carries that role), so the selection path is
        simply closed.
        ]]
        Selectable = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(tapTarget, tapTarget),
        ZIndex = 4,
        Parent = parent,
    }
    for key, value in placement do
        props[key] = value
    end

    self.copyButton = window:Create("TextButton", props)

    self.tapIcon = window:Create("ImageLabel", {
        Name = "CopyIcon",
        Image = self.copyImage or "",
        Size = UDim2.fromOffset(iconSize, iconSize),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Parent = self.copyButton,
    }, { ImageColor3 = "ContentColor" })

    window:ConnectFor(self, self.copyButton.MouseButton1Click, function()
        self:_copy()
    end)

    self:_pinPressToCanvas()
end

--[[
The press itself must not move the page — not even for a frame. The tab
page is an AutomaticCanvasSize ScrollingFrame, and the input paths this
library cannot police — engine selection-into-view, an executor bridge
that does not mark a press on a control inside a scroll surface as
game-processed and lets the page take it as a pan — move `CanvasPosition`
while the card is held. That is the copy tap that drags the card down the
page and springs it back on release.

Writing the snapshot back on release is not enough: the user watches the
card move for as long as they hold it, and every other element in the
library answers a tap without shifting a pixel. So the gesture is pinned
instead. The canvas is snapshotted when the press begins (MouseButton1 or
Touch) and a watcher writes that snapshot straight back for as long as the
press is down, so a pan started under the press is undone on the frame it
lands and the page never leaves where the press found it. Release drops
the watcher and puts the page back where the press found it, in case a
write slipped through after the last guard. A click that arrives without a
press has no snapshot, so it cannot corrupt a scroll the user made in
between.

The gesture is ended from the control (its release, or the click whose
release never reached us) and from the input service, the way the slider
ends a drag: an input bridge that swallows `InputEnded` on the control
must not leave the page pinned still for the rest of the session.
]]
function state:_pinPressToCanvas()
    local window = self.window
    if not self.copyButton then
        return
    end

    --[[
    The scroll surface a press could move: the nearest ScrollingFrame above
    the control. For a card on a tab that is the tab page. For a card inside
    a Group it is still the tab page, reached through the group's own frame
    — a Group stands in for the tab for its children, and its `tabPage` is a
    plain frame with no canvas to hold (asking a frame for its
    `CanvasPosition` is an error, not a zero). A control with no scroll
    surface above it has nothing to pin.
    ]]
    local page: any = self.copyButton
    while page and not page:IsA("ScrollingFrame") do
        page = page.Parent
    end

    if not page then
        return
    end

    local function isPress(input)
        local kind = if input ~= nil then input.UserInputType else nil
        return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
    end

    --[[ A page nothing can write to any more is not a page to pin. ]]
    local function writable()
        return not self.window.unloaded and page.Parent ~= nil
    end

    --[[
    Ends the gesture: drop the watcher, then restore the snapshot, but only
    if the page moved.
    ]]
    local function settle()
        local held = self._pressCanvas
        self._pressCanvas = nil
        if self._pressGuard then
            window:DisconnectMany(self, { self._pressGuard })
            self._pressGuard = nil
        end
        if not held then
            return
        end
        if not writable() then
            return
        end
        local now = page.CanvasPosition
        if now.X ~= held.X or now.Y ~= held.Y then
            page.CanvasPosition = held
        end
    end

    --[[
    Holds the canvas still for the length of the gesture: every write that
    lands while the press is down is answered with the snapshot.
    ]]
    local function hold()
        if self._pressCanvas then
            return
        end
        self._pressCanvas = page.CanvasPosition

        self._pressGuard = window:ConnectFor(self, page:GetPropertyChangedSignal("CanvasPosition"), function()
            local pinned = self._pressCanvas
            if not pinned then
                return
            end
            if not writable() then
                settle()
                return
            end
            local now = page.CanvasPosition
            if now.X ~= pinned.X or now.Y ~= pinned.Y then
                page.CanvasPosition = pinned
            end
        end)
    end

    window:ConnectFor(self, self.copyButton.InputBegan, function(input)
        if not isPress(input) then
            return
        end
        hold()
    end)

    window:ConnectFor(self, self.copyButton.InputEnded, function(input)
        if not isPress(input) then
            return
        end
        settle()
    end)

    --[[ A click whose release never reached us still ends the gesture. ]]
    window:ConnectFor(self, self.copyButton.MouseButton1Click, function()
        settle()
    end)

    --[[
    ...and so does the input service: the release that never reached the
    control (it landed off the window, or the bridge swallowed it) still
    ends the hold, so the page is never pinned for good.
    ]]
    window:ConnectFor(self, coreState.userInputService.InputEnded, function(input)
        if not isPress(input) then
            return
        end
        settle()
    end)

    window:ConnectFor(self, coreState.userInputService.WindowFocusReleased, function()
        settle()
    end)
end

function state:_copy(): boolean
    if self.locked then
        return false
    end

    --[[
    An empty link has nothing to copy. `link` defaults to "" and a card
    built without the prop would otherwise answer the tap with a silent
    success: "" on the clipboard, the check mark, and the callback. The
    check mark means the link is on the clipboard, so it may not be shown
    for a copy that put nothing there.
    ]]
    if self.link == "" then
        self:_reportNothingToCopy()
        return false
    end

    local writer = clipboardWriter()
    if not writer then
        self:_reportUnavailable()
        return false
    end

    --[[
    The result is read as well as the error: some hosts spell a failed
    write as a `false` return (`Clipboard.set`-style APIs) rather than as
    a raised error, and the check mark would lie for both.
    ]]
    local ok, written = pcall(writer, self.link)
    if not ok or written == false then
        self:_reportUnavailable()
        return false
    end

    --[[
    The click haptic is the tap's success answer, so it comes after the
    clipboard has actually taken the link: a tap in a clipboard-less
    environment is a failure, and it should not feel like a hit.
    ]]
    haptic.click()

    self:_confirm()

    if self.callback then
        self.window:_runGuarded(self, self.callback, self.link)
    end

    return true
end

--[[
The confirmation cycle, owned per card. The token makes a second tap
restart the hold instead of being cut short by the first one's timer, and
resetting it is what carries the rule that a card hidden mid-confirmation
comes back on the copy glyph.
]]
function state:_confirm()
    if not self.tapIcon or not self.checkImage then
        return
    end

    self._copyToken += 1
    local token = self._copyToken
    self:_showGlyph("check")

    task.delay(confirmSeconds, function()
        if self._copyToken ~= token or self.window.unloaded then
            return
        end
        --[[
        A removed tab destroys its page and everything on it while the
        window lives on: the token cannot see that, so the card answers
        for itself rather than writing a glyph into a destroyed label.
        ]]
        if not self:_alive() then
            return
        end
        self:_resetCopyState()
    end)
end

--[[
Is the card still in a live tree? A tab taken out of a window destroys its
page (and this card with it) and drops the reference, which leaves a hold
running against instances nothing can see — and nothing left to write to.
]]
function state:_alive(): boolean
    local main = self.main
    if main == nil or self.tab.tabPage == nil then
        return false
    end
    return main.Parent ~= nil
end

function state:_resetCopyState()
    self._copyToken += 1
    self:_showGlyph("copy")
end

--[[
The glyph is written the way the window writes every other image
(`Window:Create` routes image props through the same call): the resolved
icon may be a remote URL the cache rewrites to a local asset before any
Image property can load it, so assigning the raw value here would leave
the control blank on exactly the hosts that need the rewrite.
]]
function state:_showGlyph(which)
    if not self.tapIcon then
        return
    end

    self._glyph = which
    local source = if which == "check" then self.checkImage else self.copyImage
    image.assign(self.tapIcon, "Image", source or "")
end

function state:IsConfirming(): boolean
    return self._glyph == "check"
end

--[[
A failed copy keeps the copy glyph: the check mark means the link is on
the clipboard, so nothing else may show it. The console says why once, and
the notification is the only visible answer the user gets for the tap
(exact duplicates coalesce, so repeated taps refresh one card).
]]
function state:_reportUnavailable()
    warnOnce(
        "clipboard",
        "Astra: no clipboard API was found in this environment, so a Link card cannot copy its URL (looked for setclipboard, toclipboard, setrbxclipboard, Clipboard and StudioService)."
    )

    self.window:Notify({
        title = locale.resolve("Copy failed"),
        content = locale.resolve("This environment has no clipboard API."),
        icon = "clipboard-x",
        duration = 3,
    })
end

--[[
The other way a copy can end up with nothing to put on the clipboard: the
card carries no link. Same shape as the missing-API answer — the glyph
stays on copy, the console says why once, the notification is the user's
only visible answer.
]]
function state:_reportNothingToCopy()
    warnOnce(
        "empty",
        "Astra: a Link card has no link to copy (its `link` prop is empty), so its copy control has nothing to put on the clipboard."
    )

    self.window:Notify({
        title = locale.resolve("Nothing to copy"),
        content = locale.resolve("This link card has no URL."),
        icon = "unlink",
        duration = 3,
    })
end

function state:_applyPresence()
    local hasSubtitle = self.subtitle ~= ""
    if self.subtitleLabel then
        self.subtitleLabel.Visible = hasSubtitle
    end
    if self.container then
        self.container.Size = UDim2.new(1, -contentInset, 0, self:_contentHeight())
    end
    if self.textColumn then
        local offset = if self.icon then -(iconSize + iconGap) else 0
        self.textColumn.Size = UDim2.new(1, offset, 0, self:_contentHeight())
    end
    --[[
    The card's base just changed height (43 with one line, 56 with two), so
    the description line has to be re-seated against the new base the way
    the slider re-seats it for every layout it writes: `attach` pinned it
    once, at the height the card had when it was built, and nothing else
    has moved it since. Without this the line keeps its old offset — 13px
    too low on a card that just dropped its subtitle — where it sits on
    top of the text column or past the card's bottom edge.
    ]]
    description.rebase(self, self:_baseHeight())
    self:_layoutContent()
end

function state:Set(link)
    self.link = if link ~= nil then tostring(link) else ""
end

function state:SetLink(link)
    return self:Set(link)
end

function state:SetTitle(text)
    self.name = if text ~= nil then tostring(text) else ""
    self.window:_bindLocale(self.title, "Text", self.name)
end

function state:SetSubtitle(text)
    self.subtitle = if text ~= nil then tostring(text) else ""
    self.window:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
    self:_applyPresence()
end

function state:SetIcon(icon)
    local resolved = self.window:ResolveIcon(icon)
    self.icon = resolved

    if self.iconLabel then
        image.assign(self.iconLabel, "Image", resolved or "")
        self.iconLabel.Visible = resolved ~= nil
    end

    if self.textColumn then
        local offset = if resolved then -(iconSize + iconGap) else 0
        self.textColumn.Size = UDim2.new(1, offset, 0, self:_contentHeight())
    end
end

--[[
Programmatic copy: the same cycle a tap runs, including the check mark and
the callback, for hosts that drive it from a keybind or a button.
]]
function state:Copy(): boolean
    return self:_copy()
end

function state:_setShown(shown, animate)
    --[[
    The trailing glyph is this card's own part, not one of the shared ones
    `_revealCommon`/`_hideCommon` walk, so it fades with the card here —
    the same way the Dropdown and the collapsible headers fade their own
    chevrons. Hiding it too is what keeps a card that folds away (tab
    switch, collapse, minimise) from leaving a floating mark behind.
    ]]
    self.window:_reveal(self.tapIcon, { ImageTransparency = if shown then restingGlyphTransparency else 1 }, animate)

    if shown then
        self.window:_revealCommon(self, animate)
        self.window:_reveal(self.subtitleLabel, { TextTransparency = restingSubtitleTransparency }, animate)
        --[[
        A revealed card always starts on the copy glyph. For a card that
        was tapped and folded away this is a no-op — hiding already ended
        the confirmation — and it is the answer for the one path that
        never hid: a programmatic `Copy()` on a card nothing was looking
        at, whose hold would otherwise still be running when the card came
        back, showing a check mark nobody tapped for.
        ]]
        if self._glyph ~= "copy" then
            self:_resetCopyState()
        end
    else
        self.window:_hideCommon(self, animate)
        self.window:_reveal(self.subtitleLabel, { TextTransparency = 1 }, animate)
        --[[
        Hiding the card ends its confirmation: a Collapsible Group that
        closed over a check mark reopens on the copy glyph, and each card
        keeps its own cycle regardless of the container.
        ]]
        self:_resetCopyState()
    end
end

--[[
The width a compact row needs before its text starts truncating, measured
against the row that actually renders: the row's own padding, the icon and
the gap the UIListLayout puts after it, the title, the subtitle with its
gap, and the trailing copy target with its gap. `group:_wrapChild` freezes
a wrapped row at exactly this width, so an under-measure here shows up as
a row that clips its own contents (`ClipsDescendants`) instead of one
that wraps.
]]
function state:_minWidth()
    local font = self.window.theme.Font
    local width = rowPadding * 2
    if self.icon then
        width += iconSize + rowGap
    end
    width += functions.textWidth(font, titleSize, locale.resolve(self.name))
    if self.subtitle ~= "" then
        width += rowGap + functions.textWidth(font, subtitleSize, locale.resolve(self.subtitle))
    end
    width += rowGap + tapTarget
    return width
end

moveable(state)
lockable(state)

return state
