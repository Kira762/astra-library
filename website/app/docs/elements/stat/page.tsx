import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Stat",
  description: "Create an Astra stat element: a read-only value that rolls on change, with percentage or delta readouts and text-value badges.",
  path: "/docs/elements/stat/",
});

export default function Stat() {
  return (
    <>
      <PageHeader
        title="Stat"
        description="A read-only value that rolls on change and shows how far it moved."
        meta={<span className="pill">tab:CreateStat</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local stat = tab:CreateStat({
    name = "Kills",
    value = 128,
    prefix = "",
    suffix = " kills",
})

stat:Set(200)              -- rolls to the new number
stat:ResetBaseline(0)      -- measure the next change from 0`}
      />

      <H2 id="display">Display modes</H2>
      <PropTable
        headers={["Prop", "Values"]}
        rows={[
          ["display", "\"value\" shows the number itself (the default); \"change\" shows how far it moved."],
          ["changeMode", "\"percentage\" or \"delta\" — how the change is expressed when a change is shown."],
          ["changeBaseline", "\"previous\" (default) measures against the last value; \"initial\" measures against the starting value. Any other value, a number included, reads as \"previous\"."],
          ["numberEasing", "Whether the readout eases towards its target instead of snapping."],
          ["compact", "Trims the card for a dense row of stats."],
          ["prefix / suffix", "Text on either side of the number, e.g. a currency symbol or a unit."],
        ]}
      />
      <div className="prose-docs">
        <p>
          To measure from an explicit number, call <C>stat:ResetBaseline(value)</C> — that is the way
          to set a numeric baseline, since a number passed as <C>changeBaseline</C> is read as{" "}
          <C>&quot;previous&quot;</C>.
        </p>
      </div>

      <H2 id="text-values">Text values</H2>
      <div className="prose-docs">
        <p>
          A stat&apos;s value may be a string. Text renders as a single-letter badge by default —{" "}
          <C>letter = true</C> is the same thing, spelled explicitly. With{" "}
          <C>letter = false</C> the whole value reads out as text instead: one label, no digit roll and
          no change readout.
        </p>
      </div>
      <CodeBlock
        code={`local theme = tab:CreateStat({ name = "Current theme", value = "Default", letter = false })

theme:SetText("Emerald")   -- the card reads "Emerald", not "E"`}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon, unless the value renders as a letter badge."],
          ["value", "Starting number, or a string for a text stat."],
          ["prefix / suffix", "Text around the readout."],
          ["display", "\"value\" or \"change\"."],
          ["changeMode", "\"percentage\" or \"delta\"."],
          ["changeBaseline", "\"previous\" or \"initial\"; use ResetBaseline for a numeric baseline."],
          ["numberEasing", "Ease the readout towards the target instead of snapping."],
          ["compact", "Dense card for rows of stats."],
          ["letter", "true forces a single-letter badge; false forces the full text readout."],
        ]}
      />

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Method", "Description"]}
        rows={[
          ["Set(value)", "Write a number (or a string) and roll the readout."],
          ["SetText(text)", "Write a text value explicitly."],
          ["ResetBaseline(value?)", "Set what the next change is measured against."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the card."],
        ]}
      />
      <Callout type="note" title="Stats move, but they do not lock">
        <p>
          A stat has no callback and no interaction beyond its readout, and it is moveable rather than
          lockable — there is nothing for a player to disable. Use a{" "}
          <C>display = &quot;change&quot;</C> stat for movement and a plain one for totals.
        </p>
      </Callout>
    </>
  );
}
