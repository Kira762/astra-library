#!/usr/bin/env python3
"""Flag repo-path references in .luau/.md files that no longer exist.

When a file is deleted, source comments, docs and test headers can keep
naming it and nothing notices until a reader follows the stale path — this
is how deleted modules and moved files stayed cited in the tree.

Scope is deliberately narrow so the check stays silent on prose:

- Only slash-anchored paths whose first segment is a top-level source
  directory are considered (`themes/default.luau`, `components/window.luau`,
  `scripts/check_all.sh`). Bare names (`file.luau`, `skills.sh`, `profile.txt`)
  are too ambiguous to judge and are ignored.
- URLs are stripped first, and tree-diagram lines (`├──`, `└──`) are skipped
  because their paths are relative to the diagram's own root, not the repo.
- A path resolves against the referencing file's directory first (relative
  Markdown links), then the repo root, with `.luau` / `.md` / `init.luau`
  retries for extensionless module references (`cache/imageCache` ->
  `cache/imageCache.luau`, `components/window.luau` -> `components/window/init.luau`).
- Historical records (CHANGELOG.md, ANALYSIS.md, PERFORMANCE_CHANGES.md),
  the generated bundle (version-1.luau) and hidden/vendored directories are
  out of scope: they describe past states on purpose.
- A hit on a line containing deleted/removed/no longer (or the line right
  after, for headings like MODULES.md's "### `components/changelogPanel.luau`"
  whose next line reads "Deleted.") is intentional history. A line can also
  opt out with the marker `dangling-ok`.

Exit 0 = clean, 1 = hits found (prints file:line: path).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

HISTORICAL_FILES = {"CHANGELOG.md", "ANALYSIS.md", "PERFORMANCE_CHANGES.md"}
GENERATED_FILES = {"version-1.luau"}
TOP_LEVEL_DIRS = {
    "core", "components", "elements", "settings", "cache", "functions",
    "layouts", "images", "icons", "themes", "utilities", "scripts",
    "skills", "assets",
}

TOKEN_RE = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_./\-]*")
URL_RE = re.compile(r"https?://\S+")
TREE_RE = re.compile(r"[├└]")
HISTORY_RE = re.compile(r"deleted|removed|no longer|dangling-ok", re.IGNORECASE)


def skip_file(rel: Path) -> bool:
    if any(part.startswith(".") or part == "node_modules" for part in rel.parts):
        return True
    return rel.name in HISTORICAL_FILES or rel.name in GENERATED_FILES


def is_repo_path_token(token: str) -> bool:
    if "/" not in token:
        return False
    first = token.split("/", 1)[0]
    return first in TOP_LEVEL_DIRS


def resolves(token: str, referencing_file: Path) -> bool:
    name = Path(token).name
    has_extension = "." in name
    bases = [referencing_file.parent, ROOT]
    for base in bases:
        candidate = (base / token).resolve()
        if candidate.exists():
            return True
        if not has_extension:
            if Path(str(candidate) + ".luau").exists():
                return True
            if Path(str(candidate) + ".md").exists():
                return True
            if (candidate / "init.luau").exists():
                return True
        elif token.endswith(".luau"):
            # Rojo init semantics: `components/window.luau` may mean the
            # folder module `components/window/init.luau`.
            if (candidate.parent / candidate.stem / "init.luau").exists():
                return True
    return False


def main() -> int:
    hits = []
    scanned = 0
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.suffix not in {".luau", ".md"}:
            continue
        rel = path.relative_to(ROOT)
        if skip_file(rel):
            continue
        scanned += 1
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for lineno, raw_line in enumerate(lines, 1):
            if TREE_RE.search(raw_line):
                continue
            # History on this line or the next one (a heading followed by
            # "Deleted." on its own line still counts as intentional).
            context = raw_line
            if lineno < len(lines):
                context = raw_line + "\n" + lines[lineno]
            if HISTORY_RE.search(context):
                continue
            line = URL_RE.sub(" ", raw_line)
            for match in TOKEN_RE.finditer(line):
                token = match.group(0).rstrip(".")
                if not token or not is_repo_path_token(token):
                    continue
                if not resolves(token, path):
                    hits.append(f"{rel}:{lineno}: {token}")
    if hits:
        print("\n".join(hits))
        print(f"\n{len(hits)} dangling reference(s) across {scanned} file(s)")
        return 1
    print(f"no dangling repo references ({scanned} file(s) checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
