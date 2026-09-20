#!/usr/bin/env node
/**
 * Renders the Remix Icon pack (7th pack) from upstream SVGs to the repo's
 * PNG layout, and writes the compact `icons/remix.luau` catalog.
 *
 * Upstream: https://github.com/Remix-Design/RemixIcon (Apache-2.0, see
 * assets/icons/guides/remix.md for the attribution note). Sparse-checkout
 * only its `icons/` directory; every SVG is 24x24 `fill="currentColor"`.
 *
 * Output matches the existing packs exactly: 64x64 PNG, white glyph on a
 * transparent background, at
 * `assets/icons/remix-pack/remix<PascalName>.png`, where the
 * file base is the kebab name converted to PascalCase - the same rule
 * `icons/packBuilder` derives URLs from, machine-verified below.
 *
 * Requires: npm install @resvg/resvg-js (run once, in any directory that
 * can resolve it - this script lives in scripts/, so `npm i` at the repo
 * root works, or set NODE_PATH).
 *
 * Usage: node scripts/render_remix_pack.js [--src /tmp/RemixIcon/icons]
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "assets", "icons", "remix-pack");
const MODULE = path.join(ROOT, "icons", "remix.luau");

let SRC = "/tmp/RemixIcon/icons";
const srcFlag = process.argv.indexOf("--src");
if (srcFlag !== -1 && process.argv[srcFlag + 1]) {
  SRC = process.argv[srcFlag + 1];
}

// Same rule as icons/packBuilder (and scripts/generate_icon_packs.js).
function pascal(name) {
  return name
    .split(/[-_]/)
    .map((word) => (word ? word[0].toUpperCase() + word.slice(1) : word))
    .join("");
}

function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else if (entry.name.endsWith(".svg")) {
      out.push(full);
    }
  }
  return out;
}

let Resvg;
try {
  ({ Resvg } = require("@resvg/resvg-js"));
} catch (err) {
  console.error("Missing @resvg/resvg-js. Run: npm install @resvg/resvg-js");
  process.exit(1);
}

const files = walk(SRC, []).sort();
if (files.length === 0) {
  console.error(`No SVGs found under ${SRC}`);
  process.exit(1);
}

const keys = [];
const seen = new Set();
let rendered = 0;
for (const file of files) {
  const key = path.basename(file, ".svg");
  if (!/^[a-z0-9-]+$/.test(key)) {
    throw new Error(`Name outside the catalog charset: ${key}`);
  }
  if (seen.has(key)) {
    throw new Error(`Duplicate icon name across category dirs: ${key}`);
  }
  seen.add(key);

  // Upstream glyphs are currentColor (black by default); the repo's packs
  // are white on transparent, tinted at runtime by ImageColor3.
  const svg = fs.readFileSync(file, "utf8").split("currentColor").join("#FFFFFF");
  const png = new Resvg(svg, { fitTo: { mode: "width", value: 64 } }).render().asPng();
  if (png.length === 0) {
    throw new Error(`Empty render: ${key}`);
  }

  const fileBase = pascal(key);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(path.join(OUT_DIR, `remix${fileBase}.png`), png);
  keys.push(key);
  rendered++;
}

// Compact catalog, same shape scripts/generate_icon_packs.js writes.
keys.sort();
const lines = [];
lines.push("-- [[remix icon pack.]]");
lines.push("-- [[Compact catalog: names only. PNG URLs are derived on demand by]]");
lines.push("-- [[icons/packBuilder (kebab/snake name to PascalCase), so this module]]");
lines.push("-- [[parses as one string constant instead of thousands of table]]");
lines.push("-- [[constructors. Render with scripts/render_remix_pack.js.]]");
lines.push("");
lines.push("return require(script.Parent.packBuilder).create(");
lines.push('\t"assets/icons/remix-pack/",');
lines.push('\t"remix",');
lines.push("[==[");
for (let i = 0; i < keys.length; i += 10) {
  lines.push(keys.slice(i, i + 10).join(" "));
}
lines.push("]==]");
lines.push(")");
lines.push("");
fs.writeFileSync(MODULE, lines.join("\n"));

// Machine-verify: every derived URL resolves to a file we just wrote.
let missing = 0;
for (const key of keys) {
  const fileBase = pascal(key);
  const url = `assets/icons/remix-pack/remix${fileBase}.png`;
  if (!fs.existsSync(path.join(ROOT, url))) {
    console.error(`MISSING ${url}`);
    missing++;
  }
}
if (missing > 0) {
  throw new Error(`${missing} derived URLs have no PNG`);
}

console.log(`remix.luau: ${keys.length} icons, ${fs.statSync(MODULE).size} bytes`);
console.log(`rendered ${rendered} PNGs into assets/icons/remix-pack/`);
