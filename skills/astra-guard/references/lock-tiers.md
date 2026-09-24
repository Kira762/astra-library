# Lock tiers — the five cumulative Element Lock Modes

## Default mapping

Source of truth is `utilities/lockable.luau`:

```lua
local defaultLockLevels = {
  Link = 2,
  Input = 2,
  Dropdown = 2,
  Keybind = 2,
  Toggle = 3,
  Slider = 3,
  Button = 3,
  AboutCard = 3,
  ModePicker = 3,
}
-- fallback for anything not listed:
return defaultLockLevels[element.__type] or 5
```

Group tiers: `components/window/elements.luau` + `elements/collapsibleGroup.luau` / `isolated.luau` default to `5` (the `remaining` tier) unless overridden.

There is intentionally **no entry at `1`**. Level 1 is reserved for explicit opt-in only.

## Override table (`lockGroup` → level)

Also in `utilities/lockable.luau`:

```
minor, low, noncritical         → 1
standard, input, selection      → 2
action, important               → 3
advanced, sensitive, highimpact → 4
remaining, all                  → 5
```

Accepted as `lockLevel` (number 1–5, clamped/rounded) or `lockGroup` (string, case/space/underscore/hyphen insensitive). A number wins over a group name; either wins over the default. `lockable.register` reads props as `lockLevel`/`LockLevel` then `lockGroup`/`LockGroup`.

## Cumulative modes

```
Mode 1 — nothing automatic (only explicit Level 1). Subtitle: "Mode 1 — all controls unlocked"
Mode 2 — Level 1–2              (inputs, links, dropdowns, keybinds)
Mode 3 — Level 1–3              + Toggles, Sliders, Buttons, ModePickers, AboutCard actions
Mode 4 — Level 1–4              + sensitive / advanced
Mode 5 — Level 1–5              = every registered lockable control
```

Lowering the mode unlocks only tiers above it. Raising it never unlocks. `Window:SetElementLockMode` / `GetElementLockMode` clamp to 1–5.

## Registry rules

- **Who registers.** Only functional controls call `lockable.register` after building their UI. Each registered element gets `lockable:astra:<elementId>` (`elementId` normalized from `id`/`Id`/`elementId`/`ElementId` or the display name, deduped per window). `element.usage` merges the existing `usage` prop with the lock tag.
- **Who does not.** Static presentation elements (`Text`, `Stat`, `Divider`, `Section`, `Footer`, `Changelog`, `Group`) and Buttons without a real callback never register — `usageTag == nil` and `_isLockable ~= true`. They are never affected by mode changes.
- **AboutCard special case.** The card itself is static; when it carries an `action = { callback }`, the action's `id`/`usage` is carried onto the card (`aboutAction` etc.) and the card becomes lockable at `3`. Without an action it stays non-lockable.
- **Duplicate ids.** Same normalized name → suffix `2, 3, ...` per window (`duplicate`, `duplicate2`).

## Controller exemption

`window._elementLockModePicker` (built in `components/settings.luau`, `flag = "astra.elementLockMode"`) is exempt:

```
_lockSystemController = true, _isLockable = false
usageTag = nil, usage = nil, IsLocked() == false at every mode including 5
Manual Lock/Unlock are no-ops on it
```

It drives `Window:SetElementLockMode` and keeps its own `Mode N — …` subtitle in sync. Its five modes are fixed (`minModes = 5, maxModes = 5, allow_mode_add_remove = false`).

## Manual locks compose

```
element:Lock(reason)   → sets _manualLocked
element:Unlock()       → clears _manualLocked only
mode lock              → sets _modeLocked
effective locked = _manualLocked or _modeLocked
```

`Unlock` cannot clear a mode lock. Lowering the mode cannot clear a manual lock. The scrim and `element.locked` reflect the composition.

## What to check after a change

- `defaultLockLevels` still has no `=1`; fallback still `or 5`.
- New element types added with `lockable.register` default to `5` unless intentionally tiered.
- Any rename of `lockGroupLevels` keys stays case/space insensitive.
- Tests: `sh scripts/guard_invariants_test.sh` and `sh scripts/elements_lock_test.sh` both green.
