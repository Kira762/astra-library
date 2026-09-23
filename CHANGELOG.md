# Changelog

## 2026-09-23 — Link copy taps hold still, and four Link bugs closed

A tap on a Link card's copy control still moved the card. Restoring the canvas
on release (the previous fix) left the page scrolling *during* the press — the
user watched the card slide down the page and spring back, which no other
element in the library does on a tap. The gesture is now pinned instead: the
canvas is snapshotted when the press begins, a watcher writes that snapshot
back for as long as the press is down, and the page is therefore never seen to
move at all. Release drops the watcher, and the gesture is ended from the
input service as well as the control, so a release the bridge swallows cannot
leave the page pinned for the rest of the session.

Running the suite under the Luau CLI also turned up a bug no static read could
see: **a Link card built with a `description` prop could not be built at all.**
`elements/description.luau` stores its base height on the element as
`_baseHeight`, and the Link card owns a `_baseHeight()` *method* — so
`description.attach` replaced the method with a number and the very next line
(`description.center(self, self:_baseHeight())`) died with "attempt to call a
number value". The module's field is now `_descriptionBase`.

- **`elements/link.luau`**
  - `_pinPressToCanvas` holds the canvas still for the length of the gesture
    (snapshot + watcher) instead of restoring it on release; the gesture ends
    on the control's release, on a press-less click, on
    `UserInputService.InputEnded`, and on `WindowFocusReleased`; the pinned
    surface is the nearest `ScrollingFrame` above the control, so a card
    inside a Group pins the tab page rather than asking the group's own frame
    for a canvas — asking a frame for its `CanvasPosition` is an error, not a
    zero, so a press on a grouped card used to throw "CanvasPosition is not a
    valid member of Frame".
  - `_applyPresence` re-seats the description line against the new base
    (`description.rebase`) when the subtitle comes or goes: the card shrinks
    56 → 43 and the line used to stay 13px too low, overlapping the text
    column or running past the card's bottom edge.
  - `_copy` refuses an empty link (no clipboard write, no check mark, no
    callback, a notification that says why) — `link` defaults to `""`, and a
    card built without the prop used to report a silent success.
  - `_copy` reads the writer's return value as well as the `pcall`: some hosts
    spell a failed write as `false`.
  - `haptic.click()` moved after the clipboard has actually taken the link, so
    a failed tap no longer feels like a hit.
  - The confirm timer checks the card is still in a live tree before it
    resets, so a hold ends with the tab its card belonged to instead of
    running two seconds against a destroyed glyph.
  - `_setShown(true)` puts a revealed card back on the copy glyph, closing the
    one path no hide covered: a programmatic `Copy()` on a card nothing was
    looking at.
  - `_minWidth` measures the compact row that actually renders (row padding,
    icon slot, gaps, copy target) instead of hard-coded stand-ins 8px short —
    `group:_wrapChild` freezes a wrapped row at exactly this width, so an
    under-measure clipped the row's own contents.
  - The warn-once flag is module scope, not per card: ten link cards in a
    clipboard-less host log one warning, not ten.
  - `getfenv` is looked up inside a `pcall`, so a sandbox that ships a throwing
    one answers the tap instead of erroring out of it.
  - `checkCandidates` runs deeper, so a pack carrying `copy` but no `check`
    still gives a successful copy its feedback.
- **`elements/description.luau`** — the base height rides on `_descriptionBase`
  rather than `_baseHeight`, a name no element owns as a method.
- **`scripts/link_element_test.luau`** — L11 rewritten for the new contract (a
  mid-press pan never moves the page, a quiet press writes nothing, a
  swallowed release still ends the hold), plus new sections: L12 a card with a
  description builds and its line follows every base change, L13 an empty link
  copies nothing, L14 a press inside a Group, L15 a clipboard that fails by
  return value and a throwing `getfenv`, L16 the row's measured width, L17 a
  hold ends with its tab.
- **Docs** — `USAGE.md` (links row: the empty-link answer, and the press that
  never scrolls the page).
- **`version-1.luau` / `version-1.luau.sig` / `loader.luau`** — bundle
  regenerated and re-signed (dev-key path), loader pinned key synced.

## 2026-09-23 — Link copy taps no longer bounce the page

