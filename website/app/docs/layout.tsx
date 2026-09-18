import { DocsPager, DocsSidebar, DocsToc } from "@/components/docs-nav";

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex max-w-shell flex-col px-4 lg:flex-row lg:gap-8 lg:px-6">
      <DocsSidebar />
      <div className="min-w-0 flex-1 pb-8 pt-2 sm:pt-4 lg:pb-14 lg:pt-8">
        <main id="content" className="min-w-0 max-w-3xl">
          {children}
          <DocsPager />
        </main>
      </div>
      <DocsToc />
    </div>
  );
}
