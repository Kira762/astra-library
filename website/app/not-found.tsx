import Link from "next/link";
import { CardGrid, DocCard } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Page not found",
  description: "That page is not in this guide. Search the documentation or start from the overview.",
  path: "/404/",
});

export default function NotFound() {
  return (
    <main id="content" className="mx-auto w-full max-w-3xl min-w-0 max-w-[100vw] overflow-x-clip px-4 py-20 lg:px-6">
      <p className="pill">404</p>
      <h1 className="mt-4 min-w-0 text-3xl font-semibold tracking-tight sm:text-4xl">
        That page is not here
      </h1>
      <p className="mt-3 min-w-0 max-w-prose text-base leading-7 text-muted">
        The link may be from an older version of this guide, which used to be a single page. Everything
        below is current — or press{" "}
        <kbd className="kbd">⌘ K</kbd> and search.
      </p>
      <CardGrid>
        <DocCard
          href="/docs/getting-started"
          icon="zap"
          title="Getting started"
          description="Load the bundle and build a window."
        />
        <DocCard
          href="/docs/elements"
          icon="layers"
          title="Elements overview"
          description="Every element type, with props and handles."
        />
        <DocCard
          href="/docs/api/methods"
          icon="book"
          title="Method index"
          description="Every method on every handle."
        />
        <DocCard
          href="/"
          icon="star"
          title="Overview"
          description="Back to the landing page and the live preview."
        />
      </CardGrid>
      <p className="mt-6 min-w-0 text-sm text-subtle">
        Looking for the source?{" "}
        <Link href="/docs/repo" className="text-accent hover:underline">
          Repository and deployment
        </Link>{" "}
        explains what lives where.
      </p>
    </main>
  );
}
