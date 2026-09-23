local state = {}
state.__index = state
state.__type = "TabSection"

local constants = require(script.Parent.Parent.utilities.locale)
local TabSection = require(script.Parent.Parent.utilities.log)

local tab = 20

local props = 6

local name = 3

local function icon(window)
    for _, tab in window.tabs do
        if not tab.neglectSelector then
            return true
        end
    end
    return #window.tabSections > 0
end

function state.new(window, element)
    element = if typeof(element) == "table" then element else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = element.name or element.Name or "Section",
        icon = window:ResolveIcon(element.icon or element.Icon),
    }, state)

    if window.layout.mode ~= "sidebar" then
        if not window._warnedTabSection then
            window._warnedTabSection = true
            TabSection.warn("Astra: Window:CreateSection needs the sidebar layout; it does nothing on the top strip.")
        end
        self.inert = true
        return self
    end

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = UDim2.new(1, -tab * 2, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        Visible = false,
        Parent = window.tabList,
    })

    self.padding = window:Create("UIPadding", {
        PaddingTop = UDim.new(0, if icon(window) then props else 0),
        PaddingBottom = UDim.new(0, name),

        Parent = self.main,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,

        Parent = self.main,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 0,

            ImageTransparency = 1,
            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = constants.t(self.name),

        Size = UDim2.new(1, if self.icon then -22 else 0, 0, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    return self
end

function state:_setShown(frame, a10)
    if not self.main then
        return
    end
    local w = self.window
    w:_reveal(self.title, { TextTransparency = if frame then 0.6 else 1 }, a10)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if frame then 0.65 else 1 }, a10)
    end
end

function state:_setVisible(a11)
    if self.main then
        self.main.Visible = a11
    end
end

function state:Remove()
    local a12 = table.find(self.window.tabSections, self)
    if a12 then
        table.remove(self.window.tabSections, a12)
    end
    self.window:DestroySubtree(self.main)
    self.main = nil
end

return state
