---
name: astra-guard
description: "Regression guard for Astra v1 — prevents the three recurring bug classes: Mode 1 locking when it should be unlocked, text/subtitle not rendering or not updating on locale change, and UI misalignment (placement shifts, rounded corners, track geometry). Use when touching elements/, components/window/elements.luau, utilities/lockable.luau, utilities/locale, components/window/theme.luau, or themes. Enforces exhaustive lock-tier, placement, corner-sync, and locale invariants that check_all.sh runs."
---

# Astra Guard — Regression Guard

This skill stops the bugs that have shipped more than once:

- **Mode 1 default locking** — Mode 1 must leave automatically tiered controls unlocked. Only an explicit `lockLevel=1` / `lockGroup="minor"` locks at Mode 1.
- **Text not rendering / bugging** — `string expected, got table` when a locale token table was written to `TextLabel.Text`, plus stale subtitles after `SetLocale`.
- **UI misalignment** — lock scrims shifting `Position`/`Size`/`Parent`, header corners rounding over a straight divider, slider/mode-picker track geometry.

It is the **complement** to `skills/astra` (the build/edit skill). That skill tells you *how* to build; this one tells you *what must still be true afterwards*.

## When to use

- Any edit to `utilities/lockable.luau`, `components/window/elements.luau`, `elements/*.luau` (especially `modePicker.luau`, `collapsibleGroup.luau`, `isolated.luau`, `slider.luau`, `button.luau`, `link.luau`), `utilities/locale.luau`, or `components/window/theme.luau`.
- Before pushing a branch that touches element construction, lock, locale binding, or corner/theme code.
- When `scripts/check_all.sh` is red on `elements_lock_test`, `guard_invariants_test`, `mode_picker_test`, or `slider_travel_test`.

## Invariants (the contract)

Read the three references for the full spec; the short rules are:

### 1. Lock tiers — `references/lock-tiers.md`

- **No automatic Level 1.** `defaultLockLevels` has no entry `=1`; fallback is `5`. Explicit `=1` still works via `lockLevel=1` or `lockGroup="minor"/"low"/"noncritical"`.
- **Standard mapping:** Link/Input/Dropdown/Keybind = `2`, Toggle/Slider/Button/ModePicker/AboutCard(with action) = `3`, Groups default `5`, `sensitive`/`advanced`/`highimpact` = `4`. Documented in `utilities/lockable.luau`.
- **Cumulative modes:** Mode N locks every element with `lockLevel <= N`. Mode 5 locks all registered lockable elements. Lowering the mode unlocks only the tier above it.
- **Registry:** Only functional controls register (`lockable.register` via `utilities/lockable.luau`). Static elements and callback-free Buttons never get `lockable:astra:<id>` / `_isLockable`.

### 2. Text / locale — `references/text-locale.md`

- Never assign a locale token table to `TextLabel.Text`. Use `Window:_bindLocale(instance, "Text", token)` so `Text` is always a string and updates when the locale changes.
- The built-in controller `window._elementLockModePicker` — and any `ModePicker` through `SetSubtitle` — must keep the subtitle locale-bound (`_bindLocale`), not a direct `Text = table`.
- Mode 1 controller subtitle is `Mode 1 — all controls unlocked` (documents the unlocked default).

### 3. Layout & geometry — `references/layout-geometry.md`

- **Placement preserved:** `main.Position / Size / Parent` (and `headerCorner` metrics) are identical before vs after `SetElementLockMode(5)` for every element on the page — 16 elements in the guard harness. The scrim is an overlay (`Visible` + `ZIndex 60`), never a re-parent or resize.
- **Corner sync:** CollapsibleGroup and Isolated headers flip corners: `collapsed → 8,8` (all four), `expanded → 8,0` (top only). Their `lockScrimCorner` mirrors `headerCorner` — expanded shows a straight divider, not rounded bottom arcs.
- **Track geometry (slider/mode-picker):** knob clearance `knobGap = 2` on all sides, fill is the knob's pill (`knobHeight`/`knobRadius` + `knobGap` inset), running to the knob's trailing edge, so last stop fills end-to-end and no accent bleeds above/below the knob.

## How to use

1. Make the change.
2. Run the gates in order (same as `skills/astra/references/repo-workflow.md`):
   ```sh
   node scripts/generate_bundle.js
   sh scripts/check_all.sh
   ```
   `check_all.sh` already runs the guard as `scripts/guard_invariants_test.sh` (45+ checks). Do not ship if it is red.
3. If you changed tiers, locale, or corners, open the specific reference and verify the table there still matches `utilities/lockable.luau` / `components/window/elements.luau`.
4. For a focused repro without the full suite:
   ```sh
   sh scripts/guard_invariants_test.sh        # exhaustive guard
   sh scripts/elements_lock_test.sh          # cumulative lock matrix
   sh scripts/mode_picker_test.sh            # knob/fill geometry + controller
   ```

## What the guard test covers

`scripts/guard_invariants_test.luau` (run via `scripts/guard_invariants_test.sh`) builds one tab with every lockable and non-lockable element, then asserts:

- 12 lockable types have correct `lockLevel` and `usageTag = lockable:astra:<id>` present in `usage`; 8 non-lockable have `usageTag=nil` and `_isLockable~=true`
- Mode 1 locks only explicit `=1`; Mode 2/3/4/5 are cumulative; late element inherits current mode; manual `Lock`/`Unlock` compose and `Unlock` cannot bypass a mode lock
- Placement invariant (`Position/Size/Parent`) for 16 elements across `SetElementLockMode(5)`
- Header `lockScrimCorner` mirrors `headerCorner` for `8,0` vs `8,8` in both expanded and collapsed states for CollapsibleGroup and Isolated
- Controller `_elementLockModePicker` is exempt (`_isLockable=false`, `IsLocked()=false` at Mode 5), subtitle is a string and locale-bound (regular `ModePicker:SetSubtitle` also)
- Sliding: locked Toggle/Dropdown/Input/Button guard callbacks and preserve values; open dropdown stays open under its scrim

The 45/45 runtime suite plus this guard must stay green. A guard failure is a contract violation, not a flake — fix the source, regenerate the bundle, and re-run `check_all.sh`.

## References

- `references/lock-tiers.md` — the five tiers, allowed overrides, cumulative mode table, and registry rules.
- `references/text-locale.md` — why `_bindLocale` is required, the `string expected got table` class, and the locale-update check.
- `references/layout-geometry.md` — placement invariant, corner sync, and track/fill geometry.

## Failure signatures (what the guard catches)

| What you see | Guard section | What it means |
|---|---|---|
| `Mode 1 locks link` / `Links default to standard tier` | lock tiers | `defaultLockLevels.Link` is `1` again, or fallback changed from `5` |
| `string expected, got table` on subtitle / stale subtitle after `SetLocale` | text/locale | `SetSubtitle` wrote a token table directly instead of `_bindLocale` |
| `Placement Position/Size shifted at Mode 5` | layout — placement | lock scrim reparented, resized the card, or changed flow; scrim must be overlay only |
| `header 8 vs scrim 8` / `expanded should be 8,0` | layout — corners | scrim corner not synced to `headerCorner`; locked expanded card shows rounded bottom |
| `controller is lockable` / `Mode 5 locks controller` | lock tiers — controller | `_elementLockModePicker` lost its `exempt`/`_lockSystemController` guard |
| `locked toggle ran its callback` | lock tiers — guards | element did not gate `MouseButton1Click` / `_runGuarded` while `locked` |
