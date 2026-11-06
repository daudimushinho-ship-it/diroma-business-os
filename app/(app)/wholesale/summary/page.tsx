import { PrintButton } from "@/components/PrintButton";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { partnerOverview } from "@/lib/wholesale";
import { businessToday, tzs } from "@/lib/format";

/** Combined, printable summary of all wholesale partners as of today. */
export default async function PartnersSummary() {
  const ws = await requireWorkspace("wholesale.manage");
  const { x } = await getSalesDict();
  const w = x.wholesale;
  const rows = await partnerOverview(null);
  const sum = (k: "held" | "held_value" | "invoiced" | "paid" | "outstanding" | "credit") => rows.reduce((a, r) => a + r[k], 0);
  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-4 flex justify-end print:hidden"><PrintButton label="PDF / Print" /></div>
      <article className="card overflow-x-auto p-6 text-sm print:border-0 print:p-0">
        <p className="text-xl font-bold tracking-[0.3em]">DIROMA</p>
        <p className="mb-4 text-xs text-muted">{w.combined} · {businessToday()} · Africa/Dar_es_Salaam · TZS · {ws.display_name}</p>
        <table className="w-full min-w-[720px]">
          <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{w.partner}</th><th className="py-1 text-right font-medium">{w.held}</th>
            <th className="py-1 text-right font-medium">{w.heldValue}</th><th className="py-1 text-right font-medium">{w.invoiced}</th><th className="py-1 text-right font-medium">{w.paid}</th>
            <th className="py-1 text-right font-medium">{w.outstanding}</th><th className="py-1 font-medium">{w.oldestDue}</th></tr></thead>
          <tbody className="tabular-nums">
            {rows.map((r) => <tr key={r.partner_id} className="border-t border-line"><td className="py-1">{r.name}</td><td className="py-1 text-right">{r.held}</td>
              <td className="py-1 text-right">{r.held_value.toLocaleString("en-US")}</td><td className="py-1 text-right">{r.invoiced.toLocaleString("en-US")}</td>
              <td className="py-1 text-right">{r.paid.toLocaleString("en-US")}</td><td className="py-1 text-right font-semibold">{r.outstanding.toLocaleString("en-US")}</td>
              <td className="py-1">{r.oldest_due ?? "—"}</td></tr>)}
          </tbody>
          <tfoot className="font-bold tabular-nums"><tr className="border-t-2 border-line"><td className="py-2">Σ</td><td className="py-2 text-right">{sum("held")}</td>
            <td className="py-2 text-right">{tzs(sum("held_value"))}</td><td className="py-2 text-right">{tzs(sum("invoiced"))}</td><td className="py-2 text-right">{tzs(sum("paid"))}</td>
            <td className="py-2 text-right">{tzs(sum("outstanding"))}</td><td /></tr></tfoot>
        </table>
        <p className="mt-3 text-xs text-muted">{w.noRevenue}</p>
      </article>
    </div>
  );
}
