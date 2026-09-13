#!/usr/bin/env python3
"""Compare the pre-refactor monolith bundle with the regenerated bundle.

Verifies that every module body in the original bundle exists in the new
bundle after canonicalizing require paths and normalizing whitespace.

Exit code 0 = all original modules accounted for; non-zero prints the
missing/differring module indices.
"""
import re
import sys
from collections import Counter

OLD = "/tmp/original_version-1.luau"
NEW = "version-1.luau"

# Old require path -> canonical new path (the mapping the refactor applied).
# Patterns are anchored to the variable styles used in the original bundle:
#   - `utility` = script.Parent.Parent.utilities (elements/components)
#   - `script.Parent.<name>` (utilities siblings / ui siblings)
PATH_MAP = [
    # -- shared state merge: utilities/variables + utilities/runtime -> core/state
    (r"require\(utility\.variables\)", "require(utility.Parent.core.state)"),
    (r"require\(script\.Parent\.Parent\.utilities\.variables\)", "require(script.Parent.Parent.core.state)"),
    (r"require\(script\.Parent\.variables\)", "require(script.Parent.Parent.core.state)"),
    (r"require\(script\.Parent\.runtime\)", "require(script.Parent.Parent.core.state)"),
    # -- generic helpers moved to functions/
    (r"require\(utility\.functions\)", "require(script.Parent.Parent.functions)"),
    (r"require\(script\.Parent\.Parent\.utilities\.functions\)", "require(script.Parent.Parent.functions)"),
    (r"require\(script\.Parent\.textMetrics\)", "require(script.Parent.Parent.functions.textMetrics)"),
    (r"require\(script\.Parent\.colors\)", "require(script.Parent.Parent.functions.colors)"),
    (r"require\(script\.Parent\.flagNames\)", "require(script.Parent.Parent.functions.flagNames)"),
    (r"require\(utility\.colors\)", "require(script.Parent.Parent.functions.colors)"),
    (r"require\(utility\.flagNames\)", "require(script.Parent.Parent.functions.flagNames)"),
    (r"require\(utility\.textMetrics\)", "require(script.Parent.Parent.functions.textMetrics)"),
    # -- icons split + lazy loading
    (r"require\(utility\.icons\)", "require(script.Parent.Parent.icons)"),
    (r"require\(script\.Parent\.icons\)", "require(script.Parent.Parent.icons)"),
    # -- images domain
    (r"require\(utility\.image\)", "require(script.Parent.Parent.images.image)"),
    (r"require\(script\.Parent\.image\)", "require(script.Parent.Parent.images.image)"),
    (r"require\(script\.Parent\.windowIcons\)", "require(script.Parent.Parent.images.windowIcons)"),
    # -- cache domain
    (r"require\(script\.Parent\.imageCache\)", "require(script.Parent.Parent.cache.imageCache)"),
    (r"require\(utility\.imageCache\)", "require(script.Parent.Parent.cache.imageCache)"),
    # -- utilities siblings now addressed through utilities/ explicitly
    (r"require\(script\.Parent\.filesystem\)", "require(script.Parent.Parent.utilities.filesystem)"),
    (r"require\(script\.Parent\.path\)", "require(script.Parent.Parent.utilities.path)"),
    (r"require\(script\.Parent\.constants\)", "require(script.Parent.Parent.utilities.constants)"),
    (r"require\(script\.Parent\.locale\)", "require(script.Parent.Parent.utilities.locale)"),
    (r"require\(script\.Parent\.log\)", "require(script.Parent.Parent.utilities.log)"),
    (r"require\(script\.Parent\.enums\)", "require(script.Parent.Parent.utilities.enums)"),
    (r"require\(script\.Parent\.services\)", "require(script.Parent.Parent.utilities.services)"),
    # -- ui/ sibling requires (modules inside ui/ requiring each other)
    (r"require\(script\.Parent\.search\)", "require(script.Parent.Parent.components.search)"),
    (r"require\(script\.Parent\.tabSelector\)", "require(script.Parent.Parent.components.tabSelector)"),
    (r"require\(script\.Parent\.sidebar\)", "require(script.Parent.Parent.components.sidebar)"),
    (r"require\(script\.Parent\.chrome\)", "require(script.Parent.Parent.components.chrome)"),
    (r"require\(script\.Parent\.descriptor\)", "require(script.Parent.Parent.elements.descriptor)"),
    (r"require\(script\.Parent\.popup\)", "require(script.Parent.Parent.components.popup)"),
    (r"require\(script\.Parent\.toast\)", "require(script.Parent.Parent.components.toast)"),
    (r"require\(script\.Parent\.notification\)", "require(script.Parent.Parent.components.notification)"),
    # -- ui/ split into components/ and elements/
    (r"script\.Parent\.ui\.window", "script.Parent.components.window"),
    (r"script\.Parent\.ui\.action", "script.Parent.components.action"),
    (r"script\.Parent\.ui\.chrome", "script.Parent.components.chrome"),
    (r"script\.Parent\.ui\.drag", "script.Parent.components.drag"),
    (r"script\.Parent\.ui\.notification", "script.Parent.components.notification"),
    (r"script\.Parent\.ui\.popup", "script.Parent.components.popup"),
    (r"script\.Parent\.ui\.search", "script.Parent.components.search"),
    (r"script\.Parent\.ui\.sidebar", "script.Parent.components.sidebar"),
    (r"script\.Parent\.ui\.tabSelector", "script.Parent.components.tabSelector"),
    (r"script\.Parent\.ui\.toast", "script.Parent.components.toast"),
    (r"script\.Parent\.ui\.button", "script.Parent.elements.button"),
    (r"script\.Parent\.ui\.console", "script.Parent.elements.console"),
    (r"script\.Parent\.ui\.descriptor", "script.Parent.elements.descriptor"),
    (r"script\.Parent\.ui\.divider", "script.Parent.elements.divider"),
    (r"script\.Parent\.ui\.dropdown", "script.Parent.elements.dropdown"),
    (r"script\.Parent\.ui\.group", "script.Parent.elements.group"),
    (r"script\.Parent\.ui\.input", "script.Parent.elements.input"),
    (r"script\.Parent\.ui\.keybind", "script.Parent.elements.keybind"),
    (r"script\.Parent\.ui\.progress", "script.Parent.elements.progress"),
    (r"script\.Parent\.ui\.section", "script.Parent.elements.section"),
    (r"script\.Parent\.ui\.slider", "script.Parent.elements.slider"),
    (r"script\.Parent\.ui\.stat", "script.Parent.elements.stat"),
    (r"script\.Parent\.ui\.tab\b", "script.Parent.elements.tab"),
    (r"script\.Parent\.ui\.tabSection", "script.Parent.elements.tabSection"),
    (r"script\.Parent\.ui\.tag", "script.Parent.elements.tag"),
    (r"script\.Parent\.ui\.text", "script.Parent.elements.text"),
    (r"script\.Parent\.ui\.toggle", "script.Parent.elements.toggle"),
]

