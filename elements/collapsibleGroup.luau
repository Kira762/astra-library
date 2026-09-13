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
    Keybind = function(parent, props) return require(script.Parent.keybind).new(parent, props) end,
    Stat = function(parent, props) return require(script.Parent.stat).new(parent, props) end,
    Progress = function(parent, props) return require(script.Parent.progress).new(parent, props) end,
    Console = function(parent, props) return require(script.Parent.console).new(parent, props) end,
    Section = function(parent, props) return require(script.Parent.section).new(parent, props) end,
    Text = function(parent, props) return require(script.Parent.text).new(parent, props) end,
    Changelog = function(parent, props) return require(script.Parent.changelog).new(parent, props) end,
    Divider = function(parent, props) return require(script.Parent.divider).new(parent, props) end,
    Group = function(parent, props) return require(script.Parent.group).new(parent, props) end,
}
local compactTypes = { Button = true, Toggle = true, Switch = true, Slider = true, Stat = true, Group = true }

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
                child = parent:_add(string.lower(if kind == "Switch" then "Toggle" else kind), spec)
            end
        else
            child = constructors[kind](parent, if kind == "Group" then groupProps(spec) else spec)
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
        description = props.description or props.Description,
        icon = tab.window:ResolveIcon(props.icon or props.Icon),
        deriveFlagFromName = tab.deriveFlagFromName,
        forgetState = props.forgetState or tab.forgetState,
        _expanded = false, _shown = false,
    }, Collapsible)
    local w = self.window
    self.headerHeight = if self.description then 61 else 41
    -- The container only reserves layout space: it must not clip. The header
    -- card fills it edge to edge, and a tight ClipsDescendants parent shaves
    -- the outer half of its 1px stroke (Border mode straddles the edge) plus
    -- the corner arcs on all four sides — the flaw that made these corners
    -- read thinner than every other element. Clipping lives on the body
    -- frame below, mirroring the dropdown: its expanding panel clips, while
    -- its stroked top card never sits inside a tight clipper.
    self.main = w:Create("Frame", {
        Name = self.name, Size = UDim2.new(1, -20, 0, self.headerHeight),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Parent = tab.tabPage,
    })
    self.header = w:Create("Frame", {
        Name = "Header", Size = UDim2.new(1, 0, 0, self.headerHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })
    -- StyleElementBody paints the ElementGradient over a white base, exactly
    -- like every other element surface; binding the base to ElementSurface
    -- here multiplied the gradient and drew the header almost black.
    self.stroke = w:StyleElementBody(self.header)
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
    -- The clipper is 20px wider than the container (10px of transparent
    -- bleed each side) so children — which size themselves at UDim2.new(1,
    -- -20) — land at exactly the header's width instead of compounding the
    -- container's own -20 into a second, narrower inset. The bleed is
    -- transparent and `main` no longer clips, so it reads as nothing; the
    -- only reveal edge is the clipper's own bounds. The content sits 1px
    -- inside those bounds so the first and last child's stroke keep the same
    -- breathing room on every side as standalone elements.
    self.bodyClip = w:Create("Frame", {
        Name = "ContentsClip",
        Position = UDim2.new(0, -10, 0, self.headerHeight + 6),
        Size = UDim2.new(1, 20, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, Parent = self.main,
    })
    self.body = w:Create("Frame", {
        Name = "Contents", Position = UDim2.fromOffset(0, 1),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = self.bodyClip,
    })
    self.tabPage = self.body
    self.contentLayout = w:Create("UIListLayout", {
        Padding = UDim.new(0, 7), FillDirection = Enum.FillDirection.Vertical,
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

function Collapsible:_resize(animate)
    -- (The engine always reports an AbsoluteContentSize; the test harness
    -- only stubs it once content is driven, so an unmeasured layout reads 0.)
    local measured = self.contentLayout.AbsoluteContentSize
    local contentHeight = if measured then measured.Y else 0
    local height = self.headerHeight
    local clipHeight = 0
    if self._expanded then
        -- 7px of tab rhythm between the header and the first child; the
        -- container then ends exactly at the last child, with no dead slack.
        height += 7 + contentHeight
        -- 1px of stroke breathing room above and below the revealed content.
        clipHeight = contentHeight + 2
    end
    local size = UDim2.new(1, -20, 0, height)
    local clipSize = UDim2.new(1, 20, 0, clipHeight)
    self._resizeRevision = (self._resizeRevision or 0) + 1
    local revision = self._resizeRevision
    local function finish()
        if not self.window.unloaded and self.main.Parent and self._resizeRevision == revision and not self._expanded then
            self.body.Visible = false
            self.bodyClip.Visible = false
        end
    end
    if animate and self._shown then
        -- The layout reservation (main) and the reveal mask (bodyClip) ride
        -- the same spec so the mask's edge never leads or trails the frame.
        -- A nil tween means the size is already applied (instant profile, or
        -- already at target), so the settle path runs directly.
        local mainTween = motion.tween(self.main, { Size = size }, "snappy", finish)
        motion.tween(self.bodyClip, { Size = clipSize }, "snappy")
        if not mainTween then finish() end
    else
        motion.cancel(self.main)
        motion.cancel(self.bodyClip)
        self.main.Size = size
        self.bodyClip.Size = clipSize
        finish()
    end
end

function Collapsible:_setExpanded(expanded, animate)
    if self._expanded == expanded then return end
    self._expanded = expanded
    if expanded then
        self.body.Visible = true
        self.bodyClip.Visible = true
        for _, child in ipairs(self.elements) do child:_setShown(self._shown, false) end
    else
        -- End transient editing, but never reset values or trigger callbacks.
        visit(self.elements, function(child)
            if child.__type == "Dropdown" and child._isOpen then child:_close() end
            if child.recording then child:_stopRecording() end
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
    w:_reveal(self.header, { BackgroundTransparency = if shown then w.theme.ElementTransparency or 0 else 1 }, animate)
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.chevron, { ImageTransparency = if shown then 0.4 else 1 }, animate)
    if self.iconLabel then w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate) end
    if self.descriptionLabel then w:_reveal(self.descriptionLabel, { TextTransparency = if shown then 0.45 else 1 }, animate) end
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
