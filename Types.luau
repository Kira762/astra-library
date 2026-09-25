export type Theme = string | { [string]: any }

-- Lockable interactive elements receive a stable `lockable:astra:<id>` usage
-- tag automatically. `lockLevel` (1..5) or `lockGroup` can override the
-- automatic type-based group; a lock mode of 5 always covers every tag.
export type ElementUsage = string | { string }
export type LockableProps = {
    id: string?,
    elementId: string?,
    usage: ElementUsage?,
    lockLevel: number?,
    lockGroup: string?,
}

export type Translator = (source: string, localeId: string) -> string?

export type Translations = { [string]: { [string]: string } }
export type IconPack = "lucide" | "material" | "tabler" | "phosphor" | "heroicons" | "feather" | "remix"

export type ChangelogChange = {
    symbol: string?,
    text: string?,
    category: string?,
}

export type ChangelogEntry = {
    version: string?,
    date: string?,
    game: string?,
    gameId: string?,
    title: string?,
    changes: { ChangelogChange }?,
}

export type ChangelogProps = {
    name: string?,
    emptyText: string?,
    entries: { ChangelogEntry }?,
}

export type WindowConfiguration = {
    autoSave: boolean?,
    autoLoad: boolean?,
    fileName: string?,
    customFolder: string?,
}

export type WindowProps = {
    name: string?,
    subtitle: string?,
    theme: Theme?,
    icon: (string | number)?,
    showName: string?,
    showIcon: (string | number)?,
    showIconOnly: boolean?,     configuration: WindowConfiguration?,
    fallbackFont: (Font | Enum.Font)?,     locale: string?,     translations: Translations?,     translator: Translator?, }

export type TabProps = {
    name: string?,
    icon: (string | number)?,
    locked: boolean?,
}

export type SectionProps = {
    name: string?,
    icon: (string | number)?,
}

export type TextProps = {
    name: string?,     text: string?,
}

--[[
One segment of a Footer's centred run: a `text` run, an `icon` run, or
both (the text renders, then the icon). Plain strings in `parts` are
shorthand for `{ text = ... }`.
]]
export type FooterPart = {
    text: string?,
    icon: (string | number)?,
}

export type FooterProps = {
    parts: { (string | FooterPart) }?,
    textSize: number?,
    spacing: number?,
}

export type DividerProps = {
    text: string?,     spacing: number?,     line: boolean?, }

export type GroupProps = {
    direction: string?, }

--[[
Definitions use the corresponding element's normal properties plus `type`.
`elements` is allowed only for ordinary Groups; CollapsibleGroups cannot nest.
]]
export type CollapsibleElementProps = {
    type: "Button" | "Toggle" | "Switch" | "Slider" | "Dropdown" | "Input"
        | "Link" | "Stat" | "Section" | "Text" | "Footer" | "Changelog" | "Divider" | "Group",
    elements: { CollapsibleElementProps }?,
    [string]: any,
}

export type CollapsibleGroupProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    elements: { CollapsibleElementProps }?,
}

--[[
The Isolated changelog container only accepts Changelog definitions; any
other child type errors at construction.
]]
export type IsolatedElementProps = {
    type: "Changelog",
    [string]: any,
}

export type IsolatedProps = LockableProps & {
    name: string?,
    subtitle: string?,
    icon: (string | number)?,
    elements: { IsolatedElementProps }?,
}

export type ButtonProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    -- Deprecated, ignored compatibility props; functional info badges were removed.
    info: string?,
    infoIcon: (string | number)?,
    -- Built-in right-edge tap glyph: false hides it, a name/asset id replaces it.
    callback: (() -> ())?,
}

export type ToggleProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    info: string?, -- Deprecated; ignored
    infoIcon: (string | number)?, -- Deprecated; ignored
    flag: string?,
    value: boolean?,
    forgetState: boolean?,
    callback: ((value: boolean) -> ())?,
}

