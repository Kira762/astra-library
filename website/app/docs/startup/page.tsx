import Link from "next/link";
import { C, Callout, H2, PageHeader } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Startup performance",
  description: "How Astra builds a window across frames: cooperative budgets, deferred show, staged arrival, and the notification queue that keeps large hubs responsive.",
  path: "/docs/startup/",
});

export default function Startup() {
  return (
    <>
      <PageHeader
        title="Startup performance"
        description="Window construction is staged across frames, so a hub that builds hundreds of controls still opens instantly."
        meta={
          <>
            <span className="pill">~4&nbsp;ms per batch</span>
            <span className="pill">120 instances per batch</span>
            <span className="pill">show on the next frame</span>
          </>
        }
      />

      <div className="prose-docs">
        <p>
          Nothing here needs a flag or an option. It is how <C>CreateWindow</C> behaves, and it is why
          a large script can keep writing straight-line constructor calls.
        </p>
      </div>

      <H2 id="staged">Staged construction</H2>
      <div className="prose-docs">
        <p>
          Large initial batches of <C>CreateTab</C> and <C>Create…</C> calls yield at completed-control
          boundaries after roughly 4&nbsp;ms of work or 120 new instances. Those are cooperative
          limits, not a hard frame-time cap: one expensive control can exceed them on its own.
        </p>
        <p>
          Calls still return fully built objects, so your code reads the same — it just may yield while
          creating the initial interface.
        </p>
      </div>

      <H2 id="auto-show">Automatic show</H2>
      <div className="prose-docs">
        <p>
          The show happens on the next frame: one deferred tick plus one heartbeat. That delay is
          deliberate — it lets the caller&apos;s first synchronous <C>CreateTab</C> calls land before the
          shell appears. The remaining constructors keep streaming in behind the already-visible
          window in small budget-limited batches until the build goes quiet, so the opening tween keeps
          receiving frames.
        </p>
        <p>
          <C>window:Hide()</C> before the first reveal cancels auto-show; <C>window:Show()</C> can still
          be called explicitly.
        </p>
      </div>

      <H2 id="arrival">The arrival</H2>
      <div className="prose-docs">
        <p>The entrance is staged rather than instant:</p>
        <ol>
          <li>The shell — frame, surface, corner, topbar — animates in first.</li>
          <li>The page&apos;s controls cascade in one control per beat, a beat later.</li>
          <li>Overlays follow the content.</li>
        </ol>
        <p>
          The whole sequence runs through the <Link href="/docs/motion">motion service</Link>, so the
          player&apos;s animation-speed setting stretches or shortens it.
        </p>
      </div>

      <H2 id="notify-queue">Notification queue</H2>
      <div className="prose-docs">
        <p>
          Because overlays follow the content, <C>window:Notify</C> cards are queued: each card is
          built on its own turn, one entrance at a time, with a cooldown between two of them, instead
          of all landing on the frame the window opens on.
        </p>
        <p>
          A backlog stays bounded — past six waiting requests the oldest one that has not been built
          yet is dropped. The call itself is unchanged: the same props, dismissal on click and on
          timeout, and the same visible cap.
        </p>
      </div>

      <Callout type="tip" title="Instant speed keeps the order, drops the pauses">
        <p>
          With the speed profile set to <C>Instant</C>, a host that fires a notification per loaded
          module still gets a cascade rather than a freeze, but without the waiting between cards.
        </p>
      </Callout>

      <H2 id="lazy">What stays lazy</H2>
      <div className="prose-docs">
        <p>Three parts of the window are built when they are first needed, not at construction:</p>
        <ul>
          <li>
            <strong>Search controls</strong> are created the first time search opens.
          </li>
          <li>
            <strong>Settings tabs</strong> beyond the first are created on first settings access, and
            their controls remain lazy until each tab is selected.
          </li>
          <li>
            <strong>Controls on inactive tabs</strong> wait until that tab is shown before running their
            reveal animations.
          </li>
        </ul>
        <p>
          Collapsible groups are the exception worth knowing: their controls are built in the startup
          batches even while collapsed, so saved flags are usable before the first expansion.
        </p>
      </div>
    </>
  );
}
