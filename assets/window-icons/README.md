# Window icons

Human-readable fallback PNGs for `images/windowIcons` + `cache/imageCache`.
`cache/imageCache` builds `https://raw.../assets/window-icons/<file>` for
secure-mode rewrites, so every role needs its PNG here.

| Role | rbxassetid | File |
|------|-----------|------|
| window **Sirius** | `91452555903853` | `sirius.png` |
| close | `83277910885129` | `close.png` |
| minimise | `108115485663409` | `minimise.png` |
| maximise | `88738500661569` | `maximise.png` |
| settings | `129180860773723` | `settings.png` |
| search | `100604009889706` | `search.png` |
| chevron | `88479147175134` | `chevron.png` |
| check | `125626312718314` | `check.png` |
| dot / Astra | `80387863064905` | `astra.png` |
| config | `125823673784681` | `config.png` |

The **window default icon is Sirius**: `components/window/startup.luau`
resolves `icons.resolve("sirius")` (the lowercase `sirius` from
`images/uiIcons.luau`, and the legacy `Sirius` spelling) to
`assets/window-icons/sirius.png`. A user file at `custom_asset/sirius.png`
wins over that named asset, because custom assets are checked first —
`assets/custom-icon/sirius.png` is the starter copy for that folder. Icon
names remain case-sensitive.

Numeric IDs stay in `images/windowIcons.luau` `windowIcons.ids` for
`rbxassetid://` loading; `windowIcons.files` maps each role to its human
filename.
