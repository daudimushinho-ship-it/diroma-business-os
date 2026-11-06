import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { listDesigns } from "@/lib/stock";
import { tzs } from "@/lib/format";

export default async function ProductsPage({ searchParams }: { searchParams: Promise<{ q?: string; ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("products.view");
  const { s } = await getStockDict();
  const sp = await searchParams;
  const designs = await listDesigns(sp.q);
  const manage = can(ws, "products.manage");
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={s.products} subtitle={`${designs.length} designs`}>
        {manage && (
          <div className="flex gap-2">
            <Link href="/products/import" className="btn btn-ghost">{s.importCsv}</Link>
            <Link href="/products/new" className="btn btn-primary">+ {s.newDesign}</Link>
          </div>
        )}
      </PageHeader>
      <Flash ok={sp.ok} err={sp.err} />
      <form className="mb-4" role="search">
        <label htmlFor="q" className="sr-only">{s.search}</label>
        <input id="q" name="q" defaultValue={sp.q} placeholder={`${s.search}: ${s.code} / ${s.name}`} className="input max-w-md" />
      </form>
      {designs.length === 0 ? <p className="card p-6 text-sm text-muted">{s.noData}</p> : (
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {designs.map((d) => (
            <li key={d.design_id}>
              <Link href={`/products/${d.design_id}`} className="card block p-4 hover:border-champagne">
                <p className="font-mono text-xs text-muted">{d.code}</p>
                <p className="mt-0.5 font-semibold">{d.name}</p>
                <p className="mt-1 text-xs text-muted">{(d.colors ?? []).filter(Boolean).join(", ")} · {d.variant_count} {s.variants}</p>
                <p className="mt-2 text-sm">
                  {d.retail_from ? <>{s.from} <strong>{tzs(d.retail_from)}</strong></> : <span className="text-warn">{s.unpriced}</span>}
                  {d.unpriced_variants > 0 && d.retail_from && <span className="ml-2 badge bg-[#fff4de] text-warn">{d.unpriced_variants} {s.unpriced}</span>}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
