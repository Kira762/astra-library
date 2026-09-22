local utilities = script.Parent.Parent.utilities
local motion = require(utilities.motion)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local moveable = require(utilities.moveable)
local lockable = require(utilities.lockable)
local ordering = require(utilities.ordering)
local image = require(script.Parent.Parent.images.image)

local Isolated = {}
Isolated.__index = Isolated
Isolated.__type = "Isolated"

--[[
The Isolated container is the Changelog's own home: a collapsed header
card — icon, title/subtitle stack and the built-in expansion chevron —
that reveals a body of release-history entries exactly the way a
CollapsibleGroup reveals its controls. It is a strict container: the
only accepted child definition is a Changelog, everything else errors
at construction instead of rendering a control the container cannot
lay out. The right-hand chevron is part of the container itself: it is
always drawn, never changeable and never removable, so no setter for
it exists on purpose.
]]
local GUARD_MESSAGE = "Astra:CreateIsolated — only Changelog elements can be placed inside Isolated"

local function changelogConstructor(parent, props)
    return require(script.Parent.changelog).new(parent, props)
end

--[[
Which corners of the header band carry the container's arcs. Open, the band
is only the top of the card: its bottom edge is the straight divider, so the
bottom corners must stay square or they would notch into the revealed body.
Closed, the band *is* the whole card, so its bottom corners have to carry the
container's bottom arcs exactly like its top ones carry the top.
]]
local bandCorners = {
    expanded = { "TopLeftRadius", "TopRightRadius" },
    collapsed = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" },
}

local function validate(definitions, path)
    assert(type(definitions) == "table", path .. " must be an array")
    local count = 0
    for key in pairs(definitions) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0, path .. " must be an array")
        count += 1
    end
    for index = 1, count do
        local spec = definitions[index]
        local kind = if type(spec) == "table" then spec.type or spec.Type else nil
        --[[
        One rule, one message: whatever is not a Changelog definition —
        another control type, a nested container, a built element or a
        non-table value — is rejected here, before any instance exists.
        Level 0 keeps the message exact so hosts can match on it.
        ]]
        if kind ~= "Changelog" or (type(spec) == "table" and spec.elements ~= nil) then
            error(GUARD_MESSAGE, 0)
        end
    end
end

local function read(properties, lower, upper)
    local value = properties[lower]
    if value == nil then
        value = properties[upper]
    end
    return value
end

