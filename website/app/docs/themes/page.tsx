import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Themes",
  description: "Ten built-in Astra themes plus custom theme tables: swap the theme at runtime, or override individual colour keys and let the rest of the palette stand.",
  path: "/docs/themes/",
});

const THEMES = [
  ["default", "23, 153, 110", "#17996E"],
  ["amethyst", "177, 126, 230", "#B17EE6"],
  ["cobalt", "78, 157, 235", "#4E9DEB"],
  ["crimson", "224, 78, 84", "#E04E54"],
  ["ember", "226, 145, 58", "#E2913A"],
  ["emerald", "72, 199, 116", "#48C774"],
  ["frost", "86, 197, 235", "#56C5EB"],
  ["gold", "233, 196, 74", "#E9C44A"],
  ["onyx", "205, 210, 220", "#CDD2DC"],
  ["rose", "218, 105, 145", "#DA6991"],
];

export default function Themes() {
  return (
    <>
      <PageHeader
        title="Themes"
        description="Ten built-in themes, or bring your own. Swap one in at runtime and every colour tweens across."
        meta={<span className="pill">theme key: name or table</span>}
      />

      <H2 id="built-in">Built-in themes</H2>
      <div className="prose-docs">
        <p>
          Each theme is a full palette — background, surfaces, strokes, text tiers, success and warning
          colours — and each one is a module in <C>themes/</C> if you want to read the values.
        </p>
      </div>
      <div className="my-4 grid min-w-0 gap-2 sm:grid-cols-2">
        {THEMES.map(([name, rgb, hex]) => (
          <div key={name} className="card flex min-w-0 items-center gap-3 px-3 py-2.5">
            <span
              aria-hidden
              className="h-6 w-6 shrink-0 rounded-full border border-line"
              style={{ background: hex }}
            />
            <span className="font-mono text-sm text-ink">{name}</span>
            <span className="ml-auto font-mono text-xs text-subtle">AccentColor({rgb})</span>
          </div>
        ))}
      </div>
      <div className="prose-docs">
        <p>
          The landing page has a live version of this list — pick a chip under the window preview and
          the preview restyles, using the accent colours above.
        </p>
      </div>

      <H2 id="change">Change at runtime</H2>
      <CodeBlock
        code={`-- a built-in name
window:ChangeTheme("amethyst")

-- or a theme table of your own
window:ChangeTheme({
    ElementGradient = ColorSequence.new(Color3.fromRGB(20, 20, 30), Color3.fromRGB(30, 30, 45)),
    AccentColor = Color3.fromRGB(120, 90, 220),
})`}
      />
      <div className="prose-docs">
        <p>
          The same value can be handed to <C>theme</C> at construction time. Switching at runtime
          tweens colour properties rather than snapping them, and the tween runs through the{" "}
          <Link href="/docs/motion">motion service</Link>, so it follows the player&apos;s animation
          speed.
        </p>
      </div>

      <H2 id="custom">Custom theme tables</H2>
      <div className="prose-docs">
        <p>
          A theme table is a partial palette: keys you set are used, keys you leave out fall back to
          the base theme. That makes a one-line override — &quot;this hub is violet&quot; — a complete
          answer rather than a second full palette to maintain.
        </p>
      </div>
      <H2 id="keys">Theme keys</H2>
      <div className="prose-docs">
        <p>
          These are the keys worth knowing. Everything a theme declares is a colour, a ColorSequence
          or a number the window reads once and binds wherever it is used.
        </p>
      </div>
      <PropTable
        headers={["Key", "What it colours"]}
        rows={[
          ["Background", "The window's outer surface behind everything."],
          ["WindowSurface", "The main content surface cards sit on."],
          ["TabBackground", "The tab rail, as a ColorSequence for its gradient."],
          ["SliderBackground / SliderBackgroundHover", "Slider tracks in their two states."],
          ["StatBackground", "The stat card surface."],
          ["AccentColor", "The colour everything that matters is drawn in — toggles, sliders, highlights."],
          ["ElementGradient", "The gradient used across element cards."],
          ["Text tiers", "Title, content and muted copy read from the same palette."],
          ["Success / Warning", "Semantic colours for changelog symbols, validation and status."],
        ]}
      />
      <Callout type="tip" title="Start from AccentColor">
        <p>
          Almost every visible accent reads from <C>AccentColor</C>. Set that one key with a theme table
          and the window already looks like yours; add the rest only where you need control.
        </p>
      </Callout>
      <Callout type="note" title="The player can still change it">
        <p>
          The theme is a setting, not a lock: <strong>Settings → Appearance → Theme</strong> offers the
          built-ins with an Apply confirmation, so a player can move off your palette.
        </p>
      </Callout>
    </>
  );
}
