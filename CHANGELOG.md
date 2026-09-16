# Changelog

All notable changes to Astra v1. Dates use 2026.

## 2026-09-16 — The drag handle shows up again (and answers the pointer)

The small detached pill under the window never appeared. It is built
`Visible = false`, and the window wrote that flag to `false` in ten places
while writing it `true` in exactly one — the minimise settle, 0.5s after
folding. So in the normal expanded state the hitbox was invisible, a hidden
parent takes `MouseEnter`/`MouseLeave` with it, and the pill could not be
revealed by a hover, could not be grabbed, and did not exist as far as the
window's own topbar drag was concerned.

- **The handle now leaves its visibility to the handle.** `components/drag.luau`
  gains the four live states it already had values for — `handleHover` (64x3,
  0.5), `handleGrab` (56x3, 0), `handleIdle` (48x3, 0.7, the faint hint) and
  `handleParked` (0x3, 1.0) — plus `Drag:enable`, `Drag:disable`,
  `Drag:fadeOut` and `Drag:setMoving`. `components/window.luau` no longer writes
  `self.drag.drag.Visible` anywhere; it calls the lifecycle instead, and every
  write that used to switch the handle off now *parks* the pill as well, so an
  entrance can never inherit a look from the hover the previous one was
  interrupted in.
- **Reachable after every settle.** `_firstShow`'s settle and `_quickRestore`'s
  settle call `enable`, as does `ToggleMinimise` in both directions (the expand
  branch previously never brought the handle back at all — un-minimising left
  it dead until the next hide/show cycle). Enabled means *reachable*, not
  revealed: the pill stays unseen until the pointer finds it, so a window
  that has never been moved does not announce a handle it does not need.
- **Shown when the window is moved.** `Window:_bindTopbarDrag` now distinguishes
  a click from a move (the existing 4px threshold) and calls
  `Drag:setMoving(true)` on the first real movement: the pill brightens to the
  hover look for the length of the drag, follows the window at the same 22px
  gap, then settles to the idle hint when the move ends. It stays there — the
  faint pill under the window is the affordance the next interaction starts
  from — until the window is hidden, folded or closed. A press that never
  crosses the threshold is a click and leaves the handle untouched.
- **Hovering and dragging it works again** for the same reason: a reachable
  hitbox fires `MouseEnter`/`MouseLeave`, so the pill fades in at the hover
  size and can be grabbed to move the window (with the grab look while held).
  While the window is being moved by its topbar the hover tweens stand down —
  `moving` is recorded but the pill is not fought over — so the sweep of the
  handle past the cursor cannot flicker it between looks.
- **The 22px offset is named.** `dragHandleGap` in `window.luau` (next to the
  other local layout constants) and `handleGap` in `drag.luau`; the five places
  that place the handle all read the constant instead of a bare `22`.
- **Verification:** new suite `scripts/drag_handle_test.sh` /
  `scripts/drag_handle_test.luau` (H1-H9) pins the reachability of a settled
  window, the hover reveal, the move reveal (topbar and handle drag, both
  driven through real input events), the 22px ride, the click-versus-move
  threshold, hide/show, minimise/expand and close. The stub environment grew
  the vector/UDim2 arithmetic those paths need (`__add`/`__sub`/`__mul`,
  `Magnitude`, `UDim2:Lerp`) — without it the drag code could not run under a
  suite at all. All 29 runtime suites plus a compile of every published
  `.luau` pass.

## 2026-09-16 — The bundle loader is a single `loadstring` line