HEADER_RE = re.compile(
    r"^\s*\[(\d+)\]\s*=\s*function\(\)local wax,script,require=ImportGlobals\(\d+\)local ImportGlobals return \(function\(\.\.\.\)"
)
TAIL = "end)() end,"


def canonicalize(text: str) -> str:
    for pattern, replacement in PATH_MAP:
        text = re.sub(pattern, replacement, text)
    return text


def extract_modules(path: str):
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()
    modules = {}
    current_index = None
    buf = []
    for line in content.splitlines():
        m = HEADER_RE.match(line)
        if m:
            if current_index is not None:
                modules[current_index] = canonicalize("\n".join(buf))
            current_index = int(m.group(1))
            # Keep any module code that shares the header line.
            buf = [line[m.end():]]
        elif current_index is not None:
            buf.append(line)
    if current_index is not None:
        modules[current_index] = canonicalize("\n".join(buf))

    # Normalize: strip blank lines + trailing whitespace per line.
    normalized = {}
    for idx, body in modules.items():
        lines = [ln.rstrip() for ln in body.splitlines()]
        lines = [ln for ln in lines if ln.strip()]
        normalized[idx] = "\n".join(lines)
    return normalized


def main():
    old_mods = extract_modules(OLD)
    new_mods = extract_modules(NEW)

    new_bodies = Counter(new_mods.values())
    missing = []
    matched = 0
    for idx in sorted(old_mods):
        body = old_mods[idx]
        if new_bodies.get(body, 0) > 0:
            new_bodies[body] -= 1
            matched += 1
        else:
            missing.append(idx)

    print(f"original modules: {len(old_mods)}")
    print(f"regenerated modules: {len(new_mods)}")
    print(f"exact-match bodies found in new bundle: {matched}")
    if missing:
        print("MISSING / CHANGED module indices:", missing)
        return 1
    print("ALL ORIGINAL MODULE BODIES PRESENT IN REGENERATED BUNDLE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
