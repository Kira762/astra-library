-- [[Centred inline text-and-icon strip — the "Built with ⚡ Astra ♡" line.]]
-- [[A Footer is an ordered run of text segments and inline icons that is]]
-- [[always centred as one unit: every segment auto-sizes, each icon scales to]]
-- [[the text size so the line keeps its proportions, and the whole run]]
-- [[re-centres itself whenever its content changes.]]

local state = {}
state.__index = state
state.__type = "Footer"

local constants = require(script.Parent.Parent.utilities.moveable)
local Locale = require(script.Parent.Parent.utilities.locale)

-- [[Resting transparency of the line: quieter than body text, matching the]]
-- [[muted credit row that usually sits under a divider.]]
local restingTransparency = 0.5

local defaultTextSize = 13
local defaultSpacing = 6

-- [[Icons ride slightly larger than the text so glyphs read at the same]]
-- [[optical weight as the words beside them.]]
local iconWeightBonus = 3

-- [[Normalise the accepted shapes into an ordered run list: a plain string is]]
-- [[a text segment, a table is `{ text = ... }` and/or `{ icon = ... }` (both]]
-- [[in one entry renders the text then the icon). Empty and unknown entries]]
-- [[are dropped so the centred line never shows dead gaps.]]
local function normalizeParts(input)
    local parts = {}
    if type(input) == "string" then
        return { { kind = "text", value = input } }
    end
    if type(input) ~= "table" then
        return parts
    end
    for _, part in input do
        if type(part) == "string" then
            parts[#parts + 1] = { kind = "text", value = part }
        elseif type(part) == "table" then
            if part.text ~= nil then
                parts[#parts + 1] = { kind = "text", value = tostring(part.text) }
            end
            if part.icon ~= nil then
                parts[#parts + 1] = { kind = "icon", value = part.icon }
            end
        end
    end
    return parts
end

local function isAssetReference(value)
    if type(value) == "number" then
        return true
    end
    if type(value) ~= "string" then
        return false
    end
    -- [[Prefix test by hand: a plain `string.find` would take the `^` anchor]]
    -- [[literally, and a pattern find would over-match on magic characters.]]
    return string.sub(value, 1, 9) == "rbxasset:"
        or string.sub(value, 1, 11) == "rbxassetid:"
        or string.sub(value, 1, 4) == "http"
end

-- [[A pack name that fails to resolve comes back from the resolver unchanged;]]
-- [[rendering it would leave a dead gap in the centred line, so the segment]]
-- [[drops instead. Explicit asset references always survive.]]
local function resolveIconRun(window, value)
    local resolved = window:ResolveIcon(value)
    if resolved == value and not isAssetReference(value) then
        return nil
    end
    return resolved
end

function state.new(tab, props)
    props = if typeof(props) == "table" then props else {}

    local requestedTextSize = tonumber(props.textSize or props.TextSize)
    local requestedSpacing = tonumber(props.spacing or props.Spacing)

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        textSize = math.max(requestedTextSize or defaultTextSize, 8),
        spacing = math.max(requestedSpacing or defaultSpacing, 0),
        parts = normalizeParts(props.parts or props.segments or props.items or props.Parts),
        runs = {},
    }, state)

    self.iconSize = self.textSize + iconWeightBonus

    -- [[The container is a transparent host and carries NO theme binding —
    -- [[deliberately. Every other white frame that binds BackgroundTransparency
    -- [[to ElementTransparency is an element card: a StyleElementBody/
    -- [[StyleElementPanel gradient tints it dark the moment the binding paints
    -- [[it opaque. This frame never receives that styling, so the next theme
    -- [[pass (a settings Apply/Reset, the secure-mode font swap, any host
    -- [[ChangeTheme — e.g. after a bar-layout switch) would tween its bare
    -- [[white base to opaque and bury the run: the solid white band that made
    -- [[the footer look "white only". Transparency 1 is its permanent state;
    -- [[visibility lives entirely on the text/icon runs (see _setShown).]]
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = "Footer",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    })

    -- [[The single horizontal layout is the whole trick of the element: it]]
    -- [[centres every segment as one unit and re-centres automatically when]]
    -- [[a label re-wraps, an icon swaps or Set() rebuilds the run.]]
    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, self.spacing),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    self:_buildRuns()
    self:_applyPresence()

    return self
end

function state:_buildRuns()
    for order, part in self.parts do
        if part.kind == "text" then
            self:_buildLabel(order, part.value)
        else
            self:_buildIcon(order, part.value)
        end
    end
end

function state:_buildLabel(order, text)
    local label = self.window:Create("TextLabel", {
        Text = Locale.t(text),
        RichText = true,
        TextSize = self.textSize,
        Size = UDim2.fromOffset(0, self.textSize + 2),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = order,

        TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.runs[#self.runs + 1] = { kind = "text", instance = label }
end

function state:_buildIcon(order, value)
    local resolved = resolveIconRun(self.window, value)
    if resolved == nil then
        return
    end

    local image = self.window:Create("ImageLabel", {
        Image = resolved,
        Size = UDim2.fromOffset(self.iconSize, self.iconSize),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = order,

        ImageTransparency = 1,
        Parent = self.main,
    }, { ImageColor3 = "ContentColor" })

    self.runs[#self.runs + 1] = { kind = "icon", instance = image }
end

-- [[An empty run renders nothing at all rather than a blank row.]]
function state:_applyPresence()
    self.main.Visible = #self.runs > 0
end

function state:Set(parts)
    self.parts = normalizeParts(parts)

    -- [[Destroy through the window, like every other element's rebuild path:
    -- [[DestroySubtree unregisters the run from themeProperties/localeProperties
    -- [[first, so the next theme pass is not pointed at a destroyed label (a
    -- [[raw :Destroy() left the binding behind and ChangeTheme then failed on
    -- [["property cannot be assigned ... instance has been destroyed").]]
    for _, run in self.runs do
        self.window:DestroySubtree(run.instance)
    end
    self.runs = {}

    self:_buildRuns()
    self:_applyPresence()

    -- [[Rebuilt segments start hidden so a visible window re-reveals them]] 
    -- [[through the same motion every other element uses.]]
    if #self.runs > 0 and not self.window.hidden then
        self:_setShown(true, true)
    end
end

function state:_setShown(shown, animate)
    local window = self.window
    local transparency = if shown then restingTransparency else 1

    for _, run in self.runs do
        if run.kind == "text" then
            window:_reveal(run.instance, { TextTransparency = transparency }, animate)
        else
            window:_reveal(run.instance, { ImageTransparency = transparency }, animate)
        end
    end
end

constants(state)

return state
