---
name: astra
description: "Build and edit Roblox UIs and executor GUI hubs with Astra v1, the Luau UI library loaded as one bundle (version-1.luau) through loadstring plus game:HttpGet. Use for Astra:CreateWindow scripts and everything they build — windows, tabs, groups and elements (Button, Toggle, Slider, Dropdown, Input, Stat, Text, Section, Divider, Collapsible Group, Changelog, Isolated changelog container), flags, saved configs, themes, icons, motion, notifications, popups and localisation. Also use when changing the Astra repository itself (modular tree, generated bundle, syntax gate, runtime tests)."
---

# Astra v1

Astra is a Roblox/Luau UI library for executor scripts. One public entry point —
`Astra:CreateWindow(props)` — then a window owns tabs, tabs own elements, and
every element is created from a single props table. Everything below is the API
surface that actually exists; do not invent parallel methods or props.

## Load the library

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()
```

Three details are load-bearing:

- **The trailing `()` is required.** `loadstring(text)` only compiles and returns
  a chunk; calling it runs Astra and returns the module table. Without the call,
  every later `Astra:CreateWindow` fails with `attempt to index a function value`.
- **Fetch the bundle, never the modular tree.** `version-1.luau` is the generated
  artifact (see `scripts/generate_bundle.js`); `core/`, `elements/` and friends are
  source for building it.
- **The URL must be the raw file of a public repo**, and `HttpService` requests
  must be enabled in the runtime.

Inside Studio/Rojo (no `loadstring`) the same library is a ModuleScript:
`require(game:GetService("ReplicatedStorage").Astra)`.

A failed load looks like `rAnDoMcHuNkNaMe:1: attempt to call a nil value` — that is
the *loader*, not an Astra bug. It means the fetched text never compiled, usually
because the fetch returned an HTML error page (private repo, wrong branch, rate
limit). Confirm with `print(game:HttpGet(url):sub(1, 120))`. Inside this repo, run
`sh scripts/check_syntax.sh` and regenerate with `node scripts/generate_bundle.js`.

## Minimal working script

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()

local window = Astra:CreateWindow({
    name = "Example Hub",
    subtitle = "v1.0",
    icon = "house",
})

local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateButton({
    name = "Say hello",
    icon = "play",
    callback = function()
        window:Notify({ title = "Hello", content = "Your first element works." })
    end,
})

tab:CreateToggle({
    name = "Auto Sprint",
    flag = "autoSprint",
    value = false,
    callback = function(on) print("Auto Sprint:", on) end,
})

tab:Select()
```

The first tab opens on its own and layout is a user setting (**Settings → Appearance
→ Bar Layout**), so there is no layout prop and no sub-tab API to wire up.

## Rules that prevent most broken scripts

1. **One props table, always.** Every constructor is `parent:CreateX({ ... })`.
   Positional arguments are not supported.
2. **Colons on library calls.** `Astra:CreateWindow`, `window:CreateTab`,
   `window:Notify`, `tab:CreateButton`, `handle:Set(...)`.
3. **Create the parent first.** Elements are created on a **Tab** (or on a
   **Group** created by a tab). `CreateCollapsibleGroup` exists *only* on a tab.
4. **Keep the returned handles.** They are objects with methods (`:Set`, `:Add`,
   `:Remove`, `:Refresh`, `:MoveUp`, `:Lock`, …), not plain data.
5. **Window methods live on the window**: `window:ChangeTheme`, `window:SetLocale`,
   `window:Notify`, `window:Popup`, `window:Get`/`Set`. There is no
   `Astra.ChangeTheme` or `Astra.Unload`.
6. **Never build a second live window by accident.** With the default
   `antiWindowDuplicate` setting on, a new `Astra:CreateWindow` unloads the existing
   window first. Reuse the handle, call `window:Unload()`, or opt out per window
   with `settings = { antiWindowDuplicate = false }`.
7. **Flags are shared key space.** Give every control that must restore a unique,
   stable `flag`; elements with `forgetState = true` stay out of save/load.
8. **Icons are pack-qualified or global, and case-sensitive.** A bare name is
   searched across lucide, material, tabler, phosphor, heroicons, feather, remix in that
   order; `"tabler:home"` pins one pack. An unresolved value is returned unchanged,
   so a typo silently yields a bad image, not an error — check with
   `Astra.Icons.get("house")`.