export type SliderProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    info: string?, -- Deprecated; ignored
    infoIcon: (string | number)?, -- Deprecated; ignored
    flag: string?,
    range: { number }?,     increment: number?,
    value: number?,
    suffix: string?,
    minimal: boolean?,     forgetState: boolean?,
        callback: ((value: number, dragging: boolean) -> ())?,
}

--[[
The [−] [value] [+] counter row. `min` defaults to 0 (the value never
sinks below it) and `max` is optional — omit it for no upper limit.
`step` is one button tap and the value display's precision.
]]
export type StepperProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    flag: string?,
    min: number?,
    max: number?,
    step: number?,
    value: number?,
    increment: number?, -- Deprecated alias of `step`
    forgetState: boolean?,
    callback: ((value: number) -> ())?,
}

export type DropdownProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    info: string?, -- Deprecated; ignored
    infoIcon: (string | number)?, -- Deprecated; ignored
    flag: string?,
    options: { string }?,
    value: (string | { string })?,
    multiSelect: boolean?,
    placeholder: string?,
    forgetState: boolean?,
    callback: ((value: any) -> ())?,
}

--[[
Required, editable one-letter key field. Strings are normalised to uppercase;
invalid edits restore the previous letter instead of leaving the control blank.
]]
export type KeybindProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    value: (string | EnumItem)?,
    flag: string?,
    forgetState: boolean?,
    callback: ((letter: string) -> ())?,
}

export type InputProps = LockableProps & {
    name: string?,
    icon: (string | number)?,
    info: string?, -- Deprecated; ignored
    infoIcon: (string | number)?, -- Deprecated; ignored
    flag: string?,
    value: string?,
    placeholder: string?,
    numeric: boolean?,
    clearOnFocus: boolean?,
    forgetState: boolean?,
    callback: ((value: string) -> ())?,
}

export type ModeDefinition = {
    label: string?,
    description: string?,
    type: string?,           -- "default" | "toggle" | "dot" (descriptive)
    dot_position: number?,   -- normalized to 1..n by dot order
    onEnable: ((index: number, label: string) -> ())?,
    optional: boolean?,      -- only optional modes can be removed at runtime
    icon_color: (Color3 | { r: number?, g: number?, b: number?, a: number? })?,
}

export type ModePickerProps = LockableProps & {
    left_icon: (string | number)?,
    right_icon: (string | number)?,

    title: string?,
    subtitle: string?,

    mode: number?,           -- initial mode, default 1
    min_modes: number?,      -- clamped to a floor of 3
    max_modes: number?,      -- clamped to a ceiling of 5
    allow_mode_add_remove: boolean?,

    title_color_same_as_left_icon: boolean?,
    -- the subtitle always wears the default text colors; no props exist.
    ui_color: string?,               -- "inherit" (default); anything else is ignored
    slider_shape: string?,           -- "toggle_knob" (default, the only shape)
    accent: string?,                 -- "theme" (default) | "left_icon"

    left_icon_color: (Color3 | { r: number?, g: number?, b: number?, a: number? })?,
    reset_on_right_icon_press: boolean?,

    modes: { ModeDefinition } | { [number]: ModeDefinition },

    flag: string?,
    forgetState: boolean?,
    callback: ((index: number, label: string) -> ())?,
    onReset: ((picker: any) -> ())?,
    -- Internal: keep the built-in element-lock controller outside its own lock tiers.
    lockSystemController: boolean?,
}

export type StatProps = {
    name: string?,
    prefix: string?,
    suffix: string?,
    value: (number | string)?,
    display: string?,     compact: boolean?,
    --[[
    Show the value as a single letter badge (no icon) instead of the numeric
    readouts; text values use this automatically unless set to false, in
    which case the whole value reads out as a text readout (no odometer, no
    change readout) that Set / SetText / ResetBaseline all write to.
    ]]
    letter: boolean?,
    changeMode: string?,     changeBaseline: string?,     numberEasing: boolean?,
}

