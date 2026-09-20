# Assets

```
assets/
├── window-icons/   ← 10 chrome fallbacks, **Sirius** is now window default
│   ├── README.md
│   ├── sirius.png       (window — was 91452555903853.png, Icons.get("Sirius"))
│   ├── astra.png        (dot — was 80387863064905.png, Icons.get("Astra"))
│   ├── close.png
│   ├── minimise.png
│   ├── maximise.png
│   ├── settings.png
│   ├── search.png
│   ├── chevron.png
│   ├── check.png
│   └── config.png
├── custom-icon/    ← starter kit for your executor's custom_asset/ folder (sirius_ namespaced)
│   ├── README.md
│   ├── brand/sirius_brand.png
│   └── example/{sirius_house,sirius_star}.png
└── icons/          ← catalog PNGs for the 7 icon packs (see icons/README.md)
    ├── feather-pack/   (287)            — flat, no a/b sharding
    ├── heroicons-pack/ (648)            — flat
    ├── lucide-pack/    (1776)           — flat
    ├── material-pack/  (1133)           — flat, was white/ + black/
    ├── phosphor-pack/  (1512)           — flat
    ├── remix-pack/     (3229)           — flat, was 2/4/a…/z
    ├── tabler-pack/    (5130)           — flat
    └── guides/         (7 generated markdown previews, 1.7 MB)
```

* `window-icons/` files are fetched by `cache/imageCache` as `assets/window-icons/<name>.png`.
* Numeric rbxassetids live in `images/windowIcons.luau` — filenames are just the human alias.
* `Icons.get("Astra")` → `astra.png`; `Icons.get("Sirius")` → `sirius.png` — **window default is now Sirius** (`Sirius` in `components/window/startup.luau`).
* Previous root `assets/<numeric>.png` + `assets/Astra.png` layout was removed in favor of named files.
