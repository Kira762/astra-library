local state = {}
state.__index = state
state.__type = "Dropdown"

local constants = script.Parent.Parent.utilities

local Dropdown = require(constants.Parent.core.state)
local tab = require(script.Parent.Parent.functions)
local props = require(script.Parent.Parent.images.image)
local name = require(constants.constants)
local flag = require(constants.locale)
local options = require(constants.HapticEngine)
local value = require(constants.windowSizing)
local multiSelect = require(constants.lockable)
local description = require(script.Parent.description)

local placeholder = name.icons.chevron
local callback = name.icons.check
local element = name.icons.dot
local frame = name.icons.search

local button = UDim.new(0, 12)
local list = UDim.new(0, 7)

local isOpen = 30
local selected = 38

local a19 = 38
local a20 = 5
local a21 = 2
local a22 = 41
local a23 = 6
local a24 = 7
local a25 = 6
local a26 = a24 + a25

local a27 = 4

local a28 = 22
local a29 = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local a30 = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local a31 = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local a32 = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local a33 = TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local a34 = 0.4
local a35 = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local function a36(a37)
    local a38 = {}
    local a39 = {}
    for _, v in a37 do
        if typeof(v) == "string" and not a38[v] then
            a38[v] = true
            table.insert(a39, v)
        end
    end
    return a39
end

local function a40(a41, a42)
    if a41 == nil then
        return {}
    end
    if typeof(a41) == "string" then
        return { a41 }
    end
    if typeof(a41) == "table" then
        local a43 = a36(a41)
        if not a42 and #a43 > 1 then
            return { a43[1] }
        end
        return a43
    end
    return {}
end

local function a44(a45, a46)
    local a47 = {}
    for _, v in a45 do
        if table.find(a46, v) then
            table.insert(a47, v)
        end
    end
    return a47
end

local function a48(a, b)
    if #a ~= #b then
        return false
    end
    for _, v in a do
        if not table.find(b, v) then
            return false
        end
    end
    return true
end

