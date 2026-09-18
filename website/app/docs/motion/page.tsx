import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Motion",
  description: "One animation service behind every Astra transition: named specs, custom TweenInfo, speed profiles, and completion callbacks that never race.",
  path: "/docs/motion/",
});

export default function Motion() {
  return (
    <>
      <PageHeader
        title="Motion"
        description="Astra's own transitions and yours run through the same service, so they share one vocabulary and one speed setting."
      />

      <div className="prose-docs">
        <p>
          Window transitions — hover, element reveal, the window entrance, the result flashes, every
          card&apos;s entrance and dismissal — all go through this service. So does the entrance queue
          that spaces notification arrivals, which is why it stretches and shortens with the speed the
          player picked in <strong>Performance &amp; Motion</strong>.
        </p>
      </div>

      <H2 id="specs">Specs</H2>
      <div className="prose-docs">
        <p>
          A spec is a named tween: <C>instant</C>, <C>fast</C>, <C>snappy</C>, <C>normal</C>,{" "}
          <C>smooth</C>, <C>emphasized</C>, <C>pop</C>, <C>glide</C>, <C>exit</C>, <C>spring</C>,{" "}
          <C>settle</C>, <C>spin</C> and <C>drift</C>. A <C>TweenInfo</C> works anywhere a name does.
        </p>
        <p>The vocabulary is a system rather than a list of durations:</p>
        <ul>
          <li>Entrances decelerate (Out).</li>
          <li>
            Exits accelerate — <C>exit</C> is In, because a dismissal should be quicker than its
            entrance.
          </li>
          <li>
            Lateral state moves ease InOut (<C>glide</C>, used by the window folding into its capsule).
          </li>
          <li>
            Playful surfaces get a small Back overshoot: <C>pop</C> for the shell, <C>settle</C> for
            small elements, <C>spring</C> for drag landings.
          </li>
        </ul>
      </div>

      <H2 id="api">Motion API</H2>
      <CodeBlock
        code={`-- Animate with the library's own specs.
Astra.Motion.tween(frame, { BackgroundTransparency = 0.5 }, "snappy")

-- A TweenInfo works anywhere a name does.
Astra.Motion.tween(stroke, { Color = Color3.new(1, 1, 1) }, TweenInfo.new(0.3))

-- Settle work after the animation, without racing a synchronous completion.
Astra.Motion.tween(panel, { Position = target }, "smooth", function()
    panel.Visible = false
end)

-- Steer the whole interface.
Astra.Motion.setProfile("relaxed")   -- relaxed | normal | snappy | instant
Astra.Motion.setTimeScale(0.8)       -- custom multiplier instead
Astra.Motion.setEnabled(false)       -- apply targets immediately, no tweens
Astra.Motion.step(0.035)             -- cascade pacing, scaled like the rest
Astra.Motion.cancel(frame)           -- stop what the service owns here`}
      />

      <H2 id="rules">How it behaves</H2>
      <PropTable
        headers={["Behaviour", "Why it matters"]}
        rows={[
          [
            "No tween for a satisfied target",
            "A call whose properties are all already at their targets creates no tween at all, so guarded calls stay cheap.",
          ],
          [
            "In-flight tweens are cancelled",
            "A new tween that would fight over the same property cancels the old one, so repeated calls from an event handler cannot stack up competing animations.",
          ],
          [
            "Completion callbacks do not race",
            "The third argument runs when the animation settles, including the synchronous paths, so follow-up work lands in order.",
          ],
          [
            "Disabled means immediate",
            "With motion disabled the targets are applied with no animation — the interface stays correct, it just stops moving.",
          ],
        ]}
      />
      <Callout type="tip" title="The speed setting is the player's, not yours">
        <p>
          <C>setProfile</C> and <C>setTimeScale</C> exist for hosts that want their own pacing, but the
          setting in <strong>Performance &amp; Motion</strong> is what the player chose. Reading it
          through the service is what keeps your animations and the window&apos;s in step.
        </p>
      </Callout>
      <Callout type="note" title="Related">
        <p>
          The arrival sequence that uses this service is described in{" "}
          <Link href="/docs/startup#arrival">Startup performance</Link>, and collapsible groups open
          and close through it too.
        </p>
      </Callout>
    </>
  );
}
