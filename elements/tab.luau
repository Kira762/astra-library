local state = {}
state.__index = state
state.__type = "Tab"

local constants = script.Parent.Parent.utilities

local Tab = require(constants.Parent.core.state)
local motion = require(constants.motion)
local window = require(constants.ordering)
local props = require(constants.HapticEngine)
local name = require(script.Parent.Parent.components.search)
local icon = require(script.Parent.Parent.components.tabSelector)
local flagNames = require(script.Parent.Parent.functions.flagNames)

local function customOrder(window, forgetState)
    for _, element in forgetState do
        if element.__type == "Group" or element.__type == "CollapsibleGroup" then
            customOrder(window, element.elements)
        else
            window:_unregisterControl(element)
        end

                if element.connections then
            for _, neglectSelector in element.connections do
                window:Disconnect(neglectSelector)
            end
            element.connections = nil
        end

                if element._dragConnection then
            element._dragConnection:Disconnect()
            element._dragConnection = nil
        end
                        if window._recordingKeybind == element then
            window._recordingKeybind = nil
        end
        if element._outsideClickConn then
            window:Disconnect(element._outsideClickConn)
            element._outsideClickConn = nil
        end
    end
end

-- [[Tab state changes ride the motion service's shared specs: `normal` for
-- the pill's selected/rest states, `snappy` for the page hand-off.]]
local element, page = "normal", "snappy"

local function selector(elements)
    if elements.mode == "sidebar" then
        return UDim2.new(1, -35, 1, 0)
    end
    return UDim2.new(1, -20, 1, 0)
end

local function a15(a16)
    if a16.mode == "sidebar" then
        return UDim2.new(0, 35, 0, 0)
    end
    return UDim2.new(0, 0, 0, 0)
end

function state.new(window, a17)
    a17 = if typeof(a17) == "table" then a17 else {}
    -- [[Validate the dependency before resolving the tab icon so malformed tab]]
    -- [[construction reports the actual missing Window argument.]]
    window = assert(window, "Missing argument #1 (Window expected)")

    local self = setmetatable({
        window = window,
        name = a17.name or a17.Name,
        icon = window:ResolveIcon(a17.icon or a17.Icon),
        neglectSelector = a17.neglectSelector or a17.NeglectSelector or false,
        customOrder = a17.customOrder or a17.CustomOrder or 0,
                forgetState = a17.forgetState or a17.ForgetState or false,
        _isSettingsTab = a17.isSettingsTab == true or a17.IsSettingsTab == true,
        deriveFlagFromName = flagNames.deriveFlagFromName,

        elements = {},
        connections = {},     }, state)

        assert(self.name or self.icon, "A tab needs a name or an icon.")

        if not self.neglectSelector then
        icon.build(self, self.window.layout)
    end

        self.tabPage = self.window:Create("ScrollingFrame", {
        Name = self.name,
        Size = selector(self.window.layout),
        Position = a15(self.window.layout),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,

        LayoutOrder = self.customOrder or 0,

        Parent = self.window.elements,
    })

    self.tabPageLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tabPage,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 33),

        Parent = self.tabPage,
    })

    self:_bindSelector()

    return self
end

function state:_bindSelector()
    if self.neglectSelector or not self.topbarItemInteract then
        return
    end
    table.insert(self.connections, self.window:Connect(self.topbarItemInteract.MouseButton1Click, function()
        props.click()
        self:Select()
    end))
    table.insert(self.connections, self.window:Connect(self.topbarItemInteract.MouseEnter, function()
        if not self.window:_interactive() then
            return
        end
        if self.window.selectedTab ~= self then
            self:_applyVisual("hover", page)
            self:_spinGradients()
        end
    end))
    table.insert(self.connections, self.window:Connect(self.topbarItemInteract.MouseLeave, function()
        if self.window.selectedTab ~= self then
            self:_applyVisual("unselected", page)
        end
    end))
end

function state:_rebuildSelector()
    if self.neglectSelector then
        return
    end
    for _, a18 in self.connections do
        self.window:Disconnect(a18)
    end
    table.clear(self.connections)
    if self.topbarItem then
        self.window:DestroySubtree(self.topbarItem)
    end
    icon.build(self, self.window.layout)
    self:_bindSelector()
end

function state:_applyVisual(a19, a20)
    if self.neglectSelector or not self.topbarItem then
        return
    end

    local a21 = icon.states[self.window.layout.mode][a19]
    if not a21 then
        return
    end

    icon.applyVisual(self, a21, a20)
end

function state:_spinGradients()
    if self.neglectSelector then
        return
    end

    for _, a23 in { self.topbarItemGradient, self.topbarItemStrokeGradient } do
        a23.Rotation = 90 - 360         Tab.tweenService:Create(a23, motion.spec("spin"), { Rotation = 90 }):Play()
    end
end

