import type { Config } from "tailwindcss";

/** Colours resolve to the CSS channel variables in app/globals.css. */
const token = (name: string) => `rgb(var(--c-${name}) / <alpha-value>)`;

export default {
  // The theme toggle puts `.dark` or `.light` on <html>, so the variant follows the class.
  darkMode: "class",
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        base: token("base"),
        surface: token("surface"),
        raised: token("raised"),
        line: token("line"),
        "line-soft": token("line-soft"),
        "line-strong": token("line-strong"),
        ink: token("ink"),
        muted: token("muted"),
        subtle: token("subtle"),
        accent: {
          DEFAULT: token("accent"),
          soft: token("accent-soft"),
          ink: token("accent-ink"),
        },
        gold: token("gold"),
        success: token("success"),
        warning: token("warning"),
        danger: token("danger"),
        info: token("info"),
      },
      fontFamily: {
        display: ['"Archivo Variable"', "Archivo", "system-ui", "sans-serif"],
        sans: ['"Instrument Sans Variable"', '"Instrument Sans"', "system-ui", "sans-serif"],
        mono: ['"JetBrains Mono Variable"', "ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
      /* One scale, by role. Line-heights are unitless so they follow the size,
         and headings tighten as they grow instead of inheriting a text
         leading that only suits paragraphs. */
      fontSize: {
        // 12px — the floor: metadata, keycaps, badges.
        "2xs": ["0.75rem", { lineHeight: "1.0625rem", letterSpacing: "0.005em" }],
        // 13px — captions, table headers, tab labels.
        xs: ["0.8125rem", { lineHeight: "1.3125rem" }],
        // 14px — interface text: nav, tables, cards, buttons.
        sm: ["0.875rem", { lineHeight: "1.5rem" }],
        // 16px — long-form reading.
        base: ["1rem", { lineHeight: "1.65" }],
        lg: ["1.125rem", { lineHeight: "1.55" }],
        xl: ["1.25rem", { lineHeight: "1.35" }],
        "2xl": ["1.5rem", { lineHeight: "1.2" }],
        "3xl": ["1.875rem", { lineHeight: "1.15" }],
        "4xl": ["2.25rem", { lineHeight: "1.1" }],
        "5xl": ["3rem", { lineHeight: "1.05" }],
        "6xl": ["3.5rem", { lineHeight: "1.03" }],
      },
      borderRadius: {
        inner: "8px",
        control: "10px",
        card: "16px",
      },
      /* Concentric where it matters: the ring sits inside the 1px border the
         component already draws, so radius changes read as one shape. */
      boxShadow: {
        frame: "0 1px 2px -1px rgb(0 0 0 / 0.28), 0 16px 40px -32px rgb(0 0 0 / 0.75)",
        lift: "0 2px 4px -2px rgb(0 0 0 / 0.35), 0 20px 44px -34px rgb(0 0 0 / 0.9)",
        pop: "0 24px 64px -32px rgb(0 0 0 / 0.9)",
      },
      maxWidth: {
        shell: "1500px",
        // 65 characters is the comfortable end of a reading measure; the old
        // 72ch was long enough that the eye lost the line on wide screens.
        prose: "65ch",
      },
      transitionTimingFunction: {
        out: "cubic-bezier(0.22, 1, 0.36, 1)",
        swift: "cubic-bezier(0.2, 0, 0, 1)",
      },
    },
  },
  plugins: [],
} satisfies Config;