local function buildChildren(parent, definitions)
    for _, spec in ipairs(definitions) do
        local child = changelogConstructor(parent, spec)
        child._collapsibleChild = true
        table.insert(parent.elements, child)
        ordering(child, #parent.elements * 10)
        parent.window:_restoreLate(child)
        parent.window:_constructionCheckpoint(false)
    end
end

local function visit(elements, callback)
    for _, child in ipairs(elements) do
        callback(child)
        if child.elements then visit(child.elements, callback) end
    end
end

function Isolated.new(tab, props)
    assert(tab and tab.__type == "Tab", "Isolated containers must be direct children of a Tab")
    props = if type(props) == "table" then props else {}
    validate(props.elements or {}, "Isolated.elements")
    local self = setmetatable({
        tab = tab, window = tab.window, elements = {}, connections = {},
        name = tostring(read(props, "name", "Name") or read(props, "title", "Title") or "View Changelog"),
        subtitle = read(props, "subtitle", "Subtitle"),
        icon = tab.window:ResolveIcon(read(props, "icon", "Icon")),
        deriveFlagFromName = tab.deriveFlagFromName,
        forgetState = props.forgetState or tab.forgetState,
        _expanded = false, _shown = false,
    }, Isolated)
    self.subtitle = if self.subtitle ~= nil and tostring(self.subtitle) ~= ""
        then tostring(self.subtitle)
        else nil
    local w = self.window
    --[[
    Two-line header recipe, shared with the CollapsibleGroup's title plus
    description band: the title keeps its 41px band and the muted 14px
    subtitle rides the 20px band under it (41 -> 61). Without a subtitle
    the header is the plain 41px band.
    ]]
    self.headerHeight = if self.subtitle then 61 else 41
    local iconY = math.floor((self.headerHeight - 16) / 2)
    --[[
    One connected card, two surfaces: the header band rides the standard
    element gradient, the revealed body sits on the darker window surface
    and a 1px stroke-colored divider separates them.
    ]]
    self.bodyPad = 10
    self.main = w:Create("Frame", {
        Name = self.name, Size = UDim2.new(1, -20, 0, self.headerHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Parent = tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })
    w:Create("UIGradient", { Rotation = 270, Parent = self.main }, { Color = "ElementGradient" })
    w:Create("UICorner", { Parent = self.main }, { CornerRadius = "ElementCornerRadius" })
    self.stroke = w:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 1, Parent = self.main,
    }, { Color = "ElementStroke", Transparency = "ElementStrokeTransparency" })
    self.headerSurface = w:Create("Frame", {
        Name = "HeaderSurface", Size = UDim2.new(1, 0, 0, self.headerHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })
    w:Create("UIGradient", { Rotation = 270, Parent = self.headerSurface }, { Color = "ElementGradient" })
    self.headerCorner = w:_roundCorners(self.headerSurface, { "TopLeftRadius", "TopRightRadius" }, "ElementCornerRadius")
    self:_fitHeaderCorners()
    self.divider = w:Create("Frame", {
        Name = "HeaderDivider", Position = UDim2.fromOffset(0, self.headerHeight),
        Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
        BackgroundTransparency = 1, Visible = false, Parent = self.main,
    }, { BackgroundColor3 = "ElementStroke", BackgroundTransparency = "ElementStrokeTransparency" })
    self.header = w:Create("Frame", {
        Name = "Header", Size = UDim2.new(1, 0, 0, self.headerHeight),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.main,
    })
    self.hoverOverlay = w:CreateHoverOverlay(self.header)
    --[[
    Header metrics mirror the CollapsibleGroup header: 20px gutters, a 6px
    icon gap, a 16px TitlingColor title and a 14px muted line under it.
    The icon and the chevron sit vertically centred on whichever band the
    header currently is, so the collapsed card reads as the reference:
    icon, two-line stack, chevron.
    ]]
    local textX = if self.icon then 42 else 20
    if self.icon then
        self.iconLabel = w:Create("ImageLabel", {
            Image = self.icon, Position = UDim2.fromOffset(20, iconY), Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1, ImageTransparency = 1, Parent = self.header,
        }, { ImageColor3 = "ContentColor" })
    end
    self.title = w:Create("TextLabel", {
        Text = locale.t(self.name), Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.new(1, -(textX + 42), 0, 41), BackgroundTransparency = 1,
        TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1, Parent = self.header,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })
    w:_bindLocale(self.title, "Text", self.name)
    --[[
    The subtitle label always exists so SetSubtitle can fill it at
    runtime; without a subtitle it carries empty text and the header
    stays on the single-line band.
    ]]
    self.subtitleLabel = w:Create("TextLabel", {
        Name = "Subtitle",
        Text = locale.t(self.subtitle or ""), Position = UDim2.fromOffset(textX, 37),
        Size = UDim2.new(1, -(textX + 20), 0, 18), BackgroundTransparency = 1,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1, Parent = self.header,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })
    if self.subtitle then
        w:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
    end
    --[[
    Built-in expansion affordance: always rendered, never changeable and
    never removable. There is deliberately no setter that reaches it.
    ]]
    self.chevron = w:Create("ImageLabel", {
        Image = w:ResolveIcon("chevron-right"), Position = UDim2.new(1, -36, 0, iconY),
        Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
        ImageTransparency = 1, Rotation = 0, Parent = self.header,
    }, { ImageColor3 = "ContentColor" })
    self.interact = w:Create("TextButton", {
        Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false, ZIndex = 6, Parent = self.header,
    })
    self.bodyClip = w:Create("Frame", {
        Name = "ContentsClip",
        Position = UDim2.fromOffset(0, self.headerHeight + 1),
        Size = UDim2.new(1, 0, 1, -(self.headerHeight + 1)),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })
    w:Create("UIGradient", { Rotation = 270, Parent = self.bodyClip }, { Color = "WindowColor" })
    w:_roundCorners(self.bodyClip, { "BottomLeftRadius", "BottomRightRadius" }, "ElementCornerRadius")
    self.body = w:Create("Frame", {
        Name = "Contents", Position = UDim2.fromOffset(0, self.bodyPad),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = self.bodyClip,
    })
    self.tabPage = self.body
    self.contentLayout = w:Create("UIListLayout", {
        Padding = UDim.new(0, self.bodyPad), FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.body,
    })
    w:ConnectFor(self, self.contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        self:_resize(true)
    end)
    --[[
    Use the same primary-click signal as Astra's other full-row controls.
    Some executor input bridges do not forward GuiButton.Activated, which
    left an otherwise visible Isolated header unable to open. Roblox maps
    touch taps to MouseButton1Click too, so the whole header stays usable on
    both pointer and touch input without wiring two signals and double-firing.
    ]]
    w:ConnectFor(self, self.interact.MouseButton1Click, function()
        if self.locked or not w:_interactive() then return end
        haptic.click()
        self:_setExpanded(not self._expanded, true)
    end)
    w:_wireElementHover(self, { target = self.header, titleRestKey = "TitlingColor" })
    buildChildren(self, props.elements or {})
    return self
end

--[[
Collapsed, the band is the whole card — there is no body under it — so it
has to carry the container's bottom arcs too, or its square bottom corners
paint over the silhouette the stroke draws and the card reads as rounded at
the top and uneven at the bottom. Expanded, the clipper below takes the
bottom edge (it is flush with the container's floor and keeps the same
radius token), so the band squares off against the straight divider.
]]
function Isolated:_fitHeaderCorners()
    self.window:_setRoundedCorners(
        self.headerCorner,
        if self._expanded then bandCorners.expanded else bandCorners.collapsed,
        "ElementCornerRadius"
    )
end

--[[
Every frame that derives its metrics from the header band — the band
itself, the divider seam, the reveal mask, the centred icon/chevron row
and the text stack — is re-derived here, so a runtime SetSubtitle that
adds or releases the second line reflows the whole card from one place.
]]
function Isolated:_applyHeaderMetrics()
    self.headerHeight = if self.subtitle then 61 else 41
    local iconY = math.floor((self.headerHeight - 16) / 2)
    local textX = if self.icon then 42 else 20
    if self.iconLabel then
        self.iconLabel.Position = UDim2.fromOffset(20, iconY)
    end
    self.title.Position = UDim2.fromOffset(textX, 0)
    self.title.Size = UDim2.new(1, -(textX + 42), 0, 41)
    self.subtitleLabel.Position = UDim2.fromOffset(textX, 37)
    self.subtitleLabel.Size = UDim2.new(1, -(textX + 20), 0, 18)
    self.chevron.Position = UDim2.new(1, -36, 0, iconY)
    self.headerSurface.Size = UDim2.new(1, 0, 0, self.headerHeight)
    self.header.Size = UDim2.new(1, 0, 0, self.headerHeight)
    self.divider.Position = UDim2.fromOffset(0, self.headerHeight)
    self.bodyClip.Position = UDim2.fromOffset(0, self.headerHeight + 1)
    self.bodyClip.Size = UDim2.new(1, 0, 1, -(self.headerHeight + 1))
end

function Isolated:_resize(animate)
    --[[
    (The engine always reports an AbsoluteContentSize; the test harness
    only stubs it once content is driven, so an unmeasured layout reads 0.)
    ]]
    local measured = self.contentLayout.AbsoluteContentSize
    local contentHeight = if measured then measured.Y else 0
    local height = self.headerHeight
    if self._expanded then
        --[[
        divider + top pad + content + bottom pad: the container ends one
        gutter under the last child card, the same inset its sides keep,
        with no dead slack.
        ]]
        height += 1 + self.bodyPad + contentHeight + self.bodyPad
    end
    local size = UDim2.new(1, -20, 0, height)
    self._resizeRevision = (self._resizeRevision or 0) + 1
    local revision = self._resizeRevision
    local function finish()
        if self.window.unloaded or not self.main.Parent or self._resizeRevision ~= revision then
            return
        end
        if not self._expanded then
            self.body.Visible = false
            self.bodyClip.Visible = false
            self.divider.Visible = false
        end
        self:_fitHeaderCorners()
    end
    if animate and self._shown then
        local mainTween = motion.tween(self.main, { Size = size }, "snappy", finish)
        if not mainTween then finish() end
    else
        motion.cancel(self.main)
        self.main.Size = size
        finish()
    end
end

function Isolated:_setExpanded(expanded, animate)
    if self._expanded == expanded then return end
    self._expanded = expanded
    if expanded then
        self:_fitHeaderCorners()
        self.body.Visible = true
        self.bodyClip.Visible = true
        self.divider.Visible = true
        for _, child in ipairs(self.elements) do child:_setShown(self._shown, false) end
    end
    local chevronProps = { Rotation = if expanded then 90 else 0 }
    if animate then
        motion.tween(self.chevron, chevronProps, "snappy")
    else
        motion.set(self.chevron, chevronProps)
    end
    self:_resize(animate)
end

function Isolated:_setShown(shown, animate)
    self._shown = shown
    local w = self.window
    w:_reveal(self.main, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.headerSurface, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.bodyClip, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.divider, { BackgroundTransparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.subtitleLabel, { TextTransparency = if shown then 0.45 else 1 }, animate)
    w:_reveal(self.chevron, { ImageTransparency = if shown then 0.4 else 1 }, animate)
    if self.iconLabel then w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate) end
    if self._expanded then
        for _, child in ipairs(self.elements) do child:_setShown(shown, animate) end
    end
    self:_resize(false)
end

function Isolated:_refreshTheme()
    self:_setShown(self._shown, false)
    for _, child in ipairs(self.elements) do
        if child._refreshTheme then child:_refreshTheme() end
    end
end

function Isolated:_moveElement(element, index)
    local old = table.find(self.elements, element)
    if not old then return end
    table.remove(self.elements, old)
    table.insert(self.elements, math.clamp(index, 1, #self.elements + 1), element)
    for i, child in ipairs(self.elements) do ordering(child, i * 10) end
end

--[[
Public expansion API: the same CollapsibleGroup-style tween, addressable
from the host instead of only from a header tap.
]]
function Isolated:Expand(animate)
    self:_setExpanded(true, animate ~= false)
end

function Isolated:Collapse(animate)
    self:_setExpanded(false, animate ~= false)
end

function Isolated:Toggle(animate)
    self:_setExpanded(not self._expanded, animate ~= false)
end

--[[
The changeable header slots. The chevron is not among them: it is built
into the container and no setter reaches it.
]]
function Isolated:SetTitle(title)
    self.name = tostring(title)
    self.window:_bindLocale(self.title, "Text", self.name)
end

function Isolated:SetSubtitle(subtitle)
    local next = if subtitle ~= nil and tostring(subtitle) ~= "" then tostring(subtitle) else nil
    self.subtitle = next
    if next then
        self.window:_bindLocale(self.subtitleLabel, "Text", next)
    else
        self.subtitleLabel.Text = ""
    end
    self:_applyHeaderMetrics()
    self:_resize(self._shown)
end

function Isolated:SetIcon(icon)
    local resolved = self.window:ResolveIcon(icon)
    self.icon = resolved
    if resolved then
        if not self.iconLabel then
            self.iconLabel = self.window:Create("ImageLabel", {
                Image = resolved, Position = UDim2.fromOffset(20, math.floor((self.headerHeight - 16) / 2)),
                Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1, ImageTransparency = if self._shown then 0 else 1,
                Parent = self.header,
            }, { ImageColor3 = "ContentColor" })
        else
            image.assign(self.iconLabel, "Image", resolved)
        end
    elseif self.iconLabel then
        self.window:DestroySubtree(self.iconLabel)
        self.iconLabel = nil
    end
    self:_applyHeaderMetrics()
end

moveable(Isolated)
lockable(Isolated)
return Isolated