`example.client.luau` and `USAGE.md` now load the published bundle with exactly one
statement, the one every host pastes:

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()
```

- **The guarded loader is gone.** The `loadstring or load` fallback, the byte-size and
  HTML-page probes, and the `assert`s that named each failure are removed from the
  example; there is no second way to compile the bundle.
- **The trailing `()` is load-bearing.** `loadstring(text)` only compiles — without the
  call `Astra` is a function and the first `Astra:CreateWindow` dies with `attempt to
  index a function value`, which is why the docs state it explicitly.
- **Studio keeps only its load path.** `loadstring` is an executor function, so the docs
  say the line needs one, and in Studio/Rojo the ModuleScript tree is `require`d instead.
- **The failure modes stay documented.** A text that does not compile still surfaces as
  `attempt to call a nil value` at line 1, so `USAGE.md` keeps a short "what a failed
  load looks like" list (an HTML error page, or a real syntax error caught by
  `scripts/check_syntax.sh`) instead of putting the checks back in the loader.
- **No bundle change:** `version-1.luau` is generated from the modular tree, and the
  loader is not part of it — `example.client.luau` is only compiled by
  `scripts/check_syntax.sh`. `MODULES.md`'s and `USAGE.md`'s descriptions of the example
  now match the one-tab file it actually is.
- **Carry-over fix found while re-checking the example:** its `CreateStat` passed
  `changeBaseline = 100`, but that prop is a mode string (`"previous"` | `"initial"`) and
  any other value — a number included — is read as `"previous"`, so the line never did
  anything. The example now passes `"initial"`, and `USAGE.md` lists the accepted values
  for `display`, `changeMode` and `changeBaseline` (a numeric baseline is
  `stat:ResetBaseline(number)`).

## 2026-09-16 — The Keybind element is removed

The only remaining first-party use of the Keybind element was the Settings menu
binding, and that row moved to an `Input` field in the entry below. The element
is now gone from the library rather than left as an unused public surface.

- **`tab:CreateKeybind` no longer exists.** `elements/keybind.luau` is deleted,
  the `Keybind` declarative type is no longer accepted by
  `CreateCollapsibleGroup`, and the `Keybind`/`KeybindProps` types are gone
  from `Types.luau`, `library_entrypoint.luau` and the bundle.
- **The window drops the plumbing that only served the element.**
  `Window:_keybindUsing` (the conflict check), `_recordingKeybind` (the
  capture guard in `_bindKeybind`, `ToggleHide` and tab teardown) and the
  Settings field's "bound to another Keybind" refusal are removed. The
  menu-toggle key still refuses junk text and left click, still clears on
  `none`/empty, and still toggles the window.
- **`window.settings.toggleKeybind` is unchanged.** It stays an `EnumItem`, is
  persisted the same way, and `Window:_bindKeybind` still compares against it.
- `example.client.luau` no longer shows a Keybind element or a `Keybind`
  collapsible child.
- Suites: `keybind_input_test` now covers only the Settings field;
  `collapsible_group_test`, `inline_description_test`, `input_field_test`,
  `instance_budget_test`, `window_corners_test` and the description geometry
  probe drop their Keybind rows (the wrapped-description probe uses an Input).
  `collapsible_group_test` also had its child indices re-pinned; the row/column
  Group assertions were pointing one element past their targets.
  `USAGE.md` and `MODULES.md` no longer document the element.

## 2026-09-16 — The Settings menu key is typed into an Input field

Reported from the field as a Settings keybind that would not take a click: the
row never entered its recording state, so the menu key could not be changed at
all. That row was the only place the library asked for a key through the Keybind
element's click-to-record cap, and it now asks the way every other typed value
in the library asks — through the `Input` element.

- **`components/settings.luau` builds General → Toggle Keybind as
  `type = "Input"`** (icon `keyboard`, placeholder `e.g. K, Space, MB2`). The
  field shows the bound key's name and reads one back on the commit every Input
  makes: focus lost. The Keybind element's cap is gone from Settings, and no
  second input widget is built for it.
- **`window.settings.toggleKeybind` stays an `EnumItem`.** That is what
  `Window:_bindKeybind` compares the incoming input against, what the other
  Keybind elements refuse to take, and what
  `utilities/persistenceSettings.luau` writes as `{ EnumType, Value }`, so
  existing settings files keep loading unchanged.
- **`keyLabel`/`parseKey` carry the element's display and capture rules over to
  text**: `None` for an unbound key, `MB2`/`MB3` for mouse buttons, case and
  separators ignored (`k`, `Space`, `left shift`, `f7`, `5`, `rmb`), an empty
  field or `none` clearing the binding, and anything not in that table left to
  an `Enum.KeyCode`/`Enum.UserInputType` lookup so an uncommon but real name
  still binds.
- **Refusals keep the rules they had.** A key another Keybind already owns is
  rejected with the same "%s is bound to %s. Kept %s." notification; text that
  names no key is rejected; and left click is rejected with its own reason,
  because a toggle bound to `MouseButton1` would fire on every click in the game
  and the cap's capture never offered it either. A rejected field restores the
  previous binding and flashes the error colour over the commit's flash.
- **The Keybind element itself is unchanged** — `tab:CreateKeybind` still gets
  the button-backed cap, its click-to-record flow, hold mode and conflict
  checks.
- Suite: `scripts/keybind_input_test.luau` drives the field (commit, case and
  alias parsing, mouse button, clearing, junk/left-click/conflict refusals,
  typing the bound key inside the field not toggling the window, and the new key
  toggling it afterwards) and keeps the element's cap covered beside it. Bundle
  regenerated.

## 2026-09-16 — The loader stops reporting `attempt to call a nil value`

Reported from the field as `dROpudBpfgnVovyLM:1: attempt to call a nil value`,
`Script 'LocalScript', Line 1`. Nothing in the library was at fault and nothing
in the message is a location: the random name is the executor's chunk for the
fetched string, and a one-line script means the failing call is on line 1. The
nil being called is the *compiled chunk* — `loadstring` returns
`nil, compileError` instead of throwing, so a bundle that never compiles shows
up as a nil call, and the real reason (a syntax error, or an HTML error page
where a repo was expected) is thrown away.

- **`example.client.luau` did not compile.** `CreateCollapsibleGroup` was
  missing the comma between `description` and `elements`, which is exactly the
  kind of defect the message hides: parse fails at line 141, the user sees a
  nil call at line 1. Fixed, and a Luau parse of all 136 `.luau` files in the
  tree is now clean.
- **`scripts/check_syntax.sh`** compiles the modular tree, the example and the
  bundle with the Luau CLI, so this class of defect stops shipping. It exits 2
  ("not checked") rather than 0 when no CLI is installed.
- **The example's loader now checks both steps** it used to assume: that the
  fetch returned Luau rather than an error page or a truncation, and that
  `loadstring` — not Studio's function-only `load` — is what compiled it. Each
  failure names itself instead of leaving the caller to read a nil call.
- **`USAGE.md` documents the message.** The loader snippet keeps its `assert`s,
  and the section that follows says what `attempt to call a nil value` means
  and the three things to check in order.

## 2026-09-15 — Keybinds use the original cap again

- Removed the editable TextBox path from `Keybind`; the key cap is a `TextButton`
  with a `TextLabel` again, so clicking it enters the normal capture flow instead
  of creating a separate input field.
- The built-in Settings toggle binding now uses that same Keybind control without
  the `editable` prop. Capture behavior remains: press a key or supported mouse
  button to bind, Backspace clears, Escape cancels, and conflicts are rejected.
- Updated the keybind regression to pin the original button-backed cap and
  regenerated the standalone bundle.
- Cleaned `example.client.luau` so it only demonstrates the original `Input`
  element once; duplicate no-op numeric/declarative input rows are gone.

## 2026-09-15 — Buttons stopped crashing on the first click

Reported from the field as `attempt to index nil with 'spec'`, pointing at the
bundle line inside a `LocalScript`. The example was never at fault: the fault
was in the element the example was clicking.

### The button's missing require

The button's click choreography rides the shared motion service — the tap
glyph dips on `fast` and springs back on `settle`, the card nudges on `snappy`
— but `elements/button.luau` never required it. Every `motion.spec(...)` call
read a bare global, so the module *built* cleanly and then died on the first
tap, before `self:_runCallback()` could run the caller's callback.

- **`local motion = require(constants.motion)`** added to
  `elements/button.luau`, mirroring the sibling header in `elements/toggle.luau`
  (which has the same comment block and the require the button had lost). Both
  click handlers were affected: the full card and the compact row built by a
  row `Group`.
- **`Astra.Settings.persistence` was `nil`.** `settings/init.luau` built
  `local persistenceModule = require(script.persistence)` and then exported
  `persistence = persistence` — the bare global, not the local. `MODULES.md`
  has always documented the export; the value behind it was missing. No
  internal consumer touched the field, so it failed silently.
- **The generated loader carried the same defect.** `scripts/generate_bundle.js`
  injected `ErrorNonModuleScript` and `ErrorSelfRequire` by string-replacing a
  `local ErrorNonModuleScript` declaration that the loader template never
  contained, so both `.replace()` calls were silent no-ops and the bundle's
  two require guards raised `error(nil)` — a blank message instead of
  `Expected ModuleScript got Folder` / `Cannot require self`. The constants are
  declared in the template now, where `CurrentRefPointer` is in scope.
- **New suite `scripts/button_click_test`** (B1–B6) pins the whole path: the
  tap glyph exists so the animation is really exercised, the click runs the
  callback, and the press/release *sequence* of writes lands on the tap scale
  (0.78 → 1), the card width (−26 → −20) and the stroke (open → resting token)
  for both the card and the compact row, plus the settings surface's
  persistence export. Against the previous bundle it fails with the reported
  `attempt to index nil with 'spec'`; no earlier suite ever fired a click on a
  `Button`, which is how this shipped.

## 2026-09-15 — The window's corners, and one motion system

Two fixes that were visible together: straight 1px lines drawn across the
window's four rounded corners, and an interface whose animations had drifted
into a pile of one-off curves.

### The corners

Roblox gives every GuiObject a 1px border by default. The border draws the
frame's *rectangular* outline — it does not follow UICorner arcs — so the
moment the window's background faded in, a hard square outline crossed all
four rounded corners (most visible top and bottom, where the straight line
cuts visibly across the arc). The window frame was the last surface in the
tree still shipping that default.

- **`BorderSizePixel = 0` on the window's main frame.** The silhouette is the
  UICorner's job alone; only the original rounded corners remain visible.
- **The dropdown's search icon button** carried the same latent default and
  is borderless now too.
- **New `scripts/window_corners_test`** builds a window, exercises every
  lazily-created surface (first show, elements, toast, dropdown, popup,
  profile card, collapse and restore) and asserts that no visible surface
  anywhere in the ScreenGui carries a border, and that the shell's corner
  radius still follows the theme's `CornerRoundness`.

### The motion redesign

Every component used to build its own `TweenInfo` (92 construction sites, ~30
distinct curves). Identical interactions — a hover, a dismissal, a panel
sliding home — could ease differently depending on which file they lived in,
dismissals lasted as long as entrances, and only some of the paths answered
the user's "Animation speed" setting. Everything now rides the shared motion
service and one legible vocabulary:

- **A system, not a pile of curves.** Entrances decelerate (Out); exits
  accelerate (`exit` is now a 0.3s Quart *In* — a card leaves faster than it
  arrived); lateral state moves ease InOut (new `glide`, 0.35s Quart — the
  window folding into its capsule and back); and the playful surfaces get a
  short Back overshoot (`pop` for the shell, new `settle` for small elements
  like the capsule's face and button presses, `spring` for drag landings).
  Durations still step with scale: 0.16 press → 0.25 hover → 0.4 element →
  0.5–0.6 surface → 0.55 shell.
- **Every remaining bespoke tween migrated.** Window open/close/hide/restore/
  minimise, tab pills and page hand-off, element click nudges, the toggle's
  knob (now a physical slide with a landing), slider fill and handle, field
  boxes and keybind caps, dropdown rows/panel/chevron, search pill, toast and
  notification entrances and dismissals, popups, the profile card, drag
  landings and the lock scrim all resolve through `motion.tween` or
  `motion.spec` — so all of them follow the time scale, skip no-op writes,
  and hand over one owner per animated property.
- **Targeted feel changes where the old curve fought the gesture.** Close and
  hide now contract on `glide` while their surfaces accelerate out on `exit`;
  restore unfolds on `glide` with the corner springing open on `settle`;
  toggle knobs slide on `settle` instead of drifting on a 0.6s curve; button
  and toggle press-dips spring back with a small overshoot; the collapsed
  capsule's face arrives on `settle`.
- **Theme changes are one gesture.** `ChangeTheme` batched its per-property
  tweens into one motion-service tween per instance (a theme switch used to
  create a tween per property), all cross-fading on `smooth`.
- **Bespoke curves that must stay bespoke now rescale.** The progress sweep
  keeps its ambient loop; the delayed accent-glow beats (toggle, slider) and
  the odometer's digit roll go through `motion.spec`, so they stretch and
  shorten with the speed profile like everything else. The unused
  `pillResizeInfo` constant is gone (field boxes resize on `snappy`).
- Bundle regenerated (`version-1.luau`); `motion_test` extended for the new
  vocabulary (registered specs, `settle`/`glide` easing family, exit being
  quicker than its entrance).

## 2026-09-15 — Multi-select dropdowns get a real Select all / Clear row

The bulk-action line was two bare text buttons with no state of their own: no
way to see whether "Select all" still had anything left to do, and a Clear that
read like a label rather than a control. The row is now the checkbox-and-bin
line from the design reference.

- **Select all is a checkbox.** It sits at the left edge in the same 16px glyph
  slot an option row uses — unchecked draws a 12px rounded outline (the width
  of the row glyphs), checked shows the check glyph a selected row shows — so
  the box's two states are never a size apart from the rows beside them. The
  label beside it reads at the row's own 16px instead of 13px.
- **It toggles.** With every visible option selected the box is on and a click
  clears that set; otherwise the click fills in what is missing. Individual
  picks, `Set`, `Add`/`Remove`/`Refresh` and a changed search filter all move
  the box with the list, and a filter that matches nothing leaves it off. A
  click that empties the box under the pointer leaves the outline at its hover
  brightness, and a sync that would change neither half is skipped — the filter
  runs on every keystroke, and it should not replay two tweens per character.
- **Clear keeps its meaning** — it removes only the options the filter shows,
  so selections it is hiding survive — and gains the bin icon, resolved through
  the icon packs (`trash`, lucide) like every other icon, dimmed with its label
  and brightened on hover.
- **The row is 32px**, up from the 22px text strip, so the checkbox has the
  room the reference gives it; `_openHeight()` carries the new height and the
  row keeps LayoutOrder 2, between the search bar and the list. A single-select
  dropdown is untouched: no action row, no instances.

Suite: new `scripts/dropdown_actions_test.{luau,sh}` — A1 only a multi-select
dropdown carries the row (and what it holds), A2 the box answers for the
visible options, A3/A4 Select all fills the visible set and toggles back off,
A5 Clear leaves the hidden options alone, A6 the box follows picks and filters,
A7 the row is what the open panel pays for, A8 an unchecked box stays hovered
when a click empties it under the pointer, A9 the bin is a real pack icon.

Bundle regenerated (`version-1.luau`).

## 2026-09-15 — Instant startup: the window shows on the next frame

The 1–3s wait before the window appeared was three deliberate gates, not slow
construction: a fixed one-second reveal deadline in the entrypoint (paid even
by an empty window), a settle loop behind it, and a first-show entrance that
ran *two* overlapping content cascades over the same page. The shell now
appears on the next frame and the entrance is a single staged sequence.

- **No reveal deadline.** `STARTUP_REVEAL_DELAY` (1s) and the `STARTUP_SETTLE`
  loop are gone: auto-show runs on a `task.defer` plus one heartbeat, so the
  caller's first synchronous `CreateTab` calls still land before the shell
  appears. Pacing is budget-limited on both sides of the reveal now (3ms /
  48 instances per frame) instead of dropping to one control per frame after
  it — with the window visible from frame two, the old post-reveal lane
  would have funnelled nearly every control through single-frame yields and
  made large builds finish *slower*. `Hide()` before that tick still cancels
  auto-show via `_autoShowCancelled`.
- **One cascade.** `_firstShow` used to walk the visible page twice: a
  `task.delay(firstContentDelay)` reveal *and* the `_stageContentReveal` one,
  with different pacing each. The second cascade's tweens cancelled the
  first's mid-flight through motion's cancel-on-overlap, so the entrance did
  double work to look worse. Only the staged path remains
  (`contentRevealBeat` 0.22 → 0.12, cascade budget 0.5 → 0.35); the
  `firstContent*` timers and the duplicated `_elementsPending` clear are
  removed. The `pop`/`emphasized` shell specs are untouched.
- **No tween storm while hidden.** `Window:ChangeTheme` routed every
  Color3/number binding through a 0.5s tween even when called pre-first-show
  from `Window.new`, where nothing can be seen animating. While hidden and
  never shown it now assigns the identical end state directly; every later
  theme change still tweens.
- **One secure-mode branch.** The entrypoint's two separately-guarded
  `if State.secureMode` blocks (icon preload, font swap) run as sibling
  threads under a single guard. The unread `window._startupStartedAt` stamp
  goes with the deadline it served.
- Bundle regenerated (`version-1.luau`).

## 2026-09-15 — Tab-strip end gutters and the end of Tags

Follow-up to today's tab-strip spacing pass. The outer pills could still
touch the strip's clip edges: the strip frame was inset from the *window*
but nothing separated the first and last pill from the strip's own edges, so
an end pill sat flush against the fade boundary at rest and a scrolled strip
parked the last pill against the edge. The Tag element is also removed
entirely.

- **End gutters inside the strip.** The top-layout strip now carries a
  `UIPadding` (`tabStripEdgePadding = 14`, a new layout token) at each canvas
  end. Padding scrolls with the content, so the first pill starts — and the
  last pill ends — a fixed distance inside the clip edge at every scroll
  position, while an overflowing pill still clips well inside the window
  border (the frame inset is unchanged at 30). Pill-to-pill spacing opens from
  7 to 8.
- **Chrome band is balanced.** The top clearance and the gap below the strip
  are both 6 (`tabStripTopClearance` / `tabStripBottomClearance`, was 3/3 with
  the row 1px above the topbar edge in older builds): the strip is centred in
  its band and `chromeHeight` follows, shifting the content area, search pill
  and window sizing together.
- **Fades are gutter-aware.** `tabStripFadeWidth` (30, was a local 24) covers
  the new gutter; `_refreshTabStripChrome` measures clipping from the last
  pill's canvas-space edge, so the trailing 14px gutter no longer lights the
  right fade a gutter early. `_scrollSelectedTabIntoView` lands the selected
  pill clear of whichever fade is showing (left: fade width; right: end
  gutter) and clamps against the true `AbsoluteCanvasSize - frame width`
  scroll range.
- **Tags permanently removed.** `elements/tag.luau`, `Window:CreateTag`, the
  topbar tag container and its `tags` list, the `Tag`/`TagProps` types, the
  example's tags and the USAGE/MODULES references are gone, along with the
  tag fade loops from close/hide/show. The example and docs no longer mention
  tags; new `scripts/topbar_strip_test` asserts the strip geometry, fade
  thresholds, scroll-into-view landings and the removed tag API.
- Bundle regenerated (`version-1.luau`, 102 modules).

## 2026-09-15 — Breathing room around the topbar tab strip

The top-layout tab strip sat almost flush with its surroundings: its
ScrollingFrame started one pixel *above* the topbar's bottom edge and the side
insets were only 22px, so the tabs read as pressed up against the title row and
the outermost pills crowded the window's side edges.

- **Clearance under the topbar.** `tabStripTopOffset` is now
  `topbarHeight + 3` (was `topbarHeight - 1`): the strip no longer overlaps the
  topbar's bottom edge, so a real gap separates the tab pills from the title
  row. `chromeHeight` recomputes from the same constants, so the elements area,
  the search pill, and window sizing all shift with it.
- **Wider side insets.** `tabStripInset` is 30 (was 22), so the first and last
  pills keep a visible margin from the window's edges. The edge fades and the
  scroll-into-view padding derive from the same inset and follow automatically;
  the duplicated `or 22` fallbacks in `Topbar.Build` and
  `Window:_scrollSelectedTabIntoView` now read `or 30`.
- Bundle regenerated (`version-1.luau`, 103 modules).

## 2026-09-15 — The closed Collapsible Group's bottom corners

Follow-up on today's corner entry: rounding the header band's *top* corners left
the same flaw one edge down. A closed group's container is exactly as tall as the
band, so the band is the card's bottom edge — and since Roblox rounds a GuiObject's
own surface but never clips a descendant to those arcs, its square bottom corners
painted over the container's bottom arcs. The stroke drew a rounded outline while
the fill ran past it: rounded top, uneven bottom. Open groups were already fine
(`bodyClip` is flush with the container's floor and carries those arcs), so nothing
about the revealed body changed.

- **The band now carries the container's bottom arcs while it is closed.**
  `Collapsible:_fitHeaderCorners()` re-reads one radius token (`ElementCornerRadius`)
  for both states, so only *which surface owns the edge* changes, never the radius:
  closed → all four corners round, open → the bottom pair squares off against the
  straight divider again.
- **The flip is timed to the settle, not the click.** Collapsing rounds the band in
  `Window`-independent `_resize` finish (so the shrink shows the clipper's arcs for
  every frame in between, and a reversal mid-tween cannot strand a state — a stale
  revision still returns early), while opening squares the band *before* the body is
  revealed so the first expanded frame shows a straight seam instead of two notches
  at the band's floor. Instant motion and a hidden window's deferred reveal settle
  synchronously through the same path, and the reveal/`_refreshTheme` route re-applies
  it, so a radius changed while closed still lands.
- **`Window:_setRoundedCorners(corner, corners, token)`** is the state-flipping
  companion to `_roundCorners`: the listed corners ride the token, every other corner
  of that frame goes back to square, and already-matching corners are not rewritten.
  It reuses the container's one `UICorner` (no instance churn — open/close/move still
  create nothing) and is a no-op on an engine without per-corner radii, where
  `_roundCorners` already gave the frame one radius on all four corners.
- Tests extended: the group suite asserts all four closed-band arcs against the
  container's, that the band keeps a single `UICorner` across states, that expanding
  squares only the bottom pair, that a settled collapse and an instant (zero-length)
  collapse/expansion both land in the same step, and that a theme radius change flows
  to the band's bottom corners and the body clipper. Bundle regenerated
  (`version-1.luau`, 103 modules).

## 2026-09-15 — Collapsible Group corners, and icon-only rows that stayed readable

A screenshot review found the Collapsible Group's top-left and top-right
corners squared off, and the collapsed sidebar rail showing the start of every
tab name next to its icon. Both come from the same engine rule: Roblox rounds a
GuiObject's **own** surface with `UICorner` but never clips its **descendants**
to those arcs, and a rebuilt row is a descendant that gets its state from how it
was constructed, not from where it sits.

- **The header band squares off the card's top corners.** `headerSurface` is a
  child of the container spanning its full width, so it painted over the corner
  arcs the stroke draws: the band filled the top-left and top-right corners and
  the silhouette read as a rounded outline with square corners behind it. The
  band now rounds its own top corners with the container's `ElementCornerRadius`
  (`Window:_roundCorners` takes the theme token as an optional third argument),
  and the container's own surface is the element surface the band paints
  (`ElementGradient`, not `WindowColor`), so the arcs resolve to the band's
  colour instead of a darker wedge. The revealed body keeps its darker window
  surface — `bodyClip` now paints it (the clipper is flush with the container's
  bottom edge, so it carries the container's bottom arcs and leaves the top
  corners square under the straight divider) — and it fades in with the rest of
  the card (`_setShown`), so a group revealed on a page entrance never shows an
  opaque body surface first.
- **The collapsed rail showed tab names.** Rows rebuilt *after* the rail was
  sized came back as expanded rows: `Window:_setLayoutMode` rebuilds every row
  (`Tab:_rebuildSelector`) after `ApplyWidth` had already sized the rail, and a
  `Window:CreateTab` made while the rail was icon-only built a fresh row too. In
  a 64px rail that left the 10px content padding in place with the title still
  visible, so the first characters of the name ("El…" of *Elements*) rendered
  past the icon against the rail edge, with the icon pushed off centre. Both
  paths fix at the source: `tabSelector.railCollapsed(window, layout)` reads the
  rail's current width and `tabSelector.build` collapses a row as it is built,
  and `Window:_setLayoutMode` re-applies the rail width after its rebuild loop
  (which also re-constrains a capped long title's wrapping slot — those came
  back unconstrained and overflowed the rail too).
- **The icon-only tile is square.** A collapsed row kept its full-rail width, so
  a 64px rail produced a 34x38 tile and the icon sat 7px from the tile's sides
  but 9px from its top and bottom. `setRowCollapsed` sizes a collapsed row to
  `rowHeight` square (the rail's list still centres it, the icon stays 20px), so
  the glyph has the same clearance on all four edges; an expanded row keeps the
  full-rail recipe (inset each side).
- Tests extended for both: the group suite asserts the band's top-corner radii
  against the container's, the band's square bottom corners and the body
  clipper's surface/bottom arcs; the sidebar suite asserts that a row created
  while the rail is collapsed is born an icon-only square tile (title hidden,
  content centred, no expanded padding) and that rebuilt rows keep the capped
  title slot. Bundle regenerated (`version-1.luau`, 103 modules).

## 2026-09-14 — Collapsible Group rebuilt as one connected card (design reference)

The previous container drew the header as a standalone card and the revealed
content as a second, detached panel a gap below, ran child cards edge to edge
against the panel stroke, and faded children to 75% transparency with hidden
strokes. The design reference shows one connected container with crisp inner
cards; the element now renders exactly that. This supersedes today's
"children are visually recessed" entry and restores the `Switch` declarative
alias and `description` props that the "Toggle-only API" entry had retired
(both are asserted by `scripts/collapsible_group_test.luau` and
`scripts/inline_description_test.luau`, which pass again).

- **One container, two surfaces.** `main` is a single rounded, stroked frame
  that clips its descendants; the header band rides the standard element
  gradient over the darker window surface of the body, split by a 1px
  stroke-colored divider. The outer stroke uses the supported
  `ApplyStrokeMode = Border` mode so the container's own clip can never shave
  it.
- **Children are crisp inset cards.** The reveal mask spans the container and
  rides its bottom edge; child cards keep their normal width recipes and land
  one 10px gutter inside the container on every side with 10px gaps — defined
  surfaces and visible strokes via the `CollapsibleChildElement*` theme tokens
  (0.35 surface transparency, 0 stroke transparency), instead of edge-to-edge
  75%-faded ghosts.
- **Expansion math**: collapsed height is the header (41px, 61px with a
  `description`); expanded adds divider + top pad + measured content + bottom
  pad, so the container ends exactly one gutter under the last card.
- **Fixed flaws the reference exposed**: the `description`/`Description` prop
  was dropped by every element constructor (the in-card line never rendered;
  all eight control constructors read it again), the group header never
  received its own line for the same reason, `type = "Switch"` definitions
  were rejected by `CollapsibleGroup` validation (alias of the toggle control
  in the declarative builder, ordinary Groups and `Types.luau`), and the
  content frame double-counted the header offset inside the clipper, letting
  children overflow the container's floor.
- Tests updated to the new geometry (`bodyClip` spans the container instead of
  bleeding 20px, divider position, padded expansion height); bundle
  regenerated (`version-1.luau`, 103 modules).

## 2026-09-14 — The entrance queue no longer trips over a window with no overlays

- **Hiding (or unloading) a window that had never queued an overlay raised
  `attempt to get length of a nil value` inside a coroutine.** `Window.new` seeds
  `_overlayQueue` with an empty placeholder so `Window:Unload` always has something
  to clear, and construction pauses the gate *through* that placeholder — so the
  first thing a window with no requests owns is a **paused queue with no `pending`
  list**. Opening the gate (`Window:Hide` before the first show, the settle of
  `_stageContentReveal`, `_quickRestore`) tested `queue.paused`, watched it come
  true, and then took `#queue.pending`.
