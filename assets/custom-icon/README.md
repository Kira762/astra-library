# Custom icons

Drop your own PNGs here — they win over every built-in pack.

This folder is a **template** for the executor-side `custom_asset/` folder that Astra actually reads at runtime. Nothing in `assets/custom-icon/` is loaded by the library itself; it just shows the layout so you can mirror it next to your script.

## How it works

At runtime Astra looks for `custom_asset/` **next to your executor script** (not in this repo):

```
your-script.lua
custom_asset/
├── brand.png              → Icons.get("brand")
├── hero.jpg               → Icons.get("hero")
└── brand/
    └── house.png          → Icons.get("brand/house")
```

* Supported extensions: `.png`, `.jpg`, `.jpeg`, `.webp` (in that preference order), or a bare file with no extension.
* Subfolders are namespaced: `custom_asset/brand/house.png` is `brand/house`.
* A custom file beats every pack — `Icons.get("house")` will return your file instead of lucide/material/etc.
* The folder is indexed **once** with `listfiles` (if your executor supports it), so missing names cost a table miss, not 5 `getcustomasset` probes.

## This template

```
assets/custom-icon/
├── README.md        ← this file
├── brand/
│   └── example.png  ← placeholder: replace with your own 64×64 PNG
└── example/
    ├── house.png    ← placeholder
    └── star.png
```

* Copy the structure to `custom_asset/` next to your script, or point your build tool at `assets/custom-icon` as an example.
* Call `Astra.Icons.refreshCustom()` after adding files at runtime to re-index.
* `Icons.resolve("brand/house")` and `element icon = "brand/house"` both work once the file exists.

## Tips

* Keep icons square, 64×64 or 128×128, transparent background.
* Prefer `.png` — it’s tried first.
* Name files in kebab-case or snake_case: `my-icon.png` → `my-icon`, `my_icon.png` → `my_icon` (exact match, case-sensitive).
* Don’t commit your private `custom_asset/` — this `assets/custom-icon/` is just the starter kit.

## Seeing it

```lua
local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()
-- put custom_asset/brand/house.png next to your script beforehand
print(Astra.Icons.get("brand/house")) -- → rbxasset://... (your file)
```
