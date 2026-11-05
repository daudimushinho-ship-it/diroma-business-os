import { VariantMatrix } from "@/components/VariantMatrix";
import { DesignPicker } from "./DesignPicker";
import { getDesign } from "@/lib/stock";
import { openingStock } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";

export async function Opening({ locationId, s, design, back, tab = "opening" }: { locationId: string; s: StockDict; design?: string; back: string; tab?: string }) {
  const d = design ? await getDesign(design) : null;
  return (
    <section className="card space-y-3 p-4">
      <p className="text-sm text-muted">{s.store.openingNote}</p>
      <DesignPicker label={s.choose} keep={{ loc: locationId, tab }} selected={design} />
      {d?.design && (
        <form action={openingStock} className="space-y-3">
          <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="location" value={locationId} />
          <input type="hidden" name="back" value={back} />
          <VariantMatrix variants={d.variants} inputPrefix="q_" />
          <div className="flex flex-wrap items-end gap-2">
            <label className="min-w-64 flex-1"><span className="label">{s.reason}</span><input name="reason" required className="input" placeholder="Opening count 2026-11-05" /></label>
            <button className="btn btn-primary">{s.save}</button>
          </div>
        </form>
      )}
    </section>
  );
}
