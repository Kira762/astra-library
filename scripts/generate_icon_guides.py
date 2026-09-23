#!/usr/bin/env python3
"""Generate visual catalogs from the same exact names/paths as the resolver.

Reads each pack's compact catalog (`icons/<pack>.luau`: newline-separated
names plus the shared prefix/packName) and derives every PNG URL with the
same kebab-to-PascalCase rule `icons/packBuilder` uses, so the catalogs can
never drift from what the resolver answers.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
output = root / "assets/icons/guides"
output.mkdir(exist_ok=True)
packs = ("lucide", "material", "tabler", "phosphor", "heroicons", "feather", "remix")

licenses = {
    # Upstream: https://github.com/Remix-Design/RemixIcon
    "remix": "Remix icons are \u00a9 Remix Design, Apache-2.0 (upstream: https://github.com/Remix-Design/RemixIcon).",
}


def pascal(name: str) -> str:
    return "".join(word[:1].upper() + word[1:] for word in re.split(r"[-_]", name))


def catalog(pack: str):
    src = (root / f"icons/{pack}.luau").read_text()
    match = re.search(r'create\(\s*"([^"]+)",\s*"([^"]+)",\s*\[==\[(.*?)\]==\]', src, re.DOTALL)
    if not match:
        raise SystemExit(f"icons/{pack}.luau is not a compact catalog")
    prefix, pack_name, block = match.groups()
    entries = []
    for name in block.split():
        file_base = pascal(name)
        url = f"{prefix}{pack_name}{file_base}.png"
        entries.append((name, url))
    return entries


index = ["# Astra icon catalog", "", "All packs can be mixed in one window. No window-wide pack option is needed.",
         "", 'Use `icon = "pack:name"` to select an exact icon. Copy the name from the catalogs below.',
         "Bare names search lucide \u2192 material \u2192 tabler \u2192 phosphor \u2192 heroicons \u2192 feather \u2192 remix.",
         "Names are case-sensitive. Pack tables are loaded only when looked up.",
         "", "Previews use the repository's PNG files (many are white on transparent; use GitHub dark mode).", ""]
for pack in packs:
    entries = catalog(pack)
    # Every derived URL must be a file the resolver could serve.
    missing = [url for _, url in entries if not (root / url).exists()]
    if missing:
        raise SystemExit(f"{pack}: {len(missing)} catalog URLs have no PNG (e.g. {missing[0]})")
    index.append(f"- [{pack.title()} \u2014 {len(entries)} icons](guides/{pack}.md)")
    lines = [f"# {pack.title()} icons", "", "[All icon packs](../README.md)", "",
             f'Copy a qualified name into `icon = "{pack}:name"`. Generated from `icons/{pack}.luau`.', ""]
    if pack in licenses:
        lines += [licenses[pack], ""]
    lines += ["| Preview | Icon name |", "|---|---|"]
    for name, path in entries:
        relative = "../" + path.removeprefix("assets/icons/")
        lines.append(f'| <img src="{relative}" width="24" height="24" alt="{name}"> | `{pack}:{name}` |')
    (output / f"{pack}.md").write_text("\n".join(lines) + "\n")
index += ["", licenses["remix"]]
(root / "assets/icons/README.md").write_text("\n".join(index) + "\n")
print("Generated seven icon catalogs and index")
