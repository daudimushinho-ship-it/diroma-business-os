import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Stat } from "@/components/Stat";
import { CustomerForm } from "@/components/CustomerForm";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db } from "@/lib/stock";
import { moneyAccounts, myShift } from "@/lib/sales";
import { tzs } from "@/lib/format";
import { collectPayment } from "@/app/actions/sales";

export default async function CustomerPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("customers.view");
  const { x } = await getSalesDict();
  const { id } = await params;
  const sp = await searchParams;
  const supabase = await db();
  const { data: c } = await supabase.from("customers").select("id, name, phone_e164, kind, credit_limit, terms_days, region, notes, source").eq("id", id).maybeSingle();
  if (!c) notFound();
  const [{ data: balances }, { data: open }, { data: recent }] = await Promise.all([
    supabase.rpc("customer_balances"), supabase.rpc("customer_open_sales", { p_customer: id }),
    supabase.from("sales").select("id, ref_no, sold_at, total, payment_status").eq("customer_id", id).order("sold_at", { ascending: false }).limit(30),
  ]);
  const b = ((balances ?? []) as { customer_id: string; receivable: number; credit: number }[]).find((r) => r.customer_id === id);
  const shift = await myShift();
  const accounts = (await moneyAccounts()).filter((a) => a.kind !== "cash" || a.id === shift?.cash_account_id);
  const back = `/customers/${id}`;
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: ws.business.timezone });
  return (
    <div className="mx-auto max-w-5xl space-y-5">
      <PageHeader title={c.name} subtitle={`${c.phone_e164 ?? ""} · ${c.kind === "wholesale" ? x.customers.wholesale : x.customers.retail}`} />
      <Flash ok={sp.ok} err={sp.err} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label={x.customers.receivable} value={tzs(Number(b?.receivable ?? 0))} />
        <Stat label={x.customers.credit} value={tzs(Number(b?.credit ?? 0))} />
        <Stat label={x.customers.creditLimit} value={tzs(c.credit_limit)} />
        <Stat label={x.customers.terms} value={String(c.terms_days)} />
      </div>
      <div className="grid gap-5 lg:grid-cols-2">
        <section className="card p-4 text-sm">
          <h2 className="mb-2 font-semibold">{x.customers.openSales}</h2>
          {((open ?? []) as { sale_id: string; ref_no: string; sold_at: string; total: number; balance: number }[]).map((s) => (
            <p key={s.sale_id} className="flex justify-between border-t border-line py-1.5 first:border-0">
              <Link href={`/sales/${s.sale_id}`} className="font-mono text-gold-ink underline">{s.ref_no}</Link>
              <span>{fmt.format(new Date(s.sold_at))}</span><span className="tabular-nums font-semibold">{tzs(s.balance)}</span></p>
          ))}
          {can(ws, "payments.collect") && (
            <form action={collectPayment} className="mt-4 space-y-2 border-t border-line pt-3">
              <input type="hidden" name="customer" value={id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
              <h3 className="font-semibold">{x.customers.collect}</h3>
              <div className="flex flex-wrap gap-2">
                <select name="account" className="input w-auto">{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
                <input name="amount" inputMode="numeric" required placeholder={x.customers.amount} className="input w-36" />
                <input name="ref" placeholder={x.pos.providerRef} className="input w-44" />
                <button className="btn btn-primary">{x.customers.collect}</button>
              </div>
              <p className="text-xs text-muted">{x.customers.collectNote}</p>
            </form>
          )}
        </section>
        <section className="card p-4 text-sm">
          <h2 className="mb-2 font-semibold">{x.customers.history}</h2>
          {(recent ?? []).map((s) => (
            <p key={s.id} className="flex justify-between border-t border-line py-1.5 first:border-0">
              <Link href={`/sales/${s.id}`} className="font-mono text-gold-ink underline">{s.ref_no}</Link>
              <span>{fmt.format(new Date(s.sold_at))}</span><span>{s.payment_status}</span><span className="tabular-nums">{tzs(s.total)}</span></p>
          ))}
        </section>
      </div>
      {can(ws, "customers.manage") && <section className="card p-5"><CustomerForm x={x} c={c} canCredit={can(ws, "credit.manage")} back={back} /></section>}
    </div>
  );
}
