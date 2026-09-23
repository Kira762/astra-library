local Changelog = {}
Changelog.__index = Changelog
Changelog.__type = "Changelog"
local moveable = require(script.Parent.Parent.utilities.moveable)
export type ChangelogChange = {
    symbol: string,
    text: string,
    category: string?,
}
export type ChangelogEntry = {
    version: string,
    date: string,
    game: string?,
    gameId: string?,
    title: string?,
    changes: { ChangelogChange },
}
type FadeItem = {
    instance: Instance,
    property: string,
    shownValue: number,
}
local addedColor = Color3.fromRGB(104, 210, 126)
local removedColor = Color3.fromRGB(232, 100, 100)
local changedColor = Color3.fromRGB(242, 172, 76)
local unknownColor = Color3.fromRGB(170, 170, 170)
local function read(properties, lower, upper)
    local value = properties[lower]
    if value == nil then
        value = properties[upper]
    end
    return value
end
local function normalizeSymbol(value): string
    local symbol = tostring(value or "~")
    local normalized = string.lower(symbol)
    if normalized == "added" or normalized == "add" then
        return "+"
    elseif normalized == "removed" or normalized == "remove" or normalized == "deleted" then
        return "-"
    elseif normalized == "changed" or normalized == "change" or normalized == "updated" then
        return "~"
    elseif symbol == "+" or symbol == "-" or symbol == "~" then
        return symbol
    end
    return "~"
end
local function symbolColor(symbol: string): Color3
    if symbol == "+" then
        return addedColor
    elseif symbol == "-" then
        return removedColor
    elseif symbol == "~" then
        return changedColor
    end
    return unknownColor
end
local function normalizeChange(raw): ChangelogChange?
    if typeof(raw) ~= "table" then
        return nil
    end
    local text = read(raw, "text", "Text")
    if text == nil then
        text = read(raw, "message", "Message")
    end
    if text == nil or tostring(text) == "" then
        return nil
    end
    local symbol = read(raw, "symbol", "Symbol")
    if symbol == nil then
        symbol = read(raw, "type", "Type")
    end
    local category = read(raw, "category", "Category")
    return {
        symbol = normalizeSymbol(symbol),
        text = tostring(text),
        category = if category ~= nil and tostring(category) ~= "" then tostring(category) else nil,
    }
end
local function normalizeEntry(raw): ChangelogEntry
    local properties = if typeof(raw) == "table" then raw else {}
    local rawChanges = read(properties, "changes", "Changes")
    local changes = {}
    if typeof(rawChanges) == "table" then
        for _, rawChange in ipairs(rawChanges) do
            local change = normalizeChange(rawChange)
            if change then
                table.insert(changes, change)
            end
        end
    end
    local version = read(properties, "version", "Version")
    local date = read(properties, "date", "Date")
    if date == nil then
        date = read(properties, "updatedAt", "UpdatedAt")
    end
    local game = read(properties, "game", "Game")
    if game == nil then
        game = read(properties, "gameName", "GameName")
    end
    local gameId = read(properties, "gameId", "GameId")
    if gameId == nil then
        gameId = read(properties, "placeId", "PlaceId")
    end
    local title = read(properties, "title", "Title")
    return {
        version = tostring(version or ""),
        date = tostring(date or ""),
        game = if game ~= nil and tostring(game) ~= "" then tostring(game) else nil,
        gameId = if gameId ~= nil and tostring(gameId) ~= "" then tostring(gameId) else nil,
        title = if title ~= nil and tostring(title) ~= "" then tostring(title) else nil,
        changes = changes,
    }
end
local function formatMetadata(entry: ChangelogEntry): string
    local values = {}
    if entry.version ~= "" then
        table.insert(values, `Version {entry.version}`)
    end
    if entry.game then
        local gameText = entry.game
        if entry.gameId then
            gameText ..= `  •  ID {entry.gameId}`
        end
        table.insert(values, gameText)
    elseif entry.gameId then
        table.insert(values, `Game ID {entry.gameId}`)
    end
    return table.concat(values, "  •  ")
end
function Changelog.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}
    local entries = {}
    local rawEntries = read(properties, "entries", "Entries")
    if typeof(rawEntries) == "table" then
        for _, rawEntry in ipairs(rawEntries) do
            table.insert(entries, normalizeEntry(rawEntry))
        end
    end
    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = tostring(read(properties, "name", "Name") or "Changelog"),
        emptyText = tostring(read(properties, "emptyText", "EmptyText") or "No changelog entries yet."),
        entries = entries,
        _entryFrames = {},
        _dynamicFrames = {},
        _fadeItems = {},
        _shown = false,
    }, Changelog)
    self.main = self.window:Create("Frame", {
        Name = self.name,
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })
    self.stroke = self.window:StyleElementBody(self.main)
    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        Parent = self.main,
    })
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })
    self.title = self.window:Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 24),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        RichText = true,
        TextSize = 17,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        TextTransparency = 1,
        Parent = self.main,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })
    self.window:_bindLocale(self.title, "Text", self.name)
    self.history = self.window:Create("Frame", {
        Name = "History",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        Parent = self.main,
    })
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.history,
    })
    table.insert(self._fadeItems, { instance = self.title, property = "TextTransparency", shownValue = 0 })
    self:_render()
    return self
