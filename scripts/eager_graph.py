#!/usr/bin/env python3
"""Measure the eager (transitive) module graph loaded at Astra startup.

Starts from library_entrypoint.luau and follows static require() edges,
reporting module count, total line count, and which folders got loaded.
Compares "eager" vs "with lazy icons excluded" to quantify the Phase 6 win.
"""
import os, re, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

graph = defaultdict(set)
lines = {}

def scan(f):
    if f in lines:
        return
    src = open(f).read()
    lines[f] = src.count("\n") + 1
    aliases = {}
    for m in re.finditer(r"local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(script(?:\.Parent)+(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*$", src, re.MULTILINE):
        aliases[m.group(1)] = m.group(2)
    for m in re.finditer(r"require\(([^)]+)\)", src):
        expr = m.group(1).strip()
        mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\.(.+)$", expr)
        if mm and mm.group(1) in aliases:
            expr = aliases[mm.group(1)] + "." + mm.group(2)
        segs = expr.split(".")
        if not expr.startswith("script"):
            continue
        # Rojo init semantics: init.luau IS the folder ModuleScript, so
        # `script` starts at the folder for init files.
        node = os.path.dirname(f) if os.path.basename(f) == "init.luau" else f
        for seg in segs[1:]:
            if seg == "Parent":
                node = os.path.dirname(node)
            else:
                node = os.path.join(node, seg)
        target = None
        if os.path.isfile(node + ".luau"):
            target = node + ".luau"
        elif os.path.isdir(node) and os.path.isfile(os.path.join(node, "init.luau")):
            target = os.path.join(node, "init.luau")
        elif os.path.isdir(node):
            # requiring a plain folder (e.g. themes as namespace) — count the
            # folder itself as an edge but no eager load of its children
            continue
        if target:
            graph[f].add(target)
            scan(target)

scan("library_entrypoint.luau")

def report(exclude_dir=None):
    seen = set()
    stack = ["library_entrypoint.luau"]
    while stack:
        cur = stack.pop()
        if cur in seen:
            continue
        seen.add(cur)
        for nxt in graph[cur]:
            if exclude_dir and nxt.startswith(exclude_dir + os.sep):
                continue
            stack.append(nxt)
    total = sum(lines[f] for f in seen)
    folders = defaultdict(int)
    for f in seen:
        top = f.split(os.sep)[0]
        folders[top] += 1
    return seen, total, folders

eager, eager_lines, eager_folders = report()
no_icons, no_icons_lines, _ = report("icons")

print("=== eager startup graph (from library_entrypoint) ===")
print("modules: %d   lines: %d" % (len(eager), eager_lines))
for d in sorted(eager_folders):
    print("  %-12s %d" % (d, eager_folders[d]))
print()
print("=== same graph with icons/ lazily excluded (Phase 6 design) ===")
print("modules: %d   lines: %d" % (len(no_icons), no_icons_lines))
print()
if "icons/init.luau" in eager:
    icon_pack_lines = sum(lines[os.path.join("icons", p)] for p in
                          ["lucide.luau","material.luau","tabler.luau","phosphor.luau","heroicons.luau","feather.luau"]
                          if os.path.exists(os.path.join("icons", p)))
    print("icon pack data lines (loaded only on first pack lookup): %d" % icon_pack_lines)
