local utilities = script.Parent.Parent.utilities
local motion = require(utilities.motion)
local locale = require(utilities.locale)
local haptic = require(utilities.HapticEngine)
local moveable = require(utilities.moveable)
local lockable = require(utilities.lockable)
local ordering = require(utilities.ordering)

local Collapsible = {}
Collapsible.__index = Collapsible
Collapsible.__type = "CollapsibleGroup"

-- This is a declarative adapter over the real controls, not a second set of
-- implementations. Keep the list in sync with Tab's supported element types.
local constructors = {
    Button = function(parent, props) return require(script.Parent.button).new(parent, props) end,
    Toggle = function(parent, props) return require(script.Parent.toggle).new(parent, props) end,
    Switch = function(parent, props) return require(script.Parent.toggle).new(parent, props) end,
    Slider = function(parent, props) return require(script.Parent.slider).new(parent, props) end,
    Dropdown = function(parent, props) return require(script.Parent.dropdown).new(parent, props) end,
    Input = function(parent, props) return require(script.Parent.input).new(parent, props) end,
    Link = function(parent, props) return require(script.Parent.link).new(parent, props) end,
    Stat = function(parent, props) return require(script.Parent.stat).new(parent, props) end,
    Section = function(parent, props) return require(script.Parent.section).new(parent, props) end,
    Text = function(parent, props) return require(script.Parent.text).new(parent, props) end,
    Footer = function(parent, props) return require(script.Parent.footer).new(parent, props) end,
    Changelog = function(parent, props) return require(script.Parent.changelog).new(parent, props) end,
    Divider = function(parent, props) return require(script.Parent.divider).new(parent, props) end,
    Group = function(parent, props) return require(script.Parent.group).new(parent, props) end,
}
local compactTypes = { Button = true, Toggle = true, Switch = true, Slider = true, Stat = true, Group = true, Link = true }

