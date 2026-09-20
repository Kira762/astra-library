# Window icons — now **Sirius** by default

Human-readable fallback PNGs for `images/windowIcons` + `cache/imageCache`.

| Role | rbxassetid | File | `Icons.get` name |
|------|-----------|------|-----------------|
| window **Sirius** | `91452555903853` | `sirius.png` | `Sirius` |
| close | `83277910885129` | `close.png` | — |
| minimise | `108115485663409` | `minimise.png` | — |
| maximise | `88738500661569` | `maximise.png` | — |
| settings | `129180860773723` | `settings.png` | — |
| search | `100604009889706` | `search.png` | — |
| chevron | `88479147175134` | `chevron.png` | — |
| check | `125626312718314` | `check.png` | — |
| dot / Astra | `80387863064905` | `astra.png` | `Astra` |
| config | `125823673784681` | `config.png` | — |

* Window default is now **Sirius** (`components/window/startup.luau` → `icons.resolve("Sirius")`).
* Numeric IDs stay in `images/windowIcons.luau` `windowIcons.ids` for `rbxassetid://` loading.
* `windowIcons.files` maps each role to its human filename.
* `cache/imageCache` builds `https://raw.../assets/window-icons/<file>` for secure-mode rewrites.
* `icons/init.luau` exposes `Astra` and `Sirius` as named assets pointing here.
