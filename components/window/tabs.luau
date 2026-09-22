local chrome = require(script.Parent.Parent.chrome)
local search = require(script.Parent.Parent.search)
local tooltip = require(script.Parent.Parent.tooltip)

local shared = require(script.Parent.constants)
local compactRowHeight = shared.compactRowHeight

local Window = require(script.Parent.class)

-- [[An unloaded window still accepts construction. The anti-duplicate guard
-- [[can replace this window while a superseded script's build is still adding
-- [[tabs — a key-system `onSuccess` interleaved with a re-execution is the
-- [[common case — and that thread must finish harmlessly, the same contract
-- [[`Window:Create` honours with its construction graveyard, not die to an
-- [[assert inside the caller's callback ("Astra: key system callback errored:
-- [[Cannot create a tab on an unloaded window"). `Tab.new` routes every
-- [[instance through `Window:Create`, which parents into the graveyard once
-- [[`unloaded` is set, so the returned tab is real and the host's remaining
-- [[element constructors keep working detached. Only the live-tree
-- [[bookkeeping is skipped: a dead window has no rail to insert into, select
-- [[on, or re-apply settings chrome to.]]
function Window:CreateTab(props)
    local tab = require(script.Parent.Parent.Parent.elements.tab).new(self, props)

    if self.unloaded then
        return tab
    end

    table.insert(self.tabs, tab)

    if not tab.neglectSelector then
        local isFirst = true
        for _, existingTab in self.tabs do
            if
                existingTab ~= tab
                and not existingTab.neglectSelector
                and not existingTab.locked
                and self:_railGroup(existingTab) == self:_railGroup(tab)
            then
                isFirst = false
                break
            end
        end
        -- [[A locked first tab must not steal the selection from the row
        -- [[behind it; and a locked tab never selects itself.]]
        if isFirst and not tab.locked then
            tab:Select(true)
        end

                        if not self.hidden and not self.minimised then
            tab.topbarItem.Visible = true
            tab:_applyVisual(
                if self.selectedTab == tab then "selected" else "unselected",
                "normal"
            )
        end
        -- [[A runtime-created tab may belong to the other rail.]]
        -- [[Re-apply the rail filter so it lands in the correct rail.]]
        self:_applySettingsLayout(self._settingsMode)
    end

    self:_constructionCheckpoint(false)
    return tab
end

-- [[The same contract as CreateTab: a section owed to an unloaded window is
-- [[built detached (its instances land in the construction graveyard through
-- [[`Window:Create`) instead of asserting, and only the live visibility pass
-- [[is skipped.]]
function Window:CreateSection(props)
    local section = require(script.Parent.Parent.Parent.elements.tabSection).new(self, props)
    if self.unloaded then
        return section
    end

    table.insert(self.tabSections, section)

            if not section.inert and not self.hidden and not self.minimised then
        section:_setVisible(true)
        section:_setShown(true, false)
    end

    return section
end

function Window:_setTabSectionsShown(shown, tweenInfo)
    for _, section in self.tabSections do
        section:_setShown(shown, tweenInfo)
    end
end

function Window:_setTabSectionsVisible(visible)
    for _, section in self.tabSections do
        section:_setVisible(visible)
    end
end

function Window:_refreshTabStripChrome()
end

function Window:_scrollSelectedTabIntoView(_tweened)
end

function Window:_railGroup(tab)
    if tab._isSettingsTab then
        return "settings"
    end
    return "main"
end

function Window:_activeRail()
    if self._settingsMode then
        return "settings"
    end
    return "main"
end

-- [[The icon label of a topbar action frame, or nil. `frame.ImageLabel` is a]]
-- [[direct child read on Roblox, not a safe one: the action container also]]
-- [[holds chrome with no icon - the search pill and other dividers - and]]
-- [[indexing a missing child raises "ImageLabel is not a valid member of]]
-- [[Frame". Every action-loop read goes through here instead of reading]]
-- [[frame.ImageLabel directly.]]

function Window:_jumpTo(page)
    if not page then
        return
    end
    tooltip.hide(self)
    if page.Parent == self.elements then
        self.elementsLayout:JumpTo(page)
    end
end

function Window:Navigate(tab)
    if tab == nil then
        return
    end

    local found
    -- [[The loop variable must not shadow the `tab` argument: `tab == tab`
    -- [[was always true, so every Navigate call selected the first tab in
    -- [[the list (the settings General tab) no matter what was asked for.]]
    for _, existing in self.tabs do
        if tab == existing or existing.name == tab or existing.tabPage == tab then
            found = existing
            break
        end
    end

    if not found then
        return
    end
    if found.locked then
        -- [[The gate holds for programmatic navigation too; the host unlocks
        -- [[through tab:SetLocked, not around it.]]
        return
    end
    found:Select()
end

function Window:_buildCompactRow(tab, name, zIndex)
    local row = self:Create("Frame", {
        Name = name,
        Size = UDim2.fromOffset(0, compactRowHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        ClipsDescendants = true,         BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,
        Parent = tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    local stroke = self:StyleElementBody(row)

        self:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,
        Parent = row,
    })

        self:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = row,
    })

        local button = self:Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,         AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactRowHeight),
        BorderSizePixel = 0,
        TextTransparency = 1,
        ZIndex = zIndex or 1,

        Parent = row,
    })

    self:Create("UICorner", {
        Parent = button,
    }, { CornerRadius = "ElementCornerRadius" })

    return row, stroke, button
end
