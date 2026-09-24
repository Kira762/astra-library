# Text / locale — why `_bindLocale` is required

## The bug that shipped

`elements/modePicker.luau:SetSubtitle` wrote a locale token table directly to `TextLabel.Text`:

```lua
self.subtitleLabel.Text = locale.t(text) -- locale.t returns a table token, not a string
```

Luau's `TextLabel.Text` is `string`. The assignment threw:

```
string expected, got table
```

And even when it was coerced to a string once, a later `window:SetLocale("fr")` never updated the label — the binding was missing.

Same class hit the built-in controller's subtitle in `components/settings.luau`, so the header left of the knob could be invisible or stale.

## The correct path

Always go through the window's locale binding, which stores the token and resolves it to a string, and re-resolves on every `SetLocale`/`RegisterTranslations`:

```lua
function ModePicker:SetSubtitle(text)
  self.subtitle = tostring(text or "")
  self.window:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
  self.subtitleLabel.Visible = self.subtitle ~= ""
end
```

`Window:_bindLocale` (in `components/window/theme.luau` / `utilities/locale.luau`) records the binding in `window.localeProperties` and sets `instance[prop] = locale.resolve(token)`. `window:SetLocale`, `SetTranslator`, `RegisterTranslations` walk those bindings to re-resolve.

Low-level helpers (`locale.t`, `locale.resolve`) are fine for one-off resolves inside `theme.luau`, but **UI text on an Instance must be bound**, not direct-assigned, if there is any path where the locale can change.

## What must be a string

- `TextLabel.Text`, `TextButton.Text` — always string after assignment. The guard asserts `type(label.Text) == "string"`.
- Visibility: an empty subtitle hides the label (`Visible = false`), but the binding still exists so a later non-empty subtitle can re-show localized.

## Controller subtitles

```
Mode 1 — all controls unlocked
Mode 2 — inputs and selections locked
Mode 3 — important actions locked
Mode 4 — sensitive controls locked
Mode 5 — all lockable controls locked
```

Built from `lockModeSubtitles[mode]` in `elements/modePicker.luau:_syncLockSystemMode`. The call to `SetSubtitle` there is what keeps Mode 2…5 correct; Mode 1's wording documents the unlocked default (the guard checks it after `controller:Set(1)`).

The controller itself (`window._elementLockModePicker`) uses the same `SetSubtitle` path — its subtitle is also locale-bound. A regular `ModePicker` created via `tab:CreateModePicker` is bound the same way, so both update after:

```lua
window:RegisterTranslations({ fr = { current = "Actuel" } })
window:SetLocale("fr")
-- subtitle now shows the French resolve of the same token
```

## How to verify

```sh
sh scripts/guard_invariants_test.sh   # asserts subtitle is string, visible, locale-bound, updates on SetLocale
sh scripts/elements_lock_test.sh      # checks Mode 1 controller subtitle
```

Static check: `grep -rn "locale\.t" --include="*.luau" elements/` should only appear where the result is passed to `_bindLocale` or `locale.resolve`, never to `.Text =`.

## Common mistakes

- `label.Text = locale.t(token)` — throws or ghosts; use `_bindLocale`.
- `label.Text = token` where `token` is already a table — same.
- Mutating `label.Text` directly in a locale test without `RegisterTranslations` + `SetLocale` — the guard catches stale text.
- Forgetting `_bindLocale` on a newly added header row — the element will look right in `en` but never translate.