- **`queueFor` now completes the queue's shape instead of only creating it.** It
  treats anything without a `pending` list as unbuilt, carries `paused` / `running`
  / `closed` across the upgrade (a gate closed before the first request is a gate
  that must *stay* closed), and every entry point — `pause`, `resume`, `request`,
  `pump`, `close` — reads the queue through it, so `#queue.pending` is safe
  everywhere in the module.
- **`OverlayQueue.close` leaves the queue at its placeholder values** rather than
  just draining `pending`, because `Window:Unload` clears the whole table
  immediately afterwards; a late entrance coroutine now finds an empty list
  instead of a missing one.
- **`Window:Show` returns early for an unloaded window.** Its guard covered only
  `animating`/`hidden`, so the deferred startup reveal (`library_entrypoint`) that
  is already in flight when a host unloads inside the reveal deadline reached
  `self.drag` on a torn-down window.
- New pin `Q8` in `scripts/overlay_queue_test.luau` walks the exact sequence:
  construct → hide → queue → unload, asserting the gate opens on the placeholder,
  invents no work, keeps a cancelled entrance's gate closed for anything queued
  afterwards, and never rebuilds an unloaded window.

## 2026-09-14 — Buttons show a built-in tap affordance

- Every `CreateButton` card now renders a themed 16px tap glyph on its right edge; compact rows place it as the trailing item.
- The glyph reveals and hides with the card, pulses on click, and preserves the existing callback and haptic behavior.
- `tapIcon = false` hides the glyph; `tapIcon = "name" | <assetId>` replaces it with a custom icon.

## 2026-09-14 — Startup arrives in stages: overlay entrance queue, staged window entrance

- **Everything used to land on one frame.** A host that built its UI and fired a
  notification per loaded module got all of them — plus the welcome toast, the
  optional-icon warning, the whole first page of controls and the window's own
  entrance — on the frame after construction went quiet. A 60-notification burst
  allocated **921 instances on a single frame** under the harness, and the window
  popped in with no entrance to speak of.
- **`components/overlayQueue.luau` (new) serialises the overlays.** `Window:Notify`
  and `Window:Toast` now enqueue: a card is *built* on its own turn rather than on
  the frame it was asked for, only one entrance is in flight at a time, and a
  cooldown separates two of them (shortened while a backlog waits, so a burst stays
  a cascade instead of becoming a slideshow). The same burst peaks at **82
  instances** in a frame. The waiting list is capped at six: past that, the oldest
  request that was never built is dropped, the same way `maxVisible` retires cards
  that are already on screen.
- **Cards report their own entrance.** `Notification.new`/`Toast.new` take the
  queue's `release` slot and hand it back through `_entranceDone` once their staged
  fades are committed — and the dismiss path reaches it too, so a card retired by
  the visibility cap, a click or an unload can never wedge the queue behind a tween
  that will not finish. Both classes can still be constructed directly; a card
  built without the queue behaves exactly as it did.
- **The window entrance is staged instead of instant.** `_firstShow` (and
  `_quickRestore`, on the shorter restore timing) animates the shell first — size,
  surface and corner through the motion service's `pop` spec, topbar copy, tags —
  and hands the page to the new `Window:_stageContentReveal`, which waits
  `contentRevealBeat` (0.22s, scaled by the "Animation speed" setting, skipped by
  the `instant` profile) and then reveals the controls through the same cascade
  opening a tab uses (`_revealElements`, one control per beat) instead of writing
  every card on the frame the entrance opens on. `_contentEntranceId` is the
  generation: a hide, a re-show or a layout switch between the two beats retires
  the half-finished sequence, and `_revealElements` now owns clearing
  `_elementsPending` for the page it walks.
- **Overlays follow the window, not the build.** The queue is gated closed at the
  end of `Window.new` and opened by the entrance's settle (or the staged reveal,
  whichever lands last), so anything requested while the script is still loading
  waits its turn behind the window. `Window:Hide` opens the gate when the auto-show
  was cancelled, `Window:Unload` closes the queue with the window, and both of the
  queue's waits are bounded (`gateBudget`, `entranceBudget`) so no path can park it.
- **One settle beat before the arrival** (`library_entrypoint.luau`): after the
  construction batches go quiet, the auto-show waits `STARTUP_SETTLE` (0.1s) so the
  tail of a host's script — config load, image preload, the first layout pass — does
  not share the frame the entrance opens on. The brand-font swap no longer fires
  whenever the font finishes loading either: a theme pass over every instance the
  window owns waits for the entrance to land (`FONT_SETTLE_BUDGET` bounds it).
- All queue pacing goes through `motion.step`, so **Settings → Performance →
  Motion** drives it: with animation switched off the cards still arrive one at a
  time, only with no cooldown between them.
- New suite `scripts/overlay_queue_test.{luau,sh}` pins Q1 the gate, Q2 one card
  per frame (per-frame allocation histogram, the way `startup_test` measures), Q3
  the bounded backlog, Q4 release-on-dismiss, Q5 unload, Q6 the motion-off drain
  and Q7 the staged page reveal. `scripts/profile_centering_test.luau`'s C2 pump
  went 0.35 → 0.5 to cover the settle beat, the same way it already covers the
  settings-page build. Full suite: 22 of 24 scripts green plus the bundle smoke
  test — the two failures (`collapsible_group_test`, `inline_description_test`) are
  pre-existing and still assert the `CreateSwitch` alias and the `description` prop
  that the API-removal entries today retired. Bundle regenerated
  (`version-1.luau`, 103 modules).

## 2026-09-14 — Collapsible Group children are visually recessed

- Elements rendered inside a Collapsible Group are now marked as nested content.
- Nested children use 75% card background transparency and fully hidden card strokes, including hover/reveal states and dropdown panels, so the group header remains the visible container boundary.
- Added default theme tokens for nested child transparency/strokes while preserving normal outlines for standalone elements.

## 2026-09-14 — Toggle-only API and element helper descriptions removed

- Removed the `CreateSwitch` alias from tabs, groups, typings, docs and the bundled build. Use `CreateToggle` for that control.
- Element constructors now ignore `description`/`Description` helper props, so buttons, toggles, sliders, dropdowns, inputs, keybinds, stats, progress cards, changelogs and collapsible groups render without the extra helper line.
- Updated the example and usage docs to show the simplified API.

## 2026-09-14 — Element descriptions render inside the cards again (no overlap)

