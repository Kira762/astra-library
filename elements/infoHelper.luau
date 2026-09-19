-- [[The circle-alert badge beside a functional element's name.
--
-- A functional element gets the badge from its optional `info` text: a string
-- with at least one visible character shows the `(!)` badge, while `nil` or
-- an empty/whitespace-only value draws nothing at all (the element looks
-- exactly like one that never had an `info` prop).
--
-- Placement is the point of this module: the badge is a **sibling of the
-- title, immediately after it**. The row's list layout is switched to
-- `Enum.SortOrder.LayoutOrder` and the badge is given the title's order plus
-- one, so the icon -> name -> badge order is explicit. Leaving the layout on
-- its default (Roblox currently defaults `SortOrder` to `Name`) put
-- "InfoIcon" before "TextLabel" and the badge landed in front of the name.
--
-- The title becomes width-automatic while a badge is present, so a long name
-- shrinks (and truncates) instead of pushing the badge out of the row. The
-- width recipe the title had before is remembered and restored when the badge
-- goes away - see `:SetInfo(nil)` / `:SetInfo(\"\")`.
--
-- `Window:_revealCommon` / `_hideCommon` own the badge's transparency like
-- they do for every other element part; `attach` only decides whether a badge
-- exists at all.

local infoHelper = {}

local tooltip = require(script.Parent.Parent.components.tooltip)
local locale = require(script.Parent.Parent.utilities.locale)

local badgeSize = 14
local restingTransparency = 0.45

-- [[The element's own property, with the aliases the library has always
-- [[accepted. An empty or whitespace-only string is "no description".]] 
function infoHelper.text(element): string?
    local value = element.info
    if value == nil then
        return nil
    end
    if locale.isToken(value) then
        value = locale.sourceOf(value)
    end
    if type(value) ~= "string" then
        value = tostring(value)
    end
    if value:match("^%s*$") then
        return nil
    end
    return value
end

-- [[True when the element should draw a badge.]] 
function infoHelper.has(element): boolean
    return infoHelper.text(element) ~= nil
end

-- [[Whether the element is on screen right now. The elements do not carry a
-- [[shown flag, but every reveal path drives the title's transparency, so the
-- [[badge added at runtime joins the same state the rest of the row is in.]] 
local function isRevealed(element): boolean
    local title = element.title
    return title ~= nil and title.TextTransparency == 0
end

-- [[Explicit sibling order for the row the badge joins.]] 
local function ordered(parent)
    if not parent or not parent.GetChildren then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UIListLayout") and child.SortOrder ~= Enum.SortOrder.LayoutOrder then
            child.SortOrder = Enum.SortOrder.LayoutOrder
        end
    end
end

-- [[Give the title its width-automatic recipe, remembering the one it had.]] 
local function elasticTitle(element)
    local title = element.title
    if not title then
        return
    end

    local hasFlex = false
    for _, child in ipairs(title:GetChildren()) do
        if child:IsA("UIFlexItem") then
            hasFlex = true
            break
        end
    end

    if title.AutomaticSize == Enum.AutomaticSize.None then
        element._infoTitleRestore = { size = title.Size, automatic = title.AutomaticSize }
        title.AutomaticSize = Enum.AutomaticSize.X
        title.Size = UDim2.fromOffset(0, 16)
    end

    if not hasFlex then
        element._infoTitleFlex = element.window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = title,
        })
    end
end

-- [[Put the title back the way it was before a badge joined the row.]] 
local function restoreTitle(element)
    local restore = element._infoTitleRestore
    if restore and element.title then
        element.title.AutomaticSize = restore.automatic
        element.title.Size = restore.size
        element._infoTitleRestore = nil
    end
    if element._infoTitleFlex then
        element._infoTitleFlex:Destroy()
        element._infoTitleFlex = nil
    end
end

-- [[Build the badge. `parent` is the row that holds the title (the element
-- [[container, the compact row's button, the slider's title row); the badge
-- [[lands one slot after the title inside it.]] 
function infoHelper.attach(element, parent, layoutOrder: number?): any
    if element.infoButton or not parent or not element.title then
        return nil
    end
    if not infoHelper.has(element) then
        return nil
    end

    local window = element.window

    ordered(parent)
    elasticTitle(element)

    local icon = window:ResolveIcon(element.infoIcon or "circle-alert")
    if not icon or icon == "circle-alert" then
        icon = window:ResolveIcon("alert-circle")
    end

    local infoButton = window:Create("ImageButton", {
        Name = "InfoIcon",
        Size = UDim2.fromOffset(badgeSize, badgeSize),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = icon,
        ImageTransparency = 1,
        LayoutOrder = layoutOrder or ((element.title.LayoutOrder or 1) + 1),
        ZIndex = 15,
        Parent = parent,
    }, { ImageColor3 = "ContentColor" })

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.None,
        Parent = infoButton,
    })

    tooltip.attach(element, infoButton, infoHelper.text(element))

    element.infoButton = infoButton
    element._infoParent = parent
    if isRevealed(element) then
        infoButton.ImageTransparency = restingTransparency
    end
    return infoButton
end

-- [[Take the badge away again, restoring the title's width recipe.]] 
function infoHelper.detach(element)
    if element.infoButton then
        local button = element.infoButton
        element.infoButton = nil
        button:Destroy()
    end
    restoreTitle(element)
    tooltip.hideFor(element.window, element)
end

-- [[The runtime writer behind `:SetInfo(text)`:
-- [[  * a new non-empty text adds the badge (or keeps the existing one),
-- [[  * `nil` / `\"\"` removes it and gives the title its width back.
-- [[The element's `info` field is assigned here so every element's setter
-- [[walks the same path.]] 
function infoHelper.set(element, text, parent, layoutOrder: number?): any
    element.info = text
    if not infoHelper.has(element) then
        infoHelper.detach(element)
        return nil
    end
    if element.infoButton then
        return element.infoButton
    end
    return infoHelper.attach(element, parent or element._infoParent, layoutOrder)
end

return infoHelper
