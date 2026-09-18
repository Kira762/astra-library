import { DocsPager, DocsSidebar, DocsToc } from "@/components/docs-nav";

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex w-full max-w-shell min-w-0 max-w-[100vw] flex-col overflow-x-clip px-4 lg:flex-row lg:gap-8 lg:px-6">
      <DocsSidebar />
      <div className="min-w-0 w-full flex-1 overflow-x-clip pb-8 pt-2 lg:pb-14 lg:pt-8">
        <main id="content" className="min-w-0 w-full max-w-3xl max-w-full overflow-x-clip">
          <div className="min-w-0 w-full max-w-full">{children}</div>
          <DocsPager />
        </main>
      </div>
      <DocsToc />
    </div>
  );
}
