#!/usr/bin/env node
/**
 * Device-support guard for the exported site.
 *
 * The layout is verified by eye on real devices, but the things that make it
 * work everywhere are easy to delete by accident: one `viewport` key, one
 * `@media (pointer: coarse)` block, one `env(safe-area-inset-*)` padding. If
 * any of them disappears, phones get a page that pans sideways or draws under
 * the notch — and nothing in the build fails.
 *
 * So this script reads the export (and the handful of source files that own
 * the guarantees) and fails loudly when a guarantee is gone.
 *
 *   node scripts/check-device-support.mjs [export-dir]   # default: ./out
 *
 * Every check below is matched against text this repository writes by hand
 * (globals.css, layout.tsx, the components) — never against Tailwind's
 * generated output — so a dependency upgrade cannot make it cry wolf.
 */

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const websiteDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const exportDir = resolve(process.cwd(), process.argv[2] ?? join(websiteDir, "out"));

const results = [];
let failed = 0;

/** Record one pass/fail line. */
function check(label, ok, detail = "") {
  results.push({ label, ok, detail });
  if (!ok) failed += 1;
}

/** Collapse whitespace so a matched needle survives CSS minification. */
const squash = (text) => text.replace(/\s+/g, "");

/** Every file under `dir` whose name ends with one of `exts`. */
function walk(dir, exts) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return walk(path, exts);
    return exts.some((ext) => name.endsWith(ext)) ? [path] : [];
  });
}

const read = (path) => readFileSync(path, "utf8");

/* ------------------------------------------------------------------ *
 * 1. The export exists at all
 * ------------------------------------------------------------------ */

if (!existsSync(exportDir)) {
  console.error(`No export found at ${exportDir}. Run \`npm run build\` first.`);
  process.exit(1);
}

const htmlFiles = walk(exportDir, [".html"]);
const cssFiles = walk(exportDir, [".css"]);
const css = squash(cssFiles.map(read).join("\n"));

check("Export contains HTML pages", htmlFiles.length > 0, `${htmlFiles.length} pages`);
check("Export contains a stylesheet", cssFiles.length > 0, `${cssFiles.length} files`);
check("404.html exists for GitHub Pages", existsSync(join(exportDir, "404.html")));

/* ------------------------------------------------------------------ *
 * 2. Every page states how a phone should scale it
 * ------------------------------------------------------------------ */

const missingViewport = [];
const cappedZoom = [];

for (const file of htmlFiles) {
  const html = read(file);
  const meta = html.match(/<meta name="viewport" content="([^"]*)"/);
  const content = meta?.[1] ?? "";
  const wants = ["width=device-width", "initial-scale=1", "viewport-fit=cover"];
  if (!meta || wants.some((needle) => !content.includes(needle))) {
    missingViewport.push(relative(exportDir, file));
  }
  // Capping the scale would take pinch-zoom away from everyone who needs it.
  if (/maximum-scale|user-scalable=no/.test(content)) cappedZoom.push(relative(exportDir, file));
}

check(
  "Viewport meta on every page (device-width, initial-scale, viewport-fit=cover)",
  missingViewport.length === 0,
  missingViewport.slice(0, 3).join(", "),
);
check("Pinch-zoom is never disabled", cappedZoom.length === 0, cappedZoom.slice(0, 3).join(", "));

/* ------------------------------------------------------------------ *
 * 3. The CSS keeps the per-device behaviour
 * ------------------------------------------------------------------ */

const CSS_GUARANTEES = [
  ["Safe-area padding for notched phones", "env(safe-area-inset-left)"],
  ["Safe-area padding for notched phones (bottom)", "env(safe-area-inset-bottom)"],
  ["Viewport units follow mobile browser chrome (dvh)", "100dvh"],
  ["Touch targets and slider thumb (@media pointer: coarse)", "@media(pointer:coarse)"],
  ["High-contrast/forced-colour support", "@media(forced-colors:active)"],
  ["Print stylesheet", "@mediaprint"],
  ["Wide screens get a wider shell (1800px+)", "@media(min-width:1800px)"],
  ["Tables and code can scroll instead of widening the page", "overscroll-behavior-x:contain"],
  ["Long inline code wraps instead of pushing the page", "overflow-wrap:break-word"],
  ["The preview slider is styled for Blink/WebKit", ".range::-webkit-slider-thumb"],
  ["The preview slider is styled for Gecko", ".range::-moz-range-thumb"],
  ["Reduced-motion support", "@media(prefers-reduced-motion:reduce)"],
];

