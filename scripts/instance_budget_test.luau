--[[
===== instance budget assertions =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

Instance count is the library's main frame-time lever: Roblox renders and
sorts every GUI instance it holds, so a page's element count is a direct
proxy for what the menu costs while it is open. This suite pins a ceiling per
element type and for a realistic 15-element page, so a change that quietly
re-adds invisible decoration (or stops materialising readout rows lazily)
fails here instead of in game.

Ceilings are deliberately a few instances above today's numbers: they catch
creep, not legitimate layout changes. Raise one only with a before/after
count in the changelog.

Expected behavior under test:
  * B1 every element stays under its ceiling,
  * B2 the realistic page stays under its budget,
  * B3 the odometer readouts are a small part of it (the lazy-row rule),
  * B4 a closed dropdown costs the same whatever its option list (rows and
    the search bar are materialised on the first open, so the list length
    stops mattering).
]]

local function expect(cond, message)
	if not cond then
		error("BUDGET FAIL: " .. tostring(message), 0)
	end
end

local window = Astra:CreateWindow({ name = "Budget" })
TestPump(0.6)
window:Show()
TestPump(0.6)
local tab = window:CreateTab({ name = "Budget" })

local function count(inst)
	local n = 1
	for _, child in inst:GetChildren() do
		n += count(child)
	end
	return n
end

local function labels(inst)
	local n = 0
	local function walk(node)
		for _, child in node:GetChildren() do
			if ((child.__props or {}).ClassName) == "TextLabel" then
				n += 1
			end
			walk(child)
		end
	end
	walk(inst)
	return n
end

-- ===== B1: per-element ceilings =====

local ceilings = {
	button = 12,
	toggle = 24,
	slider = 40,
	dropdown = 28,
	input = 18,
	link = 18,
	stat = 28,
	statCompact = 24,
	section = 8,
	text = 14,
	divider = 8,
	group = 6,
}

local builders = {
	button = function() return tab:CreateButton({ name = "Button", callback = function() end }) end,
	toggle = function() return tab:CreateToggle({ name = "Toggle", value = false }) end,
	slider = function() return tab:CreateSlider({ name = "Slider", range = { 0, 100 }, value = 50 }) end,
	dropdown = function()
		return tab:CreateDropdown({ name = "Dropdown", options = { "A", "B", "C" }, value = "A" })
	end,
	input = function() return tab:CreateInput({ name = "Input", placeholder = "x" }) end,
	link = function()
		return tab:CreateLink({ name = "Discord", subtitle = "Join our community", link = "https://discord.gg/astra", icon = "message-circle" })
	end,
	stat = function() return tab:CreateStat({ name = "Stat", value = 1, suffix = "" }) end,
	statCompact = function() return tab:CreateStat({ name = "StatC", value = 1, suffix = "", compact = true }) end,
	section = function() return tab:CreateSection({ name = "Section" }) end,
	text = function() return tab:CreateText({ name = "Text", text = "body" }) end,
	divider = function() return tab:CreateDivider() end,
	group = function() return tab:CreateGroup() end,
}

for name, ceiling in ceilings do
	local ok, element = pcall(builders[name])
	expect(ok, "B1 " .. name .. " builds")
	local used = count(element.main)
	expect(
		used <= ceiling,
		"B1 " .. name .. " stays under its " .. tostring(ceiling) .. " instance ceiling (used " .. tostring(used) .. ")"
	)
end
TestPump(0.3)

-- ===== B3: readouts materialise rows lazily =====

local readout = tab:CreateStat({ name = "Lazy", value = 7, suffix = "" })
TestPump(0.4)
local labelCount = labels(readout.main)
expect(
	labelCount <= 6,
	"B3 a single-digit readout materialises a handful of text labels, not one per strip row (used " .. tostring(labelCount) .. ")"
)

-- ===== B4: a closed dropdown does not pay for its rows =====

local shortList = tab:CreateDropdown({ name = "Lazy short", options = { "A", "B" }, value = "A" })
local longOptions = {}
for index = 1, 12 do
	longOptions[index] = "Option " .. index
end
local longList = tab:CreateDropdown({ name = "Lazy long", options = longOptions, value = "Option 1" })
TestPump(0.4)
expect(
	count(shortList.main) == count(longList.main),
	"B4 a closed dropdown costs the same with 12 options as with 2 (used "
		.. tostring(count(longList.main))
		.. " vs "
		.. tostring(count(shortList.main))
		.. ")"
)

-- ===== B2: a realistic page budget =====

local page = window:CreateTab({ name = "Page" })
local before = count(page.tabPage)
page:CreateSection({ name = "Stats" })
page:CreateStat({ name = "FPS", value = 60, suffix = "" })
page:CreateStat({ name = "Ping", value = 42, suffix = "ms" })
page:CreateStat({ name = "Memory", value = 1.5, suffix = "GB" })
page:CreateSection({ name = "Controls" })
page:CreateSlider({ name = "Sensitivity", range = { 0, 100 }, value = 50 })
page:CreateSlider({ name = "Volume", range = { 0, 10 }, increment = 0.1, value = 5, suffix = "%" })
page:CreateToggle({ name = "Enabled", value = true })
page:CreateToggle({ name = "Verbose", value = false })
page:CreateButton({ name = "Apply", callback = function() end })
page:CreateButton({ name = "Reset", callback = function() end })
page:CreateDropdown({ name = "Mode", options = { "Auto", "Manual", "Custom", "Expert" }, value = "Auto" })
page:CreateInput({ name = "Nickname", placeholder = "..." })
page:CreateText({ name = "Note", text = "A realistic page." })
TestPump(0.6)

local used = count(page.tabPage) - before
local pageBudget = 270
expect(
	used <= pageBudget,
	"B2 the 15-element page stays under its " .. tostring(pageBudget) .. " instance budget (used " .. tostring(used) .. ")"
)

window:Unload()
TestPump(0.1)

print("BUDGET: all assertions passed (page used " .. tostring(used) .. " instances)")
