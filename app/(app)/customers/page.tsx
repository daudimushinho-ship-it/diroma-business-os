import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { CustomerForm } from "@/components/CustomerForm";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db } from "@/lib/stock";
import { tzs } from "@/lib/format";

export default async function CustomersPage({ searchParams }: { searchParams: Promise<{ q?: string; ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("customers.view");
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const supabase = await db();
  let q = supabase.from("customers").select("id, name, phone_e164, kind, credit_limit, region").order("name").limit(1000);
  if (sp.q) q = q.or(`name.ilike.%${sp.q.replace(/[%,()]/g, "")}%,phone_e164.ilike.%${sp.q.replace(/[^0-9+]/g, "")}%`);
  const [{ data: customers }, { data: balances }] = await Promise.all([q, supabase.rpc("customer_balances")]);
  const bal = new Map(((balances ?? []) as { customer_id: string; receivable: number; credit: number; oldest_open: string | null }[]).map((b) => [b.customer_id, b]));
  const owed = [...bal.values()].reduce((a, b) => a + Number(b.receivable), 0);
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={x.customers.title} subtitle={`${(customers ?? []).length} · ${x.customers.receivable}: ${tzs(owed)}`} />
      <Flash ok={sp.ok} err={sp.err} />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div>
          <form className="mb-3"><input name="q" defaultValue={sp.q} placeholder={`${x.customers.name} / ${x.customers.phone}`} className="input max-w-sm" /></form>
          <div className="card overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">{x.customers.name}</th><th className="px-4 py-2 font-medium">{x.customers.kind}</th>
                <th className="px-4 py-2 text-right font-medium">{x.customers.receivable}</th><th className="px-4 py-2 text-right font-medium">{x.customers.credit}</th></tr></thead>
              <tbody className="divide-y divide-line">
                {(customers ?? []).map((c) => {
                  const b = bal.get(c.id);
                  return (
                    <tr key={c.id} className="hover:bg-ivory">
                      <td className="px-4 py-2"><Link href={`/customers/${c.id}`} className="font-medium text-gold-ink underline">{c.name}</Link>
                        <span className="block text-xs text-muted">{c.phone_e164 ?? ""} {c.region ? `· ${c.region}` : ""}</span></td>
                      <td className="px-4 py-2">{c.kind === "wholesale" ? x.customers.wholesale : x.customers.retail}</td>
                      <td className={`px-4 py-2 text-right tabular-nums ${Number(b?.receivable) > 0 ? "text-warn font-semibold" : ""}`}>{tzs(Number(b?.receivable ?? 0))}</td>
                      <td className="px-4 py-2 text-right tabular-nums">{tzs(Number(b?.credit ?? 0))}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
        {can(ws, "customers.manage") && (
          <section className="card h-fit p-5"><h2 className="mb-3 font-semibold">{x.customers.newCustomer}</h2>
            <CustomerForm x={x} canCredit={can(ws, "credit.manage")} back="/customers" /></section>
        )}
      </div>
    </div>
  );
}