9. **Animate through the motion service**, not ad-hoc TweenInfos, so user motion
   settings apply: `Astra.Motion.tween(instance, { BackgroundTransparency = 0.5 }, "snappy", onComplete)`.
   Specs: `instant, fast, snappy, normal, smooth, emphasized, pop, glide, exit, spring, settle, spin, drift`.
10. **Expect startup to be staged.** Constructors return fully built objects but may
    yield while the first UI is built, the window auto-shows on the next frame, and
    `Notify` overlays are queued one at a time (a backlog past six drops the oldest).
    `window:Hide()` before the first reveal cancels auto-show.

## Failure signatures

| What you see | What it means |
|---|---|
| `attempt to index a function value` on the loader line | The `()` after `loadstring(...)` is missing, so `Astra` is a chunk, not the module table. |
| `rAnDoMcHuNkNaMe:1: attempt to call a nil value` | The fetched text never compiled — usually an HTML error page (private repo, wrong branch, rate limit) or a broken bundle. `print(game:HttpGet(url):sub(1, 120))`. |
| `attempt to call a nil value` after loading | The method does not exist on that parent: `CreateCollapsibleGroup` on a Group, `CreateTab` on `Astra`, or props passed positionally. |
| An element renders a blank or broken icon | The icon name resolved to nothing and was passed through unchanged — check case, pack and spelling with `Astra.Icons.get`. |
| Values do not come back on the next run | No `flag` on the control, a duplicated flag, `forgetState = true`, or Auto Load turned off in Settings → Persistence. |
| Two shells appear at once | A second `CreateWindow` after the guard was disabled or the previous handle was left live — reuse the handle or `window:Unload()` first. |
| A control ignores clicks | It is `:Lock()`ed, or its tab has never been shown (inactive tabs reveal and build lazily). |
| A popup or notification never appears | Overlays are queued one at a time; a burst past six waiting requests drops the oldest unbuilt one. |

## Element cheat sheet

`flag`, `icon` and `name` are accepted almost everywhere; `description` is a helper
line on `CreateCollapsibleGroup` and `CreateStat` only — Button, Toggle, Slider,
Dropdown, Input, ModePicker, AboutCard and Link ignore the prop.

| Create on Tab / Group | Key props | Handle methods |
|---|---|---|
| `CreateSection({ name, icon })` | heading band for a part of the page | — |
| `CreateText({ name, text })` | body copy card | `:Set(text)`, `:SetTitle(name)` |
| `CreateButton({ name, icon, callback })` | Optional leading icon; no trailing cursor glyph | — |
| `CreateKeybind({ name, value, flag, callback })` | Required editable one-letter A–Z field; uppercase string value, default K; no description row | `Set`, `Capture`, `CancelCapture` |
| `CreateToggle({ name, value, flag, callback })` | fires `callback(on)` | `:Set(on, skipCallback?)` |
| `CreateSlider({ name, range = { min, max }, value, increment, suffix, minimal, flag, callback })` | `callback(value, dragging)` | `:Set(value)` |
| `CreateDropdown({ name, options, value, multiSelect, placeholder, flag, callback })` | multi-select value is a table | `:Refresh(options)`, `:Add(option)`, `:Remove(option)` |
| `CreateInput({ name, value, placeholder, numeric, clearOnFocus, flag, callback })` | text field, `callback(text)` | `:Set(text)` |
| `CreateLink({ name, subtitle, link, icon, callback })` | card carrying a hidden URL; the trailing control copies it and swaps in a check mark for two seconds — the link is never rendered | `:Set(link)`, `:SetLink(link)`, `:SetTitle(name)`, `:SetSubtitle(text)`, `:SetIcon(icon)`, `:Copy()`, `:IsConfirming()` |
| `CreateAboutCard({ name, subtitle, icon, rows = { { icon, label, value } }, action = { icon, name, subtitle, callback } })` | one card: branded header, **1–3** compact icon tiles kept on one equal-width line, and an optional tappable action band (a fourth row errors) | `:SetTitle(name)`, `:SetSubtitle(text?)`, `:SetIcon(icon)`, `:SetRow(index, row)` |
| `CreateStat({ name, value, prefix, suffix, display, compact, letter, changeMode, changeBaseline })` | readout card; a string `value` shows one letter unless `letter = false`, which reads the whole value | `:Set(value)`, `:SetText(text)`, `:ResetBaseline(n)` |
| `CreateFooter({ parts, textSize, spacing })` | centred run of text and inline icons (`parts = { { text = "Built with" }, { icon = "zap" }, { text = "Astra" } }`; plain strings are text shorthand); re-centres as one unit | `:Set(parts)` |
| `CreateDivider({ text, line, spacing })` | rule between controls | — |
| `CreateGroup({ direction = "row" \| "column" })` | horizontal row by default | nesting via `Create…` |
`CreateAboutCard` is tab-only, like `CreateIsolated` and `CreateChangelog`.

