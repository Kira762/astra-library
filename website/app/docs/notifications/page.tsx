import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Notifications and popups",
  description: "Tell the player something happened with window:Notify, or ask for a decision with window:Popup \u2014 props, options, boxes and dismissal.",
  path: "/docs/notifications/",
});

export default function Notifications() {
  return (
    <>
      <PageHeader
        title="Notifications and popups"
        description="Two ways to tell the player something happened: a card that arrives and leaves on its own, and a modal that waits for an answer."
      />

      <H2 id="notify">Notify</H2>
      <CodeBlock
        code={`window:Notify({
    title = "Loaded",
    content = "Everything is ready.",
    icon = "check",
    duration = 5,
})`}
      />
      <PropTable
        headers={["Prop", "Description"]}
        rows={[
          ["title", "The bold first line."],
          ["content", "The body copy."],
          ["icon", "Optional icon, resolved across all packs."],
          ["duration", "Seconds before the card dismisses itself."],
        ]}
      />
      <div className="prose-docs">
        <p>
          Cards dismiss on click as well as on timeout, and there is a cap on how many are visible at
          once. Arrivals are queued rather than stacked: see the{" "}
          <Link href="/docs/startup#notify-queue">notification queue</Link> for why a hub that fires
          one notification per loaded module still reads cleanly.
        </p>
      </div>

      <H2 id="popup">Popup</H2>
      <CodeBlock
        code={`local popup = window:Popup({
    title = "Reset settings?",
    subtitle = "This cannot be undone",
    content = "Every saved value goes back to its default.",
    icon = "alert",
    dismissable = true,
    boxes = {
        { title = "What changes", description = "Flags, not your saved configurations.", icon = "info" },
    },
    options = {
        { text = "Cancel" },
        {
            text = "Reset",
            style = "danger",
            callback = function() print("reset") end,
        },
    },
})

popup:Close()   -- programmatic dismissal`}
      />
      <PropTable
        headers={["Popup prop", "Description"]}
        rows={[
          ["title", "The heading."],
          ["subtitle", "A smaller line under the title."],
          ["icon", "Optional icon."],
          ["content", "The body copy."],
          ["boxes", "Optional attribute blocks: { title, description, icon }."],
          ["options", "The buttons, each with text, style and callback."],
          ["dismissable", "Whether clicking away closes it."],
        ]}
      />

      <H2 id="options">Popup options</H2>
      <PropTable
        headers={["Option field", "Description"]}
        rows={[
          ["text", "The button label."],
          ["style", "\"primary\", \"danger\" or \"neutral\"."],
          ["callback", "Runs when the option is chosen."],
        ]}
      />
      <CodeBlock
        code={`options = {
    { text = "Cancel" },
    { text = "Confirm", style = "primary", callback = function() end },
}`}
      />
      <Callout type="tip" title="Confirm destructive actions with a popup">
        <p>
          The window already does this for its own risky actions — <C>window:Close()</C> adds a confirm
          popup — so the pattern is worth copying for anything that discards the player&apos;s work.
        </p>
      </Callout>
    </>
  );
}
