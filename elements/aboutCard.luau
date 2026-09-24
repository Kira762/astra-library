--[[
CreateAboutCard: one card that carries an About page — a brand header, a
row of data tiles and an optional trailing action band.

The recipe is fixed and every string in it is host copy:

  * header — a leading icon plus a title/subtitle stack,
  * rows — one to three compact data tiles, each a leading icon with a
    label above its value. Every tile shares one line evenly: the three-row
    About recipe stays three-across instead of leaving its last tile alone
    on a second line,
  * action (optional) — a tappable band carrying an icon, a label, a
    subtitle and the card's trailing chevron. It is the card's trailing
    row, which is why the data rows stop at three: a fourth would be the
    action itself.

Every surface stays inside the shared theme tokens — the card is the
standard element body, each tile and the action band use ElementSurface,
and the nested badge uses that same control family — so the card themes
itself like every other element instead of hard-coding a dark inset.
]]

local state = {}
state.__index = state
state.__type = "AboutCard"

local utilities = script.Parent.Parent.utilities

local image = require(script.Parent.Parent.images.image)
local haptic = require(utilities.HapticEngine)
local locale = require(utilities.locale)
local lockable = require(utilities.lockable)
local motion = require(utilities.motion)
local moveable = require(utilities.moveable)

--[[
The rows section is capped at three tiles so the compact status band keeps
useful room for every label and value; the action remains its trailing row.
]]
local maxRows = 3

--[[
Card metrics. The card keeps the library's 20px gutter. Data tiles are a
deliberately compact 48px band: the smaller inset and badge leave enough
copy room for three equal tiles on the normal card width without making the
third row wrap below the first two.
]]
local gutter = 20
local sectionGap = 14
local headerIconSize = 38
local headerIconGap = 14
local headerTitleSize = 20
local headerTitleHeight = 26
local headerSubtitleSize = 14
local headerSubtitleHeight = 18
local headerLineGap = 2
local tileHeight = 48
local tileGap = 8
local tilePad = 8
local badgeSize = 28
local badgeIconSize = 14
local badgeGap = 8
local tileLabelSize = 11
local tileLabelHeight = 13
local tileValueSize = 14
local tileValueHeight = 17
local tileLineGap = 1
local tileTextHeight = tileLabelHeight + tileLineGap + tileValueHeight
local actionHeight = 56
local actionHeightSingle = 41
local actionPad = 14
local actionIconSize = 16
local actionIconGap = 12
local actionLabelSize = 16
local actionLabelHeight = 19
local actionSubtitleSize = 14
local actionSubtitleHeight = 16
local actionChevronSize = 16
local actionChevronInset = 16

--[[
Resting transparencies once the card has been revealed: the muted body
lines match every other 14px line in the library, the trailing chevron
matches the Isolated header's, and both step up while the pointer is over
the action band.
]]
local restingMutedTransparency = 0.45
local restingChevronTransparency = 0.4
local hoveredChevronTransparency = 0.15

--[[
What a tracked part rests at while the card is shown. Every tracked
property is a transparency, so "hidden" is always 1 and only the shown
value needs a rule. `background`, `stroke` and `muted` read the theme and
the rest are literals.
]]
local restValue = {
    background = function(self)
        return self.window:_elementBackgroundTransparency(self)
    end,
    stroke = function(self)
        return self.window:_elementStrokeTransparency(self, false)
    end,
    muted = function()
        return restingMutedTransparency
    end,
    chevron = function()
        return restingChevronTransparency
    end,
    icon = function()
        return 0
    end,
    solid = function()
        return 0
    end,
}

local function read(properties, lower, upper)
    local value = properties[lower]
    if value == nil then
        value = properties[upper]
    end
    return value
end

--[[
Text slots normalise through here: numbers are legal values (a version or
a build number), and an empty string is treated as "no copy" so the slot
that owns it can drop out of the layout instead of rendering a blank band.
]]
local function textOf(value)
    if value == nil then
        return nil
    end
    return tostring(value)
end

local function textOrNil(value)
    local text = textOf(value)
    if text == "" then
        return nil
    end
    return text
end

--[[
A nested surface uses the theme's element fill, not the much darker window
gradient. The surrounding stroke still separates each tile and action band
from the card, while their colour stays in the same hierarchy as the rest
of Astra's controls.
]]
local function insetSurface(window, frame)
    window:Create("UICorner", { Parent = frame }, { CornerRadius = "ElementCornerRadius" })
    return window:Create("UIStroke", { Transparency = 1, Parent = frame }, {
        Color = "ElementStroke",
        Transparency = "ElementStrokeTransparency",
    })