- **`description` was a dead prop.** The settings refactor (`df2a3e9`, PR #28)
  dropped `elements/description.luau` and every element's use of it while the
  types, docs and changelog kept describing the in-card line — so the line
  never rendered and nothing reserved room for helper copy: a host that drew
  its own copy under an element had it land on top of that element's UI.
- **The line lives inside the element's own card.** `elements/description.luau`
  (restored) attaches a muted 14px `ContentColor` label under the title region —
  the Collapsible Group header recipe — and the card grows by the measured
  wrapped height (`lines * 17 + 3`; one line: 41 -> 61), so the copy can never
  cover the title row, the control or the card's edge.
- **Everything that shares the card follows the growth.** Title rows and
  controls stay centred in the base region they had before the card grew
  (`description.center`), bottom-anchored pieces ride up above the line
  (slider tracks in each layout mode via `description.rebase`, progress bar and
  readout, stat value/host), every height writer — hover tweens, layout
  switches, the dropdown's closed *and* open heights — goes through
  `description.height`, and the Collapsible Group header itself is 41px without
  a description and 61px with one.
- **The line is measured, not guessed.** The wrapped count comes from the
  shared text metrics (with a greedy word count where a host has none) and
  re-measures whenever the card's width changes or the text retypes, so a
  locale switch, a window resize or a long lock message rewraps and re-grows
  the card instead of spilling over the control.
- Restored the docs (`MODULES.md`, `USAGE.md`) and the example
  (`example.client.luau`: described controls on Home, Controls, Appearance,
  Information and a described Collapsible Group), and the
  `scripts/inline_description_test.{luau,sh}` suite: D1-D12 pin the recipe and
  assert that no described element's line intersects its title row, control
  surface, track, readout or card edge. Full suite: 22/22 plus the bundle
  smoke test green.

## 2026-09-14 — Default theme matches Rayfield Gen2; capsule bar follows theme

- **`themes/default.luau` rebuilt on Rayfield Gen2's default palette.** Shared
  keys (`WindowColor`, `ElementGradient`, `AccentColor`/`AccentStroke`,
  `SliderProgress`, toggle/field tokens, corner radii, greyscale surfaces,
  white titling/content) match Gen2's `src/themes/default.luau` 1:1 — teal
  accent `23,153,110` / stroke `32,201,144`, window gradient `10→25→35`,
  `CornerRoundness` 20px, `ElementCornerRadius` 12px, translucent white
  fields (`FieldTransparency = 0.9`). Astra-only semantic keys
  (`Background`, `WindowSurface`, text tiers, `Success`/`Warning`, etc.) are
  derived from the same greys + teal so the profile card and settings stay
  coherent. Named themes (`cobalt`, `frost`, …) are unchanged and still
  overlay the new default via `themes/init.luau`.
- **Capsule / minimised bar adapts the theme.** Collapse, minimise, first-show
  entrance and close now tween `windowCorner` to `PillCornerRadius` (Gen2's
  full pill by default) instead of a hard-coded `UDim.new(1, 0)`; expanding
  restores `CornerRoundness`. `ChangeTheme` while the capsule or minimised
  bar is up re-applies the live pill radius. The collapsed-face icon corner
  binds to `PillCornerRadius` in `components/chrome.luau`.
- **Named-theme inheritance guard:** Gen2 default's translucent off-knob
  (`ToggleKnobOffTransparency = 0.8`) and near-clear track would have leaked
  into partial themes that only set `ToggleKnobOff`. `amethyst`, `cobalt`,
  `ember`, and `rose` now pin solid-knob / track tokens like the full themes
  (`frost`, `emerald`, …). Fields were already safe (`FieldTransparency = 0`).
- Bundle regenerated (`version-1.luau`, 101 modules).

## 2026-09-14 — Grouped dropdowns scroll the tab page; settings integration debt cleared

- **Opening a Dropdown inside a Collapsible Group crashed on the engine.**
  Controls built by a group receive the group as their `tab` — that is what
  parents them into the group body — and `Dropdown:_bringIntoView` read
  `AbsoluteWindowSize` / `CanvasPosition` off whatever `tabPage` it found.
  Those are ScrollingFrame-only members and a group body is a plain Frame, so
  the first open of any grouped dropdown (the built-in Settings' *Theme* and
  *Saved Configurations* pickers among them) died with
  `AbsoluteWindowSize is not a valid member of Frame`. The open-time scroll now
  walks the owner chain (`group -> … -> Tab`) and scrolls the real tab page;
  nothing else about the open changed.
- **The stub environment now models the engine's member strictness.**
  `sidebar_sizing_stubs.luau` answered `AbsoluteWindowSize` (and the other
  scroll-only members) for *every* instance, which is exactly why the crash
  above never showed up in CI; indexing them on a non-ScrollingFrame now
  raises like Roblox does. The fake executor filesystem in
  `profile_image_stubs.luau` likewise lists what `writefile` created instead
  of always `{}`, so config listing behaves like a real session.
- **New pin `D8` in `scripts/dropdown_rows_test.sh`:** a dropdown inside a
  Collapsible Group expands and opens cleanly and its owner chain ends at the
  tab that owns the scroll page. It fails against the previous bundle.
- **Settings-refactor integration debt from `df2a3e9` cleared without
  reverting any of it:** the two suites that still scanned a settings tab's
  top-level elements only (`keybind_input_test`, `sidebar_tab_sizing_test`)
  now walk group children like the rest of the suite does; the collapsible
  group suite dropped its assertion for the `description` header line that
  the settings refactor retired library-wide (types, docs and example
  included); and the profile-centring suite's first-show pump now covers the
  frames the initial settings page legitimately costs to build under the
  startup batching. Full suite: 21/21 plus the bundle smoke test green.

## 2026-09-13 — Descriptions move inside the element cards

- **Descriptions rendered as a standalone row *below* the element card.** The
  old `descriptor` element sat under the card in the tab page (and search had
  to shuttle that second frame around). It is gone: every element with a
  `description` now renders it **inside its own card** — the Collapsible Group
  header recipe (a muted 14px `ContentColor` line under the title region).
- **The card grows by the measured line.** `elements/description.luau` counts
  wrapped lines with the shared text metrics and adds `lines * 17 + 3` px
  (one line: 41 -> 61), re-measuring whenever the card's width changes
  (layout mode, window resize, search page) or the text retypes. Title rows
  and controls keep centring in the base region, bottom-anchored tracks
  (slider narrow, progress) and labels (stat) ride up above the line, and the
  dropdown's closed and open heights both include it.
- **The line stays locale-bound and still carries the lock message** exactly
  as the old row did — `SetLocale` retypes it (and the card re-measures),
  and `Lock(message)` swaps it, restoring the description on unlock.
- Removed `elements/descriptor.luau`; search no longer moves descriptor rows.
  Test: `scripts/inline_description_test.sh`.

## 2026-09-13 — Keybind cap joins the element corner; slider knob stops overlapping the card

- **The Keybind element's key cap wore the same capsule as the Input field
  did.** It now binds its corner to `ElementCornerRadius` like the input box
  fixed earlier, so both field boxes read as smaller members of the card
  family and follow host themes that round elements differently.
- **The slider knob overlapped the card edge at the top of its range.** The
  capsule rode the fill's right edge (centre at `scale 1` of the progress
  bar), so at max its centre sat on the track's end and half of its 35px —
  41px while held — width hung past it, over the card's right inset, stroke
  and corner. The knob now rides the track with its centre clamped to
  `[halfWidth, travel - halfWidth]`, and the fill's right edge is exactly
  that centre, so the bar stays tucked under the capsule at every value.
  One number drives both: `_renderProgress` places fill size and knob
  position from the same clamped centre, re-seated on every track resize
  (first layout, narrow/wide mode switch, scale-sized track on window
  resize) and re-clamped for the wider held knob on press and release.
- Suites: `scripts/input_field_test.sh` gains the keybind cap pin; new
  `scripts/slider_travel_test.sh` pins the travel in anchor-independent
  track-local pixels — clamped at max, min and mid, fill ending at the
  knob's centre, and the clamp holding while held and after release. Both
  fail against the previous bundle (capsule scale on the cap, knob centre
  on the track end), so the pins have teeth.

## 2026-09-13 — Input field rounds with the element corner, not a capsule

- **The Input element's field box wore its own capsule.** The dark box the
  text sits in carried `UICorner = UDim.new(1, 0)` — a full pill, half the
  box's height — while every other surface in the library reads its
  roundness off a theme token: element cards (and the Text card among them)
  through `ElementCornerRadius`, notifications and toasts through
  `CornerRoundness`, tab rows through the layout's row radius. The field now
  binds its corner to `ElementCornerRadius` like the card it sits inside, so
  it reads as a smaller member of the same family, and a host theme that
  rounds elements tighter or softer moves the field with everything else.
- Suite: new `scripts/input_field_test.sh` pins the recipe — pixel radius
  equal to the theme token (never a capsule scale), re-stated on a theme
  switch, and shared with the element card's own corner. It fails against
  the previous bundle on the capsule scale, so the pin has teeth.

## 2026-09-13 — Console element removed

- **`Tab:CreateConsole` is gone.** The read-only log panel (line ring buffer,
  `follow` tailing, `Set`/`Append`/`Get`/`Clear`/`Copy`/`SetHeight`) earned its
  instance budget without pulling its weight as a built-in: hosts that want a
  log view can build one from a `Text`/`ScrollingFrame` of their own, and the
  element only added a fourteenth surface style to keep in step with every
  theme, layout and motion change. `elements/console.luau` is deleted and
  every wiring point goes with it: `Tab:CreateConsole`, the `Console` /
  `ConsoleProps` types and their entrypoint re-exports, the Collapsible Group
  constructor entry (its `type` union loses `"Console"` too), and the example
  script's three consoles plus the two Element Lab buttons that only wrote
  into one.
- **Nothing else changed shape.** Remaining element types keep their indices
  in every registry, so saved configurations, flags and search behaviour are
  untouched; the standalone bundle regenerates at 100 modules.
- Suites: `scripts/instance_budget_test.luau` drops the console ceiling and
  builder; `scripts/collapsible_group_test.luau` drops the console child and
  re-indexes the child assertions that follow it (the pinned expand height is
  force-set through `contentLayout.AbsoluteContentSize`, so it is unchanged).
  All suites run against the regenerated standalone bundle.

## 2026-09-13 — Profile card: no hover surface on copy buttons, tooltip text stacks above its box

- **Holding or pressing a profile-card copy button no longer pops a stray
  surface over the row.** The copy glyph carried its own hover tooltip
  ("Copy Place ID" / "Copy Job ID" / "Copy User ID", "Copied" while the
  check was up) on the same surface the rows' truncation hover-help uses, so
  every hover, hold and press raised a wide box over the card. The button's
  feedback is again just the glyph and its green-check flash; the button
  keeps its invisible accessible label (the same wording, resolved through
  the locale layer, `Window:SetLocale` included), so nothing is lost for
  screen readers or hosts that read the label back. The truncation
  hover-help for values, the display name and the game name stays the only
  tooltip on the card.
- **The tooltips that remain draw their text above their box instead of
  under it.** The window's ScreenGui stacks with `ZIndexBehavior.Global`, so
  the tooltip surface (`ZIndex = 10`) drew over its own label (default
  `ZIndex = 1`): in game every hover-help appeared as an empty rounded box
  with the text buried beneath the surface. The label now outranks its
  surface by one (11 over 10), which is what global stacking needs for a
  child to sit on top of its parent.
- Suites: `scripts/profile_ui_test.luau` G2 now pins the no-tooltip contract
  (hover, hold and press leave the surface hidden) while still covering the
  clipboard write, the check flash, the single restore timer and the
  locale-bound label; `scripts/profile_details_test.luau` E5 additionally
  pins the label outranking its surface under global z-index stacking. Both
  run against the regenerated standalone bundle.

## 2026-09-13 — Collapsible Group corners, Text-matched header, full-width children

- **The Collapsible Group header's corners rendered thinner and flatter than
  every other element.** The container carried `ClipsDescendants` while the
  stroked header card filled it edge to edge, so the outer half of the 1px
  `UIStroke` (Border mode straddles the edge) and the corner arcs were shaved
  off on all four sides. The container is now a plain non-clipping layout
  frame with the Text card's `UDim2.new(1, -20)` footprint, and clipping moved
  to a dedicated body frame that only masks the expanding content — the same
  arrangement the dropdown uses (its panel clips, its top card never sits in
  a tight clipper). The body frame gives the first and last child 1px of
  stroke breathing room top and bottom, so no stroke is ever cut.
- **The header now matches the Text element's card spec.** Title uses
  `TitlingColor` at 16px, the description line is the Text body's 14px at
  0.45 transparency, the icon-to-text gap is 6px, and the chevron sits on the
  20px right gutter; the 41/61 header heights are unchanged. The expanded
  height also drops its 7px of invisible bottom slack (`header + 14 +
  content` → `header + 7 + content`), so an open group ends exactly at its
  last child and follows the 7px tab rhythm on both sides.
- **Children inside a group no longer shrink a second inset.** The body used
  to match the container width while children sized themselves at
  `UDim2.new(1, -20)`, compounding the container's own `-20` — inner content
  rendered 20px narrower than standalone siblings. The body frame is now 20px
  wider than the container (transparent bleed; the container no longer clips),
  so children land at exactly header width, while Section/Divider keep their
  tab-relative `-40` inset and column Groups keep working as full-bleed
  wrappers. Hover highlight is scoped to the header only via an optional
  `_wireElementHover` target (existing single-argument callers are unchanged).
- Suite: `scripts/collapsible_group_test.luau` pins the new `+907` expanded
  height and asserts the no-clip container, the `+20` clipper, the element
  corner radius, the Text-parity metrics and the unchanged child width
  recipes. All suites run against the regenerated standalone bundle.

## 2026-09-13 — Collapsible Group header rejoins the element surface, editable keybinds survive a backspace

- **The Collapsible Group header drew as a near-black card that matched nothing
  else in the window.** Every element surface is built the same way: a plain
  white base frame that `StyleElementBody` covers with the theme's
  `ElementGradient`. The header instead bound its base to `ElementSurface`, and
  because a UIGradient multiplies the color underneath it, the header rendered
  as roughly `ElementSurface × ElementGradient` — about RGB(3, 4, 6) on the
  default theme — instead of the gradient itself. The header now uses the same
  white base and `ElementTransparency` binding as Toggle, Button, Keybind and
  friends, so it picks up the exact surface color, hover stroke and theme
  changes of every other element. The collapsible suite pins the recipe: white
  base plus the same `ElementGradient` instance a sibling Toggle carries.
