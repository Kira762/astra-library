# Astra — Performance Refactor Breakdown

Goal: remove the 1–3 s startup freeze. The shell must spawn **instantly with zero
frame drops**; the rest of the UI is allowed to finish streaming in behind it.
All public features, buttons, logic and responsive behaviour are preserved.

## Headline results

Measured with the in-repo harness (`scripts/startup_test.sh`, virtual-time
Heartbeat scheduler). The *Original* column is the measurement taken when this
refactor landed (Luau CLI 0.669/0.738). The *Current* column was re-measured on
2026-09-19 against this checkout with Luau CLI 0.739; where the harness no longer
emits a metric it is marked `—` rather than guessed at.

| Metric (lower is better)                         | Before  | Original | Current   | Notes |
| ------------------------------------------------ | ------- | -------- | --------- | ----- |
| Instances built before the first shell reveal    | 155     | 66       | **67**    | one instance added since the refactor |
| Peak instance allocations in a single frame      | 82      | 64       | **57**    | improved since the refactor |
| Frames the build is spread over                  | —       | ~41      | **42**    | |
| Window with one tab + two controls, after settle | 218     | 129      | —         | harness no longer reports this |
| Profile card instances on the spawn path         | 89      | 0        | —         | harness no longer reports this |
| Bundle size (`version-1.luau`, bytes)            | 1,237,310 | 987,741 | **1,039,418** | grew with the features added since |

> **Since this document was written the profile card has been removed from the
> library entirely.** Sections 2 and 5 below, the "Profile card instances" row
> and the `EnableProfileCard` note in Verification describe work that is no
> longer in the tree; they are kept as the record of how the startup budget was
> reached, not as a description of current behaviour.

> On the wall-time row the original table carried (0.082 s → 0.074 s): that
> figure is not reproducible here and has been dropped rather than replaced.
> Timing the whole assembled harness (`stubs + bundle + assertions`, 27,131
> lines) under `luau` 0.739 gives a median of **0.347 s** over six runs, but that
> number includes process startup and the parse of the harness itself, so it
> measures something different from the original row and the two are not
> comparable.

The work that used to run in one frozen chunk is now spread over ~42 cheap
frames. Each frame respects a **3 ms CPU budget and a 48-instance budget**, so
the opening tween and input never starve; this is the accepted trade-off of a
slightly longer time-to-fully-interactive in exchange for an instant shell.

## What changed

### 1. Cooperative construction pacing (the freeze fix)

* `components/window.luau`
  * `_paceBudget(force)` / `_constructionCheckpoint(force)` yield at whole,
    completed-object boundaries (never half a control) whenever a frame has
    spent its 3 ms / 48-instance budget. Startup-only vs. lazy-build callers
    are gated separately (`_constructed`, `_startupComplete`).
  * Every element constructor, the collapsible-group child builder
    (`elements/collapsibleGroup.luau`) and late additions to live tabs pass
    through these checkpoints, so deferred builds can never monopolise a
    frame either.
  * Config restoration yields one frame per six applied controls
    (`_loadCheckpoint`) so a large saved configuration cannot hitch a freshly
    opened window.
* `library_entrypoint.luau`
  * The old fixed one-second pre-reveal wait is gone. The shell reveals on the
    next frame, then a watcher keeps pacing until **two consecutive frames see
    no construction activity** (revision + busy counters), instead of the old
    deadline every script paid even for an empty window.
  * The callers' first tab gets one frame to be added before the reveal.
  * Cancelled (`Unload` during construction) and never-shown windows end the
    watcher cleanly.

### 2. Lazy profile card (~90 themed instances off the spawn path)

* `components/profilePanel.luau` — `ensureBuilt(window)` builds the card on
  demand; it exists **iff** "Show profile" is enabled and the window is alive.
  `setEnabled` builds/tears down, arms the late-player waiter, and restores
  the 260 px pair-clamp/recenter. All resize/fade/recenter readers are
  nil-guarded. Default (off) now builds zero card instances.
* `components/window.luau` — builds the card only when enabled, re-arms the
  player-availability waiter from the toggle path, and only offsets the window
  centre when the card exists.
* `components/settings.luau` — the "Show profile" / "Reveal profile details"
  toggles drive the lazy build and keep their dependency rules.

### 3. Lazy settings panel and search

* The settings UI is built once on first open (`_buildSettingsUI`); reopening
  reuses the same instances (idempotency asserted by the startup test). Search
  builds lazily on first open as well, and is reused after that.

### 4. Compact, lazily-loaded icon packs

* Six packs (`icons/lucide|material|tabler|phosphor|heroicons|feather.luau`)
  were regenerated by `scripts/generate_icon_packs.js` into a compact table
  format compiled by `icons/packBuilder.luau`; a pack's tables are only
  expanded the first time one of its icons is resolved.
* All 10,486 URLs verified byte-identical to the original packs.
* This accounts for most of the 249 KB bundle reduction.

### 5. Overlay entrance lane: races fixed, cadence owned by the queue

