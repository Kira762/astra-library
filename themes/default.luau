local default = require(script.Parent.Parent.core.state)

-- [[Astra's default palette. The shared keys below are the historical set
-- [[every theme module provides; the Astra-only semantic keys (Background,
-- [[WindowSurface, text tiers, Success/Warning, etc.) are derived from the
-- [[same greyscale + teal accent so the capsule and settings surfaces stay
-- [[coherent with the rest of the theme.]]
return {
    -- [[Semantic palette (derived from the base greys + teal accent)]]
    Background = Color3.fromRGB(10, 10, 10),
    WindowSurface = Color3.fromRGB(25, 25, 25),
    -- [[Surface hierarchy the window's three sections are painted with: the
    -- [[topbar is the darkest, the tab rail one step lighter, the elements
    -- [[area the lightest, so the bands read distinctly from chrome to
    -- [[content instead of blending into one flat gradient. The selected
    -- [[tab row uses ElementSurface too, connecting it to the page it opens.]]
    TopbarSurface = Color3.fromRGB(18, 18, 18),
    SidebarSurface = Color3.fromRGB(25, 25, 25),
    TabSurface = Color3.fromRGB(35, 35, 35),
    TabSelected = Color3.fromRGB(23, 153, 110),
    ElementSurface = Color3.fromRGB(33, 33, 33),
    ElementHover = Color3.fromRGB(40, 40, 40),
    ElementPressed = Color3.fromRGB(22, 22, 22),
    SecondaryElement = Color3.fromRGB(25, 25, 25),
    Stroke = Color3.fromRGB(64, 64, 64),
    SecondaryStroke = Color3.fromRGB(48, 48, 48),
    PrimaryText = Color3.fromRGB(255, 255, 255),
    SecondaryText = Color3.fromRGB(200, 200, 200),
    MutedText = Color3.fromRGB(178, 178, 178),
    DisabledText = Color3.fromRGB(120, 120, 120),
    Accent = Color3.fromRGB(23, 153, 110),
    AccentHover = Color3.fromRGB(32, 201, 144),
    AccentPressed = Color3.fromRGB(0, 134, 98),
    AccentStrokeSemantic = Color3.fromRGB(32, 201, 144),
    Success = Color3.fromRGB(0, 170, 127),
    Warning = Color3.fromRGB(224, 166, 74),
    Error = Color3.fromRGB(185, 50, 50),
    NotificationSurface = Color3.fromRGB(30, 30, 30),
    PopupSurface = Color3.fromRGB(25, 25, 25),
    InputSurface = Color3.fromRGB(18, 18, 18),

    -- [[Shared keys — the set every theme module must provide]]
    -- [[Corner scale. Three tiers, each nested inside the one above so the
    -- [[arcs stay concentric instead of fighting:
    -- [[  12px `CornerRoundness` — the shell: the window silhouette and the
    -- [[     three bands that mirror its corners (topbar top pair, rail
    -- [[     bottom-left, elements bottom-right), plus the surfaces that
    -- [[     float over it (notification, popup).
    -- [[   8px `ElementCornerRadius` — everything that sits *inside* the
    -- [[     shell with padding around it: element cards, field boxes,
    -- [[     hover overlays, tab rows, panels and small chrome.
    -- [[  32px `PillCornerRadius` — the folded states. Half the 64px chrome
    -- [[     height, so the minimised bar reads as a full pill; the 50px
    -- [[     capsule clamps to its own half-height and comes out a pill
    -- [[     too (a circle in the icon-only size). Roblox clamps a corner
    -- [[     to half the smaller side, which is what makes one value serve
    -- [[     both shapes.
    -- [[Controls whose shape is inherently round — the switch, the slider
    -- [[track and handle, the drag grabber, the unread dot — derive a
    -- [[half-height pill from their own metrics rather than reading a token,
    -- [[so they stay round whatever the theme says.]]
    CornerRoundness = UDim.new(0, 12),
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 10)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(25, 25, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
    }),
    ShadowColor = Color3.fromRGB(20, 20, 20),
    ElementStroke = Color3.fromRGB(58, 58, 58),
    CardSurface = Color3.fromRGB(33, 33, 33),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(35, 35, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
    }),
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 56, 56)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(72, 72, 72)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 56, 56)),
    }),
    TabColor = Color3.fromRGB(255, 255, 255),
    TabBackground = ColorSequence.new(Color3.fromRGB(50, 50, 50), Color3.fromRGB(35, 35, 35)),
    TabStroke = ColorSequence.new(Color3.fromRGB(95, 95, 95), Color3.fromRGB(50, 50, 50)),
    SliderBackground = Color3.fromRGB(47, 47, 47),
    SliderBackgroundHover = Color3.fromRGB(60, 60, 60),
    SliderProgress = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
    SliderStroke = Color3.fromRGB(255, 255, 255),
    ActionColor = Color3.fromRGB(255, 255, 255),
    TitleFont = default.brandFont(Enum.FontWeight.SemiBold),
    Font = default.brandFont(Enum.FontWeight.Medium),
    ContentColor = Color3.fromRGB(255, 255, 255),
    LiveAnimation = false,
    DarkToggleOverlay = true,
    ElementTransparency = 0,
    -- [[Grouped children render as defined cards — a surface a shade under the
    -- [[header band and a visible stroke — the crisp rows the design
    -- [[reference shows, not 75%-faded ghosts without strokes.
    CollapsibleChildElementTransparency = 0.35,
    ElementStrokeTransparency = 0,
    CollapsibleChildElementStrokeTransparency = 0,
    ElementStrokeHoverTransparency = 0,
    CollapsibleChildElementStrokeHoverTransparency = 0,
    ElementStrokeHover = Color3.fromRGB(82, 82, 82),
    ElementCornerRadius = UDim.new(0, 8),
    ElementTextHoverColor = Color3.fromRGB(255, 255, 255),
    TitlingColor = Color3.fromRGB(255, 255, 255),
    DropdownHighlight = Color3.fromRGB(255, 255, 255),
    AccentColor = Color3.fromRGB(23, 153, 110),
    AccentStroke = Color3.fromRGB(32, 201, 144),
    AccentGlow = 0.4,
    StatBackground = Color3.fromRGB(25, 25, 25),
    SliderHandle = Color3.fromRGB(255, 255, 255),
    PillCornerRadius = UDim.new(0, 32),
    ToggleTrack = Color3.fromRGB(0, 0, 0),
    ToggleTrackTransparency = 0.9,
    ToggleKnobOff = Color3.fromRGB(255, 255, 255),
    ToggleKnobOffTransparency = 0.8,
    FieldBackground = Color3.fromRGB(255, 255, 255),
    FieldTransparency = 0.9,
    FieldGlow = Color3.fromRGB(255, 255, 255),
    PlaceholderColor = Color3.fromRGB(178, 178, 178),
    SurfaceStroke = Color3.fromRGB(72, 72, 72),
    NeutralButton = Color3.fromRGB(38, 38, 38),
    NeutralButtonHover = Color3.fromRGB(54, 54, 54),
    NeutralButtonStroke = Color3.fromRGB(255, 255, 255),
    ErrorColor = Color3.fromRGB(185, 50, 50),
    ErrorStrokeColor = Color3.fromRGB(240, 75, 75),
}