- **Editing an editable keybind (the Settings toggle binding) rebinds on
  backspace instead of accepting your next key.** Clearing the field ran the
  normal capture commit, whose stop-recording step writes the display name
  back into the TextBox — `"None"` for a cleared binding — and that write
  re-entered the text parser, whose first-letter rule read the `N` of `"None"`
  as a freshly typed key and bound it. Backspacing a binding therefore bound
  it to N, and because the same stop-recording step releases focus, the letter
  you typed next went nowhere. Typed commits now go through a commit path that
  keeps the field focused and never rewrites the label, and the parser only
  runs for text typed while the field is focused, so no programmatic display
  write (`Set`, focus restore, stop-recording) can ever parse as input.
- **Editable keybind fields now behave like a one-letter capture field.**
  Focusing no longer blanks the field: the current key stays visible and
  selected, so the next typed letter replaces the binding and Backspace clears
  it while the field stays focused for the next key. Any change is cut to a
  single uppercased letter (paste included), non-letters are dropped rather
  than written back as a label, each committed letter is re-selected so the
  next key replaces it, and leaving the field restores the bound key's display
  — including `None` when the field was left empty. Capture mode (click, press
  any key, Backspace unbinds, Escape cancels) is unchanged.
- Suite: `scripts/keybind_input_test.luau` now drives the full tap → type →
  backspace → retype → reject → blur cycle against the Settings binding, and
  `scripts/collapsible_group_test.luau` asserts the header's surface recipe.
  Both run against the regenerated standalone bundle.

## 2026-09-13 — Optional Collapsible Groups, built-in config preferences, all-pack window icons

- Added `Tab:CreateCollapsibleGroup` with one-table child definitions for all tab
  element types, including ordinary Groups. Multiple groups are independent;
  nested Collapsible Groups (including indirect nesting) are rejected up front.
- Containers use native styling and measured, animated height across topbar,
  sidebar and collapsed-sidebar layouts. No expansion setting is required in
  usage. Closing/reopening preserves control values, flags and running keybinds.
- Search finds child controls and temporarily expands their container. Tab
  cleanup and keybind conflict detection now recurse through containers.
- Added Auto Save Config and Auto Load Config in Settings → Persistence. Both
  default on, and their preferences persist separately from control values.
  Normal window usage no longer needs configuration props. Legacy overrides
  remain accepted; save writes are coalesced and the final pending edit flushes
  on unload. Internal defaults are not shown in the named-preset UI.
- Removed window-wide icon-pack selection. Bare names now use all-pack lookup
  everywhere; `pack:name` still selects an exact icon. Added generated visual
  catalogs for all six packs under `assets/icons/README.md`.
- Updated public types, usage/example scripts and regression tests. Existing
  standalone controls remain available without Collapsible Group overhead.

## 2026-09-13 — Icon resolver: name-only lookup across every pack, qualified names, indexed custom assets

- **A bare icon name is searched in every built-in pack.** `Astra.Icons.get("home")`
  used to answer from lucide alone and returned nil when lucide did not have
  the name (lucide spells it `house`); it now walks a fixed priority order —
  lucide, material, tabler, phosphor, heroicons, feather — and the first pack
  that has the name wins, so `get`, `resolve` and `window:ResolveIcon` work
  without picking a pack. The search stays lazy: `get("house")` reads the
  lucide table and stops, and `Icons.loaded()` shows exactly which packs a
  session has read (the new suite asserts one lucide name loads one pack).
- **`"pack:name"` addresses one pack exactly**, for the cases where it has to
  be the pack you asked for: `Astra.Icons.get("material:home")`,
  `resolve("tabler:home")`, `window:ResolveIcon("lucide:house")`. Names and
  pack names stay case-sensitive — `Home`, `HOME` and `Lucide:house` resolve
  to nothing rather than to a corrected name or a neighbouring pack — and an
  unknown pack warns once, not once per lookup, instead of substituting.
- **An explicit pack is never overruled.** `resolve(name, pack)`, `get(name, pack)`
  and the window's own `ResolveIcon` answer from that pack or not at all,
  which is the behaviour the profile card's alias chain relies on (its tier
  pill keeps drawing the active pack's glyph); the cross-pack search is the
  no-pack form.
- **Custom assets are indexed, not probed.** `custom_asset/` is read once with
  `listfiles` and looked up by key (subfolders included), so a name with no
  file there costs nothing: a realistic 16-element page went from 110
  `getcustomasset` calls to 0 when the folder is absent and 1 when a file is
  used, and a used file is imported once per path. Executors without
  `listfiles` keep the historic extension probe (png, jpg, jpeg, webp, then
  the bare name) with hits *and* misses memoised; `Icons.refreshCustom()`
  re-reads the folder after files change at runtime.
- **Everything that worked before still works**: the optional `pack`
  argument, `getByPack`, `list`, `packs`, `count`, `isPack`, the
  `Icons.Lucide`… constants, direct pack tables (`Astra.Icons.lucide`),
  `resolve` passing asset ids / `rbx*://` / `http(s)://` through untouched,
  and the pre-existing fallback (an unresolved value comes back unchanged).
- Suite: `scripts/icons_test.sh` pins all of the above; `Types.luau` gains
  the new surface (`isPack`, `priority`, `loaded`, `refreshCustom`).

## 2026-09-13 — Opening the menu touches only the tab you are looking at

- **Tabs nobody has opened are no longer walked.** `_revealElements`,
  `_quickRestore` and `_firstShow` set every element of every tab on every
  show, so a 5-tab x 6-element window wrote 30 element visibility sets per
  open and 24 of them were for pages `UIPageLayout` is not rendering. A tab is
  now marked when its elements are actually hidden (it was the tab on screen
  when the window hid or the layout faded, or an element was registered while
  the window was hidden) and `Window:_showTabElements` runs when the player
  opens the tab (`tab:Select`) or when the search re-parents its elements onto
  its own page - the two moments they can be seen. Measured: **30 -> 6**
  visibility sets per show/hide cycle on a 5-tab window, with a dump of every
  element's visible state (every Transparency, every Visible flag and the page
  it hangs from) at ten points in the window's life byte-identical between the
  previous bundle and this one.
- **Dropdowns build the search bar with the rows.** The bar and its six
  children (corner, stroke, glow, click button, text box, icon = 7 instances)
  were built at construction even though the bar is only reachable once the
  list is open. A closed dropdown is now **25 instances** whether it has 2, 4,
  8 or 16 options.
- **Glows for states that cannot be on screen.** A toggle's indicator glow is
  only ever visible while the switch is on and an input's field glow only ever
  appears with a validation flash, but both were built with the element. Both
  are now built on first use (`toggle:_indicatorGlow`, `input:_fieldGlow`, the
  latter called by `Window:_flashResult`), so an off switch and a fresh field
  carry no shadow instance.
- **The viewport poll no longer rewrites the rail.** `_applyWindowSize` called
  `_applyRailWidth` before asking whether anything had changed, so the 2s poll
  wrote rail properties (and invalidated layout) for the whole session whether
  or not the window had moved. The write now sits behind the "did it change?"
  check. (Not asserted in the suite: the offline harness's `UDim2`/`Vector2`
  are plain tables, where `~=` is reference inequality, so the engine's value
  comparison that this early-out depends on cannot be reproduced off-engine.)
- **New suite.** `scripts/tab_elements_test.sh` (E1-E6) pins the tab rule: the
  first show walks the selected tab only; opening a tab shows its elements in
  the same frame and in the state the reveal left the selected tab in;
  hide/show does not walk the others; the search shows every tab it renders;
  an element created while the window is hidden shows with its tab; reopening
  a shown tab costs nothing. It fails on the previous bundle with `E1 the first
  show walks the selected tab, not all four (used 20)`. `toggle_switch_test.sh`
  grew `S7` (the glow follows the switch), `dropdown_rows_test.sh` (D1-D7) now
  also pins the search bar to the same first-open rule, and the budget suites
  tightened the dropdown ceiling 40 -> 28 and the page budget 305 -> 288.

## 2026-09-13 — Dropdown option rows are built on first open

- **A closed dropdown no longer carries its option rows.** Every option was
  materialised at construction — 8 instances each (row frame, corner, stroke,
  click button, title frame, layout, icon, label) — so a 16-option dropdown
  spent 128 instances on rows nobody could see while the list was shut off.
  `dropdown:_buildOptionAt/_materialiseOptions` now build the rows when the list
  is first opened, and the mutators follow the same rule: `Refresh`, `Add`,
  `Remove` and `Set` keep working while the rows do not exist (the option list
  is the only record), and the rows are built from it at the next open.
  Measured: a closed dropdown is a flat **25 instances** with 2, 4, 8 or 16
  options (it was 48 / 64 / 96 / 160), and opening one adds exactly the 8 rows
  per option plus the 7-instance search bar the old build created up front, so
  the open list is unchanged. The realistic 16-element page drops to **281
  instances** (was 322).
- **`_open` re-runs `_updateCorners`** after materialising, which is what the
  old build got from construction-time corner assignment; a dropdown that was
  never opened skips both.
- **Same-visual verification.** A dump of every instance and every property of
  the dropdown subtree at eleven points in its life — closed, opening, row
  hover, row click, list edited while closed, reopened, closed again,
  multi-select before/after a pick, and with a search filter applied — is
  byte-identical to the previous bundle everywhere the list is on screen. The
  two closed states are identical too once the subtrees that are only visible
  while the list is open (the rows and the search bar) are removed from the old
  dump: nothing else about them moved. The one other difference is the search
  bar and the list swapping places in `GetChildren()` — both carry explicit
  `LayoutOrder`s (1 and 3) under the panel's `UIListLayout`, so the order the
  UI lays them out in is unchanged.
- **New suite.** `scripts/dropdown_rows_test.sh` (D1–D7) pins: no rows and no
  search bar while closed, one row per option in order on open (plus the bar
  once), the rows' rendered state (selected vs unselected fills, label/glyph/
  stroke transparencies, the first/last corner tiers), reopening reusing the
  same rows, edits and selections made while closed landing on the rows built
  at open, picking a row still updating the value and the header, and the
  search bar still filtering the three rows it was built with. It fails on the
  previous bundle with `D1 a closed dropdown has no rows (got 2)`. The budget
  suite grew `B4` (a closed dropdown costs the same with 2 and 12 options) and
  tightened its dropdown ceiling 60 → 40 and its page budget 340 → 305
  (`B1 dropdown ... (used 56)` on the previous bundle).

## 2026-09-13 — ColorPicker removed, odometer readouts build rows on demand

- **`CreateColorPicker` is gone.** The element (`elements/colorpicker.luau`,
  1,115 lines, 47 instances each), its factory on `Tab`, its `ColorPickerProps`
  / `ColorPicker` types, its entry in the window-icon map and both
  `example.client.luau` usages were removed; the example's two spots now use a
  Slider. `USAGE.md` and `MODULES.md` no longer list it. Bundle: 1,565,836 →
  1,549,227 bytes, 101 → 100 modules.
- **The odometer builds readout rows on demand.** Each digit of a readout is a
  clipping cell holding a strip of rows; the strip was pre-filled with all
  `reelCells` (20) TextLabels, of which at most two can ever be inside the cell,
  so a single-digit Stat carried 22 instances per digit and a Stat with a change
  readout built **42 text labels for one value**. `odometer:_row/_rows` now
  materialise only the contiguous band a transition actually travels
  (`_reelSnap` one row, `_reelRoll` the from/to span), with the same row
  positions and glyphs, so the roll looks and lands exactly as before.
  Measured: Stat 59 → 21 instances, compact Stat 38 → 19, Slider 67 → 29 —
  **-58% on the three heaviest elements**, and -41% for a realistic 16-element
  page (550 → 322 instances).
- **New suites.** `scripts/odometer_test.sh` pins the lazy-row rule and the
  readout itself (the row the strip rests on must carry the value's digit,
  after a plain change, a wrap 9→1 and a roll down 1→9, with the decimal point,
  digits and suffix still rendered) — it fails on the previous bundle with
  `O1 ... (got 40)`. `scripts/instance_budget_test.sh` pins a ceiling per
  element plus an instance budget for the 16-element page (305 after the
  dropdown rows became lazy; it was 340), so decoration creep fails in the suite
  rather than in game; it fails on the previous bundle with
  `B1 statCompact ... (used 39)`.
- Both new suites honour `ASTRA_BUNDLE=<path>` to run against an older bundle,
  which is how the "fails before / passes after" check above was made.

## 2026-09-13 — Switch geometry: mirrored states, one set of metrics, sheen under the knob

- **The knob's clearance is now the same on every side it can see.** The switch
  was built from loose numbers: a 50px track, a 25x17 knob parked at
  `1, -47` / `1, -28`, and a 15px corner. Measured from the real build, "on"
  left 22px of empty track on the left against 3px on the right (and "off" the
  mirror of that), which is the lopsided gap the screenshot shows. The track
  and knob are now derived from one set of metrics — 44x22 track, 26x18 knob,
  a 2px inset at the parked end and the same 2px above and below — so both
  resting states are exact mirrors: `off.left == on.right == 2` and
  `on.left == off.right`. The narrower track also cuts the empty slab beside
  the knob from 22px to 14px, so neither state reads as a knob floating in an
  oversized pill.
