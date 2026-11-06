import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { VariantMatrix } from "@/components/VariantMatrix";
import { DesignPicker } from "@/components/stock/DesignPicker";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db, getDesign, locationDirectory, variantLabels, variantText } from "@/lib/stock";
import { partnerOverview, whatsappLink } from "@/lib/wholesale";
import { businessToday, tzs } from "@/lib/format";
import { cancelConsignment, configurePartner, createConsignment, logReminder, resubmitWholesaleSale, wholesaleSale } from "@/app/actions/wholesale";

type SP = { tab?: string; design?: string; partner?: string; source?: string; pending?: string; ok?: string; err?: string };

export default async function WholesalePage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("wholesale.manage");
  const { x } = await getSalesDict();
  const w = x.wholesale;
  const sp = await searchParams;
  const supabase = await db();
  const tabs = [
    { key: "overview", label: w.overview }, { key: "consign", label: w.consign }, { key: "orders", label: w.orders },
    { key: "sell", label: w.sell }, { key: "partners", label: w.partners },
  ];
  const tab = tabs.some((t) => t.key === sp.tab) ? sp.tab! : "overview";
  const rows = await partnerOverview(null);
  const dir = await locationDirectory();
  const sources = [...dir.values()].filter((l) => l.kind === "warehouse" || l.kind === "shop");
  const today = businessToday();
  const { data: intervals } = await supabase.from("customers").select("id, update_interval_days").eq("kind", "wholesale");
  const interval = new Map((intervals ?? []).map((c) => [c.id, c.update_interval_days as number]));
  const fmtDate = (d: string | null) => d ?? "—";

  return (
    <div className="mx-auto max-w-7xl">
      <PageHeader title={w.title}>
        <Link href="/wholesale/summary" className="btn btn-ghost">{w.combined}</Link>
      </PageHeader>
      <Tabs active={tab} items={tabs.map((t) => ({ ...t, href: `/wholesale?tab=${t.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />
      {rows.length === 0 && <p className="card p-6 text-sm text-muted">{w.noPartners}</p>}

      {tab === "overview" && rows.length > 0 && (
        <div className="space-y-4">
          <p className="text-xs text-muted">{w.noRevenue}</p>
          <div className="card overflow-x-auto">
            <table className="w-full min-w-[980px] text-sm">
              <thead className="bg-ivory text-left text-muted"><tr>
                <th className="px-3 py-2 font-medium">{w.partner}</th><th className="px-3 py-2 text-right font-medium">{w.dispatched}</th>
                <th className="px-3 py-2 text-right font-medium">{w.sold}</th><th className="px-3 py-2 text-right font-medium">{w.returned}</th>
                <th className="px-3 py-2 text-right font-medium">{w.lost}</th><th className="px-3 py-2 text-right font-medium">{w.held}</th>
                <th className="px-3 py-2 text-right font-medium">{w.invoiced}</th><th className="px-3 py-2 text-right font-medium">{w.paid}</th>
                <th className="px-3 py-2 text-right font-medium">{w.outstanding}</th><th className="px-3 py-2 font-medium">{w.oldestDue}</th>
                <th className="px-3 py-2 font-medium">{w.nextUpdate}</th><th className="px-3 py-2" /></tr></thead>
              <tbody className="divide-y divide-line tabular-nums">
                {rows.map((r) => {
                  const overdue = r.oldest_due && r.oldest_due < today;
                  const updateDue = r.held > 0 && r.next_update_due && r.next_update_due <= today;
                  const wa = whatsappLink(r.phone, w.remindText.replace("{name}", r.name).replace("{held}", String(r.held)));
                  return (
                    <tr key={r.partner_id} className="align-top">
                      <td className="px-3 py-2"><Link href={`/wholesale/${r.partner_id}`} className="font-medium text-gold-ink underline">{r.name}</Link>
                        <span className="block text-xs text-muted">{r.region ?? ""}{r.consignment_enabled ? ` · ${w.consignment}` : ""}</span></td>
                      <td className="px-3 py-2 text-right">{r.dispatched}</td><td className="px-3 py-2 text-right">{r.sold}</td>
                      <td className="px-3 py-2 text-right">{r.returned}</td><td className="px-3 py-2 text-right">{r.lost}{r.pending_loss > 0 && <span className="text-warn"> (+{r.pending_loss}?)</span>}</td>
                      <td className="px-3 py-2 text-right font-semibold">{r.held}<span className="block text-xs font-normal text-muted">{tzs(r.held_value)}</span></td>
                      <td className="px-3 py-2 text-right">{tzs(r.invoiced)}</td><td className="px-3 py-2 text-right">{tzs(r.paid)}</td>
                      <td className="px-3 py-2 text-right font-semibold">{tzs(r.outstanding)}{r.credit > 0 && <span className="block text-xs font-normal text-ok">{w.credit} {tzs(r.credit)}</span>}</td>
                      <td className={`px-3 py-2 ${overdue ? "font-semibold text-bad" : ""}`}>{fmtDate(r.oldest_due)}</td>
                      <td className="px-3 py-2">{fmtDate(r.next_update_due)}{updateDue && <span className="ml-1 badge bg-[#fff4de] text-warn">{w.due}</span>}
                        {r.unresolved > 0 && <span className="block text-xs text-warn">{w.unresolved}: {r.unresolved}</span>}</td>
                      <td className="px-3 py-2">
                        {updateDue && wa && (
                          <div className="flex flex-col gap-1">
                            <a href={wa} target="_blank" rel="noopener noreferrer" className="text-xs font-semibold text-gold-ink underline">{w.remind}</a>
                            <form action={logReminder}><input type="hidden" name="partner" value={r.partner_id} /><input type="hidden" name="back" value="/wholesale" />
                              <button className="text-xs text-muted underline">{w.logged}</button></form>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-muted">{w.remindNote}</p>
        </div>
      )}

      {tab === "consign" && <Consign />}
      {tab === "orders" && <Orders />}
      {tab === "sell" && <Sell />}
      {tab === "partners" && (
        <div className="card divide-y divide-line">
          {rows.map((r) => (
            <form key={r.partner_id} action={configurePartner} className="flex flex-wrap items-center gap-3 px-4 py-3 text-sm">
              <input type="hidden" name="partner" value={r.partner_id} /><input type="hidden" name="back" value="/wholesale?tab=partners" />
              <span className="min-w-48 flex-1 font-medium">{r.name} <span className="text-xs text-muted">{r.phone}</span></span>
              <label className="flex items-center gap-2"><input type="checkbox" name="enabled" defaultChecked={r.consignment_enabled} /> {w.enable}</label>
              <label className="flex items-center gap-2">{w.interval}<input name="interval" type="number" min={1} max={90} defaultValue={interval.get(r.partner_id) ?? 7} className="h-9 w-16 rounded-md border border-line px-2" /></label>
              <button className="btn btn-ghost">{x.customers.save}</button>
            </form>
          ))}
        </div>
      )}
    </div>
  );

  async function Consign() {
    const enabled = rows.filter((r) => r.consignment_enabled);
    const d = sp.design ? await getDesign(sp.design) : null;
    return (
      <section className="card space-y-3 p-4">
        <p className="text-xs text-muted">{w.noRevenue}</p>
        <DesignPicker label={x.pos.chooseSize} keep={{ tab: "consign" }} selected={sp.design} />
        {d?.design && (
          <form action={createConsignment} className="space-y-3">
            <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="back" value="/wholesale?tab=consign" />
            <VariantMatrix variants={d.variants} inputPrefix="q_" />
            <div className="grid gap-3 sm:grid-cols-2">
              <label><span className="label">{w.partner}</span><select name="partner" required className="input">{enabled.map((r) => <option key={r.partner_id} value={r.partner_id}>{r.name}</option>)}</select></label>
              <label><span className="label">{w.source}</span><select name="source" className="input">{sources.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label>
              <label className="sm:col-span-2"><span className="label">{w.agreedPrice}</span><input name="unit_price" inputMode="numeric" className="input" /></label>
              <label className="sm:col-span-2"><span className="label">{x.pos.note}</span><input name="notes" className="input" /></label>
            </div>
            <button className="btn btn-primary">{w.create}</button>
          </form>
        )}
      </section>
    );
  }

  async function Orders() {
    const { data: orders } = await supabase.from("consignment_orders").select("id, ref_no, partner_id, source_location, status, created_at, notes").order("created_at", { ascending: false }).limit(50);
    const ids = (orders ?? []).map((o) => o.id);
    const { data: lines } = ids.length ? await supabase.from("consignment_order_lines").select("id, order_id, variant_id, qty_ordered, qty_dispatched, unit_price").in("order_id", ids) : { data: [] };
    const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
    const pname = new Map(rows.map((r) => [r.partner_id, r.name]));
    if (!orders?.length) return <p className="card p-6 text-sm text-muted">—</p>;
    return (
      <div className="space-y-3">
        {orders.map((o) => (
          <article key={o.id} className="card p-4 text-sm">
            <p className="font-semibold">{o.ref_no} · {pname.get(o.partner_id)} <span className="font-normal text-muted">· {dir.get(o.source_location)?.name} · {o.status}</span></p>
            <ul className="mt-2">{(lines ?? []).filter((l) => l.order_id === o.id).map((l) => (
              <li key={l.id} className="flex justify-between border-t border-line py-1"><span>{variantText(labels.get(l.variant_id))}</span>
                <span className="tabular-nums">{l.qty_dispatched}/{l.qty_ordered} · {tzs(l.unit_price)}</span></li>))}</ul>
            {(o.status === "approved" || o.status === "partially_dispatched") && (
              <form action={cancelConsignment} className="mt-2 flex flex-wrap gap-2">
                <input type="hidden" name="order" value={o.id} /><input type="hidden" name="back" value="/wholesale?tab=orders" />
                <input name="reason" required placeholder={x.sales.reason} className="input min-w-48 flex-1" />
                <button className="btn btn-danger">{w.cancel}</button>
              </form>
            )}
          </article>
        ))}
      </div>
    );
  }

  async function Sell() {
    if (sp.pending) {
      const { data: a } = await supabase.from("approval_requests").select("id, status, reasons, summary").eq("id", sp.pending).maybeSingle();
      return (
        <section className="card space-y-3 p-5 text-sm">
          <p className="font-semibold">{w.pendingApproval}</p>
          {a && <p className="text-muted">{(a.reasons as string[]).map((r) => x.pos.approvalWhy[r] ?? r).join(", ")} · {tzs((a.summary as { total: number }).total)} · <strong>{a.status}</strong></p>}
          {a?.status === "approved" && (
            <form action={resubmitWholesaleSale}><input type="hidden" name="approval" value={a.id} />
              <input type="hidden" name="back" value={`/wholesale?tab=sell&pending=${a.id}`} />
              <button className="btn btn-primary">{w.resubmit}</button></form>
          )}
        </section>
      );
    }
    const d = sp.design ? await getDesign(sp.design) : null;
    return (
      <section className="card space-y-3 p-4">
        <DesignPicker label={x.pos.chooseSize} keep={{ tab: "sell" }} selected={sp.design} />
        {d?.design && (
          <form action={wholesaleSale} className="space-y-3">
            <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="back" value="/wholesale?tab=sell" />
            <VariantMatrix variants={d.variants} inputPrefix="q_" />
            <div className="grid gap-3 sm:grid-cols-2">
              <label><span className="label">{w.partner}</span><select name="partner" required className="input">{rows.map((r) => <option key={r.partner_id} value={r.partner_id}>{r.name}</option>)}</select></label>
              <label><span className="label">{w.source}</span><select name="source" className="input">{sources.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label>
              <label className="sm:col-span-2"><span className="label">{x.pos.note}</span><input name="note" className="input" /></label>
            </div>
            <button className="btn btn-primary">{w.sell}</button>
          </form>
        )}
      </section>
    );
  }
}
