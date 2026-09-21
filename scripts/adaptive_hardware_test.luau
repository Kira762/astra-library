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

-- ===== H3: popup architecture (the dialog owns a ScreenGui above the window) =====
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
	content = "Verifying popup architecture",
	options = { { text = "OK" }, { text = "Later" } },
})
TestPump(0.4)

-- [[The dialog is a second root rather than a layer inside the window's: the
-- popup DisplayOrder lifts the whole card over the shell, so the card never has
-- to climb the window's ZIndex stack -- where, under `Global` ZIndex, it
-- outranked its own Header, copy and buttons and painted over them.]]
eq(screenGuis(), 2, "H3 popup opens its own ScreenGui while it is displayed")
expect(popup.screenGui ~= nil, "H3 popup owns a ScreenGui")
expect(popup.screenGui ~= window.screenGui, "H3 popup does not nest into window.screenGui")
expect(popup.screenGui.Parent == game:GetService("CoreGui"), "H3 popup ScreenGui is parented to the GUI container")
expect(
	popup.screenGui.DisplayOrder > window.screenGui.DisplayOrder,
	"H3 popup ScreenGui draws above the window"
)
expect(
	popup.screenGui.ZIndexBehavior == Enum.ZIndexBehavior.Global,
	"H3 popup ScreenGui keeps Global ZIndex behaviour"
)
expect(popup.popupContainer == nil, "H3 the window-nested popupContainer layer is gone")

-- The card carries the dialog's regions and its children stay visible on it.
local card = popup.card
expect(card ~= nil, "H3 popup exposes its card")
local header = card:FindFirstChild("Header")
local footer = card:FindFirstChild("Footer")
expect(header ~= nil, "H3 card has a Header")
expect(footer ~= nil, "H3 card has a Footer")
expect(header.Parent == card, "H3 Header is a child of the card")
expect(footer.Parent == card, "H3 Footer is a child of the card")

local actionButtons = 0
for _, child in footer:GetChildren() do
	if child.Name == "Button" then
		actionButtons += 1
	end
end
eq(actionButtons, 2, "H3 footer carries one action button per option")

-- [[Every painting surface of the dialog has to sit on or above the card: under
-- `Global` ZIndex a child ranked below its own parent is drawn behind the
-- parent's background, which is exactly how the card used to swallow its own
-- text and buttons. The one surface allowed underneath is the glow, and it is
-- drawn by `UIShadow` rather than by a `GuiObject` of its own.]]
local PAINTABLE = {
	Frame = true,
	ScrollingFrame = true,
	ImageLabel = true,
	ImageButton = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
}
local buried = 0
for _, descendant in card:GetDescendants() do
	if PAINTABLE[descendant.ClassName] and descendant.ZIndex < card.ZIndex then
		buried += 1
		print(
			"H3 buried: "
				.. tostring(descendant.ClassName)
				.. "/"
				.. tostring(descendant.Name)
				.. " ZIndex="
				.. tostring(descendant.ZIndex)
				.. " (card "
				.. tostring(card.ZIndex)
				.. ")"
		)
	end
end
eq(buried, 0, "H3 no part of the card is buried behind the card surface")

popup:Close()
TestPump(0.6)
eq(screenGuis(), 1, "H3 closing the popup removes its ScreenGui and leaves the window's")
expect(popup.screenGui.__destroyed == true, "H3 the popup ScreenGui is destroyed once playback finishes")

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
