-- [[Astra element-coverage example.]]
-- [[Everything lives in one tab so startup pacing and every element type can be
-- [[tested without navigating through a collection of duplicate demo tabs —
-- [[plus one locked tab demonstrating the lock badge and SetLocked.]]

-- [[The one and only bundle loader: fetch the published bundle and call the
-- [[chunk it compiles to. `loadstring` needs an executor — plain Studio does
-- [[not provide it — and the URL must be the raw file of a public repo.]]
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

local window = Astra:CreateWindow({
    name = "Astra Element Test",
    subtitle = "All elements in one paced tab",
    icon = "sirius",
    configuration = {
        fileName = "Astra-Example",
        customFolder = "AstraExamples",
        autoSave = true,
        autoLoad = true,
    },
})

-- [[One tab intentionally contains every supported element type.]]
local elements = window:CreateTab({ name = "Element Test", icon = "flask-conical" })

-- [[The About action is built before the Isolated panel lower in this file, but
-- [[the callback runs only after construction. Keep the handle here so the band
-- [[can open the real release history and bring its header into view instead of
-- [[showing a notification that leaves the changelog closed.]]
local changelogPanel
local function openChangelog()
    if not changelogPanel then
        return
    end
    changelogPanel:Expand()
    task.defer(function()
        if not changelogPanel.main.Parent then
            return
        end
        local page = elements.tabPage
        local top = page.CanvasPosition.Y + changelogPanel.main.AbsolutePosition.Y - page.AbsolutePosition.Y
        page.CanvasPosition = Vector2.new(0, math.max(0, top - 10))
    end)
end

-- [[The About card: a brand header, up to three data rows, a description
-- [[paragraph and an optional trailing action band. This one carries Astra's
-- [[own release facts — the leading mark is the library's asset id (a pack name
-- [[would do just as well) — and its action band is the card's only tappable
-- [[surface.]] 
elements:CreateAboutCard({
    name = "Astra",
    subtitle = "UI Library for a better experience.",
    icon = 80387863064905,
    rows = {
        { icon = "code", label = "Version", value = "1.4.0" },
        { icon = "package", label = "Build", value = "2026.09.12" },
        { icon = "user", label = "Author", value = "Astra Team" },
    },
    description = "Astra is a modern and flexible UI library designed to make your experience smoother, cleaner, and more customizable. Built for developers, by developers.",
    action = {
        icon = "file-text",
        name = "View Changelog",
        subtitle = "See what's new in this version",
        callback = openChangelog,
    },
})

elements:CreateSection({ name = "Basic elements" })
elements:CreateText({
    name = "Text",
    text = "This single tab builds every Astra element so startup batching and layout pacing are easy to observe.",
})

local stat = elements:CreateStat({
    name = "Stat",
    value = 128,
    suffix = " requests",
    compact = true,
    changeMode = "delta",
    changeBaseline = "initial",
})

elements:CreateDivider({ text = "Interactive elements" })

-- [[Every functional element below carries an `info` description: the (!) badge
-- [[sits right after the element's name, and hovering it (or tapping it, or
-- [[holding it down on touch) reveals the floating description. Tap the badge
-- [[again to close it. Elements without `info` draw no badge at all.]] 

elements:CreateButton({
    name = "Button",
    icon = "hand-tap",
    callback = function()
        stat:Set(stat.value + 1)
        window:Notify({ title = "Button", content = "Stat was updated." })
    end,
})

elements:CreateToggle({
    name = "Toggle",
    value = true,
    callback = function(value)
        window:Notify({ title = "Toggle", content = if value then "Enabled" else "Disabled" })
    end,
})

elements:CreateSlider({
    name = "Slider",
    range = { 0, 100 },
    value = 50,
    increment = 5,
    suffix = "%",
    callback = function(value)
        stat:Set(value)
    end,
})

elements:CreateDropdown({
    name = "Dropdown",
    options = { "Low", "Medium", "High" },
    value = "Medium",
    callback = function(value)
        window:Notify({ title = "Dropdown", content = tostring(value) })
    end,
})

elements:CreateDropdown({
    name = "Multi-select dropdown",
    options = { "Combat", "Movement", "Visual" },
    value = { "Combat" },
    multiSelect = true,
    placeholder = "Choose tags",
})

-- [[Keep the example to the original Input element: one useful text field,
-- [[not extra one-off input rows.]]
elements:CreateInput({
    name = "Input",
    placeholder = "Type something",
    callback = function(value)
        window:Notify({ title = "Input", content = tostring(value) })
    end,
})

-- [[A Link card carries its URL as a hidden value: the title and the subtitle
-- [[are the whole card, and the trailing control copies the link and confirms
-- [[with a check mark. The link itself is never rendered as text.]] 
elements:CreateLink({
    name = "Discord",
    subtitle = "Join our community",
    link = "https://discord.gg/example",
    icon = "message-circle",
})

--[=[ Lock-tab demo temporarily disabled pending the UI redesign.
-- [[Locked tab: built gated, with a lock badge when lockUIEnabled is restored.
-- [[Tapping it raises a notification instead of opening it; only host code
-- [[unlocks it, through tab:SetLocked(false).]]
local premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })
premium:CreateSection({ name = "Premium only" })
premium:CreateText({
    name = "Gated content",
    text = "This tab was built locked. The trailing badge in its row stays until host code unlocks it, and its contents are never built visible or indexed by search.",
})
premium:CreateButton({
    name = "Re-lock this tab",
    icon = "lock",
    callback = function()
        premium:SetLocked(true)
        elements:Select()
    end,
})

elements:CreateButton({
    name = "Unlock the Premium tab",
    icon = "lock-open",
    callback = function()
        premium:SetLocked(false)
        premium:Select()
    end,
})

]=]

elements:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "Element Test",
            date = "Live",
            title = "All supported elements",
            changes = {
                { symbol = "+", category = "Added", text = "This changelog renders as a standalone element." },
            },
        },
    },
})

-- [[A normal Group is an element too. Its children use the compact row layout.]]
local group = elements:CreateGroup({ direction = "column" })
group:CreateSection({ name = "Group" })
group:CreateButton({
    name = "Grouped button",
    callback = function()
        window:Notify({ title = "Group", content = "The ordinary Group child is working." })
    end,
})
group:CreateToggle({ name = "Grouped toggle", value = false })

-- [[The declarative group exercises the CollapsibleGroup path with useful child
-- [[rows; the standalone Input above covers the original input element.]]
elements:CreateCollapsibleGroup({
    name = "Collapsible Group",
    icon = "panels-top-left",
    description = "Expand this card to inspect the useful declarative child rows.",
    elements = {
        { type = "Section", name = "Declarative children" },
        { type = "Text", name = "Text child", text = "All child controls are constructed while the group is collapsed." },
        { type = "Button", name = "Button child", callback = function() window:Notify({ title = "Child button", content = "Clicked" }) end },
        { type = "Toggle", name = "Toggle child", value = true },
        { type = "Switch", name = "Switch alias child", value = false },
        { type = "Slider", name = "Slider child", range = { 0, 100 }, value = 25 },
        { type = "Dropdown", name = "Dropdown child", options = { "One", "Two" }, value = "One" },
        { type = "Stat", name = "Stat child", value = 42, suffix = " checks" },
        { type = "Link", name = "Link child", subtitle = "Copy the invite", link = "https://discord.gg/example", icon = "message-circle" },
        { type = "Divider", text = "Nested diagnostics" },
        { type = "Changelog", name = "Nested changelog", entries = { { version = "1.0", date = "Live", changes = { { symbol = "+", text = "Changelog inside collapsible group" } } } } },
        {
            type = "Group",
            direction = "column",
            elements = {
                { type = "Text", name = "Nested Group", text = "Ordinary Groups may be nested." },
                { type = "Button", name = "Nested action", callback = function() window:Notify({ title = "Nested Group", content = "The nested action works." }) end },
            },
        },
    },
})

-- [[The Isolated container is the Changelog's own home: a collapsed header
-- [[card with a changeable icon, title and subtitle, the built-in chevron, and
-- [[a body that only ever holds Changelog elements.]]
changelogPanel = elements:CreateIsolated({
	name = "View Changelog",
	subtitle = "See what's new in this version",
	icon = "file-text",
	elements = {
		{
			type = "Changelog",
			name = "Release history",
			entries = {
				{
					version = "1.2.0",
					date = "Live",
					title = "Isolated container",
					changes = {
						{ symbol = "+", text = "Added Isolated changelog container" },
						{ symbol = "~", text = "Chevron now rotates when expanded" },
					},
				},
				{
					version = "1.1.0",
					date = "Live",
					changes = { { symbol = "-", text = "Fixed CollapsibleGroup tween overflow" } },
				},
			},
		},
	},
})

-- [[The centred credit line: text and inline icons as one ordered run that
-- [[stays centred as a unit and re-centres itself when it changes.]]
elements:CreateDivider()
elements:CreateFooter({
	parts = {
		{ text = "Built with" },
		{ icon = "zap" },
		{ text = "Astra" },
		{ icon = "heart" },
	},
})

-- [[Select the only user tab explicitly so the example is deterministic.]]
elements:Select()
