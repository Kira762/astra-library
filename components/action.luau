local Action = {}
Action.__index = Action
Action.__type = "Action"

local utilities = script.Parent.Parent.utilities

local state = require(utilities.Parent.core.state)
local log = require(utilities.log)
local haptic = require(utilities.HapticEngine)
local motion = require(utilities.motion)

function Action.new(window, props)
    props = if typeof(props) == "table" then props else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = props.name or props.Name or "Action",
        icon = assert(window:ResolveIcon(props.icon or props.Icon), "Missing argument (Icon expected)"),
        callback = assert(props.callback or props.Callback, "Missing argument (Function expected)"),
        linkedTab = props.linkedTab or props.LinkedTab,
    }, Action)

    self.action = self.window:Create("Frame", {
        Name = self.name,
        BorderSizePixel = 0,
        LayoutOrder = -(props.order or 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Parent = self.window.actionContainer,
    })

    self.iconLabel = self.window:Create("ImageLabel", {
        Image = self.icon,
        Size = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Parent = self.action,
    }, { ImageColor3 = "ActionColor" })

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,
        Parent = self.action,
    })

    -- [[Optional unread dot: a fixed red badge pinned to the]]
    -- [[action's top-right corner. Created after the]]
    -- [[interact button so it renders above it; frames sink no input.]]
    if props.badge or props.Badge then
        self.badge = self.window:Create("Frame", {
            Name = "Badge",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 1, 0, -1),
            Size = UDim2.fromOffset(8, 8),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(239, 68, 68),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = self.action,
        })
        self.window:Create("UICorner", {
            CornerRadius = UDim.new(0, 0),
            Parent = self.badge,
        })
    end

    local function idleTransparency()
        if self.window.unloaded then
            return
        end
        if not self.window:_settled() then
            return
        end
        if self.linkedTab and self.window.selectedTab == self.linkedTab then
            return
        end
        if self.isLit and self:isLit() then
            return
        end
        motion.tween(self.iconLabel, { ImageTransparency = 0.6 }, "snappy")
    end

    self.window:Connect(self.interact.MouseButton1Click, function()
        haptic.click()
        task.spawn(function()
            local ok, err = pcall(self.callback)
            if not ok then
                log.warn(
                    `Astra encountered an error, with the callback for a {self.__type} component named '{self.name}':`
                )
                log.print(err)
            end
            idleTransparency()
        end)
    end)

    self.window:Connect(self.interact.MouseEnter, function()
        if not self.window:_interactive() then
            return
        end
        motion.tween(self.iconLabel, { ImageTransparency = 0.2 }, "snappy")
    end)

    self.window:Connect(self.interact.MouseLeave, idleTransparency)

    return self
end

function Action:SetBadge(shown, animate)
    if not self.badge or self.window.unloaded then
        return
    end
    self.badge.Visible = shown == true
    local target = if shown then 0 else 1
    if animate == false or not self.window:_interactive() then
        self.badge.BackgroundTransparency = target
        return
    end
    motion.tween(self.badge, { BackgroundTransparency = target }, "snappy")
end


return Action
