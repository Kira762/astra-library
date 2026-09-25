# Layout & geometry — placement, corners, and track math

## Placement invariant

Locking must be an **overlay**, not a layout change.

When `Window:SetElementLockMode` flips an element between `Mode 1` and `Mode 5`, the element's own `main` must not move or resize:

```
before = { Position = element.main.Position, Size = element.main.Size, Parent = element.main.Parent }
window:SetElementLockMode(5)
after  = { Position = element.main.Position, Size = element.main.Size, Parent = element.main.Parent }
assert(before.Position == after.Position and before.Size == after.Size and before.Parent == after.Parent)
```

Same for `headerCorner` metrics on header-based containers.

**Lock surfaces must be layout-free.** The scrim is a GuiObject child of `element.lockSurface or element.main`, and any GuiObject child of a `UIListLayout` (or `UIGridLayout` / `UITableLayout` / `UIPageLayout`) host **joins that layout as an item**. A flow layout directly on the lock surface would therefore adopt the scrim the moment the element locks and shove the surface's own content around — the compact-row regression, where the icon/label squeezed into half the pill and clipped past the row edge at Modes 3–5. Rules:

- A lock surface (`lockSurface` or `main`) never hosts a flow layout. Layout-managed surfaces keep their flow on an **inner full-size content frame** (`Window:_buildCompactRow`'s `Content` frame), and the scrim stacks absolutely beside it.
- `Window:_buildLockScrim` warns at lock time if a surface violates this; `scripts/guard_invariants_test.luau` (section D) asserts every lockable's scrim parents to a layout-free surface, and section D2 pins the compact-row shape (content frame hosts the flow, row hosts the scrim) across Mode 5.

The guard (`scripts/guard_invariants_test.luau`) snapshots `Position/Size/Parent` for **16 elements** — Button, Toggle, Slider, Input, Dropdown, Keybind, Link, ModePicker, AboutCard, CollapsibleGroup, Isolated, Stat, Text, Divider, Section, Footer — and asserts equality across `SetElementLockMode(1)` ↔ `SetElementLockMode(5)`. Lockables also assert the scrim exists as an overlay:

```
element.lockScrim.Visible == true at Mode 5 (after snap)
element.lockScrim.ZIndex == 60  (constants.zIndex.elementLock)
element.lockScrim.Parent == element.lockSurface or element.main
element.main.Visible == true    (never hidden by lock)
```

For `AboutCard` with `AutomaticSize.Y` (`Size.Y.Offset == 0`), the `Size > 0` check is wrong — compare snapshots instead.

Why it matters: every element is a card in a scrolling list. Moving one card on a mode change reflows siblings.

## Corner sync — header-based containers

`CollapsibleGroup` and `Isolated` are two-surface cards. The **header band** carries the top corners; the body clipper carries the bottom. The constants are in each element:

```lua
local bandCorners = {
  expanded  = { "TopLeftRadius", "TopRightRadius" },                                -- top only: bottom is divider
  collapsed = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" }, -- whole card
}
```

`Window:_setRoundedCorners(corner, corners, "ElementCornerRadius")` sets radii to `8` for listed corners and `0` for the rest. The header's `UICorner` (`headerCorner`) and the lock scrim's `UICorner` (`lockScrimCorner`) must carry **the same set**:

```
_expanded == true  → header 8,0 and scrim 8,0
_expanded == false → header 8,8 and scrim 8,8
```

Without the mirror, a locked, expanded header showed rounded bottom arcs over a straight `divider` line.

Isolated's body accepts only `Changelog` children, but its header/corner contract is identical to CollapsibleGroup's.

Verify with:

```sh
sh scripts/guard_invariants_test.sh   # asserts per-corner TopLeftRadius/TopRightRadius/BottomLeftRadius/BottomRightRadius offsets 8 vs 0
```

## Track / knob / fill geometry — slider & mode picker

One metric set (from `elements/modePicker.luau` / `elements/slider.luau`), shared between toggle and picker so they read as the same switch with more stops:

```
trackHeight = 22, trackRadius = 11
knobWidth = 26, knobHeight = 18, knobRadius = 9
dotSize = 4
knobGap = 2        -- toggle's switchInset; clearance all round
stopInset = knobWidth/2 + knobGap = 15  -- end stops keep knob inside track caps
sidePad = 14
```

Rules:

- **Inset.** Every stop is inset by `stopInset` (half the knob plus the gap). The first and last dots sit at the knob's centres; the knob and track caps are concentric at both ends.
- **Fill is the knob's pill.** `fill.Size = UDim2.new(fraction, stopInset - fraction*stopInset*2 + knobWidth/2 - knobGap, 0, knobHeight)` — same height/radius/inset as the knob, running from first stop to the knob's *trailing edge*. No resize handler needed; the same scale/offset pair is shared by dots and knob.
- **No bleed.** Fill never renders taller than the knob, wider radius, or beyond the knob at the ends — so accent does not show above/below or around corners, and the last stop fills end-to-end instead of leaving a 13px tail.

Verified in both element and guard:

```sh
sh scripts/mode_picker_test.sh       # M10: knob clearance at ends + above/below, fill height/radius/inset, trailing edge, end-dot centres
sh scripts/slider_travel_test.sh     # slider knob travel and value reach the ends
```

## When to touch this

Any change to `components/window/constants.luau` (`ElementCornerRadius`, `zIndex.elementLock`), `components/window/theme.luau:_setRoundedCorners`, `components/window/elements.luau:_buildLockScrim` / `_setElementLocked`, `components/window/tabs.luau:_buildCompactRow` (the content frame that keeps lock surfaces layout-free), `elements/collapsibleGroup.luau` / `isolated.luau` header band, or `elements/modePicker.luau` / `slider.luau` track metrics must be followed by:

```sh
node scripts/generate_bundle.js
sh scripts/guard_invariants_test.sh
sh scripts/mode_picker_test.sh
sh scripts/collapsible_group_test.sh
```
