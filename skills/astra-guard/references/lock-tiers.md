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
  Stepper = 3,
  Button = 3,
}
-- fallback for anything not listed:
return defaultLockLevels[element.__type] or 5
```

Group tiers: `components/window/elements.luau` + `elements/collapsibleGroup.luau` default to `5` (the `remaining` tier) unless overridden.

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
Mode 1 — nothing automatic (only explicit Level 1). Subtitle (documented wording): "all controls unlocked"
Mode 2 — Level 1–2              (inputs, links, dropdowns, keybinds). Subtitle (documented wording): "inputs and selections locked (Links, Inputs, Dropdowns, Keybinds)"
Mode 3 — Level 1–3              + Toggles, Sliders, Steppers, Buttons.
Mode 4 — Level 1–4              + sensitive / advanced. Subtitle (documented wording): "sensitive controls locked (high-impact actions)"
Mode 5 — Level 1–5              = every registered lockable control. Subtitle (documented wording): "all lockable controls locked (Collapsible Groups)"
```

Lowering the mode unlocks only tiers above it. Raising it never unlocks. `Window:SetElementLockMode` / `GetElementLockMode` clamp to 1–5.

## Registry rules

- **Who registers.** Only functional controls call `lockable.register` after building their UI. Each registered element gets `lockable:astra:<elementId>` (`elementId` normalized from `id`/`Id`/`elementId`/`ElementId` or the display name, deduped per window). `element.usage` merges the existing `usage` prop with the lock tag.
- **Who does not.** Static presentation elements (`Text`, `Stat`, `Divider`, `Section`, `Footer`, `Changelog`, `Group`) and Buttons without a real callback never register — `usageTag == nil` and `_isLockable ~= true`. They are never affected by mode changes.
- **Duplicate ids.** Same normalized name → suffix `2, 3, ...` per window (`duplicate`, `duplicate2`).

## Controller exemption

The built-in control is a single **Lock all controls** switch:
`window._elementLockAllToggle` (built in `components/settings.luau`). It is
exempt:

```
lockSystemController = true, _lockSystemController = true, _isLockable = false
usageTag = nil, usage = nil, IsLocked() == false at every mode including 5
Manual Lock/Unlock are no-ops on it
```

On flips the window to Mode 5, off to Mode 1, and it owns no flag — the tier
travels as window state (`Window:_restoreUnowned` / `_unownedConfigValues`).
`Window:SetElementLockMode` drives it back: the switch reads on at Mode 5 and
off below it, and every tier change schedules the same debounced autosave any
other control edit uses (`Window:_scheduleSave`).

## Persistence

The tier travels with the configuration under the shared flag
`astra.elementLockMode` (`components/window/constants.luau` →
`elementLockModeFlag`; used by `components/settings.luau` and
`components/window/elements.luau`).

The switch lives in a settings panel that builds lazily on first open and owns
no flag, so the tier has no control at all while a window is starting. Two
window methods close that gap, both called from
`utilities/persistenceConfig.luau`:

```
Window:_restoreUnowned(values)   load: apply a persisted tier no control owns yet
Window:_unownedConfigValues()    save: the live tier, so a snapshot is complete
```

Without `_restoreUnowned` a saved Mode 5 waited for the player to open
Settings → Controls before anything locked; without `_unownedConfigValues` a
config saved before that panel was ever opened lost a tier the host had set
through `SetElementLockMode`. A live control of the same flag always wins, so
if a host ever registers one the normal control path owns the round trip.

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
- Tests: `sh scripts/guard_invariants_test.sh`, `sh scripts/elements_lock_test.sh` and `sh scripts/lock_mode_persistence_test.sh` all green.
