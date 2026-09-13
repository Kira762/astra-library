local state = {}
state.__index = state
state.__type = "Descriptor"

local constants = require(script.Parent.Parent.utilities.locale)

function state.new(tab, Descriptor)
    Descriptor = if typeof(Descriptor) == "table" then Descriptor else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        description = Descriptor.description or Descriptor.Description or "",
    }, state)

    self.main = self.window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 0, 0),

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 0),
        Text = constants.t(self.description),
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,

                TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

        self.window:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 15),
        Parent = self.main,
    })

    return self
end

function state:Remove()
    self.main:Destroy()
end

return state
