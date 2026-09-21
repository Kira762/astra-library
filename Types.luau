export type Theme = string | { [string]: any }

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
    name: string?,     text: string?,     icon: (string | number)?,
}

-- [[One segment of a Footer's centred run: a `text` run, an `icon` run, or]]
-- [[both (the text renders, then the icon). Plain strings in `parts` are]]
-- [[shorthand for `{ text = ... }`.]]
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

-- Definitions use the corresponding element's normal properties plus `type`.
-- `elements` is allowed only for ordinary Groups; CollapsibleGroups cannot nest.
export type CollapsibleElementProps = {
    type: "Button" | "Toggle" | "Switch" | "Slider" | "Dropdown" | "Input"
        | "Link" | "Stat" | "Section" | "Text" | "Footer" | "Changelog" | "Divider" | "Group",
    elements: { CollapsibleElementProps }?,
    [string]: any,
}

export type CollapsibleGroupProps = {
    name: string?,
    icon: (string | number)?,
    elements: { CollapsibleElementProps }?,
}

-- The Isolated changelog container only accepts Changelog definitions; any
-- other child type errors at construction.
export type IsolatedElementProps = {
    type: "Changelog",
    [string]: any,
}

export type IsolatedProps = {
    name: string?,
    subtitle: string?,
    icon: (string | number)?,
    elements: { IsolatedElementProps }?,
}

export type ButtonProps = {
    name: string?,
    icon: (string | number)?,
    -- Deprecated, ignored compatibility props; functional info badges were removed.
    info: string?,
    infoIcon: (string | number)?,
    -- Built-in right-edge tap glyph: false hides it, a name/asset id replaces it.
    callback: (() -> ())?,
}

export type ToggleProps = {
    name: string?,
    icon: (string | number)?,
    info: string?, -- Deprecated; ignored
    infoIcon: (string | number)?, -- Deprecated; ignored
    flag: string?,
    value: boolean?,
    forgetState: boolean?,
    callback: ((value: boolean) -> ())?,
}

export type SliderProps = {
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

export type DropdownProps = {
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

-- Required, editable one-letter key field. Strings are normalised to uppercase;
-- invalid edits restore the previous letter instead of leaving the control blank.
export type KeybindProps = {
    name: string?,
    icon: (string | number)?,
    value: (string | EnumItem)?,
    flag: string?,
    forgetState: boolean?,
    callback: ((letter: string) -> ())?,
}

export type InputProps = {
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

export type StatProps = {
    name: string?,
    icon: (string | number)?,
    prefix: string?,
    suffix: string?,
    value: (number | string)?,
    display: string?,     compact: boolean?,
    -- Show the value as a single letter badge (no icon) instead of the numeric
    -- readouts; text values use this automatically unless set to false, in
    -- which case the whole value reads out as a text readout (no odometer, no
    -- change readout) that Set / SetText / ResetBaseline all write to.
    letter: boolean?,
    changeMode: string?,     changeBaseline: string?,     numberEasing: boolean?,
}

-- `link` is the hidden value: stored on the element and copied by the card's
-- trailing control, never rendered as text.
export type LinkProps = {
    name: string?,
    subtitle: string?,
    link: string?,
    icon: (string | number)?,
    description: string?,
    callback: ((link: string) -> ())?,
}

-- One compact data tile of an About card: a leading icon, a label and a value.
-- Up to three tiles share one line; the count drives each tile's width.
export type AboutCardRow = {
    icon: (string | number)?,
    label: string?,
    value: (string | number)?,
}

-- The card's optional trailing band. It is the fourth block of the card — the
-- one the data rows stop at three for — and it is the card's only tappable
-- surface.
export type AboutCardAction = {
    icon: (string | number)?,
    name: string?,
    subtitle: string?,
    callback: (() -> ())?,
}

export type AboutCardProps = {
    name: string?,
    subtitle: string?,
    icon: (string | number)?,
    rows: { AboutCardRow }?,
    description: string?,
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
    Lock: (self: any, reason: string?) -> (),
    Unlock: (self: any) -> (),
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
    -- [[The normalised run: ordered `{ kind = "text" | "icon", value }` entries.]]
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
    SetDescription: (self: AboutCard, text: string?) -> (),
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
    -- [[Open a pinned floating description over `anchor` / close whatever is
    -- [[open. The (!) badges open theirs through the tooltip service.]] 
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
    -- [[`name` may be a bare icon name (searched in every pack, in priority]]
    -- [[order) or a pack-qualified `"pack:name"`; `pack` addresses one pack.]]
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

-- [[The service is a plain table of functions (dot calls, like `Icons`),
-- [[so the fields carry no `self` - `Astra.Motion.tween(frame, props)`.
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

export type Astra = {
    CreateWindow: (self: Astra, props: WindowProps) -> Window,
    Icons: IconCatalog,
    Motion: MotionService,
    Performance: any?,
}

return {}