--[[
`link` is the hidden value: stored on the element and copied by the card's
trailing control, never rendered as text.
]]
export type LinkProps = LockableProps & {
    name: string?,
    subtitle: string?,
    link: string?,
    icon: (string | number)?,
    callback: ((link: string) -> ())?,
}

--[[
One compact data tile of an About card: a leading icon, a label and a value.
Up to three tiles share one line; the count drives each tile's width.
]]
export type AboutCardRow = {
    icon: (string | number)?,
    label: string?,
    value: (string | number)?,
}

--[[
The card's optional trailing band. It is the fourth block of the card — the
one the data rows stop at three for — and it is the card's only tappable
surface.
]]
export type AboutCardAction = LockableProps & {
    icon: (string | number)?,
    name: string?,
    subtitle: string?,
    callback: (() -> ())?,
}

export type AboutCardProps = LockableProps & {
    name: string?,
    subtitle: string?,
    icon: (string | number)?,
    rows: { AboutCardRow }?,
    action: AboutCardAction?,
}

-- Exact title/content duplicates refresh an active card or coalesce in the queue.
export type NotifyProps = {
    title: string?,
    content: string?,
    icon: (string | number)?,
    duration: number?,
}

export type PopupBox = {
    title: string?,
    description: string?,
    icon: (string | number)?,
}

export type PopupOption = {
    text: string?,
    style: string?,     callback: (() -> ())?,
}

export type PopupProps = {
    title: string?,
    subtitle: string?,
    icon: (string | number)?,
    content: string?,     boxes: { PopupBox }?,     options: { PopupOption }?,     dismissable: boolean?, }

export type Moveable = {
    MoveTo: (self: any, index: number) -> (),
    MoveToTop: (self: any) -> (),
    MoveToBottom: (self: any) -> (),
    MoveUp: (self: any) -> (),
    MoveDown: (self: any) -> (),
}

export type Lockable = {
    -- Automated for functional controls; static/decorative elements have none.
    elementId: string?,
    usage: ElementUsage?,
    usageTag: string?,
    lockUsage: string?,
    lockLevel: number?,
    Lock: (self: any, reason: string?) -> boolean,
    Unlock: (self: any) -> boolean,
    IsLocked: (self: any) -> boolean,
}

export type Button = Moveable & Lockable & {
    -- Deprecated compatibility no-op (info badges removed).
    SetInfo: (self: Button, text: string?) -> (),
}

export type Toggle = Moveable & Lockable & {
    value: boolean,
    Set: (self: Toggle, value: boolean, skipCallback: boolean?) -> (),
    -- Deprecated compatibility no-op (info badges removed).
    SetInfo: (self: Toggle, text: string?) -> (),
}

export type Slider = Moveable & Lockable & {
    value: number,
    Set: (self: Slider, value: number, skipCallback: boolean?) -> (),
    -- Deprecated compatibility no-op (info badges removed).
    SetInfo: (self: Slider, text: string?) -> (),
}

export type Stepper = Moveable & Lockable & {
    value: number,
    Get: (self: Stepper) -> number,
    Set: (self: Stepper, value: number, skipCallback: boolean?) -> (),
    Increment: (self: Stepper, skipCallback: boolean?) -> (),
    Decrement: (self: Stepper, skipCallback: boolean?) -> (),
    CancelEditing: (self: Stepper) -> (),
}

export type ModePicker = Moveable & Lockable & {
    mode: number,
    modes: { ModeDefinition },
    Set: (self: ModePicker, index: number, silent: boolean?) -> number,
    Get: (self: ModePicker) -> (number, string),
    Reset: (self: ModePicker) -> number,
    AddMode: (self: ModePicker, mode: ModeDefinition) -> (boolean, string?),
    RemoveMode: (self: ModePicker, index: number) -> (boolean, string?),
    SetLeftIconColor: (self: ModePicker, color: Color3 | { r: number?, g: number?, b: number?, a: number? }) -> (),
    SetSubtitle: (self: ModePicker, text: string?) -> (),
}