end

function state.new(tab, props)
    assert(tab, "Missing argument #1 (Tab expected)")
    props = if type(props) == "table" then props else {}

    local rows = read(props, "rows", "Rows")
    if rows == nil then
        rows = {}
    end
    assert(type(rows) == "table", "AboutCard.rows must be an array of rows")
    if #rows > maxRows then
        error(`Astra:CreateAboutCard — at most {maxRows} data rows are supported, got {#rows}`, 0)
    end

    local window = tab.window
    local self = setmetatable({
        tab = tab,
        window = window,
        name = textOrNil(read(props, "name", "Name")) or "About",
        subtitle = textOrNil(read(props, "subtitle", "Subtitle")),
        icon = window:ResolveIcon(read(props, "icon", "Icon")),
        rows = {},
        --[[
        Every painted part of the card in one list (see `restValue`), so a
        reveal is one loop and a part cannot be forgotten in only one of
        the show and hide paths.
        ]]
        parts = {},
        deriveFlagFromName = tab.deriveFlagFromName,
        forgetState = props.forgetState or tab.forgetState,
        _shown = false,
    }, state)

    local action = read(props, "action", "Action")
    local actionCallback = if type(action) == "table" then read(action, "callback", "Callback") else nil
    self:_build(rows, action)
    lockable.register(self, props, {
        enabled = type(actionCallback) == "function",
        id = read(props, "id", "Id") or (if type(action) == "table" then read(action, "id", "Id") else nil),
        usage = if type(action) == "table" then read(action, "usage", "Usage") else nil,
        lockLevel = if type(action) == "table" then read(action, "lockLevel", "LockLevel") else nil,
        lockGroup = if type(action) == "table" then read(action, "lockGroup", "LockGroup") else nil,
    })

    return self
end

-- Track one painted part: `{ instance, property, rest kind }`.
function state:_track(instance, property, kind)
    table.insert(self.parts, { instance, property, kind })
end

function state:_rest(kind)
    return restValue[kind](self)
end

function state:_paint(shown, animate)
    for _, part in ipairs(self.parts) do
        local value = if shown then self:_rest(part[3]) else 1
        self.window:_reveal(part[1], { [part[2]] = value }, animate)
    end
end

function state:_build(rows, action)
    local window = self.window

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = window:StyleElementBody(self.main)

    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, gutter),
        PaddingBottom = UDim.new(0, gutter),
        PaddingLeft = UDim.new(0, gutter),
        PaddingRight = UDim.new(0, gutter),
        Parent = self.main,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, sectionGap),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })

    self:_buildHeader()
    self:_buildRows(rows)
    if type(action) == "table" then
        self:_buildAction(action)
    end
end

