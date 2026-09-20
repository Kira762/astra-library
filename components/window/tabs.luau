local chrome = require(script.Parent.Parent.chrome)
local search = require(script.Parent.Parent.search)
local tooltip = require(script.Parent.Parent.tooltip)

local shared = require(script.Parent.constants)
local compactRowHeight = shared.compactRowHeight

local Window = require(script.Parent.class)

function Window:CreateTab(props)
    assert(not self.unloaded, "Cannot create a tab on an unloaded window.")
    local tab = require(script.Parent.Parent.Parent.elements.tab).new(self, props)

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

function Window:CreateSection(props)
    assert(not self.unloaded, "Cannot create a section on an unloaded window.")
    local section = require(script.Parent.Parent.Parent.elements.tabSection).new(self, props)
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