Tapping a Link card's copy control could scroll the tab page down and snap
it back on release. Nothing in the card's own copy path moved anything — no
size tween, no canvas write, no drag hook — the movement came from the press
itself: the control was `Selectable = true` (every TextButton's default), so
engine and executor input paths could pull it into selection-into-view, and
an input bridge that does not mark the press as game-processed lets the
tab's `AutomaticCanvasSize` ScrollingFrame take the press as the start of a
pan, which springs back when the press ends.

- **`elements/link.luau`** — the copy control is built `Selectable = false`
  (selection can never scroll the page to it; the card title carries that
  role), and the press is pinned to the page: the canvas position is
  snapshotted when the press begins (MouseButton1 or Touch) and written back
  when it ends, so release restores exactly what the press found. No
  movement writes nothing, and a press-less click has no snapshot to
  restore, so it can never corrupt a scroll the user made in between.
- **`scripts/link_element_test.luau`** — new L11: a 120px mid-press pan is
  restored on release with exactly one canvas write, a press that never
  moves writes nothing, a press-less click never touches the canvas, a touch
  pins the same way back to where the touch found the page, and the control
  reports `Selectable == false`.
- **`version-1.luau` / `version-1.luau.sig` / `loader.luau`** — bundle
  regenerated and re-signed (dev-key path; the integrity suite caught the
  stale signature on the way, as designed), loader pinned key synced.

## 2026-09-23 — Signed loader channel: Ed25519-verified bundle delivery with silent fail-closed stubs

The delivery path gained a defensive verification layer. `loader.luau` is now
the official one-liner: it fetches `version-1.luau` and the detached
`version-1.luau.sig`, checks `SHA-256(bundle)` inside an Ed25519-signed record
`ASTRA-BUNDLE-V1|<version>|<digest>`, and passes the exact signed bytes to
`loadstring` unchanged (LineOffsets error mapping preserved). Every failure
mode — tampered bundle, corrupted/missing signature, wrong pinned public key,
stale expected version, hostile network, or an in-bundle canary trip — ends in
the same quiet no-op stub: no "TAMPER DETECTED", no printed errors, and chains
like `Astra:CreateWindow({...}):CreateTab(...)` or `Astra.Settings.readPersisted`
stay silent because the stub returns itself for every index and call.

- **`loader.luau`** — pure SHA-256/SHA-512 (bit32 only, no native crypto) and a
  pure-Lua Ed25519 verifier (RFC 8032; ~0.1s on executor-class hardware),
  SHA-256 published vectors + RFC 8032 test vectors + a Node differential
  check all green. Config pins `EXPECTED_BUNDLE_VERSION` and `PUBLIC_KEY`
  (kept in sync by `scripts/sign_bundle.js`); official mode is strict
  signature-only — the labeled degraded second-origin pin mode exists behind
  an explicit `VERIFICATION_MODE = "pin"` edit and never triggers as a
  fallback.
- **`scripts/sign_bundle.js`** — signs/verifies the digest record; private key
  comes from the `SIGNING_KEY` Actions secret in CI, or an auto-created
  gitignored `scripts/dev_signing_key.pem` locally. Contributors never need
  the production key. Writes `version-1.luau.sig` (128 hex chars).
- **Bundle canaries (inside the signed bytes)** — environment-fingerprint
  snapshot around module execution, closure-count guard, and a decoy entry in
  the shared environment that silently flags touches; each trip returns the
  same quiet stub. No per-frame cost, no loud names in the runtime path.
- **`scripts/generate_bundle.js`** — emits the canaries and a shared wrapper
  builder so the LineOffsets scan can never drift from emitted wrappers.
- **Tests** — `scripts/loader_crypto_test.sh` (crypto vectors) and
  `scripts/loader_integrity_test.sh` (11 cases: valid → real API; tamper /
  bad sig / missing sig / wrong key / stale version / fetch error / canary
  trip / pin mismatch → stub; honest pin → real API), both discovered by
  `scripts/check_all.sh` and run in CI on the pre-obfuscation artifact.
- **`.github/workflows/sign-bundle.yml`** — verify on every relevant PR/push;
  re-sign and commit only on `main` pushes **and** only when the `SIGNING_KEY`
  secret exists.
- **Scope note (README)** — raw-bundle one-liner still works (canaries only),
  Rojo/Studio unchanged, and loader-replacement/hooking/server-enforcement are
  out of scope: *integrity ≠ authorization*.

## 2026-09-23 — Key gate icons render: the card routes images through the shared pipeline

The key gate's icons — the Sirius header mark, the close button, and every
`links` button glyph — assigned their resolved catalog URLs straight to the
`Image` property. Those URLs are raw https, which no `ImageLabel` can load,
so the whole card rendered text-only: a bare title and three icon-less
buttons. Every other surface (`Window:Create`, the gate's own notification
shim) routes image props through `image.assign`, which downloads each PNG
once into the executor cache and rewrites the property to a loadable
`getcustomasset` URI; the gate's `_create` now does the same, so the usage
example's link icons (`copy`, `external-link`, `scroll`, …) show up as drawn
and stay fully restyleable per entry.

- **`components/keySystem.luau`** — `_create` routes every non-locale prop
  through `image.assign` (identical assignment for non-image props, the
  executor image cache for `Image`/`HoverImage`/`PressedImage`), matching
  `Window:Create`; the header comment now says why direct assignment
  renders blank.
- **`scripts/key_system_test.luau`** — K13/K14 rewritten for the pipeline:
  mocked `request` (PNG bytes) + `getcustomasset` (per-path `rbxasset://`
  URIs) prove end to end that a link glyph and the Sirius mark land on
  rewritten URIs after a pump, `iconResolved` still resolves to a loadable
  catalog source, and a second gate with no `icon` prop wears the identical
  header mark (props.icon ignored at render level).
- **Docs** — `USAGE.md` (`links` row: the `icon` accepts anything the icon
  catalog accepts and renders through the same pipeline as window icons),
  `MODULES.md` (keySystem `_create` paragraph).
- **`version-1.luau`** — regenerated.

## 2026-09-22 — Key gate: forced Sirius header, plain note, 0–3 link-copy buttons with notification feedback

The gate's mockup pass replaces two affordances with one system. The header
icon prop (`icon`/`Icon`, name or asset id) is now **ignored**: the top-left mark is always the Sirius artwork, sized to the full header block so one square spans title + subtitle (`custom_asset/sirius.png` still wins as the source, per the resolver's override rule). The note lost its tap-to-copy branch — with or without `getKeyUrl` it is always a plain TextLabel — and every copy affordance moved to a new row of up to three small buttons under it.

Each entry of the new `links` prop (`{ name, icon?, link }`, 0–3 allowed) builds an equal-width face in the field's language (FieldBackground fill, 8px corners, SurfaceStroke hairline) showing **icon + name only**; the URL never renders on the card. Pressing copies it to the clipboard (while locked too — the lock is when a user needs the real-key link) and confirms through the **notification component**: title `Link copied`, content = the copied URL — the only place the link becomes visible. The legacy `getKeyUrl` prop auto-promotes to a leading **Get Key** button, so old scripts keep working with zero changes; past three total entries warn and drop from the tail (the promoted slot survives).

- **`components/keySystem.luau`** — forced-Sirius header (`_headerIcon`, square sized to `headerH`); `_buildNote` collapses to the single TextLabel path; `normalizeLinks` (single-entry shorthand, blank-`link` warn, `getKeyUrl` promotion, 3-cap warn) feeds `_buildLinkRow` (equal 1/n faces, hand-measured icon+name centering, hover swaps the stroke to AccentStroke); `_copyLink` + `_notificationHost` — a window-shaped shim (`Create` with theme bindings + locale tokens + `image.assign`, `ResolveIcon`, `CreateGlow`, `Connect`/`Disconnect` through the gate's own sweep, `DestroySubtree`, the baked theme, and a 300×800 bottom-right notifications lane in the gate's ScreenGui) so `components/notification.luau` runs before any window exists; the note-tap path (`_copyGetKeyLink`, `_copyToken`, inline confirm/restore) and the `icon`/`getKeyUrl` handle fields are gone.
- **`Types.luau`** — adds the previously referenced-but-undefined `KeySystemProps` and `KeySystem`, plus `KeySystemLink`, with `links` typed and `icon` marked accepted-but-ignored.
- **`scripts/key_system_test.luau`** — K9 rewritten (note stays `TextLabel` and never changes; `getKeyUrl` builds the Get Key face; press copies, the notification goes live with title/content, an exact duplicate replaces its card); new K13 (cap at three, faces show name never the URL, each press copies its own link into its notification, a bare gate builds no row/host and keeps the 140–176px height, the row grows the card) and K14 (`icon = "house"` ignored — `_headerIcon.Image` equals `Icons.resolve("sirius")`, square).
- **`example.client.luau`** — the demo note drops its "tap this line" promise, the redundant `icon = "sirius"` prop is gone, and the gate shows the full row: promoted Get Key (its own source blob) + Repository + Changelog — three buttons, exactly at the cap.
- **Docs** — `USAGE.md` (intro, snippet, `links`/`getKeyUrl`/`icon` rows, locked-gate copy note), `skills/astra/references/window.md` (snippet + prose), `skills/astra/SKILL.md` (key-gate blurb), `MODULES.md` (keySystem paragraph: Sirius header, links row, notification shim, new underscore fields).
- **`version-1.luau`** — regenerated.

## 2026-09-22 — A replaced window no longer breaks the key-gate build ("key system callback errored")

Re-executing a hub while its key-system `onSuccess` was still building — or running two gated hubs in one session — printed `Astra: key system callback errored: … Cannot create a tab on an unloaded window.` and the host's whole build stopped. The anti-duplicate guard's contract is that a superseded build finishes harmlessly: `Window:Create` detaches strays into the construction graveyard, construction checkpoints no-op and `Tab:Select` bails out. `Window:CreateTab`/`CreateSection` were the two constructors still hard-asserting the window alive, and since every gated build starts with exactly one `CreateTab`, the first tab after a replacement landed inside the key system's pcall and read as a broken callback.

- **`components/window/tabs.luau`** — `CreateTab` and `CreateSection` on an
  unloaded window now build detached instead of asserting: the tab/section
  (and every element the host chains onto it) routes through `Window:Create`
  into the graveyard, and only the live-tree bookkeeping is skipped (rail
  insert, first-tab selection, chrome visibility, the settings-chrome
  reflow). The constructor still returns a real `Tab`/`TabSection`, so a
  superseded `onSuccess` runs to completion cleanly.
- **`scripts/anti_duplicate_window_test.luau`** — regression: after a
  replacement destroys the tree, a late `CreateTab`, an element chained onto
  it and a late `CreateSection` all succeed, build detached, and never
  resurrect the destroyed window's live instance list.
- **`MODULES.md`** — the window's public-surface entry documents the detached
  behaviour beside `Create`'s.
- **`version-1.luau`** — regenerated.

## 2026-09-22 — The example studio now opens behind the key gate

The key gate shipped with its own docs snippet but every consumer's reference
loader still built its window ungated. The example is the loadstring-and-run
entry for this library, so it is where the gate should be exercised: the card
draws first, and nothing — no window, no tabs, no listeners — exists until a
key passes.

- **`example.client.luau`** — the studio build from the Window section down is
  now `buildStudio(unlockedKey)`, wired as `CreateKeySystem`'s `onSuccess`.
  The gate carries the demo key `ASTRA-STUDIO-2026` (`keys` list, `saveKey`
  to `Astra/keys/Astra-Example.txt`, `getKeyUrl` pointing at the example's own
  source so the note line copies where the key lives, and a five-key
  `maxAttempts` budget with `onClose`/`onMaxAttempts` prints). `keyGate`,
  `window`, `overview` and a `studioReady` seam move to file scope so the
  harness can drive the gate and know when the streamed build has gone quiet;
  the opening changelog entry now also logs the key that passed.
- **`scripts/example_test.luau`** — the harness asserts the gated order of
  events before anything else: card up, no window, a wrong submit costs an
  attempt and builds nothing, then a padded correct submit passes the gate,
  and the harness pumps until `studioReady` because the window's
  budget-paced construction yields real frames on the thread the gate
  spawns for `onSuccess` (on the old synchronous path the harness main
  thread's stray-wait no-op hid those yields entirely).
- **`README.md`, `MODULES.md`, `USAGE.md`** — the example's key-gated shape
  and the demo key.

## 2026-09-22 — New standalone key gate: `Astra:CreateKeySystem`

Hosts coming from Rayfield asked for its key-system card: a short modal that
demands a key before the hub appears. Astra had no equivalent — the popup
needs a window, and the window is exactly what a key is supposed to protect.
Rayfield's own card (500×187px, nearly the width of its host window) was also
cut for a narrower window than Astra's 600px default, so porting its size
verbatim would have read less like a modal and more like a squished window.

`Astra:CreateKeySystem(props)` is that gate, re-cut for this library: a 400px
card (the popup's width, ~150–165px tall from the measured note text) in the
window's own shell language, shown before any window exists, with the window
built inside `onSuccess`. Saved keys live at `Astra/keys/<fileName>.txt` and a
matching file skips the UI entirely.

- **`components/keySystem.luau` (new)** — standalone gate: header (key mark,
  title, subtitle, close button), a field row with the entry box and an
  attached accent Continue, and a note line that doubles as the get-key copy
  target when `getKeyUrl` is set. Enter submits; any other focus loss stays
  silent so one press never submits twice. Wrong keys shake the card on
  chained `micro`/`snappy` tweens, flash the field stroke red and clear the
  field; `maxAttempts` locks the gate and fires `onMaxAttempts` (the host
  decides what exceeding the budget means — no forced kick). The theme is the
  same value `CreateWindow` accepts, resolved once and baked in, and locale
  tokens resolve through the same translation tables.
- **`library_entrypoint.luau`** — new `Astra:CreateKeySystem`, required lazily
  like the window so hosts that never gate pay nothing at startup; plus the
  `KeySystemProps` / `KeySystem` type exports.
- **`Types.luau`** — new `KeySystemProps` and `KeySystem` types, and
  `CreateKeySystem` on the `Astra` type.
- **`scripts/key_system_test.luau` + `scripts/key_system_test.sh` (new)** —
  twelve assertions (K1–K12) covering geometry and the corner scale, wrong /
  right submits, the saved-key passthrough, the attempt budget, theme
  overlays, remote keys, the get-key copy note, dismissal and gate
  replacement. Full gate green: 41/41 runtime suites pass.
- **`USAGE.md`, `MODULES.md`, `PERFORMANCE_CHANGES.md`, the Agent Skill** —
  the Key System section, the module reference, the measured bundle delta and
  the skill's cheat-sheet entries.

## 2026-09-22 — The example is now a ten-tab studio where every control does something

`example.client.luau` had grown into three tabs of representative props: a
counter button, a notification button and a handful of sample controls. It showed
what an element looks like, not what it can do, and it left most of the public
API — persistence, themes, motion, overlays, the handle methods — unexercised.

The example is now a working testbed. Ten tabs, each built around a thing you can
actually run, with every control wired to a real effect rather than a `print`:

- **Overview** keeps the information-first rule: About Card, tour Text, three
  Links, an activity Changelog that the other nine tabs write into through
  `Add`, the Isolated release history and a Footer.
- **Player** writes `Humanoid.WalkSpeed` / `JumpPower` / `JumpHeight`, arms
  infinite jump on `UserInputService.JumpRequest` through `window:Connect` (and
  disconnects it on release), respawns on a Keybind, and re-reads the character
  on `CharacterAdded`.
- **Combat** rebuilds its target Dropdown from `Players:GetPlayers()` with
  `Refresh`, `Add` and `Remove`, and a simulation button drives three Stats.
- **Visuals** edits `Lighting` and `CurrentCamera`, and creates or destroys a
  `ColorCorrectionEffect` and a `BlurEffect` on demand.
- **World** teleports the `HumanoidRootPart` from three numeric Inputs, stores
  waypoints into a Dropdown and totals the distance travelled in a Stat.
- **Live Stats** connects one Heartbeat listener for as long as its toggle is
  on and reports fps, frame time, Lua memory, session length and ping.
- **Elements** drives every handle: `Set` on each control type, dropdown
  `Add`/`Remove`/`Refresh`, `Capture`, `MoveToTop`/`MoveUp`/`MoveDown`/
  `MoveToBottom`, `Lock`/`Unlock`/`IsLocked`, and `ShowTooltip`/`HideTooltip`.
- **Configs** uses the persistence API directly: `Save`, `Load`, `DeleteConfig`,
  `ListConfigs`, `GetPath` and a `Flags` dump.
- **Window** covers `ChangeTheme` (accent presets and both corner tokens),
  `Astra.Motion.setProfile`/`setTimeScale`/`setEnabled`, `Hide`/`ToggleHide`/
  `ToggleMinimise`/`Navigate`, notification dedupe, a popup with boxes and all
  three option styles, `Astra.Icons` and `Astra.Performance` reports, unlocking
  the gated tab, and `Unload` behind a confirmation.
- **Premium** starts `locked = true` and is unlocked from Window.

Roblox services are resolved through a small nil-safe helper block at the top,
so the same file runs in an executor, in Studio and under the headless harness;
where a service is missing a control reports back instead of throwing.

- `example.client.luau` — rewritten; 17 element constructors, ~110 controls.
- `scripts/example_test.luau` — the tab-count assertion follows (3 → 10).
- `README.md`, `USAGE.md`, `MODULES.md` — descriptions of the example updated
  (they claimed three tabs and, in USAGE, a single tab).

Verification: `sh scripts/check_all.sh` passes end to end (40 runtime tests).
Beyond the shipped suite, two throwaway harnesses drove the file under the Luau
CLI: one invoked all **114** element callbacks directly, bypassing
`Window:_runGuarded` so a broken callback would surface as an error, and one
exercised the paths that walk cannot reach (the About Card's action band,
`Isolated:Expand/Collapse/Toggle`, both popups and their options). Both run
clean; the first pass caught a real defect — `Stat:Set` was handed a
comma-formatted string for the Lua-memory readout, which the Stat rejects —
fixed by keeping the number in the Stat and the commas in the notification.

## 2026-09-22 — Link cards show their copy glyph again

The trailing control on a Link card was an empty square: the tap target worked,
the copy landed, the confirmation state changed — but the glyph inside it was
never drawn, so a card showed no copy mark and no check mark.

The glyph is built at `ImageTransparency = 1` like every other card part and was
left there. Its own comment said `tapIcon` is "the shared name the window's
reveal path reads", which was true while buttons carried a trailing tap cursor;
the 2026-09-21 cleanup removed that cursor *and its reveal paths*, and
`Window:_revealCommon` has walked only the shared parts ever since — stroke,
title, body, leading icon, description. Nothing owned the Link's glyph, so it
stayed invisible for the life of the card.

The card owns the fade now, the way the Dropdown and the collapsible headers own
their chevrons:

- `elements/link.luau` — `_setShown` reveals `tapIcon` to the new
  `restingGlyphTransparency` (0.5, the value the Button's tap glyph rested at
  and the Dropdown chevron still does) and puts it back to 1 on hide, so a card
  that folds away leaves no floating mark. The stale "the window's reveal path
  reads this" comments are replaced with what the code now does.
- `scripts/link_element_test.luau` — L2 pins the drawn glyph and the leading
  icon on a shown card, L5 records that a container collapse puts its body away
  by visibility rather than pushing `_setShown` into children, L8 covers the
  compact row, and a new L10 walks a real hide/show path (`Window:Hide` →
  `Window:Show`) in both directions. Against the pre-fix bundle L2 fails with
  `got 1, want 0.5` and, with L2 removed, L10 fails the same way — the old suite
  passed because its only glyph assertion was `tapIcon ~= nil`, which the
  invisible label satisfies.

No public API changed; the fix is visibility only.

## 2026-09-22 — Static gates: instance-field checker wired in, dangling-reference checker added

`scripts/check_instance_fields.py` existed but was never part of `check_all.sh`, and it
false-flagged the generated bundle: `version-1.luau` inlines every module into one file
scope, so a per-file holder like footer's `local image = …:Create("ImageLabel")` collided
with the `image` module table's own `image.rewrites = …` writes. The checker now scans the
modular tree only (skips `version-1.luau` and hidden/vendored directories) and reports
0 violations; a new second gate closes the class of bug where a deleted or moved file is
still named by source comments and docs.

- `scripts/check_instance_fields.py` — excludes the bundle and hidden dirs; docstring
  records why flat-scanning the bundle cannot work; wired into `check_all.sh` as `2/6`.
- `scripts/check_dangling_refs.py` (new) — flags slash-anchored repo paths under
  top-level source directories that do not resolve from `.luau`/`.md` files; skips URLs,
  tree diagrams, historical records (`CHANGELOG.md`, `ANALYSIS.md`,
  `PERFORMANCE_CHANGES.md`) and deleted/removed history lines; resolves relative links
  and extensionless module references (`cache/imageCache` → `cache/imageCache.luau`,
  `components/window.luau` → `components/window/init.luau`); wired in as `3/6`.
- `scripts/check_all.sh` — now six sections (`1/6` requires → `6/6` runtime tests);
  header comment lists every gate it runs.
- `components/window/visibility.luau` — reworded three comments that said
  `settings/normal` (reads as a path; means the settings rail vs. the normal rail).
- Docs updated: `README.md` dev commands, `MODULES.md` scripts table,
  `skills/astra/references/repo-workflow.md` build-and-verify list.

`luau-analyze` is still not wired in: without a Roblox-globals allowlist it floods
`Unknown global 'script'/'Enum'/'Color3'` on every file, so it would fail the gate on
noise rather than findings.



## 2026-09-22 — Static gates: instance-field checker wired in, dangling-reference checker added

`scripts/check_instance_fields.py` existed but was never part of `check_all.sh`, and it
false-flagged the generated bundle: `version-1.luau` inlines every module into one file
scope, so a per-file holder like footer's `local image = …:Create("ImageLabel")` collided
with the `image` module table's own `image.rewrites = …` writes. The checker now scans the
modular tree only (skips `version-1.luau` and hidden/vendored directories) and reports
0 violations; a new second gate closes the class of bug where a deleted or moved file is
still named by source comments and docs.

- `scripts/check_instance_fields.py` — excludes the bundle and hidden dirs; docstring
  records why flat-scanning the bundle cannot work; wired into `check_all.sh` as `2/6`.
- `scripts/check_dangling_refs.py` (new) — flags slash-anchored repo paths under
  top-level source directories that do not resolve from `.luau`/`.md` files; skips URLs,
  tree diagrams, historical records (`CHANGELOG.md`, `ANALYSIS.md`,
  `PERFORMANCE_CHANGES.md`) and deleted/removed history lines; resolves relative links
  and extensionless module references (`cache/imageCache` → `cache/imageCache.luau`,
  `components/window.luau` → `components/window/init.luau`); wired in as `3/6`.
- `scripts/check_all.sh` — now six sections (`1/6` requires → `6/6` runtime tests);
  header comment lists every gate it runs.
- `components/window/visibility.luau` — reworded three comments that said
  `settings/normal` (reads as a path; means the settings rail vs. the normal rail).
- Docs updated: `README.md` dev commands, `MODULES.md` scripts table,
  `skills/astra/references/repo-workflow.md` build-and-verify list.

`luau-analyze` is still not wired in: without a Roblox-globals allowlist it floods
`Unknown global 'script'/'Enum'/'Color3'` on every file, so it would fail the gate on
noise rather than findings.

## 2026-09-21 — Clean buttons, letter-only key capture and information-first tabs

Buttons no longer carry the semi-transparent trailing cursor, and settings no
longer ask users to type a key name into a general-purpose Input. The restore
capsule used to reveal while the main frame was still folding, painting its face
behind the window. It now stays explicitly invisible until the hide settles.
The element studio and built-in settings are arranged by purpose, with library
information on the first tab and no single-control collapsible wrappers.

- `elements/button.luau`, `components/window/elements.luau`, `Types.luau`:
  permanently remove the trailing tap image/scale and reveal paths in full and
  compact buttons. Optional leading icons and callback/press feedback remain.
  Legacy `tapIcon` props are ignored, not a way to re-enable the glyph.
- `elements/keybind.luau`, `utilities/keybind.luau`, tab/group/collapsible
  constructors and `Types.luau`: add `CreateKeybind` and declarative `Keybind`.
  Click the keycap, then press A–Z. One letter is required; callbacks/flags use
  uppercase strings. Escape cancels; blank, mouse, number and special-key
  bindings cannot replace the previous letter. Invalid initial values use K.
- Window input and lifecycle paths: capture runs before the menu toggle and
  respects processed/text-focused input. Switching tabs, folding a group,
  hiding/minimising, focus loss, locking, removing the tab or unloading cancels
  capture. No per-element global keyboard listeners are added.
- Settings validation/defaults and `utilities/persistenceSettings.luau`: keep
  the menu binding as a letter KeyCode; schema 2 migrates old non-letter and
  unbound settings to K, preserving valid letter bindings.
- `components/chrome.luau`, `components/window/visibility.luau`: the capsule
  icon, text and hit target only appear after Hide completes, never during the
  fold or topbar-only minimisation. Restore hides them immediately.
- `components/settings.luau`, window startup: Overview → Controls → Appearance
  → Persistence. Overview uses an About Card, copyable Links and Footer;
  Controls uses Keybind; Appearance owns theme/layout and motion/feedback.
  Layout is a standalone Dropdown, not a one-element Collapsible Group.
- `example.client.luau` and the skill starter: Overview → Actions → Preferences,
  covering every element with meaningful interactions and related-control
  groups. Information and release history stay on Overview.
- Updated guides, types, existing regressions and three new runtime suites:
  held-tween capsule visibility, keybind persistence/migration, and execution of
  the real multi-tab example. Verification uses the Luau CLI/stub harness;
  actual Roblox Studio visual validation is still a manual check.

## 2026-09-21 — Popups show their content again (dedicated `ScreenGui` restored)

A dialog opened as a blank card: the rounded surface arrived, the title, the
copy and the action buttons did not.

`Popup` had been nested into `window.screenGui` behind a `PopupContainer` layer
so that only one UI root existed. That root is `ZIndexBehavior.Global`, which
compares a `GuiObject`'s `ZIndex` against every other `GuiObject` in the
ScreenGui — the card's own descendants included. The card sat at
`ZIndex = 200001` (high enough to clear the window's stack), while its Header,
content and footer are created at the engine default of 1. A child ranked below
its parent draws behind the parent's background, so the card painted over every
part of itself and left the empty rectangle behind.

The dialog is a root of its own again:

- `Popup:_build` creates its own `ScreenGui` (`DisplayOrder = constants.displayOrder.popup`,
  `ZIndexBehavior = Enum.ZIndexBehavior.Global`, `Parent = state.guiContainer`)
  and the `PopupContainer` layer is gone — backdrop and card parent straight
  into the root. `DisplayOrder` lifts the whole dialog above the window, so the
  card no longer has to outrank anything: it keeps a plain `ZIndex = 1`, below
  nothing and above nothing it owns.
- `Popup:Close` destroys that root once the close tween reports
  `Enum.PlaybackState.Completed`.
- The window still owns the root (`window:Create` registers it), so `Unload`
  destroys every dialog left open with it — unloading a window with a popup
  still open leaves no `ScreenGui` behind.
- The test harness (`scripts/sidebar_sizing_stubs.luau`) fired `Completed` with
  no playback state, so listeners that gate their teardown on
  `Enum.PlaybackState.Completed` — `Popup:Close` among them — never ran at all
  and a dismissed dialog stayed parented forever. The stub now fires the state
  the engine passes.

- `components/popup.luau` — dedicated `ScreenGui`, plain ZIndex ranks, `popupContainer` removed.
- `scripts/sidebar_sizing_stubs.luau` — `TweenService` fires `Completed` with `Enum.PlaybackState.Completed`.
- `scripts/adaptive_hardware_test.luau` — H3 asserts the dialog's own root: two `ScreenGui`s while it is open, one after close, plus the card's `Header`, `Footer`, action buttons and ZIndex ranks.
- `PERFORMANCE_CHANGES.md` — the single-UI note now records why popups left `window.screenGui`.
- `version-1.luau` — regenerated bundle.

## 2026-09-21 — Hardware-adaptive performance engine, single-UI architecture, and aesthetic motion

Large menus with many tabs and elements on low-end devices (or weak GPUs/CPUs)
could hitch, drop frames, or crash the user's game due to heavy bursts of GUI
instance allocations and synchronous element visibility updates in a single frame.
Additionally, dialogs created unnecessary separate `ScreenGui` instances in `CoreGui`,
and animation curves were limited to mechanical linear/exponential ramps.

Key changes:

- **Adaptive Hardware Performance Engine (`utilities/hardwarePerformance.luau`)**:
  - Dynamically monitors frame delta time (`dt`), moving average FPS, and frame
    jitter on `RunService.Heartbeat`.
  - Automatically identifies device capabilities (mobile vs desktop), Roblox
    rendering quality level (`QualityLevel` / `SavedQualityLevel`), and client
    load.
  - Automatically tunes construction pacing (`_paceBudget`): scales frame budgets
    (from 1ms on low-end to 3.5ms on high-end) and instance limits (12–48 per frame).
  - Dynamically throttles when many tabs (> 5) or many elements (> 30) are present,
    or when sudden frame jitter is detected, preventing UI stutter and game freezes.
  - Config restoration adapts checkpoint frequencies based on hardware tier.
- **Cooperative Element Streaming for Heavy Tabs (`components/window/visibility.luau`)**:
  - Opening a tab with many elements (> 8) displays the visible viewport elements
    instantly, while streaming remaining elements cooperatively across micro-batches,
    eliminating the freeze when selecting heavy tabs. Small tabs (<= 8 elements)
    remain instant.
- **Single UI Architecture & Elimination of Redundant UI (`components/popup.luau`)**:
  - `Popup` now nests inside `window.screenGui` via a dedicated high-ZIndex
    `PopupContainer` layer rather than spawning a second top-level `ScreenGui` in
    `CoreGui`, keeping exactly one UI root active.
  - Destroying or unloading the window automatically tears down all popup instances
    cleanly without leaving orphaned containers.
- **Aesthetic UI-Dependent Animation System (`utilities/motion.luau`)**:
  - Added modern canvas-inspired easing curves (`Circular`, `Cubic`, `Back` spring
    overshoots: `modal`, `fluid`, `tabSwitch`, `control`, `micro`, `dropdownOpen`,
    `dropdownClose`, `toast`, `canvasEntrance`, `canvasPop`, `canvasCard`).
  - Added `Astra.Motion.uiSpec(componentType, action)` (and `Astra.Motion.forUI`),
    allowing animations to dynamically tailor to their specific UI component
    (windows, dialogs, tabs, mechanical switches, buttons, dropdowns, toasts).
  - Preserved 100% backward compatibility for all existing specs.
- **Test Suite & CI**:
  - Added `scripts/adaptive_hardware_test.luau` and `scripts/adaptive_hardware_test.sh`.
  - Fixed field formatting in `.github/scripts/discord-embed.jq` for `discord_notify_test.sh`.
  - All 37 runtime test suites pass.

- `utilities/hardwarePerformance.luau` — real-time hardware detection & dynamic budget engine.
- `utilities/motion.luau` — UI-dependent motion specs and canvas-inspired easing curves.
- `components/window/startup.luau` — adaptive `_paceBudget` and `_loadCheckpoint` wiring.
- `components/window/visibility.luau` — cooperative element streaming for heavy tabs.
- `components/popup.luau` — single ScreenGui reuse with `popupContainer` and modal easing.
- `elements/tab.luau` — total element tracking for dynamic menu scaling.
- `library_entrypoint.luau` — exposed `Astra.Performance` singleton.
- `Types.luau` — typed public definitions for `uiSpec`, `forUI`, and `Performance`.
- `.github/scripts/discord-embed.jq` — corrected diffstat fallback fields.
- `scripts/adaptive_hardware_test.luau`, `scripts/adaptive_hardware_test.sh` — regression tests.
- `version-1.luau` — regenerated bundle.

## 2026-09-22 — Footer no longer turns into a white bar on theme re-application

The Footer (the centred "Built with ⚡ Astra ♡" strip) rendered as a solid
white band after any theme re-application — Apply Theme / Reset in Settings,
the secure-mode font swap, a host calling `window:ChangeTheme` after a
bar-layout switch — leaving it showing nothing readable at all.

Two footer defects combined into that bar:

- The container frame is a transparent host (its text/icon runs are the whole
  element), yet it registered `BackgroundTransparency = "ElementTransparency"`
  like an element card. Element cards can afford that binding because their
  `StyleElementBody`/`StyleElementPanel` gradient tints the white base dark
  the moment the binding paints it opaque; the footer never receives that
  styling, so the very next `ChangeTheme` pass tweened its bare white base to
  `ElementTransparency` (0) and buried the run. The binding is simply gone:
  the container's transparency is permanently 1, and visibility lives
  entirely on the runs, exactly as `_setShown` already treats it. Every other
  element was audited — each keeps the binding only where a gradient or a
  surface colour tints the frame, so none share the defect.
- `Footer:Set()` destroyed the old run labels with a raw `:Destroy()` while
  their theme bindings were still registered, so the first `ChangeTheme`
  afterwards failed with "property cannot be assigned ... instance has been
  destroyed". The rebuild now goes through `Window:DestroySubtree` like every
  other element's rebuild path, unregistering theme/locale bindings first.

- `elements/footer.luau` — no theme binding on the transparent container
  frame; `Set` destroys rebuilt runs via `DestroySubtree`.
- `scripts/footer_test.luau` — new F9 section: a theme pass, a
  sidebar → collapsed-sidebar → sidebar round trip and a later theme edit
  all leave the container transparent and the run at resting transparency;
  the Set path no longer leaves destroyed labels registered. F10 teardown.
- `scripts/footer_test.sh` — suite description covers the regression.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — Anti Duplicate Window no longer unloads a window mid-construction

The spam-execute guard destroyed the previous window the moment a new
`CreateWindow` claimed the slot. Construction yields at pacing checkpoints,
so a re-executed script could land while the previous one's constructors
were suspended at one of those checkpoints — or had built half an element —
and the destroy pulled the tree out from under them: the resumed checkpoint
asserted ("Window unloaded during construction"), and a constructor that had
yielded mid-element then wrote into instances that were already destroyed.

Destruction of a replaced window now never interrupts active construction:

- A window with a constructor thread suspended at a checkpoint is marked
  unloaded and vanishes from the screen at once, but its tree is only
  destroyed once that construction has gone quiet (two consecutive frames
  with no suspended checkpoint and no pacing activity).
- A window overtaken while still inside `Window.new` is marked superseded
  instead of being unloaded on the spot: the host that received it keeps
  adding controls to a live window, the window is never shown, and it
  unloads once its construction goes quiet.
- Constructors that still outlive the destruction finish harmlessly instead
  of crashing: pacing checkpoints on an unloaded window neither yield nor
  assert, and `Window:Create` builds into a detached throwaway container
  instead of the destroyed tree (a repeat `Unload` clears the container).
- A configuration load stops applying values once the window is unloaded,
  and `Tab:Select` becomes a no-op on an unloaded window, so a superseded
  script's final selection call cannot write into destroyed chrome.

- `components/window/teardown.luau` — two-phase unload: the soft half
  (unloaded flag, off-screen, queues stopped) runs at once; `_destroyTree`
  runs immediately or, while `_constructionBusy > 0`, via
  `_destroyWhenConstructionQuiet`.
- `components/window/startup.luau` — `_paceBudget` and `_loadCheckpoint`
  never pace or assert on an unloaded window.
- `components/window/theme.luau` — `Window:Create` detaches post-unload
  construction into a per-window graveyard container.
- `library_entrypoint.luau` — an overtaken construction marks its window
  `_superseded`; the reveal thread unloads it at quiet instead of the old
  synchronous unload.
- `utilities/persistenceConfig.luau` — the apply loop stops on an unloaded
  window.
- `elements/tab.luau` — `Tab:Select` bails out on an unloaded window like
  the other runtime APIs, so a superseded script's final selection call
  cannot write into destroyed chrome.
- `scripts/anti_duplicate_window_test.luau` — regression coverage for
  replacing a window while a host thread is suspended at a checkpoint and
  for overtaking a construction mid-`Window.new` whose host keeps adding
  elements.
- `scripts/startup_test.luau` — the in-flight-builder case now expects the
  builder to finish detached and error-free instead of being stopped.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — Anti Duplicate Window survives spam-execute

The guard only remembered the last *finished* window, and only one of them.
`Window.new` yields at construction checkpoints, so executing the script again
while the previous shell was still building saw an empty store, created another
window, and never unloaded the one that was still in flight. Rapid re-entry
left duplicate windows on screen.

`CreateWindow` now claims a generation token in the `getgenv()` store before
construction can yield, tracks every live window (not just the last one),
unloads every replaceable predecessor immediately, and unloads itself if a
later claim overtook it while it was still building. Per-window opt-out
(`settings.antiWindowDuplicate = false`) and the persisted setting still
disable the guard.

- `library_entrypoint.luau` — generation token, live-window list, post-construction self-unload.
- `scripts/anti_duplicate_window_test.luau`, `scripts/anti_duplicate_window_test.sh` — sequential replace, opt-out, and overlapping re-entry.
- `MODULES.md` — documents the race-safe guard.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — A corner scale: the UI is no longer square

Every radius the library shipped was zero. The three theme tokens
(`CornerRoundness`, `ElementCornerRadius`, `PillCornerRadius`) were all
`UDim.new(0, 0)` in `themes/default.luau`, no other theme overrode them, and
eleven more surfaces baked `UDim.new(0, 0)` into their own `UICorner` — so 34
of the 35 corner sites in the tree drew a hard 90-degree edge. The one exception
was the dropdown's option rows, which rounded at 12px/7px inside an otherwise
square UI. The switch's own metrics comment already called the track and knob
"pills", and the drag handle's called itself "the pill in the reference
screenshot"; neither was round.

The library now works on three nested tiers, each one step inside the tier above
so the arcs stay concentric instead of fighting:

- **12px `CornerRoundness`** — the shell. The window silhouette and the three
  bands that mirror its corners (topbar top pair, rail bottom-left, elements
  bottom-right), the bottom fade, notifications and popups.
- **8px `ElementCornerRadius`** — everything inside the shell: element cards,
  field boxes, hover overlays, lock scrims, tab rows, dropdown panels, tooltips,
  the search bar, popup buttons and the About card's tiles.
- **32px `PillCornerRadius`** — the folded states. Half the 64px chrome height,
  so the minimised bar reads as a full pill; the 50px capsule clamps to its own
  half-height and comes out a pill too (a circle in the icon-only size).

Controls whose shape is inherently round derive a half-height radius from their
own metrics rather than reading a token, so no theme can square them off: the
switch (11px track, 9px knob), the slider (7px track and fill, 10px handle), the
drag pill (1.5px on a 3px bar) and the unread dot (a 4px circle on an 8px
badge). The dropdown's row tiers are now read from the theme — the outer tier is
the panel's own `ElementCornerRadius`, because the rows sit 6px inside the panel
that clips them, so a row's arc lands inside the clip instead of being cut by it
— with the seam where two rows meet 4px below it. Its search field rounds at 6px
and the multi-select checkbox at a quarter of its 12px box.

All eleven baked zeros are gone: the surfaces that belong to a family now bind
to that family's token, so `ChangeTheme` restyles them too.

- `themes/default.luau` — the three tokens, with the scale written down beside
  them.
- `utilities/layouts.luau` — `rowCornerRadius` 0 -> 8 (the rail's rows are inset
  chips, not full-bleed bands).
- `elements/toggle.luau`, `elements/slider.luau`, `components/drag.luau`,
  `components/action.luau` — geometry-derived pill/circle radii, with the
  metrics named (`handleThickness`, `trackSize`, `badgeSize`) instead of inline.
- `elements/dropdown.luau` — `rowTiers(window)` replaces the baked 12/7
  constants; `rowInset` names the 6px the rows were already inset; the search
  field and checkbox round.
- `components/search.luau`, `components/tooltip.luau`, `components/popup.luau` —
  bound to `ElementCornerRadius`; the dead `buttonCorner` local is gone.
- `scripts/dropdown_rows_test.luau` — D3 reads both tiers from the theme instead
  of pinning 12 and 7.
- `USAGE.md`, `MODULES.md`, `README.md` — the corner scale, documented where a
  host writing a custom theme table will look for it.
- `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — Compact About rows and working changelog entry point

The About card's original width-aware packing treated its three status items as
large standalone cards. At the normal sidebar width, Version and Build occupied
the first line while Author wrapped into an oversized full-width tile below.
Those inset tiles also used `WindowColor`, making them much darker than the
surrounding element UI. The demo's **View Changelog** action only raised a
notification, and the Isolated header listened to `GuiButton.Activated`, which
some executor input bridges do not forward.

About data tiles are now a compact 48px status line with smaller 28px badges,
8px insets/gaps and compact label/value type. One to three tiles divide that
single line evenly, so the standard Version / Build / Author set remains three
columns and never leaves one row below the others. Tiles and the action band now
use `ElementSurface` with the existing element stroke rather than the dark
window gradient. Theme changes continue to update those fills.

Isolated headers now use `MouseButton1Click`, matching Astra's other full-row
controls while retaining touch-tap support. Both published examples wire the
About action to the actual Isolated handle: tapping it expands the changelog and
scrolls its header into view instead of showing a dead-end notification.

- `elements/aboutCard.luau`, `elements/isolated.luau` — compact single-line data
  geometry, regular element fills and the reliable Isolated click signal.
- `example.client.luau`, `skills/astra/assets/example-window.luau` — action to
  Isolated expansion and scrolling.
- `scripts/about_card_test.luau`, `scripts/isolated_test.luau` — compact geometry,
  surface/theme and primary-click regression coverage.
- `USAGE.md`, `MODULES.md`, and the Astra skill docs — updated behavior and
  examples; `version-1.luau` regenerated from the modular sources.

## 2026-09-21 — About card

The Settings → About tab was three prose Text cards that described the library
in the abstract, and there was no element a host could use to build the card the
design reference actually shows: a brand header, a row of data tiles, a
description paragraph and a changelog entry point, all in one container. Every
host that wanted that page had to assemble it out of Text, Stat and Isolated
children and keep the geometry in step by hand.

`tab:CreateAboutCard({ ... })` adds the card as one reusable, configurable
element. `elements/aboutCard.luau` builds four blocks from a single props table:
a header (leading icon, title, subtitle), one to three data rows (each a badge
icon with a label above its value), a wrapped description paragraph, and an
optional trailing action band carrying an icon, a label, a subtitle and the
card's built-in chevron. Surfaces stay inside the shared theme tokens — the card
is the standard element body, a tile and the band use the window surface with
the element corner and stroke, a badge uses the content surface — so the card
themes itself like every other element.

The tiles are packed against the width the card actually has: as many rows as
fit share one line (split evenly, gaps out of the slice) and the rest wrap
underneath at full width, so a narrow window stacks them instead of truncating
their values and a wide one puts them side by side. A fourth row is refused at
construction with
`Astra:CreateAboutCard — at most 3 data rows are supported, got N`: the action
band is the card's trailing row. Optional parts drop out of the layout rather
than rendering blank (a row without an icon loses its badge; a card without
rows, description or action simply has fewer blocks). Reveal, hide and theme
passes run over one tracked part list, so every label, glyph and stroke moves
together and a `ChangeTheme` re-reads all of them.

- `elements/aboutCard.luau` — new element (`__type = "AboutCard"`), with
  `SetTitle`, `SetSubtitle`, `SetIcon`, `SetRow(index, row)` and
  `SetDescription` setters plus the move and lock API. The action band is the
  card's only tappable surface: a tap anywhere on it fires `callback` once, with
  a haptic click, and the trailing chevron is fixed with no setter.
- `elements/tab.luau` — `tab:CreateAboutCard(props)`, tab-only like
  `CreateIsolated` and `CreateChangelog`.
- `components/settings.luau` — the About tab now renders one About card
  (the Astra mark, `Version` / `Build` / `Author` rows and the description
  paragraph) from the module's `aboutVersion`, `aboutBuild` and `aboutAuthor`
  strings, which a release bumps. The card's action band is left off there
  because the tab has no changelog to open.
- `Types.luau`, `library_entrypoint.luau` — `AboutCardProps`, `AboutCardRow`,
  `AboutCardAction` and the `AboutCard` handle type, plus `CreateAboutCard` on
  the `Tab` type.
- `scripts/about_card_test.luau`, `scripts/about_card_test.sh` — runtime test
  covering the header recipe, the row packing (one line when the tiles fit, the
  wrap when they do not, and the "no tile below its own copy" invariant across
  widths), the four-row guard, the description, the action band and its tap, the
  setters, the reveal/hide and theme passes, and the lock.
- Docs: `USAGE.md` (About card section), `MODULES.md` (module entry and the
  Settings About builder), `README.md` (element list), and the published skill's
  `SKILL.md` cheat sheet and `references/elements.md`. `example.client.luau` and
  `skills/astra/assets/example-window.luau` build the card end to end.
