local utilities = script.Parent.Parent.Parent.utilities
local windowSizing = require(utilities.windowSizing)
local state = require(utilities.Parent.core.state)

-- [[Values shared by more than one window module. They used to be file-local
-- upvalues at the top of components/window.luau; the window is now split by
-- responsibility, so they live here and each module binds back the handful it
-- actually uses. One definition, same values, no near-miss copies.]]




-- [[Element reveals, theme cross-fades and the notification stack's lane changes all
-- ride the motion service's shared specs (see utilities/motion.luau) instead
-- of per-call TweenInfo values: one vocabulary, one time scale, one owner per
-- animated property.]]

-- [[The beat between the window's shell landing and its page coming in. Long
-- enough that the two read as one entrance in the right order — frame, then
-- content — and short enough that nothing looks like it is waiting for the
-- next thing to happen. Scaled by the motion service, and skipped entirely
-- when animation is switched off.]]
local contentRevealBeat = 0.12

local collapsedWideSize = UDim2.fromOffset(185, 50)
local collapsedIconOnlySize = UDim2.fromOffset(50, 50)
local collapsedPosition = UDim2.new(0.5, 0, 0, 20)


local compactRowHeight = 41

-- [[The drag handle's centre sits this far below the window's bottom edge
-- [[(the same `handleGap` components/drag.luau owns). Every place that puts
-- [[the handle under the window reads it, so the two files cannot drift apart
-- [[and leave the pill floating a few pixels off the window it belongs to.
local dragHandleGap = 22

-- [[The window's own surface, defined once. Everything that has to read as
-- [["the window background" is styled through Window:StyleWindowSurface, so
-- [[every surface that reads as part of the window shares one definition
-- [[instead of near-miss copies: same base colour, same WindowColor
-- [[gradient (theme token + the same rotation/offset, so a theme change moves
-- [[both together) and the same opacity once shown.]]
local windowSurfaceColor = Color3.fromRGB(255, 255, 255)
local windowSurfaceTransparency = 0
local windowSurfaceGradientRotation = 270
local windowSurfaceGradientOffset = Vector2.new(0, -0.1)

local lockScrimTransparency = 0.55
local lockedTextTransparency = 0.55

local viewportCheckInterval = 2

-- Startup is deliberately paced in small, completed-object batches, before the
-- first reveal and after it alike. This prevents a large host script from
-- monopolising a frame while still letting the opening tween render as the
-- remaining controls stream in behind the already-visible shell.
local constructionFrameBudget = 0.003
local constructionInstanceBudget = 48

-- Notifications share one entrance lane. Their 0.6s transitions do
-- not overlap, but already-visible messages are still allowed to remain in
-- their normal stacks while the next one enters.
-- The first open reads as an entrance instead of one large visibility flip:
-- the shell animates in, then `_stageContentReveal` walks the visible page one
-- control per beat (see `_firstShow`). There is exactly one cascade — an older
-- second timer used to walk the same page concurrently, restarting the first
-- cascade's tweens mid-flight through the motion service's cancel-on-overlap.

local function computeSize(mode): UDim2
    local size = state.workspace.CurrentCamera
    return windowSizing.fit(size and size.ViewportSize, mode)
end

local cornerKeys = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" }

local hasPerCornerRadius = (function()
    return (
        pcall(function()
            local instance = Instance.new("UICorner")
            instance.TopLeftRadius = UDim.new(0, 1)
            instance:Destroy()
        end)
    )
end)()

local function layoutKey(layout)
    if layout.mode == "sidebar" and layout.forceCollapsed then
        return "collapsedSidebar"
    end
    return layout.mode
end

return {
    contentRevealBeat = contentRevealBeat,
    collapsedWideSize = collapsedWideSize,
    collapsedIconOnlySize = collapsedIconOnlySize,
    collapsedPosition = collapsedPosition,
    compactRowHeight = compactRowHeight,
    dragHandleGap = dragHandleGap,
    windowSurfaceColor = windowSurfaceColor,
    windowSurfaceTransparency = windowSurfaceTransparency,
    windowSurfaceGradientRotation = windowSurfaceGradientRotation,
    windowSurfaceGradientOffset = windowSurfaceGradientOffset,
    lockScrimTransparency = lockScrimTransparency,
    lockedTextTransparency = lockedTextTransparency,
    viewportCheckInterval = viewportCheckInterval,
    constructionFrameBudget = constructionFrameBudget,
    constructionInstanceBudget = constructionInstanceBudget,
    computeSize = computeSize,
    cornerKeys = cornerKeys,
    hasPerCornerRadius = hasPerCornerRadius,
    layoutKey = layoutKey,
}
