import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Toggle",
  description: "Create an Astra toggle element: a boolean switch with a flag, a Set(value, skipCallback) handle and a Switch alias for declarative trees.",
  path: "/docs/elements/toggle/",
});

export default function Toggle() {
  return (
    <>
      <PageHeader
        title="Toggle"
        description="Switch a boolean on and off."
        meta={
          <>
            <span className="pill">tab:CreateToggle</span>
            <span className="pill">alias: Switch</span>
          </>
        }
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local toggle = tab:CreateToggle({
    name = "Auto Sprint",
    flag = "autoSprint",
    value = true,
    callback = function(on) print("Auto Sprint:", on) end,
})

toggle:Set(false)          -- fires the callback
toggle:Set(false, true)    -- silent
print(toggle.value)`}
      />

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Member", "Description"]}
        rows={[
          ["value", "The current boolean, readable at any time."],
          ["Set(value, skipCallback?)", "Set the switch. Pass true as the second argument to update the control without running the callback."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the control in its tab or group."],
          ["SetInfo(text)", "Add, retarget or remove the (!) badge at runtime — an empty text removes it."],
          ["Lock(reason?) / Unlock() / IsLocked()", "Take the control out of the player's hands; the reason shows on the card's description line."],
        ]}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon: pack name, qualified name, or asset id."],
          ["flag", "Save key. Derived from the name when omitted."],
          ["value", "Starting state. Defaults to false."],
          ["forgetState", "true keeps this control out of save/load."],
          ["callback", "Runs with the new boolean whenever the player flips it."],
          ["description", "A muted helper line inside the card."],
          ["info", "Optional (!) description: a badge right after the name reveals a floating description on hover, tap (tap again to close) or press-and-hold. Omitted or empty draws no badge."],
          ["infoIcon", "Replaces the (!) badge glyph. Defaults to circle-alert."],
        ]}
      />
      <Callout type="tip" title="Silent writes are how you restore state">
        <p>
          <C>Set(value, true)</C> is the pattern for pushing a value into a control without firing the
          callback again — useful when your own state is the source of truth. See{" "}
          <Link href="/docs/saving">Saving and flags</Link> for the flag side of the same idea.
        </p>
      </Callout>
      <Callout type="note" title="Switch">
        <p>
          <C>{'{ type = "Switch" }'}</C> is the declarative alias of the toggle control inside a{" "}
          <Link href="/docs/elements/collapsible-group">collapsible group</Link>&apos;s element list.
          The props and behaviour are the toggle&apos;s, spelled the way the declarative builder reads
          them.
        </p>
      </Callout>
    </>
  );
}
