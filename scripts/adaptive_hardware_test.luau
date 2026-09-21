-- ===== adaptive hardware & UI-dependent animation assertions =====
-- [[Verifies the hardware performance monitor, dynamic element streaming,
-- single-UI popup architecture, and UI-dependent aesthetic motion specs.]]

local function expect(cond, message)
	if not cond then
		error("ADAPTIVE TEST FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error("ADAPTIVE TEST FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")", 0)
	end
end

local motion = Astra.Motion
local perf = Astra.Performance

-- ===== H1: Astra.Performance is exposed and provides adaptive metrics =====
expect(type(perf) == "table", "H1 Astra.Performance is exposed on public root")
expect(type(perf.getBudgets) == "function", "H1 getBudgets is callable")
expect(type(perf.isLowEnd) == "function", "H1 isLowEnd is callable")
expect(type(perf.isStruggling) == "function", "H1 isStruggling is callable")
expect(type(perf.getAverageFps) == "function", "H1 getAverageFps is callable")
expect(type(perf.getLoadCheckpointStep) == "function", "H1 getLoadCheckpointStep is callable")
expect(type(perf.getElementBatchSize) == "function", "H1 getElementBatchSize is callable")

local frameBudget, instanceBudget = perf.getBudgets()
expect(type(frameBudget) == "number" and frameBudget > 0, "H1 frameBudget is positive number")
expect(type(instanceBudget) == "number" and instanceBudget > 0, "H1 instanceBudget is positive number")

-- Budgets adaptively scale down when a menu contains many elements
local bigFrameBudget, bigInstanceBudget = perf.getBudgets(100, 10)
expect(bigInstanceBudget <= instanceBudget, "H1 instance budget tightens for large element counts")
expect(bigFrameBudget <= frameBudget, "H1 frame budget tightens for large element counts")

-- ===== H2: UI-dependent aesthetic motion specs =====
expect(type(motion.uiSpec) == "function", "H2 motion.uiSpec is callable")
expect(motion.forUI == motion.uiSpec, "H2 motion.forUI is an alias of motion.uiSpec")

local windowSpec = motion.uiSpec("window")
expect(windowSpec.EasingStyle == Enum.EasingStyle.Back, "H2 window entrance uses aesthetic Back spring")
expect(windowSpec.Time >= 0.5, "H2 window entrance is visible")

local popupSpec = motion.uiSpec("popup")
expect(popupSpec.EasingStyle == Enum.EasingStyle.Circular, "H2 modal popup uses Circular deceleration")

local tabSpec = motion.uiSpec("tab")
expect(tabSpec.EasingStyle == Enum.EasingStyle.Cubic, "H2 tab switch uses smooth Cubic curve")

local controlSpec = motion.uiSpec("control")
expect(controlSpec.EasingStyle == Enum.EasingStyle.Back, "H2 mechanical control uses Back overshoot")

local buttonSpec = motion.uiSpec("button", "press")
expect(buttonSpec.EasingStyle == Enum.EasingStyle.Quad, "H2 button press uses crisp Quad micro-spec")

local toastSpec = motion.uiSpec("toast")
expect(toastSpec.EasingStyle == Enum.EasingStyle.Back, "H2 toast uses lively Back spring")

-- ===== H3: Single UI architecture (Popup shares window.screenGui) =====
local window = Astra:CreateWindow({ name = "Single UI Test" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local function screenGuis()
	local container = game:GetService("CoreGui")
	local n = 0
	for _, child in container:GetChildren() do
		if child.ClassName == "ScreenGui" and not child.__destroyed then
			n += 1
		end
	end
	return n
end

eq(screenGuis(), 1, "H3 only one ScreenGui exists before popup")

local popup = window:Popup({
	title = "Adaptive Test",
	content = "Verifying single UI architecture",
	options = { { text = "OK" } },
})
TestPump(0.4)

eq(screenGuis(), 1, "H3 only one ScreenGui exists while popup is displayed")
expect(popup.popupContainer ~= nil, "H3 popup uses dedicated container layer inside window.screenGui")
expect(popup.popupContainer.Parent == window.screenGui, "H3 popupContainer is parented into window.screenGui")

popup:Close()
TestPump(0.6)
eq(screenGuis(), 1, "H3 window.screenGui survives popup close")

-- ===== H4: Heavy tab loading streams elements smoothly =====
local heavyTab = window:CreateTab({ name = "Heavy Tab" })
for i = 1, 20 do
	heavyTab:CreateButton({ name = "Button " .. i, callback = function() end })
end

-- Switching to heavy tab displays initial viewport batch immediately
heavyTab:Select()
TestPump(0.05)

local visibleCount = 0
for _, el in heavyTab.elements do
	if el.title.TextTransparency == 0 then
		visibleCount += 1
	end
end
expect(visibleCount >= 6, "H4 initial viewport batch of elements appears without delay")

-- Pumping frames allows streaming of remaining elements
TestPump(0.6)
local totalRevealed = 0
for _, el in heavyTab.elements do
	if el.title.TextTransparency == 0 then
		totalRevealed += 1
	end
end
eq(totalRevealed, 20, "H4 all 20 elements finish loading smoothly")

window:Unload()
TestPump(0.2)
eq(screenGuis(), 0, "H3 unloading window completely removes the ScreenGui")

print("ADAPTIVE HARDWARE TEST PASSED")
