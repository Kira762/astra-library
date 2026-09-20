# Window icons

Window and capsule branding uses the lowercase `sirius` custom asset. The source
file is `assets/custom-icon/sirius.png`, which is copied to the executor's
`custom_asset/` folder and can be resolved anywhere with `icons.resolve("sirius")`; icon names remain case-sensitive.

The `assets/window-icons/` directory is reserved for legacy window-only chrome
fallbacks. Sirius is intentionally not stored here.