- **The track's sheen no longer paints over the knob.** The theme's sheen
  overlay (`DarkToggleOverlay`) is created after the knob at the same ZIndex,
  so at equal ZIndex the later sibling drew it on top of the knob, washing its
  lower half (invisible in the screenshot's theme, obvious in the light ones).
  The sheen now declares ZIndex 1 and the knob ZIndex 2, so the sheen tints the
  track and only the track.
- **Both corner radii are pills.** The track and the overlay asked for a fixed
  15px radius, which only happened to match the old 21px height; both are
  `UDim.new(1, 0)` now, and the knob's travel is `track - knob - inset`, so a
  future size change cannot reintroduce an off-centre rim.
- **Verification:** new suite `scripts/toggle_switch_test.sh` (S1 one set of
  metrics with equal clearance, S2 mirrored states inside the track, S3 the
  empty side stays under half the track, S4 the sheen draws under the knob,
  S5 the animated positions match the built ones, S6 the compact row follows the
  track width). It fails against the previous bundle as expected:
  `S2 the parked knob sits off its end by the same 2px inset (got 3)`.
  Also new offline preview — `scripts/toggle_preview.sh` +
  `scripts/render_toggle_preview.py` dump and draw both states (with the track's
  body gradient and sheen) to `assets/toggle-preview-{off,on}.png`, and
  `assets/toggle-gap-fix.png` is the before/after sheet. Bundle regenerated;
  the other nine suites and both static checks stay green.

## 2026-09-13 — Motion service: one owner for animation timing, plus a live "Animation speed" setting

- **New `utilities/motion.luau`** — the library's animation timing now lives in
  one module. Named specs (`instant`, `fast`, `snappy`, `normal`, `smooth`,
  `emphasized`, `pop`, `exit`, `spring`, `spin`, `drift`) are `TweenInfo`
  values created once and handed out (`motion.spec`), so call sites stop
  building their own; `motion.step(base)` scales a cascade's pace, and the
  speed profiles (`relaxed` 1.35x, `normal`, `snappy` 0.7x, `instant` = no
  animation) drive the whole interface from one place.
- **`motion.tween(instance, props, spec, onCompleted)`** is the drop-in for
  `TweenService:Create(...):Play()`. It drops properties that already hold
  their target value (a fully-satisfied call creates no tween at all) and
  cancels an in-flight tween it would fight with — the same property, so
  unrelated animations are left alone. That is what removes the twin tweens a
  fast hover in/out used to leave interpolating the same stroke, and the
  sometimes-flickering result that came with them. `onCompleted` is connected
  before `Play()`, so a settle path can never miss a completion that lands on
  the same tick.
- **Window hot paths moved onto the service.** Element hover (every element,
  every pointer move), element reveal, the result flash, the callback-failure
  flash and the theme's ambient gradient drift now animate through
  `motion.tween`. Hover in/out on the same element is now one writer per
  property instead of two.
- **The entrance has a little pop.** The window's first show animates its size
  and corner on `motion.spec("pop")`: the same 0.38s it always took, with a
  small `Back/Out` overshoot so the frame springs the last pixels into place
  instead of easing into them.
- **New setting: Animation speed** (Performance → Motion; `motionSpeed`, one of
  `relaxed` / `normal` / `snappy` / `instant`, default `normal`). Relaxed and
  snappy rescale every transition the motion service owns, including the
  element reveal cascade; Instant switches animation off entirely — targets are
  applied on the spot and no tween is created, which is the reduced-motion and
  low-end-device option. The value round-trips through the settings JSON and is
  validated against `motion.profiles` both by the live validator and by the
  loader, so a hand-edited file cannot name a profile that does not exist.
  `Window:LoadSettings` re-applies it, and an unknown value falls back to
  `normal`.
- **`Astra.Motion` is public.** Hosts can animate with the library's own specs
  (`Astra.Motion.tween(frame, props, "snappy")`), cancel what the service owns
  (`cancel(instance)`), or steer everything (`setProfile`, `setTimeScale`,
  `setEnabled`). Typed in `Types.luau` as `MotionService`.
- **Drive-by fix:** `settings/manager.luau` never created `values` or
  `listeners`, so `Astra.Settings.newManager()` raised "attempt to index nil"
  on the first `:set`/`:get`/`:save` a host performed. Both are initialised
  now. (The new suite is what caught it.)
- **Verification:** new suite `scripts/motion_test.sh` (specs shared and
  cached, time scale rescaling + cache invalidation, profiles and rejection of
  unknown ones, cancel-on-overlap vs. unrelated properties, no-op calls,
  animation-off applying targets with no tween, the window setting reaching the
  service, and hover running through it). Every existing suite is unchanged and
  green: `smoke_test_bundle.sh`, `profile_{centering,compact,details,reveal,ui}_test.sh`,
  `sidebar_tab_sizing_test.sh` (its Performance-tab element count moved 2 → 4
  with the new section + dropdown) and `check_requires.py`. Measured on the
  stub harness against the previous bundle: 720 → 24 tween creations for
  redundant hover states, 432 overlapping hover tweens cancelled in a rapid
  in/out sweep that used to let them keep running, 161 cancelled across
  hide/show round trips. Bundle regenerated with `node scripts/generate_bundle.js`
  (101 modules); the equivalence check reports only the intended modules
  changed.
- Still on the old path (the natural next slice): `components/toast.luau`,
  `notification.luau`, `popup.luau`, `search.luau`, the window's own
  open/close/minimise/collapse transitions, and the element-level press and
  drag tweens in `elements/*.luau` keep their own `TweenInfo`/`TweenService`
  calls, so they do not yet answer to the speed setting (and are not yet
  covered by the cancel-on-overlap rule).

## 2026-09-13 — Profile card: window-backed surface, copy feedback, Job ID row, tier icon fix

- **The card's background is the window's background, not a lookalike.**
  `Window:StyleWindowSurface(frame)` now owns the window's own surface — base
  colour, the `WindowColor` theme token, gradient rotation/offset and the
  opacity the frame shows at — and both the window frame and the card's plate
  are built through it, so there is one definition instead of two copies that
  can drift. The card is the window's height and top-aligned with it, so the
  shared gradient also lands on the same shade at the same row: a theme change
  and the theme's live gradient animation (`LiveAnimation`) move the two
  together, and the plate now fades with the window on show/hide instead of
  sitting solid beside a half-faded frame. A card rebuilt mid-animation picks
  up the window's current gradient state.
- **Copy buttons confirm in words as well as in the icon.** The press still
  writes through the executor clipboard and swaps the glyph for the green
  `Success` check for ~1.2s; the button now also carries its own accessible
  label and hover tooltip — "Copy Place ID" / "Copy Job ID" / "Copy User ID"
  while idle, "Copied" while the check is up — both resolved through the locale
  layer. A repeat press cancels the pending restore and restarts the flash, so
  one button never has two timers racing for its icon.
- **The server row is labelled "Job ID".** The value is `DataModel.JobId`, so
  the row, its copy label and the tooltips say so; `window.profileServerIdValue`
  and the `ServerId` row name are unchanged for hosts and saved state.
- **The tier pill's icon renders in every icon pack.** The pill asked for
  lucide-only names, so FREEMIUM drew a word with a blank square beside it on
  every other pack and PREMIUM lost its crown on heroicons/feather/material. The
  card now resolves its icons against the window's active pack (crown, else
  star; badge-check, else check-badge / seal-check / verified, else award), and
  every other icon on the card resolves the same way. The default pack's icons
  are unchanged.
- Suites: the new `scripts/profile_ui_test.sh` pins all four (window-matched
  surface, copy feedback and its timer, the `Job ID` wording and the absence of
  "Server ID", and the tier icon on all six packs in both states).

## 2026-09-12 — Profile card: window-matched styling, real game name, tier pill, clipboard feedback

- **The card now speaks the window's visual language verbatim.** Section
  plates are built with `Window:StyleElementBody` — the same `ElementGradient`
  body, `ElementCornerRadius` and `ElementStroke` (at `ElementStrokeTransparency`)
  every window element uses — instead of flat `CardSurface` boxes with a faded
  hairline. Headings are the Section element's own look (16px `ContentColor`
  icon at 0.65 beside a 15px `ContentColor` title at 0.6, normal case:
  `Account`, `Current Game`, `Server`, `User Session`), rows reuse the element
  text colour (`ContentColor` icons/labels/values, labels muted at 0.45) and
  the `@username` line uses the window's secondary-text treatment
  (`TitlingColor` at 0.7). The game thumbnail's ring is the element stroke too.