function state:_buildHeader()
    local window = self.window
    local height = self:_headerHeight()

    self.header = window:Create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, height),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = self.main,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, headerIconGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.header,
    })

    --[[
    The leading slot exists whether or not the card started with an icon,
    so `SetIcon` can add one later instead of silently doing nothing.
    Hidden, it is out of the list layout's flow.
    ]]
    self.iconLabel = window:Create("ImageLabel", {
        Name = "Icon",
        Image = self.icon or "",
        Size = UDim2.fromOffset(headerIconSize, headerIconSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Visible = self.icon ~= nil,
        ImageTransparency = 1,
        Parent = self.header,
    }, { ImageColor3 = "ContentColor" })

    self.headerText = window:Create("Frame", {
        Name = "Text",
        Size = UDim2.new(1, if self.icon then -(headerIconSize + headerIconGap) else 0, 0, height),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = self.header,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, headerLineGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.headerText,
    })

    self.title = window:Create("TextLabel", {
        Name = "Title",
        Text = locale.t(self.name),
        Size = UDim2.new(1, 0, 0, headerTitleHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = headerTitleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = self.headerText,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })
    window:_bindLocale(self.title, "Text", self.name)

    self.subtitleLabel = window:Create("TextLabel", {
        Name = "Subtitle",
        Text = locale.t(self.subtitle or ""),
        Size = UDim2.new(1, 0, 0, headerSubtitleHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = headerSubtitleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        Visible = self.subtitle ~= nil,
        TextTransparency = 1,
        Parent = self.headerText,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    if self.subtitle then
        window:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
    end
    self:_track(self.subtitleLabel, "TextTransparency", "muted")
end

function state:_headerHeight()
    return if self.subtitle then headerTitleHeight + headerLineGap + headerSubtitleHeight else headerTitleHeight
end

--[[
The header re-derives from the subtitle slot: adding or releasing the
second line reflows the band and the text column from one place.
]]
function state:_applyHeaderMetrics()
    local height = self:_headerHeight()
    self.header.Size = UDim2.new(1, 0, 0, height)
    self.headerText.Size = UDim2.new(1, if self.icon then -(headerIconSize + headerIconGap) else 0, 0, height)
    self.subtitleLabel.Visible = self.subtitle ~= nil
end

function state:_buildRows(rows)
    local window = self.window

    --[[
    The tiles are placed by `_layoutRows`, not by a list layout, so one to
    three equal slices can account for their gaps without wrapping.
    ]]
    self.rowsHost = window:Create("Frame", {
        Name = "Rows",
        Size = UDim2.new(1, 0, 0, tileHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Visible = #rows > 0,
        Parent = self.main,
    })

    for index, row in ipairs(rows) do
        self.rows[index] = self:_buildRow(index, row)
    end
    self:_layoutRows()
    --[[
    Scale-based slices follow resizes themselves; refreshing here also
    keeps `_rowLines` and any runtime metric changes in sync.
    ]]
    window:ConnectFor(self, self.main:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_layoutRows()
    end)
end

function state:_buildRow(index, row)
    local window = self.window
    row = if type(row) == "table" then row else {}

    local entry = {
        icon = window:ResolveIcon(read(row, "icon", "Icon")),
        label = textOf(read(row, "label", "Label")) or "",
        value = textOf(read(row, "value", "Value")) or "",
    }

    entry.main = window:Create("Frame", {
        Name = `Row{index}`,
        Size = UDim2.fromOffset(0, tileHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = index,
        Parent = self.rowsHost,
    }, {
        BackgroundColor3 = "ElementSurface",
        BackgroundTransparency = "ElementTransparency",
    })
    entry.stroke = insetSurface(window, entry.main)

    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, tilePad),
        PaddingBottom = UDim.new(0, tilePad),
        PaddingLeft = UDim.new(0, tilePad),
        PaddingRight = UDim.new(0, tilePad),
        Parent = entry.main,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, badgeGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = entry.main,
    })

    --[[
    The badge is the small square the row's icon sits in. It carries the
    content surface and the element stroke, so the mark reads as a chip on
    the tile rather than as a floating glyph.
    ]]
    entry.badge = window:Create("Frame", {
        Name = "Badge",
        Size = UDim2.fromOffset(badgeSize, badgeSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Parent = entry.main,
    }, { BackgroundColor3 = "ElementSurface", BackgroundTransparency = "ElementTransparency" })
    window:Create("UICorner", { Parent = entry.badge }, { CornerRadius = "ElementCornerRadius" })
    entry.badgeStroke = window:Create("UIStroke", { Transparency = 1, Parent = entry.badge }, {
        Color = "ElementStroke",
        Transparency = "ElementStrokeTransparency",
    })

    entry.badgeIcon = window:Create("ImageLabel", {
        Name = "Icon",
        Image = entry.icon or "",
        Size = UDim2.fromOffset(badgeIconSize, badgeIconSize),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = entry.icon ~= nil,
        ImageTransparency = 1,
        Parent = entry.badge,
    }, { ImageColor3 = "ContentColor" })

    entry.textColumn = window:Create("Frame", {
        Name = "Text",
        Size = UDim2.new(1, 0, 0, tileTextHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = entry.main,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, tileLineGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = entry.textColumn,
    })

    entry.labelLabel = window:Create("TextLabel", {
        Name = "Label",
        Text = locale.t(entry.label),
        Size = UDim2.new(1, 0, 0, tileLabelHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = tileLabelSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = entry.textColumn,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    window:_bindLocale(entry.labelLabel, "Text", entry.label)

    entry.valueLabel = window:Create("TextLabel", {
        Name = "Value",
        Text = entry.value,
        Size = UDim2.new(1, 0, 0, tileValueHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = tileValueSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        TextTransparency = 1,
        Parent = entry.textColumn,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })

    self:_track(entry.main, "BackgroundTransparency", "background")
    self:_track(entry.stroke, "Transparency", "stroke")
    self:_track(entry.badge, "BackgroundTransparency", "background")
    self:_track(entry.badgeStroke, "Transparency", "stroke")
    self:_track(entry.badgeIcon, "ImageTransparency", "icon")
    self:_track(entry.labelLabel, "TextTransparency", "muted")
    self:_track(entry.valueLabel, "TextTransparency", "solid")

    self:_applyRowIcon(entry)

    return entry
end

--[[
The tile's text column reserves exactly the badge plus its gap, so a row
without an icon hands the whole tile to its label and value.
]]
function state:_applyRowIcon(entry)
    local hasIcon = entry.icon ~= nil
    entry.badge.Visible = hasIcon
    image.assign(entry.badgeIcon, "Image", entry.icon or "")
    entry.textColumn.Size = UDim2.new(1, if hasIcon then -(badgeSize + badgeGap) else 0, 0, tileTextHeight)
end

--[[
The tiles always occupy one compact line. Their equal slices make the
Version / Build / Author recipe read as one three-part status row instead
of a two-column grid with an oversized orphan below it. The first layout
can run before Roblox has measured the card; scale-based width keeps that
pass correct and automatically follows later window resizing without a
minimum-width packing threshold.
]]
function state:_layoutRows()
    local count = #self.rows
    if count == 0 then
        return
    end

    self._rowLines = { {} }
    self.rowsHost.Size = UDim2.new(1, 0, 0, tileHeight)
    local gapShare = tileGap * (count - 1) / count
    for index, entry in ipairs(self.rows) do
        table.insert(self._rowLines[1], index)
        entry.main.Size = UDim2.new(1 / count, -gapShare, 0, tileHeight)
        entry.main.Position = UDim2.new((index - 1) / count, tileGap * (index - 1) / count, 0, 0)
    end
end

function state:_buildAction(action)
    local window = self.window

    self.action = {
        name = textOf(read(action, "name", "Name")) or "",
        subtitle = textOrNil(read(action, "subtitle", "Subtitle")),
        icon = window:ResolveIcon(read(action, "icon", "Icon")),
        callback = read(action, "callback", "Callback"),
    }

    local height = if self.action.subtitle then actionHeight else actionHeightSingle
    local leading = actionPad + (if self.action.icon then actionIconSize + actionIconGap else 0)
    local contentHeight = if self.action.subtitle
        then actionLabelHeight + tileLineGap + actionSubtitleHeight
        else actionLabelHeight

    self.actionBand = window:Create("Frame", {
        Name = "Action",
        Size = UDim2.new(1, 0, 0, height),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        Parent = self.main,
    }, {
        BackgroundColor3 = "ElementSurface",
        BackgroundTransparency = "ElementTransparency",
    })
    self.actionStroke = insetSurface(window, self.actionBand)

    self.actionIcon = window:Create("ImageLabel", {
        Name = "Icon",
        Image = self.action.icon or "",
        Size = UDim2.fromOffset(actionIconSize, actionIconSize),
        Position = UDim2.new(0, actionPad, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = self.action.icon ~= nil,
        ImageTransparency = 1,
        Parent = self.actionBand,
    }, { ImageColor3 = "ContentColor" })

    self.actionText = window:Create("Frame", {
        Name = "Text",
        Size = UDim2.new(1, -(leading + actionChevronInset + actionChevronSize + actionIconGap), 0, contentHeight),
        Position = UDim2.new(0, leading, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = self.actionBand,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, tileLineGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.actionText,
    })

    self.actionLabel = window:Create("TextLabel", {
        Name = "Label",
        Text = locale.t(self.action.name),
        Size = UDim2.new(1, 0, 0, actionLabelHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = actionLabelSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = self.actionText,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })
    window:_bindLocale(self.actionLabel, "Text", self.action.name)

    self.actionSubtitle = window:Create("TextLabel", {
        Name = "Subtitle",
        Text = locale.t(self.action.subtitle or ""),
        Size = UDim2.new(1, 0, 0, actionSubtitleHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = actionSubtitleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        Visible = self.action.subtitle ~= nil,
        TextTransparency = 1,
        Parent = self.actionText,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    if self.action.subtitle then
        window:_bindLocale(self.actionSubtitle, "Text", self.action.subtitle)
    end

    --[[
    The trailing chevron is part of the band, never changeable and never
    removable, so no setter reaches it (the same rule the Isolated header
    follows).
    ]]
    self.actionChevron = window:Create("ImageLabel", {
        Name = "Chevron",
        Image = window:ResolveIcon("chevron-right") or "",
        Size = UDim2.fromOffset(actionChevronSize, actionChevronSize),
        Position = UDim2.new(1, -actionChevronInset, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Parent = self.actionBand,
    }, { ImageColor3 = "ContentColor" })

    --[[
    The tap target is the whole band, so tapping anywhere on it — not only
    on the chevron — fires the action.
    ]]
    self.actionButton = window:Create("TextButton", {
        Name = "Tap",
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
        Parent = self.actionBand,
    })
    -- If the action has a callback, lock only its tap surface; the card's
    -- informational header and data rows remain fully readable.
    self.lockSurface = self.actionButton

    self:_track(self.actionBand, "BackgroundTransparency", "background")
    self:_track(self.actionStroke, "Transparency", "stroke")
    self:_track(self.actionIcon, "ImageTransparency", "icon")
    self:_track(self.actionLabel, "TextTransparency", "solid")
    self:_track(self.actionSubtitle, "TextTransparency", "muted")
    self:_track(self.actionChevron, "ImageTransparency", "chevron")

    window:ConnectFor(self, self.actionButton.MouseButton1Click, function()
        self:_activate()
    end)
    self:_wireActionHover()
end

function state:_activate()
    if self.locked or not self.window:_interactive() then
        return
    end
    haptic.click()
    if self.action.callback then
        self.window:_runGuarded(self, self.action.callback)
    end
end

--[[
The band is the card's interactive surface, so it carries the library's
own hover language (Window:_wireElementHover's recipe) scoped to itself:
the card stays still, the band's stroke, label and chevron answer. The
theme keys are read live, so a runtime theme change still flows through.
]]
function state:_wireActionHover()
    local window = self.window
    local theme = window.theme

    window:ConnectFor(self, self.actionButton.MouseEnter, function()
        if not window:_interactive() then
            return
        end
        motion.tween(self.actionStroke, {
            Transparency = window:_elementStrokeTransparency(self, true),
            Color = theme.ElementStrokeHover,
        }, "snappy")
        motion.tween(self.actionLabel, { TextColor3 = theme.ElementTextHoverColor }, "snappy")
        motion.tween(self.actionChevron, { ImageTransparency = hoveredChevronTransparency }, "snappy")
    end)

    window:ConnectFor(self, self.actionButton.MouseLeave, function()
        motion.tween(self.actionStroke, {
            Transparency = window:_elementStrokeTransparency(self, false),
            Color = theme.ElementStroke,
        }, "snappy")
        motion.tween(self.actionLabel, { TextColor3 = theme.TitlingColor }, "snappy")
        motion.tween(self.actionChevron, { ImageTransparency = restingChevronTransparency }, "snappy")
    end)
end

function state:_setShown(shown, animate)
    self._shown = shown
    if shown then
        self.window:_revealCommon(self, animate)
    else
        self.window:_hideCommon(self, animate)
    end
    self:_paint(shown, animate)
end

--[[
A theme change re-reads every resting value the card paints with, exactly
as a reveal does.
]]
function state:_refreshTheme()
    self:_setShown(self._shown, false)
end

--[[
Public setters. The header icon slot mirrors the Isolated container's; the
row setter rewrites one tile in place instead of rebuilding the row, so a live
status card never re-measures its layout.
]]
function state:SetTitle(title)
    self.name = textOf(title) or ""
    self.window:_bindLocale(self.title, "Text", self.name)
end

function state:SetSubtitle(subtitle)
    self.subtitle = textOrNil(subtitle)
    if self.subtitle then
        self.window:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
    else
        self.subtitleLabel.Text = ""
    end
    self:_applyHeaderMetrics()
end

function state:SetIcon(icon)
    self.icon = self.window:ResolveIcon(icon)
    image.assign(self.iconLabel, "Image", self.icon or "")
    self.iconLabel.Visible = self.icon ~= nil
    self:_applyHeaderMetrics()
    --[[
    The icon slot is tracked, so it lands at its resting transparency for
    whichever state the card is in right now.
    ]]
    self:_setShown(self._shown, false)
end

function state:SetRow(index, row)
    local entry = self.rows[index]
    assert(entry, `AboutCard:SetRow — no row at index {index}`)
    row = if type(row) == "table" then row else {}

    local changed = false

    local label = read(row, "label", "Label")
    if label ~= nil then
        entry.label = textOf(label) or ""
        self.window:_bindLocale(entry.labelLabel, "Text", entry.label)
        changed = true
    end

    local value = read(row, "value", "Value")
    if value ~= nil then
        entry.value = textOf(value) or ""
        entry.valueLabel.Text = entry.value
        changed = true
    end

    local icon = read(row, "icon", "Icon")
    if icon ~= nil then
        entry.icon = self.window:ResolveIcon(icon)
        self:_applyRowIcon(entry)
        changed = true
    end

    --[[
    Refresh the equal-slice row after an icon changes the text reservation;
    copy is truncated inside its own compact tile rather than wrapping the
    last tile onto another line.
    ]]
    if changed then
        self:_layoutRows()
        self:_setShown(self._shown, false)
    end
end

moveable(state)
lockable(state)

return state
