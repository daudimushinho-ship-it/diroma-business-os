import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Stat } from "@/components/Stat";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { myShift } from "@/lib/sales";
import { tzs } from "@/lib/format";
import { closeShift } from "@/app/actions/sales";

type SP = { closed?: string; expected?: string; counted?: string; variance?: string; err?: string };

export default async function ShiftPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("pos.sell");
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const shift = await myShift();
  if (sp.closed) {
    const v = Number(sp.variance);
    return (
      <div className="mx-auto max-w-lg">
        <PageHeader title={x.shift.closedOk} />
        <div className="grid grid-cols-3 gap-3">
          <Stat label={x.shift.expected} value={tzs(Number(sp.expected))} />
          <Stat label={x.shift.counted} value={tzs(Number(sp.counted))} />
          <Stat label={x.shift.variance} value={tzs(v)} note={v === 0 ? "✓" : undefined} />
        </div>
      </div>
    );
  }
  if (!shift) return <div className="mx-auto max-w-lg"><PageHeader title={x.shift.title} /><p className="card p-6 text-sm text-muted">{x.shift.noShift}</p></div>;
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });
  return (
    <div className="mx-auto max-w-2xl space-y-5">
      <PageHeader title={x.shift.title} subtitle={`${shift.ref_no} · ${x.shift.opened} ${fmt.format(new Date(shift.opened_at))}`} />
      <Flash err={sp.err} />
      <div className="grid grid-cols-2 gap-3">
        <Stat label={x.shift.salesCount} value={String(shift.sales_count)} />
        <Stat label={x.shift.salesTotal} value={tzs(shift.sales_total)} />
      </div>
      <section className="card p-4 text-sm">
        <h2 className="mb-2 font-semibold">{x.shift.byMethod}</h2>
        <ul>{Object.entries(shift.by_method).map(([k, v]) => <li key={k} className="flex justify-between py-1"><span>{k}</span><span className="tabular-nums">{tzs(v)}</span></li>)}</ul>
      </section>
      <form action={closeShift} className="card space-y-3 p-5">
        <input type="hidden" name="shift" value={shift.id} /><input type="hidden" name="back" value="/pos/shift" />
        <h2 className="font-semibold">{x.shift.close}</h2>
        <p className="text-xs text-muted">{x.shift.blind}</p>
        <label className="block"><span className="label">{x.shift.counted}</span><input name="counted" required inputMode="numeric" className="input text-lg" /></label>
        <label className="block"><span className="label">{x.shift.reason}</span><input name="reason" className="input" /></label>
        <button className="btn btn-primary w-full">{x.shift.close}</button>
      </form>
    </div>
  );
}
