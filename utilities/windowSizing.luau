local layoutMetrics = require(script.Parent.layouts)
local coreState = require(script.Parent.Parent.core.state)

local breakpoints = {}

export type Profile = {
	defaultSize: Vector2,
	minSize: Vector2,
	maxSize: Vector2?,
	mobileSize: Vector2,
	maxOccupancyX: number,
	maxOccupancyY: number?,
	marginFloorX: number,
	marginFloorY: number,
	topbarClearance: number?,
	maxAspectRatio: number,
	minAspectRatio: number?,
	widthCompensation: number?,
	chromeHeight: number,
}

local minTrackedViewport = 200

--[[
Astra's phone tier: viewports below this width are phone-sized. The same
breakpoint gates the fixed mobile profile in `isMobileViewport`.
]]
local mobileBreakpoint = 700

--[[
Fixed mobile footprint (per layout mode). Mobile no longer recomputes its
window from live viewport occupancy: it opens at one stable size, so
rotation / on-screen keyboard / inset changes never resize the window.
Desktop/PC keeps the responsive profiles below: 600x420 default target,
responsive shrink on smaller screens, maxSize caps so large screens stay
responsive without growing into an oversized window.
]]
local profiles = {
	sidebar = {
		defaultSize = Vector2.new(600, 420),
		minSize = Vector2.new(540, 360),
		maxSize = Vector2.new(760, 500),
		mobileSize = Vector2.new(560, 380),
		maxOccupancyX = 0.92,
		maxOccupancyY = 0.84,
		marginFloorX = 20,
		marginFloorY = 20,
		maxAspectRatio = 2.6,
		minAspectRatio = 1.18,
		chromeHeight = layoutMetrics.sidebar.chromeHeight,
	} :: Profile,
}

function breakpoints.profile(mode: layouts.Mode?): Profile
	return profiles.sidebar
end

function breakpoints.pageHeight(totalHeight: number?, modeForHeight: layouts.Mode?): number
	local sizingProfile = breakpoints.profile(modeForHeight)
	local height = if totalHeight and totalHeight > 0 then totalHeight else sizingProfile.minSize.Y
	return math.max(height - sizingProfile.chromeHeight, 0)
end

local function availableHeight(heightProfile: Profile, viewportHeight: number): number
	local available = viewportHeight - heightProfile.marginFloorY
	if heightProfile.topbarClearance then
		available = math.min(available, viewportHeight - heightProfile.topbarClearance * 2)
	end
	if heightProfile.maxOccupancyY then
		available = math.min(available, viewportHeight * heightProfile.maxOccupancyY)
	end
	return available
end

local function fitSidebar(sidebarProfile: Profile, requestedWidth: number, requestedSidebarHeight: number): UDim2
    --[[
    The Sidebar keeps its historical 540px minimum for user resizing, while
    its default width is the shared 600px window default. Keep clamp bounds
    ordered for the responsive fit calculation without changing the
    declared minimum.
    ]]
    local minWidthBound = math.min(sidebarProfile.minSize.X, sidebarProfile.defaultSize.X)
    local sidebarWidth = math.min(math.clamp(requestedWidth, minWidthBound, sidebarProfile.defaultSize.X), requestedWidth)
	local sidebarHeight = math.min(math.clamp(requestedSidebarHeight, sidebarProfile.minSize.Y, sidebarProfile.defaultSize.Y), requestedSidebarHeight)
	sidebarHeight = math.floor(math.min(sidebarHeight, sidebarWidth / (sidebarProfile.minAspectRatio :: number)))
	sidebarWidth = math.floor(math.min(sidebarWidth, sidebarHeight * sidebarProfile.maxAspectRatio))
	return UDim2.fromOffset(sidebarWidth, sidebarHeight)
end

