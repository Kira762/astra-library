import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Button",
  description: "Create an Astra button element: a card that runs a callback on click, with a built-in tap glyph you can hide or replace.",
  path: "/docs/elements/button/",
});

export default function Button() {
  return (
    <>
      <PageHeader
        title="Button"
        description="Run a function when the player clicks."
        meta={<span className="pill">tab:CreateButton</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`tab:CreateButton({
    name = "Click Me",
    icon = "play",
    callback = function() print("clicked") end,
})`}
      />

      <H2 id="tap-glyph">Tap glyph</H2>
      <div className="prose-docs">
        <p>
          Every button carries a built-in tap glyph on its right edge — phosphor <C>hand-tap</C>,
          resolved through the icon catalog. Tapping the card fires the callback and pulses that
          glyph; the glyph is part of the card, so tapping it taps the button.
        </p>
      </div>
      <CodeBlock
        code={`-- hide the glyph
tab:CreateButton({ name = "Silent", icon = "bell-off", tapIcon = false, callback = function() end })

-- or replace it with any icon name or asset id
tab:CreateButton({ name = "Refresh", tapIcon = "refresh-cw", callback = function() end })`}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon: a pack name, a qualified name, or an asset id."],
          ["tapIcon", "false hides the right-edge glyph; a name or asset id replaces it."],
          ["callback", "Runs on click. No arguments."],
          ["description", "A muted helper line inside the card."],
        ]}
      />
      <Callout type="tip" title="A button has no flag">
        <p>
          Buttons fire and forget, so there is nothing to save. If you want the click to change
          something that persists, have the callback write a flag with{" "}
          <C>window:Set(&quot;someFlag&quot;, value)</C> — see{" "}
          <Link href="/docs/saving">Saving and flags</Link>.
        </p>
      </Callout>
      <Callout type="note" title="Handle">
        <p>
          The returned button supports <C>MoveTo</C>, <C>MoveToTop</C>, <C>MoveToBottom</C>,{" "}
          <C>MoveUp</C>, <C>MoveDown</C>, <C>Lock(reason?)</C>, <C>Unlock()</C> and{" "}
          <C>IsLocked()</C>.
        </p>
      </Callout>
    </>
  );
}
