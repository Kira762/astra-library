# SPEC — Mode Picker (superseded by the shipped element)

**Status:** SUPERSEDED 2026-09-23. This draft proposed a three-part "core picker set"
(a discrete-stop slider element, a radio-card group element, and a colorway system).
The approved implementation instead shipped a single self-contained element,
`elements/modePicker.luau` (`ModePicker`), built to the config contract below and
covered by `scripts/mode_picker_test.luau` + `.sh`. Design notes that still apply
live in `MODULES.md` (elements section) and `USAGE.md` (Mode Picker section).

## What shipped

- One element, `ModePicker`: display-only left icon (RGB-customizable, per-mode
  overrides), centred title (optionally wearing the icon RGB) + default-colored
  subtitle, reset button (returns to Mode 1 and the configured mode set), and a
  multi-stop slider whose knob is the toggle's own knob snapped to one dot per
  mode, 3–5 modes enforced, per-mode `onEnable`, `AddMode`/`RemoveMode` bounds,
  flag persistence, theme-bound surfaces, reveal/hide and theme passes.
- Registration on Tab, column Groups and declarative Collapsible Groups.
- Demo on the Elements tab of `example.client.luau`; docs in `MODULES.md`,
  `USAGE.md`, `CHANGELOG.md`.

## Config contract (as approved)

`left_icon`, `right_icon`, `title`, `subtitle`, `mode`,
`min_modes` (floor 3), `max_modes` (ceiling 5), `allow_mode_add_remove`,
`title_color_same_as_left_icon`, `left_icon_color = { r, g, b, a }`,
`reset_on_right_icon_press`, `modes[i] = { label, type, dot_position,
onEnable, optional, icon_color }`, `onReset`.
Subtitle wears the default text colors by design — no color props. The picker
renders no description line; a `description` on the picker or a mode is
ignored.

## Deferred ideas (not designed, no code)

- `pickerBanner`-style summary faces and a `legendBar` strip (inspiration mockup
  furniture that the approved contract does not include).
- A library-wide colorway/accent-override system; today the picker's accent
  sources are the theme or its own `left_icon_color` (`accent = "left_icon"`).
- Column-direction card groups and live embedded controls inside cards.

Revisit these only as new proposals; nothing here is an implementation plan.