--[[
Tiered occupancy for desktop/PC: tablet and desktop share the same
perceived scale. Desktop uses lower occupancy so 1920px doesn't give a
huge window, while smaller screens still shrink responsively.
Phones (touch-only, sub-breakpoint) are diverted to the fixed mobile size
in fit(); this phone branch remains for narrow desktop/Studio viewports.
]]
local function getTieredOccupancy(viewport: Vector2, modeOrProfile: Profile): (number, number)
	local w = viewport.X
	if w < mobileBreakpoint then
		-- narrow viewport: near full width
		return modeOrProfile.maxOccupancyX, availableHeight(modeOrProfile, viewport.Y)
	elseif w < 1200 then
		-- tablet / small laptop
		return math.min(modeOrProfile.maxOccupancyX, 0.72), math.min(availableHeight(modeOrProfile, viewport.Y), viewport.Y * 0.82)
	else
		-- desktop: default target, capped by maxSize, never full-screen
		return 0.52, math.min(availableHeight(modeOrProfile, viewport.Y), viewport.Y * 0.72)
	end
end

--[[
Mobile detection: touch-only devices (phones, no hardware keyboard) whose
short side is phone-sized. Uses the min of both axes so a phone stays on
the fixed mobile size in portrait and landscape. Tablets and desktops -
including narrow desktop/Studio viewports - keep the responsive fit.
]]
function breakpoints.isMobileViewport(mobileViewport: Vector2?): boolean
	if not mobileViewport then
		return false
	end
	if mobileViewport.X < minTrackedViewport or mobileViewport.Y < minTrackedViewport then
		return false
	end
	if math.min(mobileViewport.X, mobileViewport.Y) >= mobileBreakpoint then
		return false
	end
	local inputService = coreState.userInputService
	if not inputService then
		return false
	end
	return inputService.TouchEnabled == true and inputService.KeyboardEnabled == false
end

local function fitViewport(fitProfile: Profile, fitTarget: Vector2): UDim2
	-- tiered target based on screen size
	local occX, availY = getTieredOccupancy(fitTarget, fitProfile)
	local targetWidth = math.min(fitTarget.X * occX, fitTarget.X - fitProfile.marginFloorX)
	-- clamp to maxSize so desktop doesn't explode on ultrawide
	if fitProfile.maxSize then
		targetWidth = math.min(targetWidth, fitProfile.maxSize.X)
		availY = math.min(availY, fitProfile.maxSize.Y)
	end
	local targetHeight = availY
	return fitSidebar(fitProfile, targetWidth, targetHeight)
end

function breakpoints.fit(viewport: Vector2?, modeOrProfile: layouts.Mode?): UDim2
	local fitProfile = profiles.sidebar
	if not viewport or viewport.X < minTrackedViewport or viewport.Y < minTrackedViewport then
		return UDim2.fromOffset(fitProfile.defaultSize.X, fitProfile.defaultSize.Y)
	end
	--[[
	Mobile: fixed size/profile - no occupancy math, so viewport changes
	never resize the window once it is on the mobile path.
	]]
	if breakpoints.isMobileViewport(viewport) then
		return UDim2.fromOffset(fitProfile.mobileSize.X, fitProfile.mobileSize.Y)
	end
	-- Desktop/PC: responsive viewport-based sizing (min/max protected).
	return fitViewport(fitProfile, viewport)
end

--[[
UIScale helper: desktop remains responsive, while the fixed mobile window
keeps its requested dimensions instead of being reduced by device scale.
]]
function breakpoints.scaleForViewport(scaleViewport: Vector2?): number
	if not scaleViewport or scaleViewport.X < minTrackedViewport then return 1 end
	if math.min(scaleViewport.X, scaleViewport.Y) < mobileBreakpoint then return 1 end
	-- 390 -> 0.92, 768 -> 0.98, 1280 -> 1.04, 1920 -> 1.12, 2560 -> 1.18 (clamped)
	local s = 0.88 + (scaleViewport.X / 2200) * 0.32
	-- y also matters on portrait phones: don't let tall narrow screens over-scale
	if scaleViewport.Y < 500 then s = math.min(s, 0.95) end
	return math.clamp(s, 0.88, 1.18)
end

return breakpoints
