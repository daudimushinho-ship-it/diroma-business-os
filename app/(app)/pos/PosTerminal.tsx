"use client";
import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { postSale, type SaleInput, type SaleResult } from "@/app/actions/sales";
import type { PosItem } from "@/lib/sales";
import type { SalesDict } from "@/lib/i18n-sales";

type Customer = { id: string; name: string; phone_e164: string | null; kind: "retail" | "wholesale" };
type Account = { id: string; code: string; name: string; kind: "cash" | "mobile" | "bank" };
type CartLine = { item: PosItem; qty: number; discount: number };
type Pay = { key: number; account: string; amount: string; ref: string };

const tzs = (n: number) => "TZS " + Math.round(n).toLocaleString("en-US");
const newId = () => crypto.randomUUID();

export function PosTerminal({ x, items, customers, accounts, shift }: {
  x: SalesDict; items: PosItem[]; customers: Customer[]; accounts: Account[];
  shift: { id: string; location_id: string; cash_account_id: string };
}) {
  const [q, setQ] = useState("");
  const [design, setDesign] = useState<string | null>(null);
  const [cart, setCart] = useState<CartLine[]>([]);
  const [custQ, setCustQ] = useState("");
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [wholesale, setWholesale] = useState(false);
  const [delivery, setDelivery] = useState(false);
  const [fee, setFee] = useState("");
  const [pays, setPays] = useState<Pay[]>([{ key: 1, account: shift.cash_account_id, amount: "", ref: "" }]);
  const [backdate, setBackdate] = useState("");
  const [source, setSource] = useState("");
  const [note, setNote] = useState("");
  const [idem, setIdem] = useState(newId);
  const [approval, setApproval] = useState<{ id: string; reasons: string[] } | null>(null);
  const [result, setResult] = useState<SaleResult | null>(null);
  const [step, setStep] = useState<"items" | "cart" | "pay">("items");
  const [pending, start] = useTransition();

  const channel: "retail" | "wholesale" = wholesale && customer?.kind === "wholesale" ? "wholesale" : "retail";
  const priceOf = (i: PosItem) => (channel === "wholesale" ? i.wholesale_price : i.retail_price);

  const designs = useMemo(() => {
    const term = q.trim().toLowerCase();
    const map = new Map<string, { id: string; code: string; name: string; items: PosItem[] }>();
    for (const i of items) {
      const hay = `${i.code} ${i.name} ${i.color} ${i.barcode}`.toLowerCase();
      if (term && !hay.includes(term)) continue;
      const d = map.get(i.design_id) ?? { id: i.design_id, code: i.code, name: i.name, items: [] };
      d.items.push(i); map.set(i.design_id, d);
    }
    return [...map.values()].sort((a, b) => a.code.localeCompare(b.code)).slice(0, 60);
  }, [items, q]);
  const exact = useMemo(() => items.find((i) => i.barcode === q.trim().toUpperCase()), [items, q]);

  const subtotal = cart.reduce((a, l) => a + (priceOf(l.item) ?? 0) * l.qty - l.discount, 0);
  const deliveryFee = delivery ? Math.max(0, Math.round(Number(fee.replace(/[,\s]/g, "")) || 0)) : 0;
  const total = subtotal + deliveryFee;
  const paid = pays.reduce((a, p) => a + (Math.round(Number(p.amount.replace(/[,\s]/g, ""))) || 0), 0);
  const due = total - paid;

  function add(i: PosItem) {
    if (priceOf(i) == null) return;
    setCart((c) => {
      const ex = c.find((l) => l.item.variant_id === i.variant_id);
      if (ex) return c.map((l) => (l === ex ? { ...l, qty: Math.min(l.qty + 1, i.available) } : l));
      return [...c, { item: i, qty: 1, discount: 0 }];
    });
    setResult(null); setApproval(null);
  }
  function update(id: string, patch: Partial<CartLine>) {
    setCart((c) => c.map((l) => (l.item.variant_id === id ? { ...l, ...patch } : l)).filter((l) => l.qty > 0));
    setApproval(null);
  }
  function reset() {
    setCart([]); setCustomer(null); setWholesale(false); setDelivery(false); setFee(""); setBackdate(""); setSource(""); setNote("");
    setPays([{ key: 1, account: shift.cash_account_id, amount: "", ref: "" }]); setIdem(newId()); setApproval(null); setStep("items");
  }

  function submit(withApproval: string | null) {
    const input: SaleInput = {
      idem, location: shift.location_id, shift: shift.id, customer: customer?.id ?? null, channel,
      lines: cart.map((l) => ({ variant_id: l.item.variant_id, qty: l.qty, discount: l.discount })),
      delivery_fee: deliveryFee, fulfillment: delivery ? "awaiting_delivery" : "collected",
      payments: pays.filter((p) => Number(p.amount) > 0).map((p) => p.account === "credit"
        ? { method: "customer_credit" as const, amount: Math.round(Number(p.amount.replace(/[,\s]/g, ""))) }
        : { account_id: p.account, amount: Math.round(Number(p.amount.replace(/[,\s]/g, ""))), provider_ref: p.ref || undefined }),
      sold_at: backdate || null, source: source || null, note: note || null, approval: withApproval,
    };
    start(async () => {
      const r = await postSale(input);
      setResult(r);
      if (r.status === "approval_required") setApproval({ id: r.approval_id, reasons: r.reasons });
      if (r.status === "posted") setApproval(null);
    });
  }

  if (result?.status === "posted") {
    return (
      <div role="status" className="card mx-auto max-w-md p-6 text-center">
        <p className="text-3xl" aria-hidden>✓</p>
        <h2 className="mt-2 text-xl font-semibold">{x.pos.posted}</h2>
        <p className="mt-1 font-mono">{result.ref_no}</p>
        <p className="mt-2 text-lg">{tzs(result.total)}{result.due > 0 && <span className="text-warn"> · {x.pos.due} {tzs(result.due)}</span>}</p>
        <div className="mt-5 flex justify-center gap-2">
          <Link href={`/pos/receipt/${result.sale_id}`} className="btn btn-ghost">{x.pos.printReceipt}</Link>
          <button onClick={() => { setResult(null); reset(); }} className="btn btn-primary">{x.pos.newSale}</button>
        </div>
      </div>
    );
  }

  const canPay = cart.length > 0 && due >= 0 && !pending;
  const stepBtn = (k: typeof step, label: string) => (
    <button type="button" onClick={() => setStep(k)} aria-pressed={step === k}
      className={`flex-1 rounded-lg px-3 py-2 text-sm ${step === k ? "bg-espresso text-ivory" : "bg-paper border border-line"}`}>{label}</button>
  );

  return (
    <div>
      <div className="mb-3 flex gap-2 lg:hidden">
        {stepBtn("items", `1 · ${x.pos.search.split(":")[0]}`)}{stepBtn("cart", `2 · ${x.pos.cart} (${cart.length})`)}{stepBtn("pay", `3 · ${x.pos.payments}`)}
      </div>
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)]">
        {/* Products */}
        <section className={`card p-4 ${step === "items" ? "" : "hidden lg:block"}`} aria-label="Products">
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={x.pos.search} className="input" autoFocus
            onKeyDown={(e) => { if (e.key === "Enter" && exact) { add(exact); setQ(""); } }} aria-label={x.pos.search} />
          <ul className="mt-3 max-h-[65vh] space-y-2 overflow-y-auto">
            {designs.map((d) => (
              <li key={d.id} className="rounded-lg border border-line">
                <button type="button" onClick={() => setDesign(design === d.id ? null : d.id)} className="flex w-full items-center justify-between px-3 py-2 text-left">
                  <span><span className="font-mono text-xs text-muted">{d.code}</span><span className="block text-sm font-semibold">{d.name}</span></span>
                  <span className="text-xs text-muted">{d.items.reduce((a, i) => a + i.available, 0)} {x.pos.inStock}</span>
                </button>
                {design === d.id && (
                  <div className="border-t border-line px-3 py-2">
                    <p className="mb-2 text-xs text-muted">{x.pos.chooseSize}</p>
                    {[...new Set(d.items.map((i) => i.color))].map((color) => (
                      <div key={color} className="mb-2">
                        <p className="text-xs font-medium">{color}</p>
                        <div className="mt-1 flex flex-wrap gap-1.5">
                          {d.items.filter((i) => i.color === color).sort((a, b) => a.size.localeCompare(b.size, undefined, { numeric: true })).map((i) => (
                            <button key={i.variant_id} type="button" onClick={() => add(i)} disabled={priceOf(i) == null}
                              className="min-w-14 rounded-md border border-line px-2 py-1.5 text-sm hover:border-espresso disabled:opacity-40"
                              title={priceOf(i) == null ? x.pos.unpriced : `${i.available} ${x.pos.inStock}`}>
                              <span className="font-semibold">{i.size}</span><span className="block text-[0.65rem] text-muted">{i.available}</span>
                            </button>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </li>
            ))}
          </ul>
        </section>

        {/* Cart */}
        <section className={`card p-4 ${step === "cart" ? "" : "hidden lg:block"}`} aria-label={x.pos.cart}>
          <h2 className="mb-2 font-semibold">{x.pos.cart}</h2>
          {cart.length === 0 ? <p className="text-sm text-muted">{x.pos.empty}</p> : (
            <ul className="divide-y divide-line">
              {cart.map((l) => (
                <li key={l.item.variant_id} className="py-2 text-sm">
                  <p className="font-medium">{l.item.code} · {l.item.color} · <strong>{l.item.size}</strong></p>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <button type="button" onClick={() => update(l.item.variant_id, { qty: l.qty - 1 })} className="h-9 w-9 rounded-md border border-line" aria-label="−">−</button>
                    <span className="w-6 text-center tabular-nums">{l.qty}</span>
                    <button type="button" onClick={() => update(l.item.variant_id, { qty: Math.min(l.qty + 1, l.item.available) })} className="h-9 w-9 rounded-md border border-line" aria-label="+">+</button>
                    <span className="text-muted">× {tzs(priceOf(l.item) ?? 0)}</span>
                    <label className="ml-auto flex items-center gap-1 text-xs text-muted">{x.pos.discount}
                      <input inputMode="numeric" value={l.discount || ""} onChange={(e) => update(l.item.variant_id, { discount: Math.max(0, Math.round(Number(e.target.value.replace(/[,\s]/g, "")) || 0)) })}
                        className="h-9 w-24 rounded-md border border-line px-2 text-right" /></label>
                  </div>
                </li>
              ))}
            </ul>
          )}
          <div className="mt-4 space-y-3 border-t border-line pt-3 text-sm">
            <label className="block"><span className="label">{x.pos.customer}</span>
              <input value={custQ} onChange={(e) => setCustQ(e.target.value)} placeholder={customer ? customer.name : x.pos.walkIn} className="input" list="pos-customers"
                onBlur={() => { const c = customers.find((c) => `${c.name} ${c.phone_e164 ?? ""}`.trim() === custQ.trim() || c.name === custQ.trim()); setCustomer(c ?? null); if (!c) setCustQ(""); setApproval(null); }} />
              <datalist id="pos-customers">{customers.map((c) => <option key={c.id} value={`${c.name} ${c.phone_e164 ?? ""}`.trim()} />)}</datalist>
            </label>
            {customer?.kind === "wholesale" && (
              <label className="flex items-center gap-2"><input type="checkbox" checked={wholesale} onChange={(e) => { setWholesale(e.target.checked); setApproval(null); }} /> {x.pos.wholesale}</label>
            )}
            <label className="flex items-center gap-2"><input type="checkbox" checked={delivery} onChange={(e) => setDelivery(e.target.checked)} /> {x.pos.delivery}</label>
            {delivery && <input inputMode="numeric" value={fee} onChange={(e) => setFee(e.target.value)} placeholder={x.pos.deliveryFee} className="input" />}
            <details><summary className="cursor-pointer text-muted">{x.pos.backdate} · {x.pos.source} · {x.pos.note}</summary>
              <div className="mt-2 space-y-2">
                <input type="datetime-local" value={backdate} onChange={(e) => { setBackdate(e.target.value); setApproval(null); }} className="input" aria-label={x.pos.backdate} />
                <input value={source} onChange={(e) => setSource(e.target.value)} placeholder={`${x.pos.source}: Instagram / WhatsApp / walk-in`} className="input" />
                <input value={note} onChange={(e) => setNote(e.target.value)} placeholder={x.pos.note} className="input" />
              </div>
            </details>
          </div>
        </section>

        {/* Checkout */}
        <section className={`card p-4 ${step === "pay" ? "" : "hidden lg:block"}`} aria-label={x.pos.payments}>
          <dl className="space-y-1 text-sm">
            <div className="flex justify-between"><dt>{x.pos.total}</dt><dd className="text-2xl font-semibold tabular-nums">{tzs(total)}</dd></div>
            <div className="flex justify-between text-muted"><dt>{x.pos.paid}</dt><dd className="tabular-nums">{tzs(paid)}</dd></div>
            <div className={`flex justify-between ${due > 0 ? "text-warn" : due < 0 ? "text-bad" : "text-ok"}`}><dt>{x.pos.due}</dt><dd className="tabular-nums">{tzs(due)}</dd></div>
          </dl>
          <div className="mt-4 space-y-2">
            {pays.map((p, idx) => (
              <div key={p.key} className="space-y-1 rounded-lg border border-line p-2">
                <select value={p.account} onChange={(e) => setPays((ps) => ps.map((y) => y.key === p.key ? { ...y, account: e.target.value } : y))}
                  className="input w-full" aria-label={x.pos.method}>
                  {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
                  {customer && <option value="credit">{x.pos.customerCredit}</option>}
                </select>
                <input inputMode="numeric" value={p.amount} onChange={(e) => setPays((ps) => ps.map((y) => y.key === p.key ? { ...y, amount: e.target.value } : y))}
                  className="input w-full text-right text-lg" aria-label={x.pos.amount} placeholder="0" />
                <div className="flex gap-2">
                  {accounts.find((a) => a.id === p.account)?.kind !== "cash" && p.account !== "credit" &&
                    <input value={p.ref} onChange={(e) => setPays((ps) => ps.map((y) => y.key === p.key ? { ...y, ref: e.target.value } : y))} placeholder={x.pos.providerRef} className="input text-xs" />}
                  <button type="button" onClick={() => setPays((ps) => ps.map((y) => y.key === p.key ? { ...y, amount: String(Math.max(0, (Number(y.amount) || 0) + due)) } : y))}
                    className="btn btn-ghost h-9 min-h-0 whitespace-nowrap py-1 text-xs">{x.pos.payAll}</button>
                  {idx > 0 && <button type="button" onClick={() => setPays((ps) => ps.filter((y) => y.key !== p.key))} className="btn btn-ghost h-9 min-h-0 py-1 text-xs" aria-label="remove">✕</button>}
                </div>
              </div>
            ))}
            <button type="button" onClick={() => setPays((ps) => [...ps, { key: Date.now(), account: accounts.find((a) => a.kind !== "cash")?.id ?? shift.cash_account_id, amount: "", ref: "" }])}
              className="text-sm font-medium text-gold-ink underline">+ {x.pos.addPayment}</button>
          </div>

          {result?.status === "error" && <p role="alert" className="mt-3 rounded-lg bg-[#fdf1ef] px-3 py-2 text-sm text-bad">{result.message}</p>}
          {approval && (
            <div role="status" className="mt-3 rounded-lg border border-champagne bg-[#fffaf0] p-3 text-sm">
              <p className="font-semibold">{x.pos.approvalNeeded}</p>
              <p className="text-muted">{approval.reasons.map((r) => x.pos.approvalWhy[r] ?? r).join(", ")}</p>
              <button type="button" disabled={pending} onClick={() => submit(approval.id)} className="btn btn-primary mt-2 w-full">{x.pos.checkApproval}</button>
            </div>
          )}
          {!approval && (
            <button type="button" disabled={!canPay} onClick={() => submit(null)} className="btn btn-primary mt-4 w-full text-base">
              {pending ? "…" : `${x.pos.submit} · ${tzs(total)}`}
            </button>
          )}
        </section>
      </div>
    </div>
  );
}
