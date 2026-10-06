#!/usr/bin/env node
/**
 * Strip comments and indentation from Luau source WITHOUT moving a line.
 *
 * Used by `scripts/generate_bundle.js` to shrink the published bundle. The
 * one rule that makes it safe to run on a signed, published artifact:
 *
 *   the output has EXACTLY the same number of lines as the input, and line
 *   N of the output is on line N of the input.
 *
 * A block comment is therefore replaced by as many newlines as it spanned
 * rather than by nothing, and indentation is dropped in place instead of
 * being joined onto the previous line. Nothing that Luau's own error
 * messages report -- the bundle's `LineOffsets[refId]` table, which maps a
 * closure's first bundle line back to line 1 of its virtual module -- can
 * drift, so `VirtualFullName:line: message` keeps pointing at the right
 * source line.
 *
 * What is removed:
 *   - `-- line comments` and `--[[ block comments ]]` / `--[==[ ... ]==]`
 *   - leading indentation, and runs of whitespace elsewhere collapse to one
 *     space (a separator, never a deletion -- `local` and `x` stay apart)
 *
 * What is deliberately kept:
 *   - `--!` directives (`--!strict`, `--!native`, `--!optimize`, `--!nolint`):
 *     those configure the compiler and the linter, they are not decoration.
 *   - every string, verbatim, including Luau interpolated strings.
 *
 * `scripts/strip_equivalence_test.sh` proves the semantics are unchanged by
 * compiling every published module with `luau-compile --binary` before and
 * after stripping and requiring the two blobs to be byte-identical.
 */

"use strict";

const NEWLINE = "\n";

function isHorizontalSpace(ch) {
  return ch === " " || ch === "\t" || ch === "\r" || ch === "\f" || ch === "\v";
}

function countNewlines(src, from, to) {
  let count = 0;
  for (let i = from; i < to; i++) if (src[i] === NEWLINE) count += 1;
  return count;
}

/**
 * `[==[` / `]==]` level parser. `pos` must point at the opening or closing
 * bracket. Returns the number of `=` signs, or -1 when it is not a long
 * bracket at all (a plain `[index]` for example).
 */
function longBracketLevel(src, pos, bracket) {
  if (src[pos] !== bracket) return -1;
  let i = pos + 1;
  let level = 0;
  while (src[i] === "=") {
    level += 1;
    i += 1;
  }
  if (src[i] !== bracket) return -1;
  return level;
}

function longBracketClose(level) {
  return "]" + "=".repeat(level) + "]";
}

function longBracketOpen(level) {
  return "[" + "=".repeat(level) + "[";
}

/**
 * A complete lexer walk of `src`, driven by one rule: everything is copied
 * through except comments (dropped, newlines preserved) and indentation
 * (dropped). Strings -- including Luau's interpolated `` `...{expr}...` ``
 * form, which may nest -- are copied byte for byte, because a byte that
 * looks like a comment opener inside a string is not one.
 *
 * `braceDepth` is only non-zero while walking the expression part of an
 * interpolated string; it lets the matching `}` close the interpolation
 * even when the expression itself contains table constructors.
 */
