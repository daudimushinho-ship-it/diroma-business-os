import type { PdfSection } from "@/lib/pdf";

const fmt = (v: unknown) => (typeof v === "number" ? Math.round(v).toLocaleString("en-US") : v === null || v === undefined ? "" : String(v));

/** Renders the same section/table description used for CSV and PDF exports. */
export function ReportTable({ s }: { s: PdfSection }) {
  return (
    <section className="card overflow-hidden">
      {s.heading && <h3 className="border-b border-line px-4 py-2.5 font-semibold">{s.heading}</h3>}
      {(s.lines ?? []).filter(Boolean).map((l) => <p key={l} className="px-4 py-2 text-xs text-muted">{l}</p>)}
      {s.columns && (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-ivory text-muted"><tr>{s.columns.map((c) => <th key={c.label} className={`px-3 py-2 font-medium ${c.align === "right" ? "text-right" : "text-left"}`}>{c.label}</th>)}</tr></thead>
            <tbody className="divide-y divide-line tabular-nums">
              {(s.rows ?? []).map((r, i) => <tr key={i}>{r.map((v, j) => <td key={j} className={`whitespace-nowrap px-3 py-1.5 ${s.columns![j]?.align === "right" ? "text-right" : ""}`}>{fmt(v)}</td>)}</tr>)}
              {(s.rows ?? []).length === 0 && <tr><td colSpan={s.columns.length} className="px-3 py-3 text-muted">—</td></tr>}
            </tbody>
            {s.totals && <tfoot className="border-t-2 border-line font-semibold tabular-nums"><tr>{s.totals.map((v, j) => <td key={j} className={`whitespace-nowrap px-3 py-2 ${s.columns![j]?.align === "right" ? "text-right" : ""}`}>{fmt(v)}</td>)}</tr></tfoot>}
          </table>
        </div>
      )}
    </section>
  );
}
