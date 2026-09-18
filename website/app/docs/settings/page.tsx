import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Built-in settings",
  description: "Every Astra window ships a settings panel: General, Appearance, Persistence and About \u2014 keybinds, layouts, profile card controls and saved configurations.",
  path: "/docs/settings/",
});

export default function Settings() {
  return (
    <>
      <PageHeader
        title="Built-in settings"
        description="Every window ships a settings group. You do not build it, and you do not have to add a tab for it."
      />

      <H2 id="how">How it opens</H2>
      <div className="prose-docs">
        <p>
          The gear action in the topbar switches the window into settings mode: only the settings tabs
          are shown while it is active, and clicking the gear again returns to the tab the player was
          on. Settings are window-scoped — they edit this window&apos;s behaviour and are stored per
          window, not globally.
        </p>
        <p>
          There is no sub-tab API. These tabs are built by the window itself
          (<C>Window:_buildSettingsUI</C>), not by user code, and their controls are created lazily —
          a tab&apos;s controls are built when that tab is first selected.
        </p>
      </div>

      <H2 id="tabs">The four tabs</H2>
      <PropTable
        headers={["Tab", "Contents"]}
        rows={[
          [
            "General",
            "Menu Toggle keybind field — type a key name (K, Space, MB2) and click away to bind, \"none\" or an empty field to unbind — plus the unlock-cursor toggle, welcome toast toggle, Window Behavior and Performance & Motion.",
          ],
          [
            "Appearance",
            "Theme dropdown with an Apply confirmation, Bar Layout (Default Topbar / Sidebar / Collapsed Sidebar), and the profile card controls: Show profile, Profile side and Reveal profile details.",
          ],
          [
            "Persistence",
            "Auto Save Config and Auto Load Config, plus the saved-configuration dropdown with a name field and Save / Load / Delete.",
          ],
          ["About", "Library information and links."],
        ]}
      />
      <div className="prose-docs">
        <p>
          Window Behavior and Performance & Motion are the two groups worth knowing in advance:
        </p>
      </div>
      <CodeBlock
        title="General → what the player can change"
        lang="Text"
        code={`Window Behavior
  prevent duplicate windows
  keep window on screen
  draggable capsule
  reset window & capsule positions

Performance & Motion
  haptics
  animation speed     -- drives Astra.Motion for the whole interface`}
      />

      <H2 id="behaviour">Window behaviour</H2>
      <div className="prose-docs">
        <ul>
          <li>
            <strong>Prevent duplicate windows</strong> stops a second copy of the same hub appearing.
          </li>
          <li>
            <strong>Keep window on screen</strong> clamps the window and its profile card as a pair, so
            a drag cannot push either of them off the edge.
          </li>
          <li>
            <strong>Draggable capsule</strong> allows the minimised pill to be moved.
          </li>
          <li>
            <strong>Animation speed</strong> is the same setting the{" "}
            <Link href="/docs/motion">motion service</Link> reads, so your own tweens follow the player
            too.
          </li>
        </ul>
      </div>

      <H2 id="position">Position and the profile card</H2>
      <div className="prose-docs">
        <p>
          The window and its profile card — a compact 260×420 panel, the height of the default window —
          are centred as one unit. With the card on, the window rests half a card (136&nbsp;px) off
          the screen centre on the opposite side of it, so window + 12&nbsp;px gap + card line up in the
          middle together.
        </p>
        <p>
          That resting centre is re-derived on the first show, on every hide/show restore, and whenever
          the card&apos;s state changes: toggling it, switching sides, resizing the viewport, or a
          player turning up late. A position you dragged to is always respected — auto-centring never
          overrides it — and <strong>Reset Window Position</strong> recentres the pair.
        </p>
      </div>
      <Callout type="tip" title="The panel is filled from real data">
        <p>
          Profile values come from the player and the running server. Your script only supplies the
          parts it knows through <C>window:SetProfile(profile)</C> — see{" "}
          <Link href="/docs/windows#profile">Windows</Link>.
        </p>
      </Callout>
    </>
  );
}
