import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { VariantMatrix } from "@/components/VariantMatrix";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db, getDesign } from "@/lib/stock";
import { tzs } from "@/lib/format";
import { addVariant, setPrices } from "@/app/actions/stock";

export default async function DesignPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("products.view");
  const { s } = await getStockDict();
  const { id } = await params;
  const sp = await searchParams;
  const { design, variants } = await getDesign(id);
  if (!design) notFound();
  const supabase = await db();
  const { data: stock } = await supabase.from("v_stock").select("variant_id, on_hand").eq("design_id", id);
  const totals: Record<string, number> = {};
  for (const r of stock ?? []) totals[r.variant_id] = (totals[r.variant_id] ?? 0) + r.on_hand;
  const manage = can(ws, "products.manage");
  const back = `/products/${id}`;
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader title={design.name} subtitle={`${design.code} · ${design.category}`}>
        <Link href={`/products/${id}/labels`} className="btn btn-ghost">{s.printLabels}</Link>
      </PageHeader>
      <Flash ok={sp.ok} err={sp.err} />
      <section className="card p-5">
        <h2 className="mb-3 font-semibold">{s.stock} ({ws.locations.map((l) => l.name).join(", ")})</h2>
        <VariantMatrix variants={variants} values={totals} />
      </section>
      <section className="card overflow-x-auto">
        <table className="w-full min-w-[720px] text-sm">
          <thead className="bg-ivory text-left text-muted">
            <tr>
              <th className="px-4 py-2 font-medium">{s.color}</th><th className="px-4 py-2 font-medium">{s.size}</th>
              <th className="px-4 py-2 font-medium">{s.sku}</th><th className="px-4 py-2 font-medium">{s.barcode}</th>
              <th className="px-4 py-2 font-medium">{s.retail}</th><th className="px-4 py-2 font-medium">{s.wholesale}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {variants.map((v) => (
              <tr key={v.id}>
                <td className="px-4 py-2">{v.color}</td><td className="px-4 py-2 font-semibold">{v.size}</td>
                <td className="px-4 py-2 font-mono text-xs">{v.sku}</td><td className="px-4 py-2 font-mono text-xs">{v.barcode}</td>
                {manage ? (
                  <td colSpan={2} className="px-4 py-2">
                    <form action={setPrices} className="flex flex-wrap items-center gap-2">
                      <input type="hidden" name="variant" value={v.id} /><input type="hidden" name="back" value={back} />
                      <input name="retail" defaultValue={v.retail_price ?? ""} inputMode="numeric" aria-label={s.retail} className="input h-9 min-h-0 w-28 py-1" />
                      <input name="wholesale" defaultValue={v.wholesale_price ?? ""} inputMode="numeric" aria-label={s.wholesale} className="input h-9 min-h-0 w-28 py-1" />
                      <input name="reason" placeholder={s.reason} className="input h-9 min-h-0 w-32 py-1" />
                      <button className="btn btn-ghost h-9 min-h-0 py-1">{s.save}</button>
                    </form>
                  </td>
                ) : (
                  <>
                    <td className="px-4 py-2">{v.retail_price ? tzs(v.retail_price) : <span className="text-warn">{s.unpriced}</span>}</td>
                    <td className="px-4 py-2">{tzs(v.wholesale_price)}</td>
                  </>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </section>
      {manage && (
        <section className="card p-5">
          <h2 className="mb-3 font-semibold">{s.addVariant}</h2>
          <form action={addVariant} className="flex flex-wrap items-end gap-3">
            <input type="hidden" name="design" value={id} /><input type="hidden" name="back" value={back} />
            <label><span className="label">{s.color}</span><input name="color" required className="input w-36" /></label>
            <label><span className="label">{s.size}</span><input name="size" required className="input w-24" /></label>
            <label><span className="label">{s.retail}</span><input name="retail" inputMode="numeric" className="input w-36" /></label>
            <label><span className="label">{s.wholesale}</span><input name="wholesale" inputMode="numeric" className="input w-36" /></label>
            <button className="btn btn-primary">{s.addVariant}</button>
          </form>
        </section>
      )}
    </div>
  );
}
