#!/usr/bin/env node
/**
 * Regenerates the six compact icon-pack modules from their previous
 * key -> PascalName table form is not needed at runtime any more: every PNG
 * file base is the catalog name converted to PascalCase (machine-verified),
 * so packs now ship as a newline-separated name list and icons/packBuilder
 * derives URLs lazily on first lookup.
 *
 * This generator is idempotent only against a git checkout that still
 * contains the verbose tables; it writes /tmp/expected_icons.json with the
 * fully expanded URL map for exhaustive runtime verification.
 *
 * Usage: node scripts/generate_icon_packs.js
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PACKS = ["lucide", "material", "tabler", "phosphor", "heroicons", "feather"];

function pascal(name) {
  return name
    .split(/[-_]/)
    .map((word) => (word ? word[0].toUpperCase() + word.slice(1) : word))
    .join("");
}

const expected = {};

for (const pack of PACKS) {
  const file = path.join(ROOT, "icons", pack + ".luau");
  const src = fs.readFileSync(file, "utf8");

  const header = src.match(/expand\((".*?"),\s*(".*?"),\s*\{/);
  if (!header) {
    // Already compact: nothing to do (re-running is safe).
    continue;
  }
  const prefix = header[1].slice(1, -1);
  const packName = header[2].slice(1, -1);

  const pair = /\[\s*"([^"]+)"\s*\]\s*=\s*"([^"]+)"/g;
  const keys = [];
  const urls = {};
  let match;
  while ((match = pair.exec(src))) {
    keys.push(match[1]);
    const fileBase = pascal(match[1]);
    if (fileBase !== match[2]) {
      throw new Error(`${pack}: ${match[1]} derives ${fileBase}, expected ${match[2]}`);
    }
    urls[match[1]] = prefix + packName + fileBase + ".png";
  }
  expected[pack] = urls;

  const lines = [];
  lines.push(`-- [[${pack} icon pack.]]`);
  lines.push("-- [[Compact catalog: names only. PNG URLs are derived on demand by]]");
  lines.push("-- [[icons/packBuilder (kebab/snake name to PascalCase), so this module]]");
  lines.push("-- [[parses as one string constant instead of thousands of table]]");
  lines.push("-- [[constructors. Regenerate with scripts/generate_icon_packs.js.]]");
  lines.push("");
  lines.push("return require(script.Parent.packBuilder).create(");
  lines.push(`\t"${prefix}",`);
  lines.push(`\t"${packName}",`);
  lines.push("[==[");
  for (let i = 0; i < keys.length; i += 10) {
    lines.push(keys.slice(i, i + 10).join(" "));
  }
  lines.push("]==]");
  lines.push(")");
  lines.push("");

  fs.writeFileSync(file, lines.join("\n"));
  console.log(`${pack}.luau: ${keys.length} icons, ${fs.statSync(file).size} bytes`);
}

fs.writeFileSync("/tmp/expected_icons.json", JSON.stringify(expected));
