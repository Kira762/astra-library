-- ===== geometry dump for the description diagram =====
-- [[Not a suite: prints one `ELEMENT|`/`PART|` record per described element —
-- [[the card, the in-card description line and every control rect inside it,
-- [[all in card-local coordinates with the anchor math the engine applies.
-- [[`scripts/render_description_preview.py` runs this through the stubs and
-- [[draws the records (PNG and HTML) so the layout can be inspected without
-- [[the engine; `scripts/inline_description_test.sh` is the assertion suite
-- [[that pins the same geometry.]]

local function rectIn(instance, ancestor)
	local x, y = 0, 0
	local width, height = 0, 0
	local node = instance
	while node do
		local parent = node.Parent
		if not parent then
			break
		end
		local size = parent.AbsoluteSize
		local position, nodeSize, anchor = node.Position, node.Size, node.AnchorPoint
		local nodeWidth = nodeSize.X.Scale * size.X + nodeSize.X.Offset
		local nodeHeight = nodeSize.Y.Scale * size.Y + nodeSize.Y.Offset
		if node == instance then
			width, height = nodeWidth, nodeHeight
		end
		x = x + position.X.Scale * size.X + position.X.Offset - anchor.X * nodeWidth
		y = y + position.Y.Scale * size.Y + position.Y.Offset - anchor.Y * nodeHeight
		if parent == ancestor then
			break
		end
		node = parent
	end
	return { x = x, y = y, w = width, h = height }
end

local guiClasses = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true,
}

local function kindOf(instance, hasText)
	if instance.Name == "Description" then
		return "Description"
	end
	local class = instance.__props and instance.__props.ClassName or "?"
	local background = (instance.__props and instance.__props.BackgroundTransparency) or 0
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		if hasText then
			return "Label"
		end
		return "Misc"
	end
	if background >= 1 then
		return "Misc"
	end
	if hasText then
		return "Label"
	end
	return "Surface"
end

local function num(value)
	return string.format("%.2f", value)
end

local function dump(kind, name, element)
	local main = element.main
	local card = main.AbsoluteSize
	local label = element.descriptionLabel
	print(("ELEMENT|%s|%s|%s|%s|%s"):format(
		kind, name, num(card.X), num(card.Y), tostring(label ~= nil)
	))
	local function part(instance)
		local class = instance.__props and instance.__props.ClassName or "?"
		if not guiClasses[class] then
			return
		end
		if (instance.__props and instance.__props.Visible) == false then
			return
		end
		local rect = if instance == main then { x = 0, y = 0, w = card.X, h = card.Y } else rectIn(instance, main)
		if rect.w < 1 or rect.h < 1 then
			return
		end
		local text = instance.Text
		local textSize = (instance.__props and instance.__props.TextSize) or 14
		local background = (instance.__props and instance.__props.BackgroundTransparency) or 0
		local textTransparency = (instance.__props and instance.__props.TextTransparency) or 0
		local showText = type(text) == "string" and text ~= ""
			and (textTransparency < 1 or instance.Name == "Description")
		print(("PART|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s"):format(
			instance.Name,
			kindOf(instance, showText),
			num(rect.x), num(rect.y), num(rect.w), num(rect.h),
			class,
			num(background),
			if showText then text:gsub("|", "/") else "",
			tostring(textSize)
		))
	end
	local function walk(instance, depth)
		if depth > 2 then
			return
		end
		for _, child in instance:GetChildren() do
			part(child)
			local childClass = child.__props and child.__props.ClassName or "?"
			if guiClasses[childClass] then
				walk(child, depth + 1)
			end
		end
	end
	part(main)
	walk(main, 0)
end

local window = Astra:CreateWindow({ name = "Description geometry" })
TestPump(0.6)
local tab = window:CreateTab({ name = "Controls" })
local more = window:CreateTab({ name = "More" })

local elements = {
	{ "toggle", "Notifications", tab:CreateToggle({ name = "Notifications", inlineDescription = "Ping me.", value = true }) },
	{ "button", "Run routine", tab:CreateButton({ name = "Run routine", inlineDescription = "Starts the routine.", callback = function() end }) },
	{ "slider", "Volume", tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, inlineDescription = "Master level." }) },
	{ "minimal", "Sensitivity", tab:CreateSlider({ name = "Sensitivity", range = { 0, 100 }, value = 40, minimal = true, inlineDescription = "Narrow cards keep the line." }) },
	{ "dropdown", "Quality", tab:CreateDropdown({ name = "Quality", inlineDescription = "Applies instantly.", options = { "Low", "High" }, value = "Low" }) },
	{ "input", "Display name", tab:CreateInput({ name = "Display name", inlineDescription = "Shown to friends.", placeholder = "Enter a name" }) },
	{ "stat", "Frames", tab:CreateStat({ name = "Frames", value = 240, description = "Per second." }) },
	{ "toggle", "No description", tab:CreateToggle({ name = "No description" }) },
	{ "input", "Wrapped hint", more:CreateInput({ name = "Wrapped hint", inlineDescription = "Type one letter. Extra characters are removed automatically, which makes this line wrap.", placeholder = "Enter a name" }) },
	{ "group", "Player Preferences", more:CreateCollapsibleGroup({ name = "Player Preferences", description = "Click to expand. Closing keeps the values active.", elements = {} }) },
	{
		"grouped",
		"Grouped control",
		more:CreateCollapsibleGroup({
			name = "Grouped children",
			elements = {
				{ type = "Toggle", name = "Grouped toggle", inlineDescription = "Grouped line.", value = false },
			},
		}).elements[1],
	},
}
window:Show()
TestPump(0.8)

for _, entry in elements do
	dump(entry[1], entry[2], entry[3])
end
print("DONE")
