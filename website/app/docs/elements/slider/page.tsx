import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Slider",
  description: "Create an Astra slider element: pick a number inside a range with an increment, a suffix and a minimal card style.",
  path: "/docs/elements/slider/",
});

export default function Slider() {
  return (
    <>
      <PageHeader
        title="Slider"
        description="Pick a number in a range by dragging."
        meta={<span className="pill">tab:CreateSlider</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local slider = tab:CreateSlider({
    name = "Sensitivity",
    flag = "sens",
    range = { 1, 10 },
    value = 5,
    increment = 1,
    suffix = "x",
    minimal = true,
    callback = function(value, dragging)
        -- dragging is true while the player is still moving the handle,
        -- which is the moment to skip expensive work.
        print(value, dragging)
    end,
})`}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon: pack name, qualified name, or asset id."],
          ["flag", "Save key. Derived from the name when omitted."],
          ["range", "Two numbers: { min, max }."],
          ["value", "Starting value inside the range."],
          ["increment", "Step size between values. Defaults to whole numbers."],
          ["suffix", "Text appended to the readout, e.g. \"x\" or \"px\"."],
          ["minimal", "true trims the card down to the label, handle and value."],
          ["forgetState", "true keeps this control out of save/load."],
          ["callback", "Runs with (value, dragging) — dragging is true while the handle is held."],
        ]}
      />

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Member", "Description"]}
        rows={[
          ["value", "The current number."],
          ["Set(value, skipCallback?)", "Move the handle without running the callback when the second argument is true."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the control."],
          ["Lock(reason?) / Unlock() / IsLocked()", "Disable the control and show why."],
        ]}
      />
      <Callout type="tip" title="Act on release, not on drag">
        <p>
          Guard anything expensive behind <C>dragging</C>: apply the setting when it is{" "}
          <C>false</C>, and only update a label while it is <C>true</C>.
        </p>
      </Callout>
    </>
  );
}
