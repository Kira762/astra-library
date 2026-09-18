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
      fontSize: {
        "2xs": ["0.6875rem", { lineHeight: "1.05rem" }],
      },
      maxWidth: {
        shell: "1500px",
        prose: "72ch",
      },
      transitionTimingFunction: {
        out: "cubic-bezier(0.22, 1, 0.36, 1)",
      },
    },
  },
  plugins: [],
} satisfies Config;
