/**
 * A small Luau tokeniser for the docs' code samples.
 *
 * The site deliberately ships no syntax-highlighting dependency: the snippets
 * are short, the language they are written in is small, and the snippets are
 * exactly the thing this documentation exists to show. Shipping a slice of a
 * general-purpose highlighter to colour a hundred lines would cost more
 * JavaScript than the rest of the page put together.
 *
 * One pass, one alternation, no backtracking. Kinds map to CSS classes
 * (`.tok-*` in app/globals.css) rather than inline colours, so both themes and
 * the print stylesheet stay in one place.
 */

export type TokenKind =
  | "plain"
  | "comment"
  | "string"
  | "number"
  | "keyword"
  | "builtin"
  | "function"
  | "operator";

export type Token = { kind: TokenKind; value: string };

/** Words that are part of the grammar. */
const KEYWORDS = new Set([
  "and",
  "break",
  "continue",
  "do",
  "else",
  "elseif",
  "end",
  "export",
  "false",
  "for",
  "function",
  "if",
  "in",
  "local",
  "nil",
  "not",
  "or",
  "repeat",
  "return",
  "then",
  "true",
  "type",
  "until",
  "while",
]);

/** Every global an Astra snippet plausibly touches, plus the Roblox ones. */
const BUILTINS = new Set([
  "game",
  "workspace",
  "script",
  "shared",
  "require",
  "loadstring",
  "getgenv",
  "setclipboard",
  "print",
  "warn",
  "error",
  "assert",
  "pcall",
  "xpcall",
  "ipairs",
  "pairs",
  "next",
  "select",
  "tonumber",
  "tostring",
  "typeof",
  "unpack",
  "setmetatable",
  "getmetatable",
  "table",
  "string",
  "math",
  "os",
  "task",
  "coroutine",
  "bit32",
  "utf8",
  "buffer",
  "Instance",
  "Vector2",
  "Vector3",
  "CFrame",
  "Color3",
  "UDim",
  "UDim2",
  "Rect",
  "Enum",
  "Random",
  "TweenInfo",
  "HttpService",
  "Players",
  "ReplicatedStorage",
  "RunService",
  "UserInputService",
  "TweenService",
  "Lighting",
  "StarterGui",
  "tick",
  "time",
  "wait",
  "spawn",
  "delay",
  "self",
]);

/* One alternation, numbered groups rather than named ones: the project's
   TypeScript target predates named capture groups.

   Order matters — a long comment is matched before a line comment, a quoted
   string before a long string, and an identifier before an operator.

   1 comment · 2 string · 3 number · 4 word · 5 operator · 6 anything else */
const PATTERN =
  /(--\[\[[\s\S]*?\]\]|--[^\n]*)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|\[\[[\s\S]*?\]\])|(0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|(\.\.\.?|[-+*/%^#=~<>:]+)|([\s\S])/g;

const COMMENT = 1;
const STRING = 2;
const NUMBER = 3;
const WORD = 4;
const OPERATOR = 5;

const OPERATOR_CHARS = /[-+*/%^#=~<>:.]/;

/**
 * Splits Luau source into coloured tokens, preserving every character of the
 * original text. Callers render `value` verbatim; only the class changes.
 */
export function tokenizeLuau(source: string): Token[] {
  const tokens: Token[] = [];
  PATTERN.lastIndex = 0;

  let match: RegExpExecArray | null;
  while ((match = PATTERN.exec(source)) !== null) {
    const value = match[0];
    let kind: TokenKind = "plain";

    if (match[COMMENT] !== undefined) {
      kind = "comment";
    } else if (match[STRING] !== undefined) {
      kind = "string";
    } else if (match[NUMBER] !== undefined) {
      kind = "number";
    } else if (match[WORD] !== undefined) {
      const previous = lastSignificant(tokens);
      if (previous && (previous.value === "." || previous.value === ":")) {
        // A member call: `Astra:CreateWindow`, `task.spawn`.
        kind = "function";
      } else if (KEYWORDS.has(value)) {
        kind = "keyword";
      } else if (BUILTINS.has(value)) {
        kind = "builtin";
      } else if (/^\s*\(/.test(source.slice(match.index + value.length))) {
        kind = "function";
      }
      tokens.push({ kind, value });
      continue;
    } else if (match[OPERATOR] !== undefined || OPERATOR_CHARS.test(value)) {
      kind = "operator";
    }

    // Merge runs of like kinds so the DOM stays small: a run of spaces is one
    // node, not one node per space.
    const tail = tokens[tokens.length - 1];
    if (tail && tail.kind === kind) {
      tail.value += value;
    } else {
      tokens.push({ kind, value });
    }
  }

  return tokens;
}

/** The last token that is not whitespace — the lookbehind for member calls. */
function lastSignificant(tokens: Token[]): Token | undefined {
  for (let index = tokens.length - 1; index >= 0; index -= 1) {
    const token = tokens[index];
    if (token.kind !== "plain" || token.value.trim() !== "") return token;
  }
  return undefined;
}

/** Maps a token kind to the class that colours it, or undefined for plain. */
export function tokenClass(kind: TokenKind): string | undefined {
  switch (kind) {
    case "comment":
      return "tok-comment";
    case "string":
      return "tok-string";
    case "number":
      return "tok-number";
    case "keyword":
      return "tok-keyword";
    case "function":
      return "tok-function";
    default:
      return undefined;
  }
}
