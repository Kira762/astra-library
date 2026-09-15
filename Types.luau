export type Theme = string | { [string]: any }

export type Translator = (source: string, localeId: string) -> string?

export type Translations = { [string]: { [string]: string } }
export type IconPack = "lucide" | "material" | "tabler" | "phosphor" | "heroicons" | "feather"

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
    showIconOnly: boolean?,     profile: string?,     configuration: WindowConfiguration?,
    fallbackFont: (Font | Enum.Font)?,     locale: string?,     translations: Translations?,     translator: Translator?, }

export type TabProps = {
    name: string?,
    icon: (string | number)?,
}

export type SectionProps = {
    name: string?,
    icon: (string | number)?,
}

export type TextProps = {
    name: string?,     text: string?,     icon: (string | number)?,
}

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

export type DividerProps = {
    text: string?,     spacing: number?,     line: boolean?, }

export type GroupProps = {
    direction: string?, }

-- Definitions use the corresponding element's normal properties plus `type`.
-- `elements` is allowed only for ordinary Groups; CollapsibleGroups cannot nest.
export type CollapsibleElementProps = {
    type: "Button" | "Toggle" | "Switch" | "Slider" | "Dropdown" | "Input" | "Keybind"
        | "Stat" | "Section" | "Text" | "Changelog" | "Divider" | "Group",
    elements: { CollapsibleElementProps }?,
    [string]: any,
}

export type CollapsibleGroupProps = {
    name: string?,
    icon: (string | number)?,
    elements: { CollapsibleElementProps }?,
}

export type ButtonProps = {
    name: string?,
    icon: (string | number)?,
    -- Built-in right-edge tap glyph: false hides it, a name/asset id replaces it.
    tapIcon: (string | number | boolean)?,
    callback: (() -> ())?,
}

export type ToggleProps = {
    name: string?,
    icon: (string | number)?,
    flag: string?,
    value: boolean?,
    forgetState: boolean?,
    callback: ((value: boolean) -> ())?,
}

export type SliderProps = {
    name: string?,
    icon: (string | number)?,
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
    flag: string?,
    options: { string }?,
    value: (string | { string })?,
    multiSelect: boolean?,
    placeholder: string?,
    forgetState: boolean?,
    callback: ((value: any) -> ())?,
}

export type InputProps = {
    name: string?,
    icon: (string | number)?,
    flag: string?,
    value: string?,
    placeholder: string?,
    numeric: boolean?,
    clearOnFocus: boolean?,
    forgetState: boolean?,
    callback: ((value: string) -> ())?,
}

export type KeybindProps = {
    name: string?,
    icon: (string | number)?,
    flag: string?,
    value: (EnumItem | string)?,     forgetState: boolean?,
    isMenuToggle: boolean?,     hold: boolean?,     holdThreshold: number?,     callback: ((value: EnumItem | boolean) -> ())?,     onChanged: ((key: EnumItem) -> ())?, }

export type StatProps = {
    name: string?,
    icon: (string | number)?,
    prefix: string?,
    suffix: string?,
    value: number?,
    display: string?,     compact: boolean?,
    changeMode: string?,     changeBaseline: string?,     numberEasing: boolean?,
}

export type NotifyProps = {
    title: string?,
    content: string?,
    icon: (string | number)?,
    duration: number?,
}

export type ToastProps = {
    title: string?,
    subtitle: string?,     subtitleAbove: boolean?,     icon: (string | number)?,     avatar: number?,     minWidth: number?,     duration: number?,
    position: "Top" | "Bottom"?,
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

export type Button = Moveable & Lockable & {}

export type Toggle = Moveable & Lockable & {
    value: boolean,
    Set: (self: Toggle, value: boolean, skipCallback: boolean?) -> (),
}

export type Slider = Moveable & Lockable & {
    value: number,
    Set: (self: Slider, value: number, skipCallback: boolean?) -> (),
}

export type Dropdown = Moveable & Lockable & {
    value: { string },     Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
    Refresh: (self: Dropdown, options: { string }) -> (),
    Add: (self: Dropdown, option: string) -> (),
    Remove: (self: Dropdown, option: string) -> (),
}

export type Input = Moveable & Lockable & {
    value: string,
    Set: (self: Input, value: string, skipCallback: boolean?) -> (),
}

export type Keybind = Moveable & Lockable & {
    value: EnumItem,
    Set: (self: Keybind, value: EnumItem | string, skipChanged: boolean?) -> (),
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

export type Changelog = Moveable & {
    Set: (self: Changelog, entries: { ChangelogEntry }) -> (),
    Refresh: (self: Changelog, entries: { ChangelogEntry }) -> (),
    Add: (self: Changelog, entry: ChangelogEntry, prepend: boolean?) -> (),
    Clear: (self: Changelog) -> (),
}

export type Divider = Moveable & {
    text: string,     Set: (self: Divider, text: string?) -> (),
}

export type Popup = {
    Close: (self: Popup) -> (),
}

export type Group = Moveable & {
    CreateButton: (self: Group, props: ButtonProps) -> Button,
    CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
    CreateStat: (self: Group, props: StatProps) -> Stat,
    CreateSlider: (self: Group, props: SliderProps) -> Slider,
        CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown?,
    CreateSection: (self: Group, props: SectionProps) -> Section?,
    CreateText: (self: Group, props: TextProps) -> Text?,
    CreateDivider: (self: Group, props: DividerProps?) -> Divider?,
    CreateGroup: (self: Group, props: GroupProps?) -> Group,
}

export type CollapsibleGroup = Moveable & Lockable & {
    elements: { any },
}

export type Tab = {
    CreateCollapsibleGroup: (self: Tab, props: CollapsibleGroupProps) -> CollapsibleGroup,
    Select: (self: Tab, noAnimation: boolean?) -> (),
    Deselect: (self: Tab, noAnimation: boolean?) -> (),
    Remove: (self: Tab) -> (),
    CreateButton: (self: Tab, props: ButtonProps) -> Button,
    CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSlider: (self: Tab, props: SliderProps) -> Slider,
    CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
    CreateInput: (self: Tab, props: InputProps) -> Input,
    CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
    CreateStat: (self: Tab, props: StatProps) -> Stat,
    CreateSection: (self: Tab, props: SectionProps) -> Section,
    CreateText: (self: Tab, props: TextProps) -> Text,
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
    Toast: (self: Window, props: ToastProps) -> (),
    Popup: (self: Window, props: PopupProps) -> Popup?,     Show: (self: Window) -> (),
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
}

export type Astra = {
    CreateWindow: (self: Astra, props: WindowProps) -> Window,
    Icons: IconCatalog,
    Motion: MotionService,
}

return {}
