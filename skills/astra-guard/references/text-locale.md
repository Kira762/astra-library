# Text / locale — why `_bindLocale` is required

## The bug that shipped

A setter wrote a locale token table directly to `TextLabel.Text` (the subtitle
setter of the Mode Picker element, removed since):

```lua
self.subtitleLabel.Text = locale.t(text) -- locale.t returns a table token, not a string
```

Luau's `TextLabel.Text` is `string`. The assignment threw:

```
string expected, got table
```

And even when it was coerced to a string once, a later `window:SetLocale("fr")` never updated the label — the binding was missing.

Same class hit the built-in controller's own text in `components/settings.luau`, so the control's header could be invisible or stale. That control is the **Lock all controls** switch now; its `name` rides the same bound path.

## The correct path

Always go through the window's locale binding, which stores the token and resolves it to a string, and re-resolves on every `SetLocale`/`RegisterTranslations`:

```lua
function Element:SetTitle(text)
  self.title = tostring(text or "")
  self.window:_bindLocale(self.titleLabel, "Text", self.title)
end
```

Most elements never write this by hand: `window:Create` binds any locale token
it is handed (`locale.isToken(value)` → `_bindLocale`), so passing
`locale.t(name)` as a `Text` prop is the normal path.

`Window:_bindLocale` (in `components/window/theme.luau` / `utilities/locale.luau`) records the binding in `window.localeProperties` and sets `instance[prop] = locale.resolve(token)`. `window:SetLocale`, `SetTranslator`, `RegisterTranslations` walk those bindings to re-resolve.

Low-level helpers (`locale.t`, `locale.resolve`) are fine for one-off resolves inside `theme.luau`, but **UI text on an Instance must be bound**, not direct-assigned, if there is any path where the locale can change.

## What must be a string

- `TextLabel.Text`, `TextButton.Text` — always string after assignment. The guard asserts `type(label.Text) == "string"`.
- Visibility: an empty subtitle hides the label (`Visible = false`), but the binding still exists so a later non-empty subtitle can re-show localized.

## The controller's title

The built-in switch (`window._elementLockAllToggle`) carries one line of text,
its title, and it is bound like any other element title. The guard asserts it
is a string and that it re-resolves after a locale change:

```lua
window:RegisterTranslations({ fr = { ["Lock all controls"] = "Tout verrouiller" } })
window:SetLocale("fr")
-- the switch's title now shows the French resolve of the same token
```

## How to verify

```sh
sh scripts/guard_invariants_test.sh   # asserts the controller title is a string, locale-bound and updates on SetLocale
sh scripts/elements_lock_test.sh      # drives the built-in switch end to end
```

Static check: `grep -rn "locale\.t" --include="*.luau" elements/` should only appear where the result is passed to `_bindLocale` or `locale.resolve`, never to `.Text =`.

## Common mistakes

- `label.Text = locale.t(token)` — throws or ghosts; use `_bindLocale`.
- `label.Text = token` where `token` is already a table — same.
- Mutating `label.Text` directly in a locale test without `RegisterTranslations` + `SetLocale` — the guard catches stale text.
- Forgetting `_bindLocale` on a newly added header row — the element will look right in `en` but never translate.