for (const [label, needle] of CSS_GUARANTEES) {
  check(`CSS: ${label}`, css.includes(squash(needle)));
}

/* The sticky panes are sized as `100dvh - <header height>`, so the two numbers
   live in different files and only work when they agree. Read the header
   height from the component that draws it rather than hard-coding a copy of it
   here: the check then fails when the two drift apart, which is exactly the
   mistake that took this page off the air once. */
const headerSource = read(join(websiteDir, "components", "site-header.tsx"));
const headerHeight = (headerSource.match(/flex h-(\d+)/) ?? [])[1];
const headerRem = headerHeight ? Number(headerHeight) / 4 : NaN;
const stickyNeedle = Number.isFinite(headerRem)
  ? `max-height:calc(100dvh-${headerRem}rem)`
  : null;

check(
  "Sticky panes size against the visible viewport",
  stickyNeedle !== null && css.includes(squash(stickyNeedle)),
  headerHeight ? `header is h-${headerHeight} -> expected ${stickyNeedle}` : "no header height found",
);

/* ------------------------------------------------------------------ *
 * 4. Source rules that keep the layout from growing wider than a phone
 * ------------------------------------------------------------------ */

const sourceFiles = [
  ...walk(join(websiteDir, "app"), [".tsx"]),
  ...walk(join(websiteDir, "components"), [".tsx"]),
];

if (sourceFiles.length > 0) {
  // A <table> needs an ancestor that scrolls, or it widens the whole page.
  const unscrolled = sourceFiles
    .filter((file) => read(file).includes("<table"))
    .filter((file) => {
      const source = read(file);
      return !source.includes("scroll-x") && !source.includes("overflow-x-auto");
    })
    .map((file) => relative(websiteDir, file));

  check("Every table sits in a horizontal scroller", unscrolled.length === 0, unscrolled.join(", "));

  // `w-screen` and `100vw` ignore the scrollbar and the safe-area insets.
  const fullBleed = sourceFiles
    .filter((file) => /w-screen|100vw/.test(read(file)))
    .map((file) => relative(websiteDir, file));

  check("No w-screen/100vw widths", fullBleed.length === 0, fullBleed.join(", "));

  // nowrap is fine on truncated labels; it is not fine on body copy or code
  // that has no scroll container of its own.
  const nowrap = sourceFiles
    .filter((file) => /whitespace-nowrap/.test(read(file)))
    .map((file) => relative(websiteDir, file));

  check("No whitespace-nowrap outside truncation", nowrap.length === 0, nowrap.join(", "));

  const globalsPath = join(websiteDir, "app", "globals.css");
  if (existsSync(globalsPath)) {
    const globals = read(globalsPath);
    // `overflow-x: hidden` on html/body turns the root into a scroll
    // container, which silently breaks every `position: sticky` pane.
    const rootClipped =
      /html\s*\{[^}]*overflow-x:\s*hidden/.test(globals) ||
      /body\s*\{[^}]*overflow-x:\s*hidden/.test(globals);
    check("Root element is not turned into a scroll container", !rootClipped);
  }
}

/* ------------------------------------------------------------------ *
 * Report
 * ------------------------------------------------------------------ */

const width = Math.max(...results.map((result) => result.label.length));
for (const result of results) {
  const mark = result.ok ? "ok  " : "FAIL";
  console.log(`${mark}  ${result.label.padEnd(width)}${result.detail ? `  (${result.detail})` : ""}`);
}

console.log("");
if (failed > 0) {
  console.error(
    `${failed} of ${results.length} device-support checks failed. ` +
      `If a change is intentional, update this script in the same commit — ` +
      `the guarantee it names is what keeps the site usable on a phone.`,
  );
  process.exit(1);
}

console.log(`All ${results.length} device-support checks passed (${relative(websiteDir, exportDir) || "."}).`);