export type Dropdown = Moveable & Lockable & {
    value: { string },     Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
    Refresh: (self: Dropdown, options: { string }) -> (),
    Add: (self: Dropdown, option: string) -> (),
    Remove: (self: Dropdown, option: string) -> (),
    -- Deprecated compatibility no-op (info badges removed).
    SetInfo: (self: Dropdown, text: string?) -> (),
}

export type Keybind = Moveable & Lockable & {
    value: string,
    Set: (self: Keybind, value: (string | EnumItem), silent: boolean?) -> boolean,
    Capture: (self: Keybind) -> boolean,
    CancelCapture: (self: Keybind) -> (),
}

export type Input = Moveable & Lockable & {
    value: string,
    Set: (self: Input, value: string, skipCallback: boolean?) -> (),
    -- Deprecated compatibility no-op (info badges removed).
    SetInfo: (self: Input, text: string?) -> (),
}

export type Stat = Moveable & {
    value: number,
    Set: (self: Stat, value: number) -> (),
    ResetBaseline: (self: Stat, value: number?) -> (),
}

export type Section = Moveable & {}

export type TabSection = {
    Remove: (self: TabSection) -> (),
}

export type Text = Moveable & {
    name: string,     text: string,     Set: (self: Text, text: string) -> (),
    SetTitle: (self: Text, title: string) -> (),
}

export type Footer = Moveable & {
    -- The normalised run: ordered `{ kind = "text" | "icon", value }` entries.
    parts: { FooterPart },
    textSize: number,
    spacing: number,
    Set: (self: Footer, parts: { (string | FooterPart) }?) -> (),
}

export type Changelog = Moveable & {
    Set: (self: Changelog, entries: { ChangelogEntry }) -> (),
    Refresh: (self: Changelog, entries: { ChangelogEntry }) -> (),
    Add: (self: Changelog, entry: ChangelogEntry, prepend: boolean?) -> (),
    Clear: (self: Changelog) -> (),
}

export type Divider = Moveable & {
    text: string,     Set: (self: Divider, text: string?) -> (),
}

export type Link = Moveable & Lockable & {
    -- The hidden value the copy control writes to the clipboard.
    link: string,
    Set: (self: Link, link: string) -> (),
    SetLink: (self: Link, link: string) -> (),
    SetTitle: (self: Link, title: string) -> (),
    SetSubtitle: (self: Link, subtitle: string) -> (),
    SetIcon: (self: Link, icon: (string | number)?) -> (),
    -- Copy the link now: the same cycle a tap runs, including the check mark.
    Copy: (self: Link) -> boolean,
    -- True while the control is showing its confirmation instead of the copy mark.
    IsConfirming: (self: Link) -> boolean,
}

export type AboutCard = Moveable & Lockable & {
    SetTitle: (self: AboutCard, title: string) -> (),
    SetSubtitle: (self: AboutCard, subtitle: string?) -> (),
    SetIcon: (self: AboutCard, icon: (string | number)?) -> (),
    SetRow: (self: AboutCard, index: number, row: AboutCardRow) -> (),
}

export type Popup = {
    Close: (self: Popup) -> (),
}

export type Group = Moveable & {
    CreateButton: (self: Group, props: ButtonProps) -> Button,
    CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
    CreateStat: (self: Group, props: StatProps) -> Stat,
    CreateKeybind: (self: Group, props: KeybindProps) -> Keybind?,
    CreateSlider: (self: Group, props: SliderProps) -> Slider,
    CreateStepper: (self: Group, props: StepperProps) -> Stepper,
    CreateModePicker: (self: Group, props: ModePickerProps) -> ModePicker,
        CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown?,
    CreateSection: (self: Group, props: SectionProps) -> Section?,
    CreateText: (self: Group, props: TextProps) -> Text?,
    CreateFooter: (self: Group, props: FooterProps?) -> Footer?,
    CreateDivider: (self: Group, props: DividerProps?) -> Divider?,
    CreateLink: (self: Group, props: LinkProps) -> Link,
    CreateGroup: (self: Group, props: GroupProps?) -> Group,
}

