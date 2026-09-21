local state = {}
state.__index = state
state.__type = "Group"

local constants = require(script.Parent.Parent.utilities.moveable)
local Group = require(script.Parent.Parent.utilities.log)
local tab = require(script.Parent.Parent.utilities.ordering)

local props = 8

local direction = {
    button = true,
    toggle = true,
    switch = true,
    stat = true,
    slider = true,
    link = true,
}

function state.new(tab, element)
    element = if typeof(element) == "table" then element else {}

    local frame = string.lower(element.direction or element.Direction or "row")
    local a9 = frame == "column" or frame == "vertical"
    local a10 = not a9
    local a11 = if a10 then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),         window = tab.window,
        direction = a11,
        compact = a10,         forgetState = tab.forgetState,         elements = {},
        deriveFlagFromName = tab.deriveFlagFromName,
    }, state)

        local a12 = tab.direction == Enum.FillDirection.Horizontal

    self.main = self.window:Create("Frame", {
        Name = "Group",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
                        Size = if a10 then UDim2.new(1, -20, 0, 0) else UDim2.new(1, 0, 0, 0),

        Parent = self.tab.tabPage,
    })

    if a12 then
                self.main.Size = UDim2.new(0, 0, 0, 0)
        self.window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Fill,
            Parent = self.main,
        })
    end

        self.tabPage = self.main

    self.layout = self.window:Create("UIListLayout", {
        FillDirection = a11,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, props),
        VerticalAlignment = if a10 then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
        HorizontalAlignment = if a10 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    return self
end

function state:_add(a13, a14)
    -- "Switch" is the declarative alias of the toggle control.
    if a13 == "switch" then
        a13 = "toggle"
    end
    if self.compact and not direction[a13] then
        Group.warn(
            `Astra: a row only holds compact elements (button/toggle/stat/slider), ignoring '{a13}'. Use a column for it.`
        )
        return nil
    end

    local element = require(script.Parent[a13]).new(self, a14)
    if self._collapsibleChild then
        element._collapsibleChild = true
    end
    table.insert(self.elements, element)
    tab(element, #self.elements * 10)
    self.window:_restoreLate(element)

    if self.compact then
        self:_wrapChild(element)
    end
    self:_reflowRow()
    local ownerTab = self.tab
    local contentsVisible = true
    while ownerTab.tab do
        if (ownerTab.__type == "CollapsibleGroup" or ownerTab.__type == "Isolated") and not ownerTab._expanded then contentsVisible = false end
        ownerTab = ownerTab.tab
    end
    if contentsVisible and not self.window.hidden and not self.window.minimised and self.window.selectedTab == ownerTab then
        element:_setShown(true, true)
    else
        ownerTab._elementsPending = true
    end
    self.window:_constructionCheckpoint(false)

    return element
end

function state:_reflowRow()
    if self.direction ~= Enum.FillDirection.Horizontal then
        return
    end

    local a15 = #self.elements > 0
    for _, element in self.elements do
        if element.__type ~= "Group" then
            a15 = false
            break
        end
    end

    self.layout.Padding = if a15 then UDim.new(0, -10) else UDim.new(0, props)
end

function state:_wrapChild(element)
    self.layout.Wraps = true
    self.layout.HorizontalFlex = Enum.UIFlexAlignment.Fill

            element._widthManaged = true

    local a16 = if element._minWidth then element:_minWidth() else 0
    if a16 > 0 then
        element.main.AutomaticSize = Enum.AutomaticSize.None
        element.main.Size = UDim2.new(0, a16, element.main.Size.Y.Scale, element.main.Size.Y.Offset)
    end
end

function state:CreateButton(a17)
    return self:_add("button", a17)
end
function state:CreateToggle(a18)
    return self:_add("toggle", a18)
end
function state:CreateStat(a20)
    return self:_add("stat", a20)
end
function state:CreateSlider(a21)
    return self:_add("slider", a21)
end
function state:CreateDropdown(a22)
    return self:_add("dropdown", a22)
end
function state:CreateSection(a23)
    return self:_add("section", a23)
end
function state:CreateText(a24)
    return self:_add("text", a24)
end
function state:CreateFooter(props)
    return self:_add("footer", props)
end
function state:CreateDivider(a25)
    return self:_add("divider", a25)
end

function state:CreateLink(a30)
    return self:_add("link", a30)
end

function state:_addGroup(a26)
    a26 = if typeof(a26) == "table" then table.clone(a26) else {}

        if self.direction == Enum.FillDirection.Horizontal then
                        self.layout.VerticalAlignment = Enum.VerticalAlignment.Top
                        if self.tab.direction ~= Enum.FillDirection.Horizontal then
            self.main.Size = UDim2.new(1, 0, 0, 0)
        end
    end

    local a27 = state.new(self, a26)
    if self._collapsibleChild then
        a27._collapsibleChild = true
    end
    table.insert(self.elements, a27)
    a27.main.LayoutOrder = #self.elements * 10
    self:_reflowRow()
    return a27
end

function state:CreateGroup(a28)
    return self:_addGroup(a28)
end

function state:_moveElement(element, a29)
    local a30 = table.find(self.elements, element)
    if not a30 then
        return
    end
    table.remove(self.elements, a30)
    a29 = math.clamp(a29, 1, #self.elements + 1)
    table.insert(self.elements, a29, element)
    for i, el in self.elements do
        tab(el, i * 10)
    end
end

function state:_setShown(a31, a32)
    for _, el in self.elements do
        el:_setShown(a31, a32)
    end
end

function state:_refreshTheme()
    for _, el in self.elements do
        if el._refreshTheme then
            el:_refreshTheme()
        end
    end
end

constants(state)

return state
