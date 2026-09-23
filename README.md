# Astra v1

[![skills.sh](https://skills.sh/b/Kira762/astra-version-1)](https://skills.sh/Kira762/astra-version-1)

A Roblox/Luau interface library for executor scripts: one loader line, one
`CreateWindow` call, and tabs full of elements — buttons, toggles, sliders,
dropdowns, inputs, letter-only keybinds, stats, text, dividers, groups, collapsible
groups and changelog — with built-in settings, themes, icon packs, saved configs and staged
startup.

## Use the library

The official one-liner loads through the verifying loader:

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/loader.luau"))()

local window = Astra:CreateWindow({ name = "Example Hub", subtitle = "v1.0" })
local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateButton({
    name = "Say hello",
    icon = "play",
    callback = function() window:Notify({ title = "Hello", content = "It works." }) end,
})

tab:Select()
```

Two things have to be right: the runtime must provide `loadstring` (executors do,
plain Studio does not) and `HttpService` requests must be enabled. In Studio/Rojo
the same library is a ModuleScript — `require(game:GetService("ReplicatedStorage").Astra)`.
Always load the published artifacts from the repository root; the modular folders
are the bundle's source, not a runtime entry point.

## Integrity and verification

The loader fetches `version-1.luau` plus its detached signature
`version-1.luau.sig`, checks `SHA-256(bundle)` inside an Ed25519-signed record
`ASTRA-BUNDLE-V1|<version>|<digest>`, and hands the **exact verified bytes** to
`loadstring` (no mutation, error line mapping intact). Any failure — tampered
bundle, corrupted or missing signature, pinned public key mismatch, stale
version, network error, or an in-bundle canary tripping — resolves to a silent
no-op stub: no error, no print, and `Astra:CreateWindow(...)` keeps chaining
without raising. The public key and expected version are pinned inside
`loader.luau`; CI re-signs with the `SIGNING_KEY` Actions secret (contributor
machines only ever need the gitignored throwaway dev key).

Current release checksum:

```
sha256(version-1.luau) = 74888062f11ab2aa366177bed37aed44688d73dd6fca215137fc1d210ce4f59b
```

(`node scripts/sign_bundle.js --verify` prints the live digest whenever the
bundle changes.)

### Backward compatibility and scope

| Path | Behaviour |
|---|---|
| Old one-liner loading `version-1.luau` directly | Still works. No signature check happens at this path, but the signed bundle's own canaries (environment fingerprint, closure count, decoy) still run inside it. |
| Rojo / Studio `require(ReplicatedStorage.Astra)` | Unaffected — the loader and signature files are not part of the Rojo tree. |
| Replacing `loader.luau`, hooking `loadstring`/`HttpGet`, server-side enforcement | Out of scope **on purpose**. Verification proves the bundle is the one this repository published — *integrity ≠ authorization*. It does not authenticate the client, the executor, the end user, or any server; treat it as tamper evidence for the delivery channel, not as a trust root. |

The loader is strict-mode only: there is no automatic fallback to a weaker
check. A second-origin pin mode exists as an explicitly configured, labeled
degraded option (`VERIFICATION_MODE = "pin"`) and is never selected silently.

## What is in the box

| Area | Highlights |
|---|---|
| Window | Sidebar / collapsed-sidebar layouts, minimise-to-capsule, draggable, notifications, modal popups, search, per-window settings. |
| Elements | Section, Text, Footer (centred text + inline icons), Button, Toggle (and `Switch` alias), Slider, Dropdown (single + multi-select, searchable), Input, Keybind (editable required A–Z field), Stat, Link (hidden URL with a copy control), About Card (brand header, up to three data rows, description and an optional action band), Divider, Group, Collapsible Group, Changelog, Isolated (changelog-only collapsible container). |
| State | Flags with built-in auto save/load, named configs, `forgetState` opt-out, writable-storage persistence. |
| Look | The default palette plus custom theme tables, seven icon packs (lucide, material, tabler, phosphor, heroicons, feather, remix), a `custom_asset/` folder override and a three-tier corner scale — 12px shell, 8px elements, pill folds — with round-by-nature controls (switch, slider, drag pill) deriving their own half-height radii. |
| Motion | One motion service behind every transition, driven by the user's animation-speed setting. |

## Install the agent skill

This repository is also an [Agent Skill](https://agentskills.io) source. The skill
teaches coding agents how to build Astra interfaces and how to work on the library
itself, so they stop guessing at the API:

```sh
# install everything this repo publishes (currently just `astra`)
npx skills add Kira762/astra-version-1

# non-interactive, for a specific set of agents
npx skills add Kira762/astra-version-1 --skill astra -a claude-code -a cursor -y
```

Skill contents:

```
skills/astra/
├── SKILL.md                     # loader contract, API rules, element cheat sheet
├── references/elements.md       # every element's props and handle methods
├── references/window.md         # window methods, themes, icons, motion, persistence
├── references/repo-workflow.md  # bundle generation, syntax gate, tests, docs rules
└── assets/example-window.luau   # copy-paste starter covering every element type
```

## Documentation

| File | Contents |
|---|---|
| [USAGE.md](USAGE.md) | The author-facing guide: loading, building windows, every element, flags, themes, icons, motion, localisation, settings. |
| [MODULES.md](MODULES.md) | Module-by-module reference, including the meaning of minified locals. |
| [CHANGELOG.md](CHANGELOG.md) | Dated entries explaining each behaviour change. |
| [PERFORMANCE_CHANGES.md](PERFORMANCE_CHANGES.md) | Startup and instance-budget work with measured numbers. |
| [assets/icons/README.md](assets/icons/README.md) | Visual icon catalog with copyable names across all seven packs. |
| [example.client.luau](example.client.luau) | Key-gated ten-tab working studio: every element plus live character, lighting, teleport, sampler, persistence, theme and window controls, built inside `CreateKeySystem`'s `onSuccess` (demo key `ASTRA-STUDIO-2026`). |
| [changelog.example.luau](changelog.example.luau) | Host-side changelog data file consumed by the Changelog element. |

## Repository layout

```
version-1.luau            generated bundle (never edit by hand)
library_entrypoint.luau   public API singleton
Types.luau                typed public surface
core/ components/         runtime, window shell, overlays, settings UI
elements/                 one module per element plus tab/group/section
settings/ themes/ icons/  settings registry, the default palette, icon packs
utilities/                motion, persistence, icons, locale, layouts, diagnostics
scripts/                  bundle generator, static checkers, runtime tests
skills/astra/             the published Agent Skill
```

## Development

```sh
node scripts/generate_bundle.js             # regenerate version-1.luau from the tree
sh scripts/install_luau.sh                 # build the Luau toolchain into .tools/bin (once)
sh scripts/check_all.sh                    # requires + field refs + dangling refs + bundle + syntax + tests
sh scripts/check_syntax.sh                  # compile every published .luau file
python3 scripts/check_requires.py           # require paths and cycles
python3 scripts/check_instance_fields.py    # no custom fields written on Instances
python3 scripts/check_dangling_refs.py      # .luau/.md paths must exist in the repo
sh scripts/smoke_test_bundle.sh             # runtime smoke test of the bundle
sh scripts/<feature>_test.sh                # per-feature runtime tests
```

`check_syntax.sh` and the runtime tests need the [Luau CLI](https://github.com/luau-lang/luau/releases)
(`luau-compile`, or `luau --compile`) in `PATH`, `/tmp` or `/usr/local/bin`; without
it the gate reports "not checked" (exit 2) rather than passing silently. A behaviour
change is only complete once `CHANGELOG.md` and the docs that describe it are updated.

## Third-party skills in this checkout

The following are installed locally for agents working in this repository
(canonical copies in `.agents/skills/`, symlinked into `.claude/skills/`). They are
not published from this repository — they keep their upstream authorship and can be
refreshed with `npx skills update`:

| Skill | Source | Why it is here |
|---|---|---|
| `frontend-design` | [anthropics/skills](https://github.com/anthropics/skills) | Visual-design judgement for element, theme and layout work. |
| `skill-creator` | [anthropics/skills](https://github.com/anthropics/skills) | Authoring and refining the `astra` skill itself. |
| `diagnosing-bugs` | [mattpocock/skills](https://github.com/mattpocock/skills) | Reproduce-then-fix discipline for the bug entries in the changelog. |
| `codebase-design` | [mattpocock/skills](https://github.com/mattpocock/skills) | Architecture decisions across the modular tree. |
| `web-design-guidelines` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Web interface guidelines — accessibility, focus states, motion, copy — for any web-facing work. |
| `vercel-react-best-practices` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | React and Next.js performance patterns for any web-facing work. |
| `writing-guidelines` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Prose quality for the usage guide and the docs pages. |
| `doc-coauthoring` | [anthropics/skills](https://github.com/anthropics/skills) | A structured workflow for writing and revising long-form docs such as USAGE.md. |
| `find-skills` | [vercel-labs/skills](https://github.com/vercel-labs/skills) | Discovering more skills when a task needs one. |