export type CollapsibleGroup = Moveable & Lockable & {
    elements: { any },
}

export type Isolated = Moveable & Lockable & {
    elements: { any },
    Expand: (self: Isolated, animate: boolean?) -> (),
    Collapse: (self: Isolated, animate: boolean?) -> (),
    Toggle: (self: Isolated, animate: boolean?) -> (),
    SetTitle: (self: Isolated, title: string) -> (),
    SetSubtitle: (self: Isolated, subtitle: string?) -> (),
    -- Left header icon only; the built-in right chevron has no setter.
    SetIcon: (self: Isolated, icon: (string | number)?) -> (),
}

export type Tab = {
    CreateCollapsibleGroup: (self: Tab, props: CollapsibleGroupProps) -> CollapsibleGroup,
    CreateIsolated: (self: Tab, props: IsolatedProps) -> Isolated,
    Select: (self: Tab, noAnimation: boolean?) -> (),
    Deselect: (self: Tab, noAnimation: boolean?) -> (),
    SetLocked: (self: Tab, locked: boolean) -> (),
    Remove: (self: Tab) -> (),
    CreateButton: (self: Tab, props: ButtonProps) -> Button,
    CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSlider: (self: Tab, props: SliderProps) -> Slider,
    CreateStepper: (self: Tab, props: StepperProps) -> Stepper,
    CreateModePicker: (self: Tab, props: ModePickerProps) -> ModePicker,
    CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
    CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
    CreateInput: (self: Tab, props: InputProps) -> Input,
    CreateLink: (self: Tab, props: LinkProps) -> Link,
    CreateAboutCard: (self: Tab, props: AboutCardProps) -> AboutCard,
    CreateStat: (self: Tab, props: StatProps) -> Stat,
    CreateSection: (self: Tab, props: SectionProps) -> Section,
    CreateText: (self: Tab, props: TextProps) -> Text,
    CreateFooter: (self: Tab, props: FooterProps?) -> Footer,
    CreateChangelog: (self: Tab, props: ChangelogProps) -> Changelog,
    CreateDivider: (self: Tab, props: DividerProps?) -> Divider,
    CreateGroup: (self: Tab, props: GroupProps?) -> Group,
}

export type Window = {
    unloaded: boolean,
    ResolveIcon: (self: Window, value: (string | number)?, pack: IconPack?) -> (string | number)?,
    Flags: { [string]: any },
    CreateTab: (self: Window, props: TabProps) -> Tab,
        CreateSection: (self: Window, props: SectionProps) -> TabSection,
    Notify: (self: Window, props: NotifyProps) -> (),
    Popup: (self: Window, props: PopupProps) -> Popup?,
    --[[
    Open a pinned floating description over `anchor` / close whatever is
    open. The (!) badges open theirs through the tooltip service.
    ]]
    ShowTooltip: (self: Window, anchor: any, text: string) -> (),
    HideTooltip: (self: Window) -> (),
    Show: (self: Window) -> (),
    Hide: (self: Window) -> (),
    ToggleHide: (self: Window) -> (),
    ToggleMinimise: (self: Window) -> (),
    Navigate: (self: Window, tab: string | Tab) -> (),
    ChangeTheme: (self: Window, theme: Theme) -> (),
    SetLocale: (self: Window, localeId: string) -> (),
    SetTranslator: (self: Window, translator: Translator?) -> (),
    RegisterTranslations: (self: Window, translations: Translations) -> (),
    Save: (self: Window, name: string?) -> boolean,
    Load: (self: Window, name: string?) -> boolean,
    ListConfigs: (self: Window) -> { string },
    DeleteConfig: (self: Window, name: string) -> boolean,
    GetPath: (self: Window) -> (string, string),
    Get: (self: Window, flag: string) -> any,
    Set: (self: Window, flag: string, value: any) -> boolean,
    SetElementLockMode: (self: Window, mode: number) -> number,
    GetElementLockMode: (self: Window) -> number,
    Unload: (self: Window) -> (),
}

