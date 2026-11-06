import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { addDays, businessDayStart, businessToday, tzs } from "@/lib/format";

type SP = { from?: string; to?: string; status?: string; ok?: string; err?: string };
const STATUS_TONE: Record<string, string> = { paid: "bg-[#e7f4ec] text-ok", partial: "bg-[#fff4de] text-warn", unpaid: "bg-[#fdf1ef] text-bad" };

export default async function SalesPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("sales.view");
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const to = sp.to && /^\d{4}-\d{2}-\d{2}$/.test(sp.to) ? sp.to : businessToday();
  const from = sp.from && /^\d{4}-\d{2}-\d{2}$/.test(sp.from) ? sp.from : addDays(to, -6);
  const supabase = await db();
  let q = supabase.from("sales").select("id, ref_no, sold_at, total, payment_status, fulfillment_status, customer_id, channel")
    .gte("sold_at", businessDayStart(from)).lt("sold_at", businessDayStart(addDays(to, 1))).order("sold_at", { ascending: false }).limit(500);
  if (sp.status && ["paid", "partial", "unpaid"].includes(sp.status)) q = q.eq("payment_status", sp.status);
  const { data: sales } = await q;
  const custIds = [...new Set((sales ?? []).map((s) => s.customer_id).filter(Boolean))] as string[];
  const { data: custs } = custIds.length ? await supabase.from("customers").select("id, name").in("id", custIds) : { data: [] };
  const cname = new Map((custs ?? []).map((c) => [c.id, c.name]));
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "short", timeStyle: "short", timeZone: ws.business.timezone });
  const total = (sales ?? []).reduce((a, s) => a + s.total, 0);
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={x.sales.title} subtitle={`${(sales ?? []).length} · ${tzs(total)}`} />
      <Flash ok={sp.ok} err={sp.err} />
      <form className="mb-4 flex flex-wrap items-end gap-2">
        <label><span className="label">{x.sales.date}</span><input type="date" name="from" defaultValue={from} className="input" /></label>
        <label><span className="label">&nbsp;</span><input type="date" name="to" defaultValue={to} className="input" /></label>
        <label><span className="label">{x.sales.status}</span>
          <select name="status" defaultValue={sp.status ?? ""} className="input"><option value="">—</option><option>paid</option><option>partial</option><option>unpaid</option></select></label>
        <button className="btn btn-ghost">OK</button>
      </form>
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="bg-ivory text-left text-muted"><tr>
            <th className="px-4 py-2 font-medium">{x.sales.receipt}</th><th className="px-4 py-2 font-medium">{x.sales.date}</th>
            <th className="px-4 py-2 font-medium">{x.pos.customer}</th><th className="px-4 py-2 text-right font-medium">{x.pos.total}</th>
            <th className="px-4 py-2 font-medium">{x.sales.status}</th><th className="px-4 py-2 font-medium">{x.sales.fulfilment}</th></tr></thead>
          <tbody className="divide-y divide-line">
            {(sales ?? []).map((s) => (
              <tr key={s.id} className="hover:bg-ivory">
                <td className="px-4 py-2"><Link href={`/sales/${s.id}`} className="font-mono text-gold-ink underline">{s.ref_no}</Link></td>
                <td className="whitespace-nowrap px-4 py-2">{fmt.format(new Date(s.sold_at))}</td>
                <td className="px-4 py-2">{s.customer_id ? cname.get(s.customer_id) : "—"}{s.channel === "wholesale" && <span className="ml-1 badge bg-ivory">W</span>}</td>
                <td className="px-4 py-2 text-right tabular-nums">{tzs(s.total)}</td>
                <td className="px-4 py-2"><span className={`badge ${STATUS_TONE[s.payment_status]}`}>{s.payment_status}</span></td>
                <td className="px-4 py-2 text-xs text-muted">{s.fulfillment_status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
