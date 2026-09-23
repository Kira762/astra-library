#!/usr/bin/env python3
"""Require-path and cycle checker for the Astra modular tree.

Resolves every static require() in the source modules (handling the
`local utility = script.Parent.Parent.utilities` alias convention), verifies
the target file exists, and reports dependency cycles between modules.
Exit code 1 on any problem.
"""
import os, re, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DIRS = ["core", "components", "elements", "settings", "cache", "functions",
        "images", "icons", "themes", "utilities"]
ENTRY = "library_entrypoint.luau"

files = []
for d in DIRS:
    for dirpath, _, fnames in os.walk(d):
        for fn in sorted(fnames):
            if fn.endswith(".luau"):
                files.append(os.path.join(dirpath, fn))
files.append(ENTRY)

# alias name -> luau path expression prefix (script-tree style), e.g.
#   utility -> script.Parent.Parent.utilities
def resolve_expr(expr, filepath, aliases, base=None):
    expr = expr.strip()
    # expand leading alias (e.g. `utility.constants` where
    # `local utility = script.Parent.Parent.utilities`)
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\.(.+)$", expr)
    if m and m.group(1) in aliases:
        expr = aliases[m.group(1)] + "." + m.group(2)
    if expr.startswith("("):  # e.g. (script :: any).Parent — skip
        return None
    # dynamic: script.Parent[...] or script.Parent[componentName]
    if "[" in expr:
        # require(script.Parent[componentName]) => same directory as script
        if re.match(r"^script\.Parent(\.Parent)?\[", expr):
            ups = 2 if ".Parent.Parent[" in expr else 1
            d = os.path.dirname(filepath)
            for _ in range(ups - 1):
                d = os.path.dirname(d)
            return ("dyn", d)
        return None
    segs = expr.split(".")
    if segs[0] != "script":
        return None
    # Walk segments from `script`: `Parent` ascends one directory, anything
    # else names a child (file, folder, or init-folder). For init.luau files,
    # `script` IS the folder ModuleScript, so start at the folder.
    node = base if base is not None else filepath
    for seg in segs[1:]:
        if seg == "Parent":
            node = os.path.dirname(node)
        else:
            node = os.path.join(node, seg)
    # target forms: file.luau | folder | folder/init.luau
    if os.path.isfile(node + ".luau"):
        return ("mod", node + ".luau")
    if os.path.isdir(node):
        init = os.path.join(node, "init.luau")
        if os.path.isfile(init):
            return ("mod", init)
        return ("folder", node)
    return ("missing", node)

def scan_aliases(src):
    # `local x = script.Parent[.Parent...][.name]` — capture any trailing
    # `.name` too, so alias chains like `utility.Parent.core.state` resolve.
    aliases = {}
    for m in re.finditer(
        r"local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
        r"(script(?:\.Parent)+(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*$",
        src,
        re.MULTILINE,
    ):
        aliases[m.group(1)] = m.group(2)
    return aliases

broken = []
graph = defaultdict(set)  # module -> set of modules it requires
modules = set(files)

for f in files:
    src = open(f).read()
    aliases = scan_aliases(src)
    # Rojo init semantics: init.luau IS the folder's ModuleScript, so `script`
    # starts at the folder, not at the file itself.
    base = os.path.dirname(f) if os.path.basename(f) == "init.luau" else f
    for m in re.finditer(r"require\(([^)]+)\)", src):
        res = resolve_expr(m.group(1), f, aliases, base)
        if res is None:
            continue  # dynamic / unresolvable-expr (documented exceptions)
        kind, target = res
        if kind == "missing":
            broken.append((f, m.group(1).strip(), target))
        elif kind == "mod":
            graph[f].add(target)

if broken:
    print("BROKEN REQUIRES:")
    for b in broken:
        print("  %s -> %s (missing: %s)" % b)
    sys.exit(1)

# cycle detection (DFS)
WHITE, GRAY, BLACK = 0, 1, 2
color = defaultdict(int)
stack = []
cycles = []

def dfs(u):
    color[u] = GRAY
    stack.append(u)
    for v in sorted(graph[u]):
        if color[v] == GRAY:
            i = stack.index(v)
            cycles.append(stack[i:] + [v])
        elif color[v] == WHITE:
            dfs(v)
    stack.pop()
    color[u] = BLACK

for f in sorted(files):
    if color[f] == WHITE:
        dfs(f)

print("files: %d, resolved require edges: %d" % (len(files), sum(len(v) for v in graph.values())))
if cycles:
    print("CYCLES DETECTED (%d):" % len(cycles))
    for c in cycles[:10]:
        print("  " + " -> ".join(c))
    sys.exit(1)

print("ALL STATIC REQUIRES RESOLVE; NO CYCLES IN STATIC GRAPH")
