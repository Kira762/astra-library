# Custom icons — namespaced with `sirius_`

Drop your own PNGs here — they win over every built-in pack, so namespacing matters.

This folder is a **template** for the executor-side `custom_asset/` folder that Astra actually reads at runtime. Nothing in `assets/custom-icon/` is loaded by the library itself; it just shows the layout so you can mirror it next to your script without shadowing pack icons.

## Why `sirius_` prefix?

A bare name like `house` or `star` exists in 3–6 packs (lucide, material, phosphor…). A custom file named `house.png` would **shadow** every pack's `house` — `Icons.get("house")` would return your file instead of the pack glyph, and the script wouldn't know which to render.

All examples here use `sirius_` (the project's star brand) so they never collide:

```
custom_asset/brand/sirius_brand.png  → Icons.get("brand/sirius_brand")  — safe
custom_asset/house.png               → Icons.get("house")              — shadows lucide/material!
```

## How it works

At runtime Astra looks for `custom_asset/` **next to your executor script** (not in this repo):

```
your-script.lua
custom_asset/
├── sirius_logo.png              → Icons.get("sirius_logo")
├── sirius_hero.jpg              → Icons.get("sirius_hero")
└── brand/
    └── sirius_house.png         → Icons.get("brand/sirius_house")
```

* Supported extensions: `.png`, `.jpg`, `.jpeg`, `.webp` (in that preference order), or a bare file with no extension.
* Subfolders are namespaced: `custom_asset/brand/sirius_house.png` is `brand/sirius_house`.
* A custom file beats every pack — use `sirius_` so `Icons.get("sirius_house")` can't be confused with a pack icon.
* The folder is indexed **once** with `listfiles` (if your executor supports it), so missing names cost a table miss, not 5 `getcustomasset` probes.

## This template

```
assets/custom-icon/
├── README.md
├── brand/
│   └── sirius_brand.png  ← namespaced placeholder (was example.png)
└── example/
    ├── sirius_house.png  ← was house.png (shadows 3 packs — now safe)
    └── sirius_star.png   ← was star.png (shadows 6 packs — now safe)
```

* Copy the structure to `custom_asset/` next to your script, or point your build tool at `assets/custom-icon` as an example.
* Call `Astra.Icons.refreshCustom()` after adding files at runtime to re-index.
* `Icons.resolve("brand/sirius_house")` and `element icon = "brand/sirius_house"` both work once the file exists.

## Tips

* Always prefix custom icons: `sirius_` or `custom_` — e.g. `sirius_settings.png`, `custom_logo.png`.
* Keep icons square, 64×64 or 128×128, transparent background.
* Prefer `.png` — it’s tried first.
* Name files in kebab-case or snake_case: `sirius-my-icon.png` → `sirius-my-icon` (exact match, case-sensitive).
* Don’t commit your private `custom_asset/` — this `assets/custom-icon/` is just the starter kit.

## Seeing it

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()
-- put custom_asset/brand/sirius_house.png next to your script beforehand
print(Astra.Icons.get("brand/sirius_house")) -- → rbxasset://... (your file, no pack collision)
print(Astra.Icons.get("house"))              -- → still the pack's house (untouched)
```
