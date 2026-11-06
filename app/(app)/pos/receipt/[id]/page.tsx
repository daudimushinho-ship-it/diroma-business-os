import { notFound } from "next/navigation";
import { PrintButton } from "@/components/PrintButton";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db, variantLabels } from "@/lib/stock";
import { tzs } from "@/lib/format";

/** Reprinting a receipt is read-only: nothing is posted again. */
export default async function ReceiptPage({ params }: { params: Promise<{ id: string }> }) {
  const ws = await requireWorkspace("sales.view");
  const { x } = await getSalesDict();
  const { id } = await params;
  const supabase = await db();
  const { data: sale } = await supabase.from("sales")
    .select("id, ref_no, sold_at, entered_at, total, gross_amount, discount_amount, delivery_fee, payment_status, fulfillment_status, channel, customer_id, sold_by, location_id")
    .eq("id", id).maybeSingle();
  if (!sale) notFound();
  const [{ data: lines }, { data: settl }, { data: cust }] = await Promise.all([
    supabase.from("sale_lines").select("id, variant_id, qty, list_price, discount, line_total").eq("sale_id", id),
    supabase.from("sale_settlements").select("kind, amount, payment_id").eq("sale_id", id),
    sale.customer_id ? supabase.from("customers").select("name, phone_e164").eq("id", sale.customer_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });
  const paid = (settl ?? []).reduce((a, s) => a + s.amount, 0);
  return (
    <div className="mx-auto max-w-sm">
      <div className="mb-3 flex justify-end print:hidden"><PrintButton label={x.pos.printReceipt} /></div>
      <article className="card p-5 font-mono text-sm print:border-0 print:p-0">
        <header className="text-center">
          <p className="text-lg font-bold tracking-[0.3em]">DIROMA</p>
          <p className="text-xs">Spirit of Fashion · Kariakoo</p>
          <p className="mt-2">{x.sales.receipt} {sale.ref_no}</p>
          <p className="text-xs">{fmt.format(new Date(sale.sold_at))}</p>
          {cust && <p className="text-xs">{cust.name}</p>}
        </header>
        <hr className="my-3 border-dashed border-line" />
        <ul className="space-y-1.5">
          {(lines ?? []).map((l) => {
            const v = labels.get(l.variant_id);
            return (
              <li key={l.id}>
                <p>{v?.code} {v?.color} {v?.size}</p>
                <p className="flex justify-between"><span>{l.qty} × {l.list_price.toLocaleString("en-US")}{l.discount ? ` − ${l.discount.toLocaleString("en-US")}` : ""}</span><span>{l.line_total.toLocaleString("en-US")}</span></p>
              </li>
            );
          })}
        </ul>
        <hr className="my-3 border-dashed border-line" />
        {sale.delivery_fee > 0 && <p className="flex justify-between"><span>{x.pos.deliveryFee}</span><span>{sale.delivery_fee.toLocaleString("en-US")}</span></p>}
        <p className="flex justify-between text-base font-bold"><span>{x.pos.total}</span><span>{tzs(sale.total)}</span></p>
        <p className="flex justify-between"><span>{x.pos.paid}</span><span>{tzs(paid)}</span></p>
        {sale.total - paid > 0 && <p className="flex justify-between"><span>{x.pos.due}</span><span>{tzs(sale.total - paid)}</span></p>}
        <p className="mt-3 text-center text-xs">Asante kwa kununua DIROMA</p>
      </article>
    </div>
  );
}
