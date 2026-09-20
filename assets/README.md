# Assets

```
assets/
├── window-icons/   ← 10 chrome fallbacks with human names (astra, sirius, close…)
│   ├── README.md
│   ├── astra.png        (window — was 80387863064905.png)
│   ├── sirius.png       (dot — was 91452555903853.png, also Icons.get("Sirius"))
│   ├── close.png
│   ├── minimise.png
│   ├── maximise.png
│   ├── settings.png
│   ├── search.png
│   ├── chevron.png
│   ├── check.png
│   └── config.png
├── custom-icon/    ← starter kit for your executor's custom_asset/ folder
│   ├── README.md
│   ├── brand/example.png
│   └── example/{house,star}.png
└── icons/          ← catalog PNGs for the 7 icon packs (see icons/README.md)
    ├── feather-pack/   (287)
    ├── heroicons-pack/ (648)
    ├── lucide-pack/    (1776)
    ├── material-pack/white/ (1133) — black/ removed (unused)
    ├── phosphor-pack/  (1512)
    ├── remix-pack/     (3229)
    ├── tabler-pack/    (5130)
    └── guides/         (7 generated markdown previews, 1.7 MB)
```

* `window-icons/` files are fetched by `cache/imageCache` as `assets/window-icons/<name>.png`.
* Numeric rbxassetids live in `images/windowIcons.luau` — filenames are just the human alias.
* Brand icon `Icons.get("Astra")` → `assets/window-icons/astra.png`; `Icons.get("Sirius")` → `sirius.png`.
* Previous root `assets/<numeric>.png` + `assets/Astra.png` layout was removed in favor of named files.