Tab-only declarative container: `tab:CreateCollapsibleGroup({ name, icon, description, elements = { ... } })`
where each child is `{ type = "Toggle" | "Button" | "Slider" | "Dropdown" | "Input" | "Link" | "Switch" | "Stat" | "Section" | "Text" | "Footer" | "Divider" | "Group" | "Changelog", ...same props }`.
Groups may nest inside it; collapsible groups never nest, and every collapsible
starts collapsed. `Changelog` renders as a regular element wherever it is declared.

Tab-only changelog container: `tab:CreateIsolated({ name, subtitle, icon, elements = { { type = "Changelog", ... }, ... } })`
— a CollapsibleGroup-style card (header icon + title/subtitle + built-in right
chevron) whose body accepts **Changelog definitions only**; any other child
errors with `Astra:CreateIsolated — only Changelog elements can be placed inside Isolated`.
Runtime: `:Expand()`, `:Collapse()`, `:Toggle()`, `:SetTitle(text)`,
`:SetSubtitle(text?)`, `:SetIcon(icon)` (left icon only; the chevron is fixed).

Elements support `:MoveTo(index)`, `:MoveUp()`, `:MoveDown()`, `:MoveToTop()`,
`:MoveToBottom()`; most functional elements also support `:Lock()`, `:Unlock()`,
`:IsLocked()` and participate in the five cumulative Element Lock Modes in
Settings → Controls. Modes preserve control state and guard user input; static
elements and callback-free Buttons are not lockable.

## Window surface in one glance

`window:CreateTab`, `CreateSection`, `Notify`, `Popup`, `Navigate(tab)`,
`Show`, `Hide`, `ToggleHide`, `ToggleMinimise`, `Close`, `Save(name?)`, `Load(name?)`,
`ListConfigs`, `DeleteConfig(name)`, `Get(flag)`, `Set(flag, value)`, `Flags`,
`ChangeTheme(theme)`, `SetLocale(id)`, `SetTranslator(fn)`, `RegisterTranslations(t)`,
`ResolveIcon(value, pack?)`, `GetPath()`, `Unload()`.

Built-in Settings live behind the gear action (Overview, Controls, Appearance,
Persistence) and hold menu keybind, window behaviour, motion, bar layout and
auto save/load. They are window-scoped — user code does not build them.

**Key gate.** `Astra:CreateKeySystem({ keys, onSuccess })` shows the standalone
enter-your-key card *before* any window exists — build the window inside
`onSuccess`. The header is always the Sirius mark (`icon` is ignored), the
note is plain text, and optional `links = { { name, icon, link } … }` (0–3)
plus `getKeyUrl` sugar add copy buttons that reveal the URL in a
notification. Full props in `references/window.md` (Key gate).

## References

Read only what the task needs:

- `references/elements.md` — full props and handle methods for every element, plus
  tab/group rules and the Collapsible Group declarative schema.
- `references/window.md` — window methods, popups/notifications, key gate,
  themes, icon packs, motion service, localisation, persistence, startup pacing.
- `references/repo-workflow.md` — working inside this repository: bundle generation,
  syntax and checker scripts, runtime tests, docs/changelog conventions.
- `assets/example-window.luau` — a single-file, copy-pasteable hub covering every
  element type. It is Luau-parsed, but `scripts/check_syntax.sh` only walks the
  library paths, so compile it directly after editing.