- **The game name is the real one.** The card follows Roblox's official
  two-step flow — `apis.roblox.com/universes/v1/places/{PlaceId}/universe`
  converts the place id to its universe id, then
  `games.roblox.com/v1/games?universeIds={UniverseId}` supplies the `name`
  field — with per-place caching and in-flight queuing, so `DataModel.Name`
  (the current place's title) only fills the label until the platform
  answers. The same universe resolution (`DataModel.GameId` first, official
  lookup second) now feeds the thumbnail fetch.
- **Copy actions use the executor clipboard and confirm visually.** Every
  identifier row (User ID, Place ID, Server ID, Key) carries a COPY button
  that writes through `setclipboard` (with the common executor aliases and a
  `Clipboard` table as fallbacks); a successful copy swaps the icon to a
  green `Success` check for ~1.2s and then returns to the copy icon. Buttons
  stay hidden while their value is masked, and a missing/failing clipboard
  function means no feedback rather than a false success.
- **The tier pill is always present.** It reads the host's `tier` from
  `Window:SetProfile` (uppercased) or falls back to PREMIUM / FREEMIUM from
  `MembershipType`, so a free account is labelled instead of undecorated.
  PREMIUM keeps the accent crown; other tiers read muted with a
  `badge-check` icon, and the pill width re-measures itself from its word.
- **Removed from the card:** the settings gear and its `_toggleSettingsMode`
  action (the topbar gear is now the only settings entry point), the SERVER
  UPTIME row (`workspace.DistributedGameTime`), and the FRIENDS / FOLLOWERS
  rows together with their friends-endpoint fetch. The header's name and
  subtitle reclaim the width the gear used to reserve.
- **Verification:** `profile_details_test` now asserts the element-body
  plates (gradient/corner/stroke tokens), Section-style headings, the
  element row colours, the always-present tier pill (PREMIUM, FREEMIUM and a
  host override) and the clipboard flash cycle (E7/E8); `profile_compact_test`
  asserts the removed rows/gear are gone; `sidebar_tab_sizing_test` drops its
  gear expectation. The offline preview (`scripts/profile_panel_preview.sh`)
  re-renders both card states.

## 2026-09-12 — Compact profile card: exactly the window's height (240x420)

- **The profile card is now 240px wide x 420px high** — slimmer, and exactly
  the default window's height, so the window + 12px gap + card pair reads as
  one centred unit. No information was removed: the avatar, display name,
  username, PREMIUM badge, user ID + COPY, join date / account age, friends,
  followers, current game (icon, name, place ID) and the settings gear all
  remain. The interior is compacted instead — 12px horizontal padding (was
  16), a 56px avatar (was 72), tightened gaps between every row, a 48px game
  card (was 56, with a 32px thumbnail), reduced bottom spacing, and 13px
  value text so nothing wraps, overlaps or clips in the narrower card.
- **All dependent geometry follows the constants**: the room check
  (`hasRoom`), the pair clamp (`pairHalfSize`), the off-centre rest
  (`shiftFor` is now `(240 + 12) / 2 = 126px`), the side placement in
  `layout`, the recenter paths and the cramped-viewport notification
  (now "240px beside the window and 420px of height") — everything reads
  `profilePanel.width` / `profilePanel.height`, so the 240/12/420 dimensions
  apply to centring, screen bounds, visibility and the saved-settings
  normalisation alike.
- **Toggle behaviour is unchanged and re-verified**: "Show profile" shows
  the card on the selected side and centres the pair as one group, hiding it
  recentres the window alone; "Reveal profile details" is still refused
  while "Show profile" is off (setting off, switch rolled back, "Show
  profile is required" notification), and turning "Show profile" off — or
  loading a stale configuration — clears an active reveal and re-masks the
  display name, username, user ID and place ID.
- **Verification:** new runtime suite `scripts/profile_compact_test.sh`
  (+ `profile_compact_test.luau`, D1–D8) covers the exact 240x420
  dimensions, the preserved 12px gap, right- and left-side placement,
  field completeness, no clipping/overlap, the "Show profile" show/centre/
  hide/recentre cycle from a dragged position, the full reveal dependency
  (refusal + notification, auto-clear + remasking), stale saved
  configuration normalisation through `Window:LoadSettings`, and viewport
  changes (responsive window resize, card stays attached and centred,
  portrait viewports hide the card). `profile_centering_test` and
  `sidebar_tab_sizing_test` now assert the 240/420 geometry;
  `profile_reveal_test` and the smoke test are unchanged and still pass.

## 2026-09-12 — Window + profile card centre as one unit, and "Reveal profile details" now requires "Show profile"

- **The window and its profile card are auto-centred together, and both are
  kept in view.** The pair was already meant to rest centred (window + 12px
  gap + card, so the window sits 146px off the screen centre), but three
  paths showed it un-centred or let the card hang off the screen:
  - `_firstShow` showed the frame wherever the build had left it. A window
    built before `Players.LocalPlayer` exists is built with the card
    disabled, so it rests at the plain centre; when the player turns up
    before the deferred first show, the card appears and nothing re-centred
    it (the late-player waiter bails because the player is already there,
    and a recenter that runs while the window is hidden only parks
    `_restorePosition`). The first show now re-derives the resting centre
    while the frame is still at its anchored `0.5/0.5` spot.
  - `_quickRestore` fell back to `UDim2.new(0.5, 0, 0.5, 0)` and trusted a
    `_restorePosition` recorded before the panel state changed. An anchored
    restore is now re-derived from `_profileCenterPosition()`, and the
    restore re-clamps after `_fadeSurfaces` brings the card back.
  - "Keep window on screen" clamped the window alone, so a drag — or a
    capsule dragged into a corner and expanded — could leave the card off
    the edge while the window itself stayed legal. The clamp, and the topbar
    drag that shares its math, now measure the pair through the new
    `profilePanel.pairHalfSize(window, width?, height?)`: the card's side
    gains `280 + 12`px and the vertical half-extent becomes
    `max(windowHeight / 2, 250)`, because the 500px card out-talls a short
    window. `pairHalfSize` asks the new `profilePanel.isShown(window)`
    (enabled *and* the window visible), so a minimised capsule is not shoved
    around by a card that is not there, and `ToggleMinimise`'s expand
    re-clamps once the card is visible again.
  A position the user dragged to is still respected — the re-centring only
  fires while the frame is at its anchored resting spot — and
  **Reset Window Position** remains the explicit way back to the centre.
- **"Reveal profile details" is refused while "Show profile" is off.** The
  toggle unmasks the display name, username, user ID and place ID *on the
  card*, so with the card off it was an active switch over nothing, and it
  would silently unmask identity data the moment the card came back.
  `profilePanel.setReveal(window, enabled)` is now the single driver:
  flipping the toggle on without the card keeps `showFullUsername` off,
  re-masks the card, raises a **"Show profile is required"** notification
  explaining the dependency, and returns `false` so the settings row rolls
  its switch back (silently — the work is already done). The switch is only
  accepted once "Show profile" is on.
- **The dependency holds in both directions and across saves.** Turning
  "Show profile" off switches an active reveal off with it
  (`profilePanel.setEnabled` clears it, says why in a notification and
  returns `revealCleared` so the row rolls back), and `Window:LoadSettings`
  runs the new `profilePanel.syncReveal(window)` so a settings file written
  before this rule — or edited by hand — cannot come back with reveal = on
  and the card off. `profilePanel.revealAllowed(window)` is the predicate
  both paths share, and `settings/registry.luau` records the dependency on
  the `showFullUsername` definition. Both rows' descriptions in
  Settings → Appearance now state it.
- **Verification:** new runtime suite `scripts/profile_centering_test.sh`
  (+ `profile_centering_test.luau`, C1–C6) covers the pair's resting centre
  (both edges symmetric about the screen centre, card flush with the window
  and vertically centred on it), the late-player first show, hide/show round
  trips including a dragged position being left alone, the pair-aware clamp
  with the card on either side, the card-off fallback to the plain window
  clamp, and the expand re-clamp. `scripts/profile_reveal_test.luau` gains P7
  for the refused / accepted / cleared reveal dependency and its
  notifications. Each was checked against a deliberately broken build (the
  first-show recenter removed, the clamp reverted to the window's own
  halves, the expand re-clamp removed, `revealAllowed` stubbed to `true`) to
  confirm the assertions actually fail. `smoke_test_bundle.sh`,
  `sidebar_tab_sizing_test.sh`, `check_requires.py` and
  `check_instance_fields.py` all pass under the Luau CLI 0.738, and the
  bundle is regenerated (100 modules).

## 2026-09-12 — Profile card: fixed the card that never appeared + one reveal toggle for every identity field

- **Fixed: the profile card stayed invisible even with "Show profile" on.**
  A window built before `Players.LocalPlayer` exists parks a RenderStepped
  waiter that fills the card in and fades it up when the player turns up.
  That waiter died twice over: it was registered with
  `self:Connect(connection)` — `Window:Connect` takes a *signal* and calls
  `:Connect` on it, so passing an existing connection threw
  (`attempt to call missing method 'Connect' of table`) — and, inside the
  callback, `profilePanel.refreshName` called `sidebar.mask_username`,
  which does not exist (the helper is `sidebar.maskUsername`), throwing
  `attempt to call a nil value` on every frame before `setShown` ran. Both
  are gone: the connection is adopted into `self.connections` directly and
  the mask call is fixed.
- **Changed: "Reveal full username" is now "Reveal profile details" and
  drives all four identifying values on the card** — display name
  (headline), `@username` (subtitle), user ID (ACCOUNT DETAILS) and place
  ID (CURRENT GAME). Off masks everything: names through the existing
  `sidebar.maskUsername` (`Tes****`), the two IDs as a fixed-width
  `••••••` block so neither value nor length leaks. The persisted key
  stays `showFullUsername`, so saved settings keep working; only the label,
  the description and the registry wording changed.
- **New `profilePanel.applyIdentity(window)`** is the single writer for
  those fields (plus `profilePanel.revealEnabled(window)`), called at the
  end of `build`, by the toggle and by the late-player waiter.
  `refreshName` is kept as an alias and `setSubtitle` routes through it, so
  no public signature changed. New instance handles:
  `window.profileUserIdValue`, `window.profileCopyUserId`,
  `window.profilePlaceId`.
- **Fixed: the card used to show the display name unmasked.** `build` wrote
  `player.DisplayName` straight into the headline and nothing masked it
  unless the late-player waiter happened to run, while the user ID and
  place ID were baked in at full length regardless of the toggle. The
  headline is now created empty and filled by `applyIdentity`, so the first
  frame already respects the setting.
- **The user ID's COPY action follows the reveal state:** hidden while the
  ID is masked, and the callback refuses to copy a masked value (it reads
  `state.localPlayer` at click time rather than the player captured at
  build). An explicit `Window:SetProfile` subtitle is developer copy, not
  identity data, so the toggle leaves it alone; `SetProfile(nil)` restores
  the generated `@username` line.
- **"Show profile" now explains itself when the card cannot fit.** The card
  is gated on screen room (280px beside the window, 500px of height) as
  well as on the toggle, so a cramped viewport used to leave an active
  toggle and no card. `profilePanel.setEnabled` raises a notification with
  the reason when the player is known but `hasRoom` fails (a missing player
  is still handled silently by the late-player waiter).
- **Verification:** new runtime suite `scripts/profile_reveal_test.sh`
  (+ `profile_reveal_test.luau`) covers the masked default, the toggle
  revealing/re-masking all four fields, custom-subtitle precedence, the
  late-player regression (card appears once the player turns up) and the
  no-room notification. Ran green
  under a locally built Luau CLI 0.738 — the earlier entries could not run
  the runtime suites at all; `smoke_test_bundle.sh`,
  `sidebar_tab_sizing_test.sh` (T15 extended to the masked subtitle),
  `check_requires.py` and `check_instance_fields.py` all pass, and the
  bundle is regenerated (100 modules).

## 2026-09-12 — Profile panel: fixed card layout per the design mock

- **The panel is now a content-sized card (280x500) instead of a full-window-height
  strip.** It rests vertically centred beside the window, and its interior stacks
  top-to-bottom in one flow so nothing can overlap at any window size: 72px avatar
  with presence dot, centred display name, centred @username, centred PREMIUM
  badge, divider, ACCOUNT DETAILS (User ID with the COPY action on the value row,
  Join date with account age, Friends / Followers on their own rows), divider,
  CURRENT GAME card, and the bottom-pinned settings gear.
- **Four rendering bugs from the reverted layout are gone.** The card surface is
  actually visible now (it was created with `BackgroundTransparency = 1`, leaving
  the text floating over the 3D world); the name / subtitle no longer vertically
  centre into the details stack on tall windows; the PREMIUM badge no longer lands
  on the first divider; and the CURRENT GAME plate uses the dark `CardSurface`
  theme key instead of the light `ContentColor` text colour (the white box).
- **`hasRoom` now checks vertical room too** (the card's 500px height plus margins),
  and `layout` positions the fixed-size card centred on the window centre; the
  interior is static, so drags/resizes never reflow it.
- **Scope:** presentation only — no public API change; `setSubtitle`,
  `refreshName`, `setEnabled`, `setSide`, `setShown` keep their signatures.
- **Verification:** T15 in `scripts/sidebar_tab_sizing_test.luau` updated to the
  real geometry (280 wide / 12 gap / 500 tall, panel centred on the window centre);
  static require + instance-field checkers pass; bundle regenerated (100 modules).
  The runtime smoke/sizing suites need the Luau CLI, which this sandbox could not
  download (release-asset hosts are TLS-blocked), so they were not executed here.

## 2026-09-12 — Profile system: the profile panel beside the window

- **The profile now lives in a panel beside the window, not inside it.**
  New `components/profilePanel.luau` builds a 96px-wide companion card as a
  sibling of the window frame (same ScreenGui): 48px circular avatar
  (theme plate fallback + the existing `images.image.avatar` loading with a
  generation guard), 16px name (masked as before, or full via "Reveal full
  username"), optional 14px subtitle (`Window:SetProfile` keeps its
  signature), and a bottom-pinned settings gear that opens the settings
  screen (same behavior as the topbar gear, via a shared
  `Window:_toggleSettingsMode`). The panel wears the window's surface
  treatment (WindowColor gradient, corner roundness, SurfaceStroke stroke,
  ShadowColor shadow), has a subtle hover pill on the gear, and follows
  the window on drags/restores/resizes through Position/Size
  property-change signals — no per-frame loop.
- **The window recentres so the pair is even.** Window + 8px gap + panel are
  centred on screen as one unit: at rest the window sits 52px —
  (96+8)/2 — off the screen centre, on the opposite side of the panel, so
  neither side looks cramped. Applied on first show, by "Reset Window
  Position", and live (animated) when the panel is toggled or re-sided;
  while the window is hidden the remembered restore position is updated
  instead so the next restore lands centred.
- **New "Profile side" option (Right / Left)** in the Appearance settings,
  persisted with the existing `showProfile` / `showFullUsername` settings
  (`settings.profileSide`, default `"right"`).
- **The in-window profile variants are retired** (sidebar footer, topbar
  strip, collapsed avatar-only). The responsive rail no longer reserves its
  60px profile footer (tabs get that space back), the topbar loses its 48px
  profile strip, and the old `reflowProfile` mis-detection on
  content-sized rails disappears with the code.
- **Scope:** profile placement/presentation only — no new public API, no
  animation-system changes. The panel hides whenever the screen lacks
  horizontal room for window + gap + panel (e.g. a portrait phone) and
  shows again when there is room (wide phones in landscape included); it
  hides with hide/minimise/close.
- **Verification:** the sizing suite's new T15 section asserts the panel
  geometry (sibling of the frame, ±52px window shift, flush panel edge,
  full window height), name masking, `SetProfile` subtitle, rail footer
  release, live recentering on side flips and show/hide toggles, and the
  room-based visibility (portrait phone hidden, wide landscape phone
  shown + recentred, desktop restored). A behavior probe covers the gear
  → settings round trip, hide/restore, and minimise/restore. The harness
  stubs gained Roblox-faithful name-based child indexing and default
  instance Names. Bundle regenerated (100 modules).

## 2026-09-12 — Faster window startup: lazy settings content + deferred auto-show

- **Settings tab content is now built lazily.** `CreateWindow` previously
  built all six settings tabs *and* every one of their elements
  synchronously (~600 of the ~760 instances created at window
  construction, in the example layout). Window construction now creates
  only the tab shells (rows + pages); each tab's elements are created the
  first time that tab is opened (`Tab:Select` →
  `Window:_buildSettingsContent`, exactly once per tab, pcalled so one bad
  element can't take the window down). The visible behavior is
  unchanged — content exists the instant a settings tab is opened — but
  synchronous startup instance creation drops from 764 to 169 in the
  harness (the user's own tabs are unaffected).
- **The auto-show is deferred by one tick.** `CreateWindow` showed the
  window before the calling script could create its tabs, so the window
  appeared empty and then filled in. The show now happens in a
  `task.defer`: a script that builds its tabs synchronously finishes
  first, so the window appears once, fully populated. Scripts that yield
  are unaffected (the show lands one tick after creation), and an
  explicit `Hide()` before the tick cancels the auto-show.
- **Scope:** startup timing only — no visual, animation, or API changes
  (the opening animation and staggered element reveal are untouched).
  Icon/font preloading was already async and disk-cached, so first-run
  icon downloads were left alone.
- **Verification:** the sizing test now asserts lazy settings content
  (empty before first open, built on first open, built exactly once, full
  element counts per tab on the correct page) alongside the existing
  assertions; the harness measures 169 instances at `CreateWindow`
  (was 764). Bundle regenerated (99 modules).

## 2026-09-12 — Settings screen: rail order and empty Persistence tab

- **Opening Settings now highlights the first rail row.** The rail rows
  (and the content pages) are ordered by each tab's `customOrder`, but
  the About tab was created with `customOrder = 1000` — lower than
  General's `1001` — so About sorted to the top and the gear action
  (which always opens General) highlighted the **second** row. About now
  uses `1006`, after Persistence, so the rail reads General, Appearance,
  Behavior, Performance, Persistence, About.
- **The Persistence tab is no longer empty.** Its content (Configurations
  section, Saved Configurations dropdown, name input, Save/Load/Delete
  group) was gated behind `next(self.configuration) ~= nil`, which is only
  true when the window is created with a `configuration`
  prop (autoSave/autoLoad/fileName). Windows created without it — including
  the example client — got a blank tab. The content is now built like every
  other settings tab; config save/load already works without the prop
  (paths fall back to the window name), and the dropdown shows its
  "No saved configurations" placeholder when there is nothing saved.
- **Verification:** `scripts/sidebar_tab_sizing_test.sh` now asserts the
  settings rail order (General first, About last), that opening settings
  via the gear path selects General and shows General's page in the
  content area, and that the Persistence tab builds its content for a
  window created without a `configuration` prop. The test fails against
  the pre-change tree. Bundle regenerated (99 modules).

## 2026-09-12 — Responsive sidebar rail follows the longest tab name

- **The responsive sidebar (`Sidebar (Responsive)` bar layout) now sizes its
  rail from the tab names.** The longest visible row in the current rail
  group (tabs or settings tabs, whichever mode the rail shows) determines the
  group's natural width via the existing `functions.textWidth` measurement of
  the row title (icon + spacing + paddings + row insets included). The rail
  itself takes that width, and the rows keep their original full-rail,
  side-aligned size (`scale 1, offset -rowInset*2`) — so every tab in the
  rail is exactly as wide as the longest one, with no floating/centered rows.
- **The window's available space is the cap, not a constant.** Rail width is
  `min(longest natural width, floor(window width / 2))` — no new fixed pixel
  value, and the elements area always keeps at least half of the window.
  The existing `Sidebar.ApplyWidth` already gives the elements area
  `(1, -railWidth, ...)`, so it automatically takes back whatever space the
  rail frees. When a very long name would exceed the cap, the rows hold the
  available width and that title label is constrained to the remaining slot,
  where its existing `TextWrapped` keeps the name readable.
- **Narrow windows are unchanged:** below `railCollapseBelow` the rail still
  collapses to the icon-only width (`railCollapsedWidth`), and the rail is
  considered collapsed only while it is at that icon-only width (a
  content-sized rail below the old fixed 219px still shows titles).
- **The width is re-derived whenever the visible rail group or its inputs
  change:** tab create/remove, layout-mode switch, settings-mode toggle,
  viewport/rail width changes, locale changes (translated titles measure
  differently) and theme changes (title font).
- **Scope:** only the responsive sidebar path (`Window:_railWidth` /
  `Window:_applyContentRailWidth` in `components/window.luau`,
  `tabSelector.railContentWidth` + label wrap in
  `components/tabSelector.luau`, the collapsed check in
  `components/sidebar.luau`, and a re-derive hook in
  `elements/tab.luau`). The topbar layout's per-pill `AutomaticSize.X`
  sizing, the collapsed sidebar's fixed icon-only rail, all tab styles,
  animations, selection and scrolling behavior are untouched.
  `setRowCollapsed` additionally skips rows whose rail was already destroyed
  mid-layout-switch (a destroyed instance must not have properties written
  to it).
- **Verification:** new `scripts/sidebar_tab_sizing_test.sh` (Luau CLI
  harness with a mini Roblox environment, `sidebar_sizing_stubs.luau`)
  exercises the real bundle: identical short names, short/long mixes, one
  very long name (cap + wrapped title + elements keep half the window),
  multiple long names, narrow/wide window (collapse/expand round-trip),
  settings-mode rail, icon-less and `neglectSelector` tabs, locale changes,
  and confirms the topbar and collapsed-sidebar layouts keep their existing
  sizing. The test fails against the pre-change tree (negative control).
  Bundle regenerated (99 modules).

## 2026-09-11 — Window sizing: 600x420 default, fixed mobile profile

- **Default window size is now `600x420`** (was `720x600`) in both bar-layout
  profiles (`top`, `sidebar`) in `utilities/windowSizing.luau`. The responsive
  caps were rebalanced around the new default (`maxSize` 720x480 top /
  760x500 sidebar, `widthCompensation` 100 → 80); the minimum protections are
  unchanged (500x330 top, 540x360 sidebar). No other 720x600 default remains.
- **Desktop/PC stays responsive:** `windowSizing.fit` keeps the existing
  tiered viewport-occupancy fit, so a normal desktop targets exactly 600x420,
  smaller/shorter screens shrink responsively (width compensation kicks in on
  short viewports), and large/ultrawide screens stay capped instead of growing
  into an oversized window. The viewport watcher, `_applyWindowSize`,
  dragging/collapsing and the public API in `components/window.luau` are
  unchanged (comments only).
- **Mobile now uses a fixed size/profile:** touch-only devices (phones —
  `TouchEnabled` with no hardware keyboard) whose short side is below Astra's
  existing 700px phone breakpoint get a per-mode fixed profile instead of live
  occupancy math: `316x318` (top) / `331x280` (sidebar), derived from the
  existing phone-tier fit evaluated once at a 360x390 reference (narrowest
  mainstream phone width × the reference short side `scaleForViewport`
  documents), so the fixed window fits a phone in portrait and landscape
  without clipping. Rotation, the on-screen keyboard and inset changes no
  longer resize the window; tablets, desktops and narrow desktop viewports
  keep the responsive fit.
- **New helper:** `windowSizing.isMobileViewport(viewport)`. `UIScale`
  (`scaleForViewport`) is unchanged and still applied on both paths, so the
  fixed mobile window keeps its per-device perceived scale. Bundle
  regenerated (99 modules).

## 2026-09-11 — New themes (emerald, gold, crimson, onyx) + frost redesign

- **Four new built-in themes:** `emerald` (dark forest, green accent),
  `gold` (dark bronze, gold accent), `crimson` (dark maroon, red accent),
  `onyx` (near-black, monochrome silver accent). Each defines the full
  65-key surface (surfaces, strokes, text, gradients, slider/toggle/field
  styling); omitted keys inherit from the `default` clone in
  `themes/init.luau`.
- **`frost` redesigned (kept, not removed):** was a near-white light theme
  (WindowSurface 250,252,253) — too bright. Rebuilt as a dark "arctic night"
  palette: deep navy surfaces (16,21,28), bright ice-blue accent
  (86,197,235), ice tab-stroke gradient. Same key set, same theme name, so
  persisted `theme = "frost"` picks up the new look automatically.
- Theme registration updated in both places: the settings-UI theme table +
  dropdown options in `components/window.luau` (now 10 entries) and the
  persisted-theme whitelist in `utilities/persistenceSettings.luau`.
- All other themes (`default`, `amethyst`, `cobalt`, `ember`, `rose`)
  unchanged. Bundle regenerated (99 modules).

## 2026-09-11 — Changelog element, settings rebuild, multi-tab example (`d1339ec`)

- **New element — `Tab:CreateChangelog`:** scrollable release history with
  `+` (added) / `-` (removed) / `~` (changed) symbols in green/red/amber,
  entry fade-in, and `Set` / `Refresh` / `Add(entry, prepend?)` / `Clear`.
  Types added: `ChangelogEntry`, `ChangelogChange`, `ChangelogProps`,
  `Changelog`.
- **Built-in settings rebuilt:** the v1.1 settings card +
  `Window:AddSettingsTab` sub-tab API is retired. The window now builds six
  settings tabs (`Window:_buildSettingsUI`): **General** (keybind, cursor,
  welcome toast), **Appearance** (theme + Bar Layout pickers with popup
  confirm, profile, window position), **Behavior** (duplicate-window guard),
  **Performance** (haptics), **Persistence** (saved-config Save/Load/Delete,
  only when `configuration` is passed), **About**. The topbar gear action
  toggles a settings mode that shows only settings tabs; the `activeSubTab`
  registry key is retained and still persisted for compatibility.
- **`layouts/` folder:** per-mode bar-layout builders (`Topbar`, `Sidebar`,
  `SidebarCollapsed`) extracted from the window; `utilities/layouts.luau`
  dispatches (`get` / `implementation` / `railWidthFor`).
- **`CreateWindow` props extended:** `showName`, `showIcon`,
  `showIconOnly` (minimised capsule), `fallbackFont`, `translator`
  (PascalCase aliases accepted); element props gained `description` and
  `icon` across the board; `Progress` gained `steps` / `text` / `format` /
  `showValue` / `indeterminate` props and `Get` / `GetPercentage` /
  `Remove`; `Toast` gained `subtitleAbove` / `avatar` / `minWidth`;
  `Popup` gained `subtitle` / `icon` / `dismissable`; `Console` gained
  `Copy`; `Tag` gained `Set` / `SetColor` / `SetText` / `SetIcon` /
  `Remove`.
- **New window runtime helpers:** `Close()` (animated close → `Unload`,
  wired to the topbar Close action with a confirm popup), `Create`
  (instance factory with theme/locale binding), `Connect` / `ConnectFor` /
  `Disconnect` / `DisconnectMany`, `DestroySubtree` / `DestroySubtrees`,
  `CreateGlow`, `CreateHoverOverlay`, `StyleElementBody` /
  `StyleElementPanel`, `SaveSettings` / `LoadSettings`, `SetProfile`.
- **Entrypoint:** active-window / anti-duplicate guard now also backed by a
  `getgenv()`-backed global store (`__ASTRA_ACTIVE_WINDOW_V1`); in secure
  mode `CreateWindow` preloads window images (failure notification) and
  swaps in the brand fonts.
- **Icon resolution:** pack entries are repo-relative PNG paths under
  `assets/icons/<pack>-pack/`; `icons/init.luau` maps them onto the repo's
  raw-GitHub base URL at resolve time, honours an executor
  `getcustomasset` override, and passes numeric asset ids through.
- **Persistence facade:** new `utilities/persistence.luau` consolidates the
  config + settings persistence surface.
- **Example rewritten:** `example.client.luau` loads the bundle via
  `game:HttpGet` + `loadstring` and builds a 20-tab window (Home, Controls,
  Appearance, Information, Changelog, Updates + 15 labelled test tabs)
  exercising tags, every element, groups, and the new Changelog element.
- Bundle regenerated from the modular tree (includes `layouts/` and
  `elements/changelog.luau`).

## 2026-09-06 — Settings card ColorSequence crash fix (`2ecd628`)

Opening the Settings tab crashed the window:
`Unable to assign property BackgroundColor3. Color3 expected, got ColorSequence`.

- **Cause:** `_buildSettingsCard` in `components/window.luau` themed the card
  with `BackgroundColor3 = "WindowColor"` — but `WindowColor` is a
  `ColorSequence` (a gradient), and `BackgroundColor3` only accepts a `Color3`.
- **Fix:** new `CardSurface` theme key (`Color3`) added to all six built-in
  themes (`default`, `amethyst`, `cobalt`, `ember`, `frost`, `rose`), matching
  each theme's element base color. The card now uses
  `BackgroundColor3 = "CardSurface"`. Custom theme tables inherit the key from
  `default` via `themes/init.luau`'s clone.
- Bundle regenerated and `luau-compile` verified on all changed files.

## 2026-09-06 — Luau minification (`7fa2d09`)

All 93 modular `.luau` sources + regenerated bundle minified:

- Stripped all comments and collapsed whitespace.
- Renamed locals safely inside function bodies (AST-driven, public API names,
  Roblox property keys, and icon-name strings untouched).
- Icon packs: data-only, no renames.
- `version-1.luau`: regenerated from minified sources (1,974,324 → 1,912,889
  bytes; the remaining comment lines are the Wax generator's own preamble and
  the required `WAX BUNDLED DATA BELOW` marker).
- Total: 93 files changed, −124 KB. Verified with `luau-compile`,
  `scripts/check_requires.py`, `scripts/check_instance_fields.py`.
- Minification tooling lives in `tools/minify/` (not bundled).

## 2026-09-05 — v1.1 patch set (`e779bed`)

Four bug fixes + one feature, public API unchanged:

- **Fix 1 — profile avatar not rendering:** `setProfileShown` no longer
  early-returns on `profile.Visible` (uses the `shown` argument), skips nil
  targets, and falls back to a themed plate circle when the avatar URI never
  resolves (tracked in the weak-keyed `avatarReady` side table). Empty avatar
  callback assigns a transparent placeholder instead of a broken image.
  Defensive `localPlayer` late-resolution hook in `Window.new` (2s-capped
  RenderStepped poll).
- **Fix 2 — profile layout unification:** top-mode profile is right-anchored
  in the topbar; `profileSubtitle` created in all three layout branches;
  `reflowProfile`/`applyWidth` handle the unified structure.
- **Fix 3 — settings card + rail race:** new `SettingsCard` overlay
  (`Window:_buildSettingsCard`, element-styled via `StyleElementBody`); rail
  visibility restored independently of `elements.Visible` so it can't get
  stuck hidden.
- **Fix 4 — settings sub-tabs:** new public `Window:AddSettingsTab({ name,
  icon })` builds compact sub-tabs inside the settings card; content delegates
  to the normal element registration/persistence pipeline; `activeSubTab` is
  persisted (registry, defaults, appearance validation, JSON persistence).
- **Fix 5 (SettingsManager wiring) intentionally deferred.**

See `ARCHITECTURE.md` for the full pre-v1.1 modular-refactor history.
