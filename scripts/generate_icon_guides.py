#!/usr/bin/env python3
"""Generate visual catalogs from the same exact names/paths as the resolver."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
output = root / "assets/icons/guides"
output.mkdir(exist_ok=True)
packs = ("lucide", "material", "tabler", "phosphor", "heroicons", "feather")
index = ["# Astra icon catalog", "", "All packs can be mixed in one window. No window-wide pack option is needed.",
         "", 'Use `icon = "pack:name"` to select an exact icon. Copy the name from the catalogs below.',
         "Bare names search lucide → material → tabler → phosphor → heroicons → feather.",
         "Names are case-sensitive. Pack tables are loaded only when looked up.",
         "", "Previews use the repository's PNG files (many are white on transparent; use GitHub dark mode).", ""]
for pack in packs:
    entries = re.findall(r'\["([^"\n]+)"\]\s*=\s*"(assets/icons/[^"\n]+)"', (root / f"icons/{pack}.luau").read_text())
    index.append(f"- [{pack.title()} — {len(entries)} icons](guides/{pack}.md)")
    lines = [f"# {pack.title()} icons", "", "[All icon packs](../README.md)", "",
             f'Copy a qualified name into `icon = "{pack}:name"`. Generated from `icons/{pack}.luau`.', "",
             "| Preview | Icon name |", "|---|---|"]
    for name, path in entries:
        relative = "../" + path.removeprefix("assets/icons/")
        lines.append(f'| <img src="{relative}" width="24" height="24" alt="{name}"> | `{pack}:{name}` |')
    (output / f"{pack}.md").write_text("\n".join(lines) + "\n")
(root / "assets/icons/README.md").write_text("\n".join(index) + "\n")
print("Generated six icon catalogs and index")