* `components/overlayQueue.luau`
  * One pump per window drains a single entrance lane; queue shape is
    `{ pending, paused, closed, running }` and is never replaced or cleared
    wholesale, which fixes a pump/unload race (`#nil` after
    `table.clear`). Unload and close drain `pending` and park the pump without
    touching the shared table; the pump nil-guards `pending` on every turn.
  * Requests that arrive while a window is hidden and has never been shown
    re-park behind the window entrance gate.
  * Cadence lives in the queue, not in the cards: after the **first natural
    hand-off** the next card waits a motion-scaled `entranceCadence` (0.45 s
    after the 0.1 s staggered reveal, so two 0.6 s entrances never overlap); a
    deep backlog then drains with a short 0.06 s beat, and a card
    dismissed/retired mid-entrance releases early and skips the cadence.
    Motion disabled collapses every beat to zero (one card per frame).
* `components/notification.luau`, `components/toast.luau` — cards hand their
    lane slot back through an idempotent `_entranceDone(early)` from both the
    natural reveal path and `_dismiss`; stagger beats collapse to nothing when
    motion is off.

### 6. Bugs fixed while auditing startup paths

* **Auto-load was never wired.** Nothing called `Window:Load()` after the host
  finished building controls, so "Auto Load Config" (default on) never restored
  anything at next startup. The quiet-frame point in `library_entrypoint.luau`
  now performs the once-per-window auto-load; controls registered even later
  are still restored via `Window:_restoreLate`.
* Unload/pump race and hidden-never-shown re-pause (see §5).
* Notification/toast entrances no longer overlap (see §5).

### 7. Cleanup

* Motion hygiene (2026-09-15 animation pass): every component tween now runs
  through the shared motion service — named `TweenInfo` specs created once, so
  hover/press/reveal paths allocate nothing per event; already-satisfied
  targets are skipped (no tween at all); and one owner per animated property
  (rapid hover in/out cancels instead of stacking competing tweens). Theme
  switches batch one tween per instance instead of one per property.

* Dead code removed: unused `overlayEntranceCadence` (window), `epsilon`,
  `scrollbarWidth`, `layoutFor` (window), `contentSpacing` (toast), dead
  padding constants in `elements/text.luau`, and an unused require in the
  entry point.
* `images/windowIcons.luau` — the id→roles manifest and sorted role list are
  now memoised module constants; `roleForId` used to rebuild the whole manifest
  for every failed icon.
* Services, tweens and per-cycle `TweenInfo` (ambient live animation) are
  cached/hoisted; deferred threads guard `unloaded`.

### 8. Hardware-adaptive performance engine and single-UI consolidation (2026-09-21)

* `utilities/hardwarePerformance.luau`
  * Automatically monitors frame delta time (`dt`), moving average FPS, and
    frame jitter on `Heartbeat`.
  * Detects low-end mobile devices and Roblox rendering quality level.
  * Dynamically calculates `_paceBudget`: scales frame budget (1.2ms on low-end
    to 3.5ms on high-end) and instance budget (16 to 48 per frame).
  * Dynamically tightens budgets when many elements (> 30) or many tabs (> 5)
    are created, ensuring smooth streaming without hitching.
  * Instant jitter protection: yields immediately if a frame drop is detected.
* `components/window/visibility.luau`
  * Tab switching with heavy element counts (> 8 elements) reveals the visible
    viewport batch immediately and streams remaining elements in micro-batches
    across subsequent frames, preventing client freeze.
* `components/popup.luau`
  * Popups nest in the window's `ScreenGui` no longer. They were moved into a
    high-ZIndex `PopupContainer` layer inside `window.screenGui` to leave only
    one ScreenGui in `CoreGui`, but that root is `ZIndexBehavior.Global`, so the
    card's ZIndex outranked its own Header, copy and buttons and painted over
    them. Each dialog is a `ScreenGui` of its own again (popup `DisplayOrder`,
    plain ZIndex ranks inside), still created through `window:Create`, so the
    window owns it and `Unload` destroys any dialog left open — no orphaned
    roots, which is what the consolidation was after. See the changelog entry
    "Popups show their content again".
* `utilities/motion.luau`
  * Added UI-dependent aesthetic easing specs (`modal`, `fluid`, `tabSwitch`,
    `control`, `micro`, `dropdownOpen`, `dropdownClose`, `toast`, `canvasPop`)
    and the `Astra.Motion.uiSpec(componentType, action)` selector.

## Deliberately *not* changed

* **Collapsible-group children still construct eagerly.** Host scripts
  reference `group.elements[i]` immediately after
  `CreateCollapsibleGroup`, and saved values must restore while collapsed
  (`config_preferences` asserts this). Deferring instances would break that
  contract; instead each child already crosses the frame-budget checkpoint, so
  a big group streams in without hitching.
* Entrance animations still tween `UIScale`/size only; theming, dragging,
  singleton semantics (`__ASTRA_ACTIVE_WINDOW_V1__`), camelCase/PascalCase
  prop aliases and the 260 px side-card clamp/recenter are untouched.

## Verification

* `scripts/runall` equivalent: all **24 test scripts pass** on both
  Luau 0.669 and Luau 0.738 (the pinned baseline had 9 failing scripts, several
  of which exposed the real races and the missing auto-load above).
* The stale profile tests were updated to exercise the new contract — they
  enable the card through the actual "Show profile" settings toggle (shared
  `EnableProfileCard` test helper) rather than assuming an eager card.
* Bundle regenerated via `node scripts/generate_bundle.js` (103 modules);
  source files remain the source of truth.