-- [[Which corners of the header band carry the container's arcs. Open, the band
-- [[is only the top of the card: its bottom edge is the straight divider, so the
-- [[bottom corners must stay square or they would notch into the revealed body.
-- [[Closed, the band *is* the whole card, so its bottom corners have to carry the
-- [[container's bottom arcs exactly like its top ones carry the top.]]
local bandCorners = {
    expanded = { "TopLeftRadius", "TopRightRadius" },
    collapsed = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" },
}

local function validate(definitions, path, ancestors, depth)
    assert(type(definitions) == "table", path .. " must be an array")
    assert(not ancestors[definitions] and depth <= 32, path .. ": cyclic or excessively deep group definitions")
    ancestors[definitions] = true
    local count = 0
    for key in pairs(definitions) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0, path .. " must be an array")
        count += 1
    end
    for index = 1, count do
        local spec = definitions[index]
        local location = path .. "[" .. index .. "]"
        assert(type(spec) == "table", location .. " must be an element definition")
        local kind = spec.type or spec.Type
        assert(kind ~= "CollapsibleGroup", location .. ": CollapsibleGroups cannot be nested, including inside Groups")
        assert(kind ~= "Isolated", location .. ": Isolated containers cannot be nested, including inside Groups")
        assert(constructors[kind], location .. ": unsupported element type " .. tostring(kind))
        if kind == "Group" then
            validate(spec.elements or {}, location .. ".elements", ancestors, depth + 1)
        else
            assert(spec.elements == nil, location .. ": only ordinary Groups can contain elements")
        end
    end
    ancestors[definitions] = nil
end

local function groupProps(spec)
    local props = table.clone(spec)
    -- Ordinary row Groups support compact controls only. A declarative Group
    -- containing other control types becomes a column so no element is dropped.
    for _, child in ipairs(spec.elements or {}) do
        if not compactTypes[child.type or child.Type] then
            props.direction = "column"
            break
        end
    end
    return props
end

local function buildChildren(parent, definitions)
    for _, spec in ipairs(definitions) do
        local kind = spec.type or spec.Type
        local child
        if parent.__type == "Group" then
            if kind == "Group" then
                child = parent:CreateGroup(groupProps(spec))
            else
                child = parent:_add(string.lower(kind), spec)
            end
        else
            child = constructors[kind](parent, if kind == "Group" then groupProps(spec) else spec)
            child._collapsibleChild = true
            table.insert(parent.elements, child)
            ordering(child, #parent.elements * 10)
            parent.window:_restoreLate(child)
        end
        if kind == "Group" then
            buildChildren(child, spec.elements or {})
        end
        parent.window:_constructionCheckpoint(false)
    end
end

local function visit(elements, callback)
    for _, child in ipairs(elements) do
        callback(child)
        if child.elements then visit(child.elements, callback) end
    end
end

function Collapsible.new(tab, props)
    assert(tab and tab.__type == "Tab", "CollapsibleGroups must be direct children of a Tab")
    props = if type(props) == "table" then props else {}
    validate(props.elements or {}, "CollapsibleGroup.elements", {}, 0)
    local self = setmetatable({
        tab = tab, window = tab.window, elements = {}, connections = {},
        name = props.name or props.Name or "Collapsible Group",
        icon = tab.window:ResolveIcon(props.icon or props.Icon),
        description = props.description or props.Description,
        deriveFlagFromName = tab.deriveFlagFromName,
        forgetState = props.forgetState or tab.forgetState,
        _expanded = false, _shown = false,
    }, Collapsible)
    local w = self.window
    -- [[One muted 14px line under the title band, the element-description
    -- [[recipe: the header grows by the line's 20px band (41 -> 61) instead of
    -- [[letting the line run into the title row or the first child.]]
    self.headerHeight = if self.description then 61 else 41
    -- [[One connected card, two surfaces: the header band rides the standard
    -- [[element gradient, the revealed body sits on the darker window surface
    -- [[and a 1px stroke-colored divider separates them — the unified
    -- [[container the design reference shows, instead of a header card and a
    -- [[detached panel floating a gap apart.
    self.bodyPad = 10
    self.main = w:Create("Frame", {
        Name = self.name, Size = UDim2.new(1, -20, 0, self.headerHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Parent = tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })
    -- [[The container's own surface is the element surface (the white base
    -- [[under the ElementGradient recipe every element uses), so the card's
    -- [[silhouette — its rounded top corners included — reads as the header
    -- [[band. Roblox rounds a GuiObject's own surface but never clips its
    -- [[descendants to the arcs, so the band below carries the same radius on
    -- [[its top corners and the body clipper paints the darker window surface
    -- [[the revealed body sits on.
    w:Create("UIGradient", { Rotation = 270, Parent = self.main }, { Color = "ElementGradient" })
    w:Create("UICorner", { Parent = self.main }, { CornerRadius = "ElementCornerRadius" })
    -- [[The container masks its own descendants to its bounds; the rounded
    -- [[silhouette comes from the container's corner plus the band's matching
    -- [[top-corner radius.]]
    -- [[UIStroke supports Border/Contextual modes, not Interior; Border keeps
    -- [[the outline on the container without reading an invalid enum member.]]
    self.stroke = w:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 1, Parent = self.main,
    }, { Color = "ElementStroke", Transparency = "ElementStrokeTransparency" })
    self.headerSurface = w:Create("Frame", {
        Name = "HeaderSurface", Size = UDim2.new(1, 0, 0, self.headerHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })
    -- [[The plain white base under the ElementGradient is the standard element
    -- [[surface recipe; a themed base would multiply the gradient near-black.
    w:Create("UIGradient", { Rotation = 270, Parent = self.headerSurface }, { Color = "ElementGradient" })
    -- [[The band is a child of the container, and Roblox only rounds a
    -- [[GuiObject's own surface — descendants paint over the arcs. Left
    -- [[square, the band filled the card's top-left and top-right corners and
    -- [[squared off the silhouette the stroke draws. Rounding the band's top
    -- [[corners with the container's own radius makes the two arcs one, and
    -- [[_fitHeaderCorners adds the bottom pair while the group is closed.
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
    -- Header metrics mirror the Text element: 20px gutters, a 6px icon gap,
    -- a 16px TitlingColor title and a 14px body line at 0.45 transparency.
    local textX = if self.icon then 42 else 20
    if self.icon then
        self.iconLabel = w:Create("ImageLabel", {
            Image = self.icon, Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1, ImageTransparency = 1, Parent = self.header,
        }, { ImageColor3 = "ContentColor" })
    end
    self.title = w:Create("TextLabel", {
        Text = locale.t(self.name), Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.new(1, -(textX + 42), 0, 41), BackgroundTransparency = 1,
        TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1, Parent = self.header,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })
    if self.description then
        self.descriptionLabel = w:Create("TextLabel", {
            Name = "Description",
            Text = locale.t(self.description), Position = UDim2.fromOffset(textX, 37),
            Size = UDim2.new(1, -(textX + 20), 0, 18), BackgroundTransparency = 1,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 1, Parent = self.header,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })
    end
    self.chevron = w:Create("ImageLabel", {
        Image = w:ResolveIcon("chevron-right"), Position = UDim2.new(1, -36, 0, 12),
        Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
        ImageTransparency = 1, Rotation = 0, Parent = self.header,
    }, { ImageColor3 = "ContentColor" })
    self.interact = w:Create("TextButton", {
        Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false, ZIndex = 6, Parent = self.header,
    })
    -- [[The reveal mask spans the container edge to edge and rides its bottom
    -- [[edge, so the mask's floor always matches the container's own corner
    -- [[arcs. Children keep their normal width recipes — a card at
    -- [[UDim2.new(1, -20) of this full-width body lands exactly one gutter
    -- [[inside the container on each side, the inset the reference shows,
    -- [[instead of running edge to edge against the container stroke.
    self.bodyClip = w:Create("Frame", {
        Name = "ContentsClip",
        Position = UDim2.fromOffset(0, self.headerHeight + 1),
        Size = UDim2.new(1, 0, 1, -(self.headerHeight + 1)),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })
    -- [[The revealed body sits on the darker window surface, and the clipper
    -- [[is flush with the container's bottom edge, so it paints that surface
    -- [[for the whole body region and keeps the container's bottom arcs (its
    -- [[top corners stay square — the divider above is a straight line).
    w:Create("UIGradient", { Rotation = 270, Parent = self.bodyClip }, { Color = "WindowColor" })
    w:_roundCorners(self.bodyClip, { "BottomLeftRadius", "BottomRightRadius" }, "ElementCornerRadius")
    -- [[body lives inside the clipper, which already starts under the divider,
    -- [[so only the top pad offsets it here.
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
    w:ConnectFor(self, self.interact.Activated, function()
        if self.locked or not w:_interactive() then return end
        haptic.click()
        self:_setExpanded(not self._expanded, true)
    end)
    w:_wireElementHover(self, { target = self.header, titleRestKey = "TitlingColor" })
    buildChildren(self, props.elements or {})
    return self
end

-- [[Collapsed, the band is the whole card — there is no body under it — so it
-- [[has to carry the container's bottom arcs too, or its square bottom corners
-- [[paint over the silhouette the stroke draws and the card reads as rounded at
-- [[the top and uneven at the bottom. Expanded, the clipper below takes the
-- [[bottom edge (it is flush with the container's floor and keeps the same
-- [[radius token), so the band squares off against the straight divider. One
-- [[token for both states means the corner never changes radius, only which
-- [[surface owns it, and the clipper keeps the arcs for every frame in between:
-- [[the collapse rounds the band as it settles, and the opening squares it
-- [[before the body is revealed underneath.]]
function Collapsible:_fitHeaderCorners()
    self.window:_setRoundedCorners(
        self.headerCorner,
        if self._expanded then bandCorners.expanded else bandCorners.collapsed,
        "ElementCornerRadius"
    )
end

function Collapsible:_resize(animate)
    -- (The engine always reports an AbsoluteContentSize; the test harness
    -- only stubs it once content is driven, so an unmeasured layout reads 0.)
    local measured = self.contentLayout.AbsoluteContentSize
    local contentHeight = if measured then measured.Y else 0
    local height = self.headerHeight
    if self._expanded then
        -- divider + top pad + content + bottom pad: the container ends one
        -- gutter under the last child card, the same inset its sides keep,
        -- with no dead slack.
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
        -- [[Runs on every settle, in both states: the corner set follows the
        -- [[height the container has actually reached, so a reversal mid-tween
        -- [[(a stale revision returns above) can never leave the band's bottom
        -- [[arcs on a card that is about to show its body, or off a card that
        -- [[has just released it.]]
        self:_fitHeaderCorners()
    end
    if animate and self._shown then
        -- The reveal mask derives its bounds from the container, so a single
        -- tween grows both in lockstep; the mask's edge never leads or trails
        -- the frame. A nil tween means the size is already applied (instant
        -- profile, or already at target), so the settle path runs directly.
        local mainTween = motion.tween(self.main, { Size = size }, "snappy", finish)
        if not mainTween then finish() end
    else
        motion.cancel(self.main)
        self.main.Size = size
        finish()
    end
end

function Collapsible:_setExpanded(expanded, animate)
    if self._expanded == expanded then return end
    self._expanded = expanded
    if expanded then
        -- [[Square the band off against the divider before the body surfaces
        -- [[under it, so the first revealed frame already shows a straight
        -- [[header/body seam instead of two notches at the band's floor.
        self:_fitHeaderCorners()
        self.body.Visible = true
        self.bodyClip.Visible = true
        self.divider.Visible = true
        for _, child in ipairs(self.elements) do child:_setShown(self._shown, false) end
    else
        -- End transient editing, but never reset values or trigger callbacks.
        visit(self.elements, function(child)
            if child.__type == "Dropdown" and child._isOpen then child:_close() end
            if child.recording then child:_stopRecording() end
            -- [[Same rule as the open dropdown: a transient state that belongs
            -- [[to a visible card cannot survive the body being put away, so a
            -- [[Link that was confirming its copy comes back on the copy mark
            -- [[instead of greeting the next open with a stale check.]]
            if child.__type == "Link" then child:_resetCopyState() end
            if child.__type == "Input" then
                local ok, focused = pcall(function() return child.input:IsFocused() end)
                if ok and focused then
                    -- Cancel the uncommitted edit, so hiding a container cannot
                    -- silently commit input or trigger its value callback.
                    child.input.Text = child.value
                    child.input:ReleaseFocus()
                end
            end
        end)
    end
    local chevronProps = { Rotation = if expanded then 90 else 0 }
    if animate then
        motion.tween(self.chevron, chevronProps, "snappy")
    else
        motion.set(self.chevron, chevronProps)
    end
    self:_resize(animate)
end

function Collapsible:_setShown(shown, animate)
    self._shown = shown
    local w = self.window
    w:_reveal(self.main, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.headerSurface, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.bodyClip, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.divider, { BackgroundTransparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.chevron, { ImageTransparency = if shown then 0.4 else 1 }, animate)
    if self.iconLabel then w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate) end
    if self.descriptionLabel then
        w:_reveal(self.descriptionLabel, { TextTransparency = if shown then 0.45 else 1 }, animate)
    end
    if self._expanded then
        for _, child in ipairs(self.elements) do child:_setShown(shown, animate) end
    end
    self:_resize(false)
end

function Collapsible:_refreshTheme()
    self:_setShown(self._shown, false)
    for _, child in ipairs(self.elements) do
        if child._refreshTheme then child:_refreshTheme() end
    end
end

function Collapsible:_moveElement(element, index)
    local old = table.find(self.elements, element)
    if not old then return end
    table.remove(self.elements, old)
    table.insert(self.elements, math.clamp(index, 1, #self.elements + 1), element)
    for i, child in ipairs(self.elements) do ordering(child, i * 10) end
end

moveable(Collapsible)
lockable(Collapsible)
return Collapsible