export type IconCatalog = {
    Lucide: IconPack,
    Material: IconPack,
    Tabler: IconPack,
    Phosphor: IconPack,
    Heroicons: IconPack,
    Feather: IconPack,
    Remix: IconPack,
    --[[
    `name` may be a bare icon name (searched in every pack, in priority
    order) or a pack-qualified `"pack:name"`; `pack` addresses one pack.
    ]]
    get: (name: string, pack: IconPack?) -> string?,
    getByPack: (pack: IconPack, name: string) -> string?,
    list: (pack: IconPack?) -> { string },
    packs: () -> { string },
    count: (pack: IconPack?) -> number,
    isPack: (pack: string?) -> boolean,
    priority: () -> { string },
    loaded: () -> { string },
    refreshCustom: () -> number,
    resolve: (value: (string | number)?, pack: IconPack?) -> (string | number)?,
}

export type MotionSpec = string | TweenInfo

--[[
The service is a plain table of functions (dot calls, like `Icons`),
so the fields carry no `self` - `Astra.Motion.tween(frame, props)`.
]]
export type MotionService = {
    enabled: boolean,
    timeScale: number,
    profile: string,
    profiles: { [string]: { timeScale: number?, enabled: boolean? } },
    specNames: { string },
    spec: (spec: MotionSpec?) -> TweenInfo,
    step: (base: number) -> number,
    setTimeScale: (scale: number) -> number,
    getTimeScale: () -> number,
    setEnabled: (enabled: boolean) -> boolean,
    isEnabled: () -> boolean,
    setProfile: (name: string) -> boolean,
    getProfile: () -> string,
    cancel: (instance: Instance?) -> boolean,
    tween: (instance: Instance?, props: { [string]: any }, spec: MotionSpec?, onCompleted: (() -> ())?) -> Tween?,
    set: (instance: Instance?, props: { [string]: any }) -> (),
    uiSpec: (componentType: string?, action: string?) -> TweenInfo,
    forUI: (componentType: string?, action: string?) -> TweenInfo,
}

--[[
A key-gate link button: the face shows `name` (and `icon`); `link` stays
hidden on the UI and only surfaces — via copy + notification — when the
button is pressed. The gate accepts at most three entries.
]]
export type KeySystemLink = {
    name: string?,
    icon: (string | number)?,
    link: string,
}

--[[
Standalone enter-your-key card, shown before any window exists. `links`
carries the 0-3 copy buttons under the note; `getKeyUrl` is legacy sugar
that prepends a "Get Key" button. `icon` is accepted for older scripts but
ignored: the header always wears the Sirius mark.
]]
export type KeySystemProps = {
    title: string?,
    subtitle: string?,
    note: string?,
    placeholder: string?,
    keys: (string | { string })?,
    getKeyUrl: string?,
    grabKeyFromSite: boolean?,
    links: { KeySystemLink }?,
    saveKey: boolean?,
    fileName: string?,
    maxAttempts: number?,
    dismissable: boolean?,
    theme: Theme?,
    icon: (string | number)?,
    onSuccess: ((key: string) -> ())?,
    onClose: (() -> ())?,
    onMaxAttempts: (() -> ())?,
}

export type KeySystem = {
    title: string,
    subtitle: string,
    note: string,
    passed: boolean,
    closed: boolean,
    locked: boolean,
    attempts: number,
    Close: (self: KeySystem) -> (),
}

export type Astra = {
    CreateWindow: (self: Astra, props: WindowProps) -> Window,
    CreateKeySystem: (self: Astra, props: KeySystemProps) -> KeySystem,
    Icons: IconCatalog,
    Motion: MotionService,
    Performance: any?,
}

return {}