function walk(src, out, start, braceDepth) {
  let i = start;
  const n = src.length;
  let atLineStart = true;
  let pendingSpace = false;

  const flushSpace = () => {
    if (pendingSpace) {
      out.push(" ");
      pendingSpace = false;
    }
  };

  while (i < n) {
    const ch = src[i];

    if (ch === NEWLINE) {
      out.push(NEWLINE);
      i += 1;
      atLineStart = true;
      pendingSpace = false;
      continue;
    }

    if (isHorizontalSpace(ch)) {
      // Indentation goes; interior whitespace becomes a single separator.
      if (!atLineStart) pendingSpace = true;
      i += 1;
      continue;
    }

    // ---- comments ------------------------------------------------------
    if (ch === "-" && src[i + 1] === "-") {
      // `--!` directives are compiler/linter configuration, not prose.
      if (src[i + 2] === "!") {
        flushSpace();
        atLineStart = false;
        const nl = src.indexOf(NEWLINE, i);
        const stop = nl === -1 ? n : nl;
        out.push(src.slice(i, stop));
        i = stop;
        continue;
      }

      const level = longBracketLevel(src, i + 2, "[");
      if (level >= 0) {
        const close = longBracketClose(level);
        const end = src.indexOf(close, i + 2 + level + 2);
        const stop = end === -1 ? n : end + close.length;
        // Keep every newline the comment occupied: line numbers must hold.
        out.push(NEWLINE.repeat(countNewlines(src, i, stop)));
        i = stop;
        continue;
      }

      const nl = src.indexOf(NEWLINE, i);
      i = nl === -1 ? n : nl;
      continue;
    }

    // ---- the interpolation terminator ----------------------------------
    if (braceDepth > 0 && ch === "}") {
      out.push("}");
      return { index: i + 1, closed: true };
    }

    flushSpace();
    atLineStart = false;

    // ---- long strings --------------------------------------------------
    if (ch === "[") {
      const level = longBracketLevel(src, i, "[");
      if (level >= 0) {
        const close = longBracketClose(level);
        const end = src.indexOf(close, i + level + 2);
        const stop = end === -1 ? n : end + close.length;
        out.push(src.slice(i, stop));
        i = stop;
        continue;
      }
    }

    // ---- quoted strings ------------------------------------------------
    if (ch === '"' || ch === "'") {
      const stop = scanQuoted(src, i);
      out.push(src.slice(i, stop));
      i = stop;
      continue;
    }

    // ---- interpolated strings ------------------------------------------
    if (ch === "`") {
      i = scanInterpolated(src, i, out);
      continue;
    }

    if (ch === "{") {
      out.push("{");
      i += 1;
      continue;
    }

    out.push(ch);
    i += 1;
  }

  return { index: i, closed: false };
}

/** Index just past the closing quote (or the newline of an unterminated one). */
function scanQuoted(src, start) {
  const quote = src[start];
  let i = start + 1;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "\\") {
      i += 2;
      continue;
    }
    if (ch === quote) return i + 1;
    if (ch === NEWLINE) return i; // Luau strings do not span raw newlines
    i += 1;
  }
  return n;
}

/**
 * Copy a whole interpolated string verbatim. `{` opens a Lua expression
 * that is walked as ordinary code (so nested strings, nested interpolated
 * strings and nested table constructors are all handled) until its `}`.
 */
function scanInterpolated(src, start, out) {
  let i = start;
  const n = src.length;
  out.push("`");
  i += 1;
  while (i < n) {
    const ch = src[i];

    if (ch === "\\") {
      // `\u{1F600}` is one escape, not the start of an interpolation.
      if (src[i + 1] === "u" && src[i + 2] === "{") {
        const end = src.indexOf("}", i + 2);
        const stop = end === -1 ? n : end + 1;
        out.push(src.slice(i, stop));
        i = stop;
        continue;
      }
      out.push(src.slice(i, i + 2));
      i += 2;
      continue;
    }

    if (ch === "`") {
      out.push("`");
      return i + 1;
    }

    if (ch === "{") {
      out.push("{");
      const inner = walk(src, out, i + 1, 1);
      if (!inner.closed) return inner.index; // unterminated: stop here
      i = inner.index;
      continue;
    }

    out.push(ch);
    i += 1;
  }
  return n;
}

/**
 * Strip `src`. The result always has the same line count as `src`.
 * Throws when it would not, so a bug here can never ship a bundle whose
 * `LineOffsets` are quietly wrong.
 */
function stripLuau(src) {
  const out = [];
  walk(src, out, 0, 0);
  const result = out.join("");

  if (src.length > 0) {
    const before = src.split(NEWLINE).length;
    const after = result.split(NEWLINE).length;
    if (before !== after) {
      throw new Error(
        `strip: line count changed (${before} -> ${after}); refusing to emit a bundle with drifted LineOffsets`
      );
    }
  }
  return result;
}

module.exports = { stripLuau };

if (require.main === module) {
  const fs = require("fs");
  const [srcFile, dstFile] = process.argv.slice(2);
  if (!srcFile) {
    console.error("usage: node scripts/strip_luau.js <file.luau> [out.luau]");
    process.exit(2);
  }
  const src = fs.readFileSync(srcFile, "utf8");
  const dst = stripLuau(src);
  if (dstFile) fs.writeFileSync(dstFile, dst);
  const saved = 100 * (1 - dst.length / src.length);
  console.error(
    `${srcFile}: ${src.length} -> ${dst.length} bytes (-${saved.toFixed(1)}%), lines ${
      src.split(NEWLINE).length
    } preserved`
  );
}
