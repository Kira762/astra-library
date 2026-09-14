local search = require(script.Parent.Parent.components.search)
local functions = require(script.Parent.Parent.functions)
local utilities = script.Parent.Parent.utilities
local constants = require(utilities.constants)

local Topbar = {}

local FADE_WIDTH = 24

-- [[The window surface's WindowColor gradient runs bottom-to-top (rotation]]
-- [[270), so the colour behind the strip — at the top of the window — is]]
-- [[the sequence's last keypoint. Flattening it is the same trick the]]
-- [[bottom fade uses, so a theme can never drift the two apart.]]
local function topSurfaceColor(color)
    local keypoints = functions.toColorSequence(color).Keypoints
    return ColorSequence.new(keypoints[#keypoints].Value)
end

local function buildFade(window, layout, inset, name, anchoredRight, transparentEdge)
    -- [[transparentEdge is the frame edge that must be fully clear:]]
    -- [[left for the right fade (it dissolves towards the visible tabs),]]
    -- [[right for the left fade.]]
    local fade = window:Create("Frame", {
        Name = name,
        Size = UDim2.fromOffset(FADE_WIDTH, layout.tabStripHeight),
        Position = if anchoredRight
            then UDim2.new(1, -(inset + FADE_WIDTH), 0, layout.tabStripTop)
            else UDim2.new(0, inset, 0, layout.tabStripTop),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = constants.zIndex.tabFade,

        Parent = window.main,
    })

    window:Create("UIGradient", {
        Rotation = 0,
        Transparency = if transparentEdge == "left"
            then NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            })
            else NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        Parent = fade,
    }, { Color = { "WindowColor", topSurfaceColor } })

    return fade
end

function Topbar.Build(window, layout)
    -- [[The strip is inset from the window edge on both sides (instead of]]
    -- [[using UIPadding, which would scroll away with the content), so a]]
    -- [[tab that overflows clips inside the window — never touching its]]
    -- [[border — and the edge fades below mark where tabs go off.]]
    local inset = layout.tabStripInset or 22

    window.tabList = window:Create("ScrollingFrame", {
        Name = "Tabs",
        Active = true,
        Size = UDim2.new(1, -inset * 2, 0, layout.tabStripHeight),
        Position = UDim2.new(0, inset, 0, layout.tabStripTop),
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ScrollingDirection = Enum.ScrollingDirection.X,
        Parent = window.main,
    })
    window.tabListLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = window.tabList,
    })

    window.tabFadeLeft = buildFade(window, layout, inset, "TabFadeLeft", false, "right")
    window.tabFadeRight = buildFade(window, layout, inset, "TabFadeRight", true, "left")

    -- [[Canvas content changes (tabs added/removed) and scrolling move the]]
    -- [[clipping edges; the window's Size covers resizes and the entrance]]
    -- [[tween. _refreshTabStripChrome skips writes when nothing changed.]]
    window:Connect(window.tabList:GetPropertyChangedSignal("CanvasSize"), function()
        window:_refreshTabStripChrome()
    end)
    window:Connect(window.tabList:GetPropertyChangedSignal("CanvasPosition"), function()
        window:_refreshTabStripChrome()
    end)
    window:Connect(window.main:GetPropertyChangedSignal("Size"), function()
        window:_refreshTabStripChrome()
    end)
    window:_refreshTabStripChrome()
end

function Topbar.ApplyWidth(window)
    search.railWidth(window, 0)
    window.elements.Size = UDim2.new(1, 0, 1, -window.layout.chromeHeight)
    window.bottomFade.Size = UDim2.new(1, 0, window.layout.fadeSize.Y.Scale, window.layout.fadeSize.Y.Offset)
end

return Topbar
