"use client";
import { useActionState } from "react";
import { importCatalogue } from "@/app/actions/import";
import { SubmitButton } from "@/components/SubmitButton";
import type { StockDict } from "@/lib/i18n-stock";

const TEMPLATE = "design_code,design_name,category,color,size,retail_price,wholesale_price,barcode,supplier\nDR#2516-43,Slim fit suit,suit_2pc,Black,48,450000,380000,,Guangzhou Supplier\n";

export function ImportForm({ s, categories }: { s: StockDict; categories: string[] }) {
  const [state, action] = useActionState(importCatalogue, undefined);
  const rows = state && "rows" in state ? state.rows ?? [] : [];
  const bad = rows.filter((r) => r.errors.length).length;

  if (state?.stage === "done") {
    return (
      <div role="status" className="card p-5">
        <h2 className="font-semibold">{s.importPage.result}</h2>
        <pre className="mt-3 overflow-x-auto rounded-lg bg-ivory p-3 text-sm">{JSON.stringify(state.result, null, 2)}</pre>
        <a href="/products" className="btn btn-primary mt-4">{s.products}</a>
      </div>
    );
  }
  return (
    <div className="space-y-5">
      <form action={action} className="card space-y-4 p-5">
        <input type="hidden" name="intent" value="preview" />
        <p className="text-sm text-muted">{s.importPage.intro}</p>
        <p className="text-xs text-muted">{s.importPage.categories}: <span className="font-mono">{categories.join(", ")}</span></p>
        <a download="diroma-catalogue-template.csv" href={`data:text/csv;charset=utf-8,${encodeURIComponent(TEMPLATE)}`} className="text-sm font-semibold text-gold-ink underline">{s.importPage.template}</a>
        <label className="block"><span className="label">{s.importPage.paste}</span>
          <input type="file" name="file" accept=".csv,text/csv" className="block text-sm" />
          <textarea name="csv" rows={6} className="input mt-2 font-mono text-xs" placeholder={TEMPLATE} />
        </label>
        <fieldset><legend className="label">{s.importPage.mode}</legend>
          <label className="mr-4 text-sm"><input type="radio" name="mode" value="create_only" defaultChecked /> {s.importPage.createOnly}</label>
          <label className="text-sm"><input type="radio" name="mode" value="update_prices" /> {s.importPage.updatePrices}</label>
        </fieldset>
        <SubmitButton className="btn btn-ghost">{s.importPage.preview}</SubmitButton>
      </form>

      {state && (state.stage === "error" || (state.stage === "preview" && state.fatal)) && (
        <p role="alert" className="rounded-lg bg-[#fdf1ef] px-3 py-2 text-sm text-bad">{state.stage === "error" ? state.message : state.fatal}</p>
      )}

      {rows.length > 0 && (
        <section className="card overflow-hidden">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-3">
            <p className="text-sm">{s.importPage.rows}: <strong>{rows.length}</strong> · {s.importPage.errors}: <strong className={bad ? "text-bad" : "text-ok"}>{bad}</strong></p>
            {bad === 0 && (
              <form action={action}><input type="hidden" name="intent" value="commit" />
                <SubmitButton className="btn btn-primary">{s.importPage.commit}</SubmitButton></form>
            )}
          </div>
          <div className="max-h-[60vh] overflow-auto">
            <table className="w-full text-xs">
              <thead className="sticky top-0 bg-ivory text-left text-muted"><tr>
                <th className="px-3 py-2">#</th><th className="px-3 py-2">design_code</th><th className="px-3 py-2">color</th>
                <th className="px-3 py-2">size</th><th className="px-3 py-2">retail</th><th className="px-3 py-2">{s.importPage.errors}</th></tr></thead>
              <tbody className="divide-y divide-line">
                {rows.map((r) => (
                  <tr key={r.line} className={r.errors.length ? "bg-[#fdf1ef]" : ""}>
                    <td className="px-3 py-1.5 text-muted">{r.line}</td><td className="px-3 py-1.5 font-mono">{r.row.design_code}</td>
                    <td className="px-3 py-1.5">{r.row.color}</td><td className="px-3 py-1.5">{r.row.size}</td>
                    <td className="px-3 py-1.5">{r.row.retail_price ?? "—"}</td>
                    <td className="px-3 py-1.5 text-bad">{r.errors.join("; ") || <span className="text-ok">{s.importPage.ok}</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