function state:Select(a24)
            if self.window._searching then
        name.close(self.window, { showTabs = true, jumpTo = false })
    end

    self.window.selectedTab = self
    if self.window._setSettingsMode then
        self.window:_setSettingsMode(self._isSettingsTab == true)
    elseif self.window._applySettingsLayout then
        self.window:_applySettingsLayout(self == self.window.rfSettings)
    end
    -- [[Settings tab content is created lazily (after construction):]]
    -- [[make sure it exists before the page is shown.]]
    if self._isSettingsTab and self.window._constructed and self.window._buildSettingsContent ~= nil then
        self.window:_buildSettingsContent(self)
    end
    self.window:_jumpTo(self.tabPage)

    -- [[A tab nobody has opened yet still has its elements hidden: its page is
    -- [[not the current page of window.elements until the line above, so this
    -- [[is the first frame any of them can be seen. Showing them here is the
    -- [[same instant show the window's reveal used to run for every tab.]]
    if self._elementsPending and not self.window.hidden and not self.window.minimised then
        self.window:_showTabElements(self)
    end

                    local a25 = a24 or not self.window:_interactive()

    if not self.neglectSelector and not a25 then
        self:_applyVisual("selected", element)
    end

    -- [[Topbar mode only (a no-op on the sidebar): the selected pill]]
    -- [[must stay in view as the user moves through a long strip.]]
    self.window:_scrollSelectedTabIntoView(not a25)

    for _, tab in self.window.tabs do
        if tab ~= self.window.selectedTab then
            tab:Deselect(a25)
        end
    end

    if self.window.settingsAction then
        local actionTransparency = if self._isSettingsTab then 0 else 0.6
        if a25 then
            self.window.settingsAction.iconLabel.ImageTransparency = actionTransparency
        else
            motion.tween(self.window.settingsAction.iconLabel, { ImageTransparency = actionTransparency }, "snappy")
        end
    end
end

function state:Deselect(a26)
    if not self.neglectSelector and not a26 then
        self:_applyVisual("unselected", element)
    end
end

function state:_register(element)
    table.insert(self.elements, element)
    window(element, #self.elements * 10)
    self.window:_restoreLate(element)

    if not self.window.hidden and not self.window.minimised and self.window.selectedTab == self then
        -- Controls added after the startup shell is visible should join it
        -- with their normal reveal animation instead of popping in instantly.
        -- Window:_constructionCheckpoint paces these registrations in small
        -- budget-limited batches while the initial host build is still active.
        element:_setShown(true, true)
    else
        -- [[The element stayed hidden with the window: remember that this tab
        -- [[has something to show when it is next opened.]]
        self._elementsPending = true
    end

    self.window:_constructionCheckpoint(false)
    return element
end

function state:CreateButton(a27)
    return self:_register(require(script.Parent.button).new(self, a27))
end

function state:CreateToggle(a28)
    return self:_register(require(script.Parent.toggle).new(self, a28))
end


function state:CreateSection(a30)
    return self:_register(require(script.Parent.section).new(self, a30))
end

function state:CreateText(a31)
    return self:_register(require(script.Parent.text).new(self, a31))
end

function state:CreateChangelog(a32)
    return self:_register(require(script.Parent.changelog).new(self, a32))
end

function state:CreateDivider(a32)
    return self:_register(require(script.Parent.divider).new(self, a32))
end

function state:CreateStat(a35)
    return self:_register(require(script.Parent.stat).new(self, a35))
end

function state:CreateSlider(a36)
    return self:_register(require(script.Parent.slider).new(self, a36))
end

function state:CreateDropdown(a37)
    return self:_register(require(script.Parent.dropdown).new(self, a37))
end

function state:CreateInput(a38)
    return self:_register(require(script.Parent.input).new(self, a38))
end

function state:CreateKeybind(a39)
    return self:_register(require(script.Parent.keybind).new(self, a39))
end

function state:CreateCollapsibleGroup(props)
    return self:_register(require(script.Parent.collapsibleGroup).new(self, props))
end

function state:CreateGroup(a41)
    return self:_register(require(script.Parent.group).new(self, a41))
end

function state:_moveElement(element, a42)
    local a43 = table.find(self.elements, element)
    if not a43 then
        return
    end
    table.remove(self.elements, a43)
    a42 = math.clamp(a42, 1, #self.elements + 1)
    table.insert(self.elements, a42, element)
    for i, el in self.elements do
        window(el, i * 10)
    end
end

function state:Remove()
    local window = self.window

            if window._searching then
        name.close(window, { showTabs = true, jumpTo = window.selectedTab and window.selectedTab.tabPage })
    end

    local a44 = table.find(window.tabs, self)
    if a44 then
        table.remove(window.tabs, a44)
    end

        if window.selectedTab == self then
        window.selectedTab = nil
        -- [[Prefer a fallback from the same rail so removing the selected tab]]
        -- [[cannot yank the user out of settings mode (or into it).]]
        local fallback
        for _, tab in ipairs(window.tabs) do
            if not tab.neglectSelector then
                fallback = fallback or tab
                if (tab._isSettingsTab == true) == (self._isSettingsTab == true) then
                    fallback = tab
                    break
                end
            end
        end
        if fallback then
            fallback:Select()
        end
    end

            customOrder(window, self.elements)

            for _, a45 in self.connections do
        window:Disconnect(a45)
    end
    self.connections = {}

    if self.topbarItem then
        window:DestroySubtree(self.topbarItem)
    end
    if self.tabPage then
        window:DestroySubtree(self.tabPage)
    end
    -- [[The removed row may have been the widest: re-derive the]]
    -- [[responsive rail's width from the rows that remain (no-op elsewhere).]]
    window:_applyContentRailWidth()
    self.topbarItem = nil
    self.tabPage = nil
    self.elements = {}
end

return state