end
function Changelog:_addFade(instance: Instance, property: string, shownValue: number)
    table.insert(self._fadeItems, { instance = instance, property = property, shownValue = shownValue })
end
function Changelog:_makeLabel(parent, name, text, textSize, shownValue, layoutOrder, theme)
    local label = self.window:Create("TextLabel", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        RichText = true,
        TextSize = textSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = layoutOrder,
        TextTransparency = 1,
        Parent = parent,
    }, theme or { TextColor3 = "ContentColor", FontFace = "Font" })
    self.window:_bindLocale(label, "Text", text)
    self:_addFade(label, "TextTransparency", shownValue)
    return label
end
function Changelog:_renderEntry(entry: ChangelogEntry, index: number)
    local card = self.window:Create("Frame", {
        Name = `Entry_{index}`,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = index,
        Parent = self.history,
    })
    local stroke = self.window:StyleElementPanel(card)
    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 11),
        PaddingBottom = UDim.new(0, 11),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = card,
    })
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })
    self:_addFade(card, "BackgroundTransparency", self.window:_elementBackgroundTransparency(self))
    self:_addFade(stroke, "Transparency", self.window:_elementStrokeTransparency(self, false))
    local header = self.window:Create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = card,
    })
    local heading = entry.title or if entry.version ~= "" then entry.version else "Update"
    local title =
        self:_makeLabel(header, "Title", heading, 15, 0, 1, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })
    title.Size = UDim2.new(1, -100, 1, 0)
    title.AutomaticSize = Enum.AutomaticSize.None
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.TextYAlignment = Enum.TextYAlignment.Center
    local date = self.window:Create("TextLabel", {
        Name = "Date",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(96, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = entry.date,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        Parent = header,
    }, { TextColor3 = "PlaceholderColor", FontFace = "Font" })
    self:_addFade(date, "TextTransparency", 0.55)
    local metadata = formatMetadata(entry)
    if metadata ~= "" then
        self:_makeLabel(card, "Metadata", metadata, 11, 0.55, 2)
    end
    local changesFrame = self.window:Create("Frame", {
        Name = "Changes",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4,
        Parent = card,
    })
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = changesFrame,
    })
    local lastCategory = nil
    for changeIndex, change in ipairs(entry.changes) do
        if change.category and change.category ~= lastCategory then
            self:_makeLabel(
                changesFrame,
                `Category_{changeIndex}`,
                string.upper(change.category),
                10,
                0.45,
                changeIndex * 2 - 1,
                { TextColor3 = "PlaceholderColor", FontFace = "Font" }
            )
            lastCategory = change.category
        end
        local row = self.window:Create("Frame", {
            Name = `Change_{changeIndex}`,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = changeIndex * 2,
            Parent = changesFrame,
        })
        local symbol = self.window:Create("TextLabel", {
            Name = "Symbol",
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.fromOffset(18, 20),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = change.symbol,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTransparency = 1,
            Parent = row,
        }, { FontFace = "TitleFont" })
        symbol.TextColor3 = symbolColor(change.symbol)
        self:_addFade(symbol, "TextTransparency", 0)
        local body = self:_makeLabel(
            row,
            `ChangeText_{changeIndex}`,
            change.text,
            12,
            0.15,
            2,
            { TextColor3 = "ContentColor", FontFace = "Font" }
        )
        body.Position = UDim2.fromOffset(25, 0)
        body.Size = UDim2.new(1, -25, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
    end
    table.insert(self._entryFrames, card)
    table.insert(self._dynamicFrames, card)
end
function Changelog:_render()
    for _, frame in ipairs(self._dynamicFrames) do
        self.window:DestroySubtree(frame)
    end
    table.clear(self._entryFrames)
    table.clear(self._dynamicFrames)
    local rootFadeItems = {}
    for _, item in ipairs(self._fadeItems) do
        if item.instance == self.title then
            table.insert(rootFadeItems, item)
        end
    end
    self._fadeItems = rootFadeItems
    if #self.entries == 0 then
        local empty = self:_makeLabel(self.history, "Empty", self.emptyText, 12, 0.7, 1)
        empty.TextXAlignment = Enum.TextXAlignment.Center
        table.insert(self._dynamicFrames, empty)
    else
        for index, entry in ipairs(self.entries) do
            self:_renderEntry(entry, index)
        end
    end
    if self._shown then
        self:_setShown(true, false)
    end
end
function Changelog:_setShown(shown, animate)
    self._shown = shown
    self.window:_revealCommon(self, animate)
    for _, item in ipairs(self._fadeItems) do
        self.window:_reveal(item.instance, { [item.property] = if shown then item.shownValue else 1 }, animate)
    end
end
function Changelog:Set(entries)
    self.entries = {}
    if typeof(entries) == "table" then
        for _, rawEntry in ipairs(entries) do
            table.insert(self.entries, normalizeEntry(rawEntry))
        end
    end
    self:_render()
end
function Changelog:Refresh(entries)
    self:Set(entries)
end
function Changelog:Add(entry, prepend)
    local normalized = normalizeEntry(entry)
    if prepend == false then
        table.insert(self.entries, normalized)
    else
        table.insert(self.entries, 1, normalized)
    end
    self:_render()
end
function Changelog:Clear()
    self.entries = {}
    self:_render()
end
moveable(Changelog)
return Changelog
