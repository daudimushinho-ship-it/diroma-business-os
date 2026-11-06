"use client";
import { useActionState } from "react";
import { migrate } from "@/app/actions/migration";
import { SubmitButton } from "@/components/SubmitButton";

const TEMPLATES = {
  customers: "name,phone,kind,credit_limit,terms_days,region,source,opening_balance\nMteja Mfano,0712000000,retail,0,0,Dar es Salaam,instagram,0\n",
  stock: "design_code,color,size,location_code,qty\nDR#2516-43,Black,48,WH,12\n",
};

export function MigrationForm({ kind, shops, today, labels }: {
  kind: "customers" | "stock"; shops: { id: string; name: string }[]; today: string;
  labels: { title: string; intro: string; preview: string; commit: string; template: string };
}) {
  const [state, action] = useActionState(migrate, undefined);
  if (state?.stage === "done") return (
    <div role="status" className="card p-5"><h2 className="font-semibold">{labels.title} ✓</h2>
      <pre className="mt-2 overflow-x-auto rounded bg-ivory p-3 text-sm">{JSON.stringify(state.result, null, 2)}</pre></div>
  );
  const rows = state?.stage === "preview" ? state.rows : [];
  const bad = rows.filter((r) => r.errors.length).length;
  const cols = rows[0] ? Object.keys(rows[0].row) : [];
  return (
    <section className="card space-y-3 p-5">
      <h2 className="font-semibold">{labels.title}</h2>
      <p className="text-sm text-muted">{labels.intro}</p>
      <a download={`diroma-${kind}-template.csv`} href={`data:text/csv;charset=utf-8,${encodeURIComponent(TEMPLATES[kind])}`} className="text-sm font-semibold text-gold-ink underline">{labels.template}</a>
      <form action={action} className="space-y-2">
        <input type="hidden" name="kind" value={kind} /><input type="hidden" name="intent" value="preview" />
        <input type="file" name="file" accept=".csv,text/csv" className="block text-sm" />
        {kind === "customers" ? (
          <div className="flex flex-wrap gap-2 text-sm">
            <label><span className="label">As of (balances date)</span><input type="date" name="as_of" max={today} defaultValue={today} className="input" /></label>
            <label><span className="label">Shop owning opening balances</span><select name="location" className="input">{shops.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></label>
            <label><span className="label">Existing phone</span><select name="mode" className="input"><option value="create_only">error</option><option value="update">update</option></select></label>
          </div>
        ) : <input name="reason" required placeholder="Reason (e.g. physical count 2026-11-30)" className="input" />}
        <SubmitButton className="btn btn-ghost">{labels.preview}</SubmitButton>
      </form>
      {(state?.stage === "error" || (state?.stage === "preview" && state.fatal)) && (
        <p role="alert" className="rounded bg-[#fdf1ef] px-3 py-2 text-sm text-bad">{state.stage === "error" ? state.message : state.fatal}</p>
      )}
      {rows.length > 0 && (
        <>
          <p className="text-sm">{rows.length} rows · <strong className={bad ? "text-bad" : "text-ok"}>{bad} errors</strong></p>
          <div className="max-h-[50vh] overflow-auto rounded border border-line">
            <table className="w-full text-xs"><thead className="sticky top-0 bg-ivory text-left"><tr><th className="px-2 py-1">#</th>{cols.map((c) => <th key={c} className="px-2 py-1">{c}</th>)}<th className="px-2 py-1">!</th></tr></thead>
              <tbody>{rows.map((r) => <tr key={r.line} className={r.errors.length ? "bg-[#fdf1ef]" : ""}><td className="px-2 py-1 text-muted">{r.line}</td>
                {cols.map((c) => <td key={c} className="px-2 py-1">{String(r.row[c] ?? "")}</td>)}<td className="px-2 py-1 text-bad">{r.errors.join("; ")}</td></tr>)}</tbody></table>
          </div>
          {bad === 0 && <form action={action}><input type="hidden" name="kind" value={kind} /><input type="hidden" name="intent" value="commit" />
            <SubmitButton className="btn btn-primary">{labels.commit}</SubmitButton></form>}
        </>
      )}
    </section>
  );
}