function state.new(tab, a49)
    a49 = if typeof(a49) == "table" then a49 else {}

    local a50 = a49.options or a49.Options or {}
    local a51 = a49.multiSelect or a49.MultiSelect or a49.MultipleOptions or false

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = a49.name or a49.Name or "Dropdown",
        description = a49.description or a49.Description,
        icon = tab.window:ResolveIcon(a49.icon or a49.Icon),
        forgetState = a49.forgetState or a49.ForgetState or tab.forgetState,
        flag = a49.flag
            or a49.Flag
            or (
                not (a49.forgetState or a49.ForgetState or tab.forgetState)
                    and tab.deriveFlagFromName(a49.name or a49.Name or "Dropdown")
                or nil
            ),

        callback = a49.callback or a49.Callback or function() end,

        options = a36(a50),
        multiSelect = a51,
        placeholderText = flag.resolve(a49.placeholder or a49.Placeholder or "None"),
        value = a40(
            a49.value or a49.Value or a49.currentOption or a49.CurrentOption,
            a51
        ),

        _isOpen = false,
        _searchOpen = false,
        _optionFrames = {},
        _optionsBuilt = false,
    }, state)

            self._desiredValue = self.value
    self.value = a44(self.value, self.options)

        self.window:_registerControl(self)

                    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    -- [[The card grows for a description before anything is built inside it:
    -- [[the visible top card, the title row and the value column all seat
    -- [[themselves against the base region of the taller card, and the option
    -- [[panel keeps its 41px card plus the gap above it.]]
    description.attach(self)

        self.top = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, description.height(self, 41)),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        ZIndex = 1,

        Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })

            self.stroke = self.window:StyleElementBody(self.top)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.top)
    self.flashTarget = self.top
    self.container = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.top,
        Size = UDim2.new(1, -195, 0, 16),
        Position = UDim2.new(0, 20, description.center(self, 41)),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

                        ImageTransparency = 1,
            ZIndex = 5,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = flag.t(self.name),

        Size = UDim2.new(1, if self.icon then -21 else 0, 0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1,
        ZIndex = 5,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.selectedLabel = self.window:Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -41, description.center(self, 41)),
        Size = UDim2.fromOffset(130, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,

        TextTransparency = 1,
        ZIndex = 5,
        Parent = self.top,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.chevron = self.window:Create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, description.center(self, 41)),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(placeholder),
        Rotation = 180,

                ImageTransparency = 1,
        ZIndex = 5,
        Parent = self.top,
    }, { ImageColor3 = "ContentColor" })

        self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, description.height(self, 41)),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,
        AutoButtonColor = false,

        Parent = self.main,
    })

                    self.panel = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, -(a22 + a23 + (self._descriptionExtra or 0))),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 1,

        BackgroundTransparency = 1,
        Parent = self.main,
    })

    self.panelStroke = self.window:StyleElementPanel(self.panel)

                self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.panel,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, a24),
        PaddingBottom = UDim.new(0, a25),

        Parent = self.panel,
    })

    -- [[The search bar is built with the rows, on the first open: until then
    -- [[it is behind a closed panel and cannot be reached.]]
    self:_buildActions()

    self.list = self.window:Create("ScrollingFrame", {
        Active = true,
        Size = UDim2.new(1, 0, 0, 0),         BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Color3.fromRGB(240, 240, 240),
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 1,         ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 3,
        ZIndex = 1,

        Parent = self.panel,
    })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,

        Parent = self.list,
    })

    self.window:ConnectFor(self, self.list:GetPropertyChangedSignal("CanvasPosition"), function()
        self:_syncScrollHint()
    end)
    self.window:ConnectFor(self, self.list:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
        self:_syncScrollHint()
    end)

                self.window:ConnectFor(self, self.list:GetPropertyChangedSignal("AbsoluteWindowSize"), function()
        self:_syncScrollHint()
    end)

    self.listLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.list,
    })

            self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, a21),
        PaddingBottom = UDim.new(0, a21),

        Parent = self.list,
    })

            self.emptyLabel = self.window:Create("TextLabel", {
        Name = "Empty",
        Size = UDim2.new(1, -12, 0, a19),
        BackgroundTransparency = 1,
        Text = flag.t("No matches"),
        TextSize = 14,
        TextTransparency = 0.55,
        Visible = false,
        LayoutOrder = 1,

        Parent = self.list,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    local function a52(a53)
        return table.find(self.value, a53) ~= nil
    end

    local function a54(a55, a56)
        local a57 = a52(a55.name)
        local a58 = if self._isOpen then (a57 and 0.9 or 0.95) else 1
        local a59 = if self._isOpen then (a57 and 0 or 0.3) else 1
                local a60 = if self._isOpen then (a57 and 0 or 0.7) else 1
        local a61 = if self._isOpen then (a57 and 0.85 or 0.93) else 1

        props.assign(a55.checkIcon, "Image", if a57 then callback else element)

        if a56 then
            local a62 = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            Dropdown.tweenService:Create(a55.frame, a62, { BackgroundTransparency = a58 }):Play()
            Dropdown.tweenService:Create(a55.title, a62, { TextTransparency = a59 }):Play()
            Dropdown.tweenService:Create(a55.checkIcon, a62, { ImageTransparency = a60 }):Play()
            Dropdown.tweenService:Create(a55.stroke, a62, { Transparency = a61 }):Play()
        else
            a55.frame.BackgroundTransparency = a58
            a55.title.TextTransparency = a59
            a55.checkIcon.ImageTransparency = a60
            a55.stroke.Transparency = a61
        end
    end

    local function a63()
        if self.multiSelect then
            local n = #self.value
            if n == 0 then
                self.selectedLabel.Text = self.placeholderText
            elseif n == 1 then
                self.selectedLabel.Text = self.value[1]
            else
                self.selectedLabel.Text = flag.resolve("Various")
            end
        else
            self.selectedLabel.Text = self.value[1] or self.placeholderText
        end
    end

    self._renderOptionState = a54
    self._updateSelectedLabel = a63

    local function a64(a65)
        local a66 = self.window:Create("Frame", {
            Size = UDim2.new(1, -12, 0, a19),
            BorderSizePixel = 0,
                                    LayoutOrder = #self._optionFrames + 1,

            BackgroundTransparency = 1,

            Parent = self.list,
        }, { BackgroundColor3 = "DropdownHighlight" })

                local a67 = self.window:Create("UICorner", {
            CornerRadius = list,
            Parent = a66,
        })

                local a68 = self.window:Create("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 1,             Parent = a66,
        })

        local a69 = self.window:Create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextTransparency = 1,
            ZIndex = 50,
            Parent = a66,
        })

        local a70 = self.window:Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,
            Parent = a66,
        })

        self.window:Create("UIListLayout", {
            Padding = UDim.new(0, 5),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = a70,
        })

        local a71 = self.window:Create("ImageLabel", {
            Image = "rbxassetid://" .. tostring(callback),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            ZIndex = 5,
            Parent = a70,
        }, { ImageColor3 = "ContentColor" })

        local a72 = self.window:Create("TextLabel", {
            Text = a65,
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            ZIndex = 5,
            Parent = a70,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        local a73 = {
            name = a65,
            frame = a66,
            interact = a69,
            title = a72,
            checkIcon = a71,
            container = a70,
            stroke = a68,
            corner = a67,
                        connections = {},
        }

        table.insert(
            a73.connections,
            self.window:ConnectFor(self, a66.MouseEnter, function()
                if not self._isOpen or not self.window:_interactive() then
                    return
                end
                if a52(a73.name) then
                    return
                end
                Dropdown.tweenService
                    :Create(
                        a66,
                        a29,
                        { BackgroundTransparency = 0.9 }
                    )
                    :Play()
                Dropdown.tweenService
                    :Create(
                        a72,
                        a29,
                        { TextTransparency = 0.15 }
                    )
                    :Play()
            end)
        )

        table.insert(
            a73.connections,
            self.window:ConnectFor(self, a66.MouseLeave, function()
                if not self._isOpen then
                    return
                end
                if a52(a73.name) then
                    return
                end
                Dropdown.tweenService
                    :Create(
                        a66,
                        a29,
                        { BackgroundTransparency = 0.95 }
                    )
                    :Play()
                Dropdown.tweenService
                    :Create(
                        a72,
                        a29,
                        { TextTransparency = 0.3 }
                    )
                    :Play()
            end)
        )

        table.insert(
            a73.connections,
            self.window:ConnectFor(self, a69.MouseButton1Click, function()
                                if not self._isOpen then
                    return
                end
                options.click()
                local a74 = a52(a73.name)

                if not self.multiSelect then
                    if a74 then
                        self:_close()
                        return
                    end
                    table.clear(self.value)
                    table.insert(self.value, a73.name)
                else
                    if a74 then
                        local a75 = table.find(self.value, a73.name)
                        if a75 then
                            table.remove(self.value, a75)
                        end
                    else
                        table.insert(self.value, a73.name)
                    end
                end

                                                self._desiredValue = table.clone(self.value)

                for _, d in self._optionFrames do
                    a54(d, true)
                end

                a63()

                self.window:_runGuarded(self, self.callback, self:_callbackValue())
                self.window:_persist(self)

                if not self.multiSelect then
                    task.wait(0.1)
                    if self.window.unloaded or not self.main.Parent then
                        return
                    end
                    self:_close()
                end
            end)
        )

        return a73
    end

    self._buildOption = a64

    -- [[Rows are built on the first open, not here: a closed dropdown shows
    -- [[only its header, so its options cost nothing until the user looks at
    -- [[them. self.options stays the source of truth, so anything that changes
    -- [[the list while closed is simply reflected the next time it opens.]]

    a63()
    self:_updateCorners()

        self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        options.click()
        if self._isOpen then
            self:_close()
        else
            self:_open()
        end
    end)

            self.window:ConnectFor(self, self.main.MouseEnter, function()
        if self._isOpen or not self.window:_interactive() then
            return
        end
        Dropdown.tweenService
            :Create(self.title, a30, { TextColor3 = self.window.theme.ElementTextHoverColor })
            :Play()
        Dropdown.tweenService:Create(self.hoverOverlay, a30, { BackgroundTransparency = 0.97 }):Play()
        Dropdown.tweenService
            :Create(self.stroke, a30, {
                Transparency = self.window.theme.ElementStrokeHoverTransparency,
                Color = self.window.theme.ElementStrokeHover,
            })
            :Play()
    end)

    self.window:ConnectFor(self, self.main.MouseLeave, function()
        Dropdown.tweenService:Create(self.title, a30, { TextColor3 = self.window.theme.ContentColor }):Play()
        Dropdown.tweenService:Create(self.hoverOverlay, a30, { BackgroundTransparency = 1 }):Play()
        Dropdown.tweenService
            :Create(self.stroke, a30, {
                Transparency = self.window.theme.ElementStrokeTransparency,
                Color = self.window.theme.ElementStroke,
            })
            :Play()
    end)

    return self
end

function state:_callbackValue()
    if self.multiSelect then
        return table.clone(self.value)
    end
    return self.value[1]
end

function state:_buildSearch()
    self._searchOpen = false

    self.searchbar = self.window:Create("Frame", {
        Name = "Search",
        Size = UDim2.new(1, -12, 0, isOpen),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,         LayoutOrder = 1,
        ClipsDescendants = false,
        ZIndex = 1,

        Parent = self.panel,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = self.searchbar,
    })

    self.searchStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,         Parent = self.searchbar,
    })

    self.searchShadow = self.window:CreateGlow(self.searchbar, Color3.fromRGB(255, 255, 255), 20, 1)
            self.searchToggle = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 51,
        Parent = self.searchbar,
    })

    self.searchInput = self.window:Create("TextBox", {
        Text = "",
        PlaceholderText = flag.t("Search..."),
        Size = UDim2.new(1, -58, 0, 16),
        Position = UDim2.new(0, 44, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextEditable = false,         Interactable = false,         ZIndex = 52,

        TextTransparency = 1,
        Parent = self.searchbar,
    }, { TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })

    self.searchIcon = self.window:Create("ImageButton", {
        Image = "rbxassetid://" .. tostring(frame),
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(0, 24, 0.5, 0),         AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        ZIndex = 53,

        ImageTransparency = 1,
        Parent = self.searchbar,
    }, { ImageColor3 = "ContentColor" })

    self.window:ConnectFor(self, self.searchToggle.MouseButton1Click, function()
        if not self._searchOpen then
            self:_expandSearch()
        end
    end)
    self.window:ConnectFor(self, self.searchIcon.MouseButton1Click, function()
        if self._searchOpen then
            self:_collapseSearch()
        else
            self:_expandSearch()
        end
    end)
    self.window:ConnectFor(self, self.searchInput:GetPropertyChangedSignal("Text"), function()
        self:_applyFilter(self.searchInput.Text)
    end)
    self.window:ConnectFor(self, self.searchInput.FocusLost, function()
        if self.searchInput.Text == "" then
            self:_collapseSearch()
        end
    end)
end

function state:_expandSearch()
    if self._searchOpen then
        return
    end
    self._searchOpen = true
    self.searchInput.TextEditable = true
    self.searchInput.Interactable = true

    Dropdown.tweenService
        :Create(
            self.searchbar,
            a35,
            { Size = UDim2.new(1, -12, 0, selected), BackgroundTransparency = 0.92 }
        )
        :Play()
    Dropdown.tweenService:Create(self.searchStroke, a35, { Transparency = 0.86 }):Play()
    Dropdown.tweenService:Create(self.searchShadow, a35, { Transparency = 0.92 }):Play()
    Dropdown.tweenService:Create(self.searchInput, a35, { TextTransparency = 0.3 }):Play()

    self:_resizeToOptions()     self.searchInput:CaptureFocus()
end

function state:_collapseSearch()
    if not self._searchOpen then
        return
    end
    self._searchOpen = false
    self.searchInput.TextEditable = false
    self.searchInput.Interactable = false
    self.searchInput:ReleaseFocus()
    self.searchInput.Text = ""
    Dropdown.tweenService
        :Create(
            self.searchbar,
            a35,
            { Size = UDim2.new(1, -12, 0, isOpen), BackgroundTransparency = 1 }
        )
        :Play()
    Dropdown.tweenService:Create(self.searchStroke, a35, { Transparency = 1 }):Play()
    Dropdown.tweenService:Create(self.searchShadow, a35, { Transparency = 1 }):Play()
    Dropdown.tweenService:Create(self.searchInput, a35, { TextTransparency = 1 }):Play()

    self:_resizeToOptions()
end

function state:_applyFilter(a78)
    a78 = string.lower(a78 or "")
    local a79 = 0
    for _, a80 in self._optionFrames do
        local a81 = a78 == "" or string.find(string.lower(a80.name), a78, 1, true) ~= nil
        a80.frame.Visible = a81
        if a81 then
            a79 += 1
        end
    end

            self.emptyLabel.Visible = a79 == 0 and a78 ~= ""
    self:_updateCorners()
    self:_resizeToOptions()
    self:_syncScrollHint()
end

function state:_syncScrollHint()
        local a82, a83, at =
        self.list.AbsoluteCanvasSize, self.list.AbsoluteWindowSize, self.list.CanvasPosition
    if not a82 or not a83 or not at then
        return
    end

    local a84 = self._isOpen and a83.Y > 0 and a82.Y - (at.Y + a83.Y) > 1

    Dropdown.tweenService
        :Create(self.list, a29, { ScrollBarImageTransparency = if a84 then a34 else 1 })
        :Play()
end

function state:_visibleOptions(): { string }
    local a85 = {}
    for _, a86 in self._optionFrames do
        if a86.frame.Visible then
            table.insert(a85, a86.name)
        end
    end
    return a85
end

function state:_buildActions()
    if not self.multiSelect then
        return     end

    self.actions = self.window:Create("Frame", {
        Name = "Actions",
        Size = UDim2.new(1, -12, 0, a28),
        BackgroundTransparency = 1,
        LayoutOrder = 2,

        Parent = self.panel,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 12),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.actions,
    })

    local function a87(a88: string, a89: number, a90: () -> ())
        local a91 = self.window:Create("TextButton", {
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, a28),
            BackgroundTransparency = 1,
            Text = flag.t(a88),
            TextSize = 13,
            TextTransparency = 0.45,             LayoutOrder = a89,

            Parent = self.actions,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        self.window:ConnectFor(self, a91.MouseEnter, function()
            Dropdown.tweenService:Create(a91, a29, { TextTransparency = 0.15 }):Play()
        end)
        self.window:ConnectFor(self, a91.MouseLeave, function()
            Dropdown.tweenService:Create(a91, a29, { TextTransparency = 0.45 }):Play()
        end)
        self.window:ConnectFor(self, a91.MouseButton1Click, function()
            a90()
            self:_afterBulkChange()
        end)

        return a91
    end

                a87("Select all", 1, function()
        local a92 = self:_visibleOptions()
        for _, a93 in a92 do
            if not table.find(self.value, a93) then
                table.insert(self.value, a93)
            end
        end
    end)
    a87("Clear", 2, function()
        local a94 = self:_visibleOptions()
        for a95 = #self.value, 1, -1 do
            if table.find(a94, self.value[a95]) then
                table.remove(self.value, a95)
            end
        end
    end)
end

function state:_afterBulkChange()
            self._desiredValue = table.clone(self.value)

    for _, a96 in self._optionFrames do
        self._renderOptionState(a96, true)
    end
    self:_updateSelectedLabel()
    self:_updateCorners()
    self.window:_runGuarded(self, self.callback, self:_callbackValue())
    self.window:_persist(self)
    options.click()
end

function state:_resizeToOptions()
    if not self._isOpen then
        return
    end
    Dropdown.tweenService:Create(self.main, a35, { Size = UDim2.new(1, -20, 0, self:_openHeight()) }):Play()
end

function state:_updateCorners()
    local a97 = {}
    for _, a98 in self._optionFrames do
        if a98.frame.Visible then
            table.insert(a97, a98)
        end
    end

    for i, a99 in a97 do
        local a100 = if i == 1 then button else list
        local a101 = if i == #a97 then button else list
        a99.corner.TopLeftRadius = a100
        a99.corner.TopRightRadius = a100
        a99.corner.BottomLeftRadius = a101
        a99.corner.BottomRightRadius = a101
    end
end

local function a102(a103: number): number
    return a103 * a19 + math.max(0, a103 - 1) * a20 + a21 * 2
end

local function a104(a105: number): number
    return math.max(math.floor((a105 - a21 * 2 + a20) / (a19 + a20)), 1)
end

function state:_pageHeight(): number
    local a106 = self.window.size
    return value.pageHeight(a106 and a106.Y.Offset, self.window.layout.mode)
end

function state:_openHeight()
    local n = 0
    for _, a107 in self._optionFrames do
        if a107.frame.Visible then
            n += 1
        end
    end

            local a108 = if self._searchOpen then selected else isOpen
    local a109 = a22
        + a23
        + a26
        + a108
        + a20
        + (if self.actions then a28 + a20 else 0)

    local a110 = self:_pageHeight()
        local a111 = math.min(math.max(n, 1), a27, a104(a110 - a109))

    return math.min(a109 + a102(a111), a110) + (self._descriptionExtra or 0)
end

-- [[Materialise one row, by option index. Idempotent: the row keeps whatever
-- [[state it already carries, so this can be called from any path that needs
-- [[the row to exist.]]
function state:_buildOptionAt(a: number)
    local built = self._optionFrames[a]
    if built then
        return built
    end

    local optionFrame = self._buildOption(self.options[a])
    optionFrame.frame.LayoutOrder = a
    self._optionFrames[a] = optionFrame
    return optionFrame
end

-- [[Build every row the current option list implies. Called when the list is
-- [[first looked at (opening), which is also the first moment the rows can be
-- [[seen, measured or hovered.]]
function state:_materialiseOptions()
    if self._optionsBuilt then
        return
    end
    self._optionsBuilt = true

    -- [[The bar goes in first, exactly where construction used to put it, so
    -- [[the panel's child order is what it always was. It is a sibling of the
    -- [[list (LayoutOrder 1 against the list's 3), not of the rows.]]
    if not self.searchbar then
        self:_buildSearch()
    end

    for a = 1, #self.options do
        self:_buildOptionAt(a)
    end
end

function state:_open()
    if self._isOpen then
        return
    end
    self:_materialiseOptions()
    self:_updateCorners()
    self._isOpen = true

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
    end
    self._outsideClickConn = self.window:Connect(Dropdown.userInputService.InputBegan, function(a112)
        if
            a112.UserInputType ~= Enum.UserInputType.MouseButton1
            and a112.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local a113 = a112.Position
        local a114 = self.main.AbsolutePosition
        local a115 = self.main.AbsoluteSize
        if
            a113.X < a114.X
            or a113.X > a114.X + a115.X
            or a113.Y < a114.Y
            or a113.Y > a114.Y + a115.Y
        then
            self:_close()
        end
    end)

    Dropdown.tweenService
        :Create(
            self.main,
            a32,
            { Size = UDim2.new(1, -20, 0, self:_openHeight()) }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.chevron,
            a33,
            { Rotation = 0 }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.panel,
            a31,
            { BackgroundTransparency = self.window.theme.ElementTransparency or 0 }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.panelStroke,
            a31,
            { Transparency = self.window.theme.ElementStrokeTransparency }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.searchIcon,
            a31,
            { ImageTransparency = 0.5 }
        )
        :Play()

    for _, a116 in self._optionFrames do
        self._renderOptionState(a116, true)
    end

    self:_syncScrollHint()
    self:_bringIntoView()
end

function state:_bringIntoView()
    -- [[Controls built inside a Collapsible Group receive the group as their]]
    -- [[`tab` (that is what parents them into the group body), and an ordinary]]
    -- [[Group nests one link deeper still. Only the real Tab's tabPage is a]]
    -- [[ScrollingFrame: the group's body is a plain Frame, so reading]]
    -- [[AbsoluteWindowSize/CanvasPosition off it throws on the engine. Walk]]
    -- [[the owner chain up to the Tab before touching scroll members.]]
    local host = self.tab
    while host and host.__type ~= "Tab" do
        host = host.tab
    end
    local a117 = host and host.tabPage
    if not a117 then
        return
    end

        local a118, at, a119, a120 =
        a117.AbsoluteWindowSize, a117.CanvasPosition, a117.AbsolutePosition, self.main.AbsolutePosition
    if not a118 or not at or not a119 or not a120 or a118.Y <= 0 then
        return
    end

        local a121 = a120.Y - a119.Y + at.Y
    local a122 = a121 + self:_openHeight()
    local a123 = a122 - (at.Y + a118.Y)
    if a123 <= 0 then
        return     end

            local a124 = math.min(at.Y + a123 + 8, a121)
    Dropdown.tweenService
        :Create(a117, a31, {
            CanvasPosition = Vector2.new(at.X, a124),
        })
        :Play()
end

function state:_close()
    if not self._isOpen then
        return
    end
    self._isOpen = false

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
        self._outsideClickConn = nil
    end

    self:_collapseSearch()
    self:_syncScrollHint()

    Dropdown.tweenService
        :Create(
            self.chevron,
            a33,
            { Rotation = 180 }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.panel,
            a31,
            { BackgroundTransparency = 1 }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.panelStroke,
            a31,
            { Transparency = 1 }
        )
        :Play()
    Dropdown.tweenService
        :Create(
            self.searchIcon,
            a31,
            { ImageTransparency = 1 }
        )
        :Play()

    for _, a125 in self._optionFrames do
        self._renderOptionState(a125, true)
    end

    Dropdown.tweenService
        :Create(
            self.main,
            a32,
            { Size = UDim2.new(1, -20, 0, description.height(self, 41)) }
        )
        :Play()
end

function state:_destroyOption(a126)
    if a126.connections then
        for _, a127 in a126.connections do
            local a128 = table.find(self.connections, a127)
            if a128 then
                table.remove(self.connections, a128)
            end
            self.window:Disconnect(a127)
        end
        a126.connections = nil
    end
    self.window:DestroySubtree(a126.frame)
end

function state:_deriveSelection()
    local a129 = self.value
    self.value = a44(self._desiredValue or self.value, self.options)
    return not a48(self.value, a129)
end

function state:_reindexOptions()
    for a130, a131 in self._optionFrames do
        a131.frame.LayoutOrder = a130
    end
end

function state:_rebindOption(a132, a133, a134)
    a132.name = a133
    a132.title.Text = a133
    a132.frame.LayoutOrder = a134
end

function state:_destroyOptionsFrom(a135)
    local a136, a137 = {}, {}

    for a138 = #self._optionFrames, a135, -1 do
        local a139 = self._optionFrames[a138]
        table.insert(a136, a139.frame)
        if a139.connections then
            table.move(a139.connections, 1, #a139.connections, #a137 + 1, a137)
            a139.connections = nil
        end
        self._optionFrames[a138] = nil
    end

    self.window:DisconnectMany(self, a137)
    self.window:DestroySubtrees(a136)
end

function state:Refresh(a140)
    self.options = a36(a140 or {})

    local a141 = self:_deriveSelection()

    -- [[A dropdown that was never opened has no rows to rebind: the new list
    -- [[is what the rows are built from the first time it is opened.]]
    if self._optionsBuilt then
                        local a142 = #self._optionFrames
        local a143 = #self.options

        for a144 = 1, math.min(a142, a143) do
            self:_rebindOption(self._optionFrames[a144], self.options[a144], a144)
        end

        for a145 = a142 + 1, a143 do
            local a146 = self._buildOption(self.options[a145])
            a146.frame.LayoutOrder = a145
            table.insert(self._optionFrames, a146)
        end

        if a143 < a142 then
            self:_destroyOptionsFrom(a143 + 1)
        end

                    for _, a147 in self._optionFrames do
            self._renderOptionState(a147, false)
        end
    end

    self._updateSelectedLabel()
        self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")

        if a141 then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function state:Add(a148)
    if typeof(a148) ~= "string" or a148 == "" then
        return
    end
    if table.find(self.options, a148) then
        return
    end

    table.insert(self.options, a148)
    -- [[While the rows are still unbuilt the option list is the only record;
    -- [[the new row appears with the rest the first time this dropdown opens.]]
    local a149 = if self._optionsBuilt then self:_buildOptionAt(#self.options) else nil

        local a150 = self:_deriveSelection()

    if self._isOpen and a149 then
        self:_renderOptionState(a149, true)
    end

            self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")

        if a150 then
        self._updateSelectedLabel()
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function state:Remove(a151)
    local a152 = table.find(self.options, a151)
    if not a152 then
        return
    end

    table.remove(self.options, a152)

    for i, a153 in self._optionFrames do
        if a153.name == a151 then
            self:_destroyOption(a153)
            table.remove(self._optionFrames, i)
            self:_reindexOptions()
            break
        end
    end

            if self._desiredValue then
        local a154 = table.find(self._desiredValue, a151)
        if a154 then
            table.remove(self._desiredValue, a154)
        end
    end

    local a155 = table.find(self.value, a151)
    if a155 then
        table.remove(self.value, a155)
        self._updateSelectedLabel()
                self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end

        self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")
end

function state:Set(a156, a157)
    local a158 = a40(a156, self.multiSelect)
        self._desiredValue = a158
    self.value = a44(a158, self.options)

    for _, a159 in self._optionFrames do
        self._renderOptionState(a159, true)
    end
    self._updateSelectedLabel()

    if not a157 then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)     end
end

function state:_setShown(a160, a161)
            local w = self.window
    w:_reveal(self.stroke, { Transparency = if a160 then w.theme.ElementStrokeTransparency else 1 }, a161)
    w:_reveal(self.title, { TextTransparency = if a160 then 0 else 1 }, a161)
    w:_reveal(self.top, { BackgroundTransparency = if a160 then (w.theme.ElementTransparency or 0) else 1 }, a161)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if a160 then 0 else 1 }, a161)
    end
    w:_reveal(self.selectedLabel, { TextTransparency = if a160 then 0.5 else 1 }, a161)
    w:_reveal(self.chevron, { ImageTransparency = if a160 then 0.5 else 1 }, a161)

        if not a160 and self._isOpen then
        self:_close()
    end
end

function state:MoveTo(a162)
    self.tab:_moveElement(self, a162)
end

function state:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function state:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function state:MoveUp()
    local a163 = table.find(self.tab.elements, self)
    if a163 then
        self.tab:_moveElement(self, a163 - 1)
    end
end

function state:MoveDown()
    local a164 = table.find(self.tab.elements, self)
    if a164 then
        self.tab:_moveElement(self, a164 + 1)
    end
end

multiSelect(state)

return state
