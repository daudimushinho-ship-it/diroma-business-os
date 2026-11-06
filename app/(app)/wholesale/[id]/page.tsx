import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Stat } from "@/components/Stat";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db, variantLabels, variantText } from "@/lib/stock";
import { partnerOverview, whatsappLink } from "@/lib/wholesale";
import { businessToday, tzs } from "@/lib/format";
import { logReminder, reportConsignment } from "@/app/actions/wholesale";

type Holding = { variant_id: string; design_code: string; design_name: string; color: string; size: string; held: number; pending_loss: number; value: number };

export default async function PartnerPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("wholesale.manage");
  const { x } = await getSalesDict();
  const w = x.wholesale;
  const { id } = await params;
  const sp = await searchParams;
  const [p] = await partnerOverview(id);
  if (!p) notFound();
  const supabase = await db();
  const [{ data: hold }, { data: invoices }, { data: reports }, { data: losses }] = await Promise.all([
    supabase.rpc("partner_holdings", { p_partner: id }),
    supabase.from("sales").select("id, ref_no, sold_at, total, payment_status").eq("customer_id", id).eq("channel", "wholesale").order("sold_at", { ascending: false }).limit(30),
    supabase.from("consignment_reports").select("id, ref_no, report_date, note, sale_id").eq("partner_id", id).order("created_at", { ascending: false }).limit(20),
    supabase.from("consignment_losses").select("id, variant_id, qty, status, created_at").eq("partner_id", id).order("created_at", { ascending: false }).limit(20),
  ]);
  const holdings = ((hold ?? []) as Holding[]).map((h) => ({ ...h, held: Number(h.held), pending_loss: Number(h.pending_loss), value: Number(h.value) }));
  const labels = await variantLabels((losses ?? []).map((l) => l.variant_id));
  const back = `/wholesale/${id}`;
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: ws.business.timezone });
  const wa = whatsappLink(p.phone, w.remindText.replace("{name}", p.name).replace("{held}", String(p.held)));
  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader title={p.name} subtitle={`${p.phone ?? ""} · ${p.region ?? ""} · ${x.customers.creditLimit}: ${tzs(p.credit_limit)} · ${p.terms_days}d`}>
        <div className="flex flex-wrap gap-2">
          <Link href={`/wholesale/${id}/statement`} className="btn btn-ghost">{w.statement}</Link>
          <Link href={`/customers/${id}`} className="btn btn-ghost">{x.customers.collect}</Link>
          {wa && <a href={wa} target="_blank" rel="noopener noreferrer" className="btn btn-ghost">{w.remind}</a>}
        </div>
      </PageHeader>
      <Flash ok={sp.ok} err={sp.err} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-6">
        <Stat label={w.dispatched} value={String(p.dispatched)} /><Stat label={w.sold} value={String(p.sold)} />
        <Stat label={w.returned} value={String(p.returned)} /><Stat label={w.lost} value={String(p.lost)} note={p.pending_loss ? `+${p.pending_loss} ?` : undefined} />
        <Stat label={w.held} value={`${p.held} pcs`} note={tzs(p.held_value)} />
        <Stat label={w.outstanding} value={tzs(p.outstanding)} note={`${w.invoiced} ${tzs(p.invoiced)} · ${w.paid} ${tzs(p.paid)}`} />
      </div>
      <p className="text-xs text-muted">{w.noRevenue} {w.nextUpdate}: {p.next_update_due ?? "—"} · {w.oldestDue}: {p.oldest_due ?? "—"}</p>

      {holdings.length > 0 && (
        <form action={reportConsignment} className="card p-4">
          <input type="hidden" name="partner" value={id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
          <h2 className="font-semibold">{w.report}</h2>
          <p className="mb-3 text-xs text-muted">{w.reportNote}</p>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{x.sales.lines}</th><th className="py-1 text-right font-medium">{w.held}</th>
                <th className="py-1 font-medium">{w.sold}</th><th className="py-1 font-medium">{w.returned}</th><th className="py-1 font-medium">{w.lost}</th></tr></thead>
              <tbody>
                {holdings.map((h) => {
                  const max = h.held - h.pending_loss;
                  return (
                    <tr key={h.variant_id} className="border-t border-line">
                      <td className="py-1.5">{h.design_code} · {h.color} · <strong>{h.size}</strong></td>
                      <td className="py-1.5 text-right tabular-nums">{h.held}{h.pending_loss > 0 && <span className="text-warn"> ({h.pending_loss}?)</span>}</td>
                      {(["sold", "returned", "lost"] as const).map((k) => (
                        <td key={k} className="py-1"><input name={`${k}_${h.variant_id}`} type="number" min={0} max={max} className="h-9 w-20 rounded-md border border-line px-2" aria-label={w[k]} /></td>
                      ))}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div className="mt-3 flex flex-wrap items-end gap-2">
            <label><span className="label">{w.reportDate}</span><input type="date" name="date" required defaultValue={businessToday()} max={businessToday()} className="input" /></label>
            <label className="min-w-48 flex-1"><span className="label">{x.pos.note}</span><input name="note" className="input" placeholder="WhatsApp / simu / ziara" /></label>
            <button className="btn btn-primary">{w.report}</button>
          </div>
        </form>
      )}

      <div className="grid gap-5 lg:grid-cols-2">
        <section className="card p-4 text-sm">
          <h2 className="mb-2 font-semibold">{w.invoices}</h2>
          {(invoices ?? []).map((s) => (
            <p key={s.id} className="flex justify-between border-t border-line py-1.5 first:border-0">
              <Link href={`/sales/${s.id}`} className="font-mono text-gold-ink underline">{s.ref_no}</Link>
              <span>{fmt.format(new Date(s.sold_at))}</span><span>{s.payment_status}</span><span className="tabular-nums">{tzs(s.total)}</span></p>
          ))}
        </section>
        <section className="card p-4 text-sm">
          <h2 className="mb-2 font-semibold">{w.reports}</h2>
          {(reports ?? []).map((r) => <p key={r.id} className="border-t border-line py-1.5 first:border-0"><strong>{r.ref_no}</strong> · {r.report_date} · {r.note}</p>)}
          {(losses ?? []).length > 0 && <>
            <h3 className="mb-1 mt-4 font-semibold">{w.lost}</h3>
            {(losses ?? []).map((l) => <p key={l.id} className="border-t border-line py-1.5 first:border-0">{variantText(labels.get(l.variant_id))} · {l.qty} · <strong>{l.status}</strong></p>)}
          </>}
          <form action={logReminder} className="mt-4 flex gap-2"><input type="hidden" name="partner" value={id} /><input type="hidden" name="back" value={back} />
            <select name="channel" className="input w-auto"><option value="whatsapp">WhatsApp</option><option value="call">Simu / Call</option><option value="sms">SMS</option><option value="visit">Ziara / Visit</option></select>
            <button className="btn btn-ghost">{w.logged}</button></form>
          {p.last_reminder && <p className="mt-1 text-xs text-muted">{fmt.format(new Date(p.last_reminder))}</p>}
        </section>
      </div>
    </div>
  );
}
