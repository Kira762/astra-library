#!/usr/bin/env python3
"""Flag custom-Lua-field writes on Roblox instances.

Roblox instances reject unknown members, so code like

    window.profileAvatar = window:Create("ImageLabel", {...})
    window.profileAvatar._myFlag = value   -- THROWS at runtime

is a crash. Instances in Astra are created via `window:Create(...)` /
`Instance.new(...)`, so this check:

1. Collects the names of fields assigned from `*:Create(` / `Instance.new(`
   calls (e.g. `window.profileAvatar = ...` marks `window.profileAvatar`).
2. Flags any later `<x>.<field> = ...` where `<x>.<field>` was collected as
   an instance holder, unless the field is a real Roblox member (allowlist:
   common property names starting uppercase, plus known children holders).

Scope: the modular tree only.

- Hidden/vendored directories (.git, .tools, .agents, ...) are skipped.
- `version-1.luau` is skipped on purpose: the bundle inlines every module
  into one file, so a per-file holder set leaks across module scopes and
  false-flags unrelated same-name locals (e.g. footer's `local image = ...
  :Create("ImageLabel")` colliding with the `image` module table's
  `image.rewrites = ...` writes). The bundle is generated from this tree
  and bundle freshness is gated separately in check_all.sh.

Exit 0 = clean, 1 = violations found (prints file:line).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_NAMES = {"version-1.luau"}

CREATE_RE = re.compile(
    r"([A-Za-z_][\w.]*)\s*=\s*(?:(?:window|self\.window)[%s]?\s*:%sCreate|Instance\.new)"
    % ("%", ":")
)
# Simpler: match `x = <anything>:Create(` or `x = Instance.new(`
ASSIGN_CREATE_RE = re.compile(r"^\s*(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*(?:.*?):Create\s*\(")
INSTANCE_NEW_RE = re.compile(r"^\s*(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*Instance\.new\s*\(")
FIELD_WRITE_RE = re.compile(r"^\s*([A-Za-z_][\w.]*)\.([A-Za-z_]\w*)\s*=(?!=)")

# Fields that are legitimate Roblox members (upper-case properties, plus a few
# lowercase APIs like Parent). Custom Astra state is lowerCamel with a leading
# underscore or lowercase word, so anything upper-case is safe.
SAFE_FIELD = re.compile(r"^[A-Z]")


def luau_files():
    for path in sorted(ROOT.rglob("*.luau")):
        rel = path.relative_to(ROOT)
        if any(part.startswith(".") or part == "node_modules" for part in rel.parts):
            continue
        if rel.name in SKIP_NAMES:
            continue
        yield path


def main():
    violations = []
    for path in luau_files():
        rel = path.relative_to(ROOT)
        instance_holders = set()
        lines = path.read_text(encoding="utf-8").splitlines()
        for lineno, line in enumerate(lines, 1):
            m = ASSIGN_CREATE_RE.match(line) or INSTANCE_NEW_RE.match(line)
            if m:
                instance_holders.add(m.group(1))
                continue
            w = FIELD_WRITE_RE.match(line)
            if w:
                holder, field = w.group(1), w.group(2)
                if holder in instance_holders and not SAFE_FIELD.match(field):
                    violations.append(
                        f"{rel}:{lineno}: custom field '{field}' written on "
                        f"instance holder '{holder}': {line.strip()[:100]}"
                    )
    if violations:
        print("\n".join(violations))
        print(f"\n{len(violations)} violation(s)")
        return 1
    print("no custom-field writes on instance holders")
    return 0


if __name__ == "__main__":
    sys.exit(main())
