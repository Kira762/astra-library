-- [[Astra Hardware Performance Engine.
--
-- Automatically detects GPU, CPU, frame timing, and device capabilities to
-- dynamically tune UI construction pacing, instance budgets, element loading,
-- and animation profiles.
--
-- On low-end mobile devices, weak GPUs, or under high frame jitter / load,
-- this module automatically reduces per-frame instance allocations and frame time
-- budgets, preventing Roblox client lag spikes, frame drops, and out-of-memory
-- or engine crashes. On high-end devices, it expands budgets for instant,
-- silky-smooth delivery.
--]]

local state = require(script.Parent.Parent.core.state)

local hardwarePerformance = {}

local SAMPLES_CAP = 30
local dtSamples = {}
local sampleIndex = 0
local sampleSum = 0
local averageDt = 0.0166 -- Baseline 60 FPS
local lastDt = 0.0166
local frameJitter = 0
local struggling = false

-- Device heuristics (cached once, refreshed lazily)
local isMobile = false
local isMock = false
local detectedQuality = 10

local function checkEnvironment()
	-- Detect mock / test harness environment
	local hasSettings = pcall(function()
		return settings()
	end)
	if not hasSettings then
		isMock = true
		return
	end

	-- Mobile check
	pcall(function()
		local uis = state.userInputService
		if uis and uis.TouchEnabled and not uis.KeyboardEnabled then
			isMobile = true
		end
	end)

	-- Graphics / GPU quality level check
	pcall(function()
		local rendering = settings().Rendering
		if rendering and rendering.QualityLevel then
			local val = rendering.QualityLevel.Value
			if typeof(val) == "number" and val > 0 then
				detectedQuality = val
			end
		end
	end)

	pcall(function()
		local gs = UserSettings().GameSettings
		if gs and gs.SavedQualityLevel then
			local val = gs.SavedQualityLevel.Value
			if typeof(val) == "number" and val > 0 then
				detectedQuality = math.min(detectedQuality, val)
			end
		end
	end)
end

checkEnvironment()

-- Monitor frame delta times on Heartbeat
if state.runService and state.runService.Heartbeat then
	pcall(function()
		state.runService.Heartbeat:Connect(function(dt: number)
			if isMock then
				return
			end
			local clampedDt = math.clamp(dt or 0.0166, 0.001, 0.25)
			lastDt = clampedDt

			if #dtSamples < SAMPLES_CAP then
				table.insert(dtSamples, clampedDt)
				sampleSum += clampedDt
			else
				sampleIndex = (sampleIndex % SAMPLES_CAP) + 1
				sampleSum = sampleSum - dtSamples[sampleIndex] + clampedDt
				dtSamples[sampleIndex] = clampedDt
			end

			local count = #dtSamples
			if count > 0 then
				averageDt = sampleSum / count
				frameJitter = math.abs(clampedDt - averageDt)
				-- If current frame took > 33ms (~30 FPS) or moving average is < 40 FPS,
				-- or jitter is very high, the GPU/CPU is struggling.
				struggling = clampedDt > 0.033 or averageDt > 0.025 or frameJitter > 0.018
			end
		end)
	end)
end

function hardwarePerformance.isLowEnd(): boolean
	if isMock then
		return false
	end
	return isMobile or detectedQuality <= 3 or averageDt > 0.028 or struggling
end

function hardwarePerformance.isStruggling(): boolean
	if isMock then
		return false
	end
	return struggling or lastDt > 0.035
end

function hardwarePerformance.getAverageFps(): number
	if averageDt <= 0 then
		return 60
	end
	return math.clamp(1 / averageDt, 1, 240)
end

-- [[Computes adaptive (frameBudgetSeconds, instanceBudget) based on GPU/CPU
-- and current menu size (total elements & tabs).]]
function hardwarePerformance.getBudgets(totalElements: number?, tabCount: number?): (number, number)
	if isMock then
		-- Keep stable pinned baseline for virtual-time test suites
		return 0.003, 48
	end

	local baseFrameBudget: number
	local baseInstanceBudget: number

	if hardwarePerformance.isLowEnd() then
		-- Low-end GPU/CPU or mobile: tight budgets to prevent freezes/crashes
		baseFrameBudget = 0.0012 -- ~1.2ms
		baseInstanceBudget = 16
	elseif detectedQuality <= 6 or averageDt > 0.020 then
		-- Medium-tier device
		baseFrameBudget = 0.0022 -- ~2.2ms
		baseInstanceBudget = 32
	else
		-- High-end device with healthy 60+ FPS
		baseFrameBudget = 0.0035 -- ~3.5ms
		baseInstanceBudget = 48
	end

	-- Automatically adjust when there are many elements and tabs:
	-- Spread heavy menus across more cheap frames so the device never hitches.
	local elems = totalElements or 0
	if elems > 30 then
		local factor = math.clamp(1 - (elems - 30) * 0.008, 0.5, 1.0)
		baseInstanceBudget = math.max(12, math.floor(baseInstanceBudget * factor))
		baseFrameBudget = math.max(0.0009, baseFrameBudget * factor)
	end

	local tabs = tabCount or 0
	if tabs > 5 then
		baseInstanceBudget = math.max(12, baseInstanceBudget - 4)
	end

	-- Immediate throttle if an active frame drop / jitter spike was detected
	if hardwarePerformance.isStruggling() then
		baseInstanceBudget = math.max(8, math.floor(baseInstanceBudget * 0.6))
		baseFrameBudget = math.max(0.0008, baseFrameBudget * 0.6)
	end

	return baseFrameBudget, baseInstanceBudget
end

-- [[Step size for config persistence checkpoint (fewer items between yields on weak devices)]]
function hardwarePerformance.getLoadCheckpointStep(): number
	if isMock then
		return 6
	end
	if hardwarePerformance.isLowEnd() then
		return 3
	elseif detectedQuality <= 6 then
		return 4
	end
	return 6
end

-- [[Micro-batch size for streaming elements on heavy tabs]]
function hardwarePerformance.getElementBatchSize(): number
	if isMock then
		return 24
	end
	if hardwarePerformance.isLowEnd() then
		return 6
	end
	return 12
end

return hardwarePerformance
