import { saveCustomer } from "@/app/actions/sales";
import type { SalesDict } from "@/lib/i18n-sales";

type C = { id: string; name: string; phone_e164: string | null; kind: string; credit_limit: number; terms_days: number; region: string | null; notes: string | null; source: string | null };

export function CustomerForm({ x, c, canCredit, back }: { x: SalesDict; c?: C; canCredit: boolean; back: string }) {
  return (
    <form action={saveCustomer} className="space-y-3">
      <input type="hidden" name="back" value={back} />{c && <input type="hidden" name="id" value={c.id} />}
      <label className="block"><span className="label">{x.customers.name}</span><input name="name" required defaultValue={c?.name} className="input" /></label>
      <label className="block"><span className="label">{x.customers.phone}</span><input name="phone" type="tel" defaultValue={c?.phone_e164 ?? ""} className="input" /></label>
      {canCredit ? (
        <div className="grid grid-cols-3 gap-2">
          <label><span className="label">{x.customers.kind}</span>
            <select name="kind" defaultValue={c?.kind ?? "retail"} className="input"><option value="retail">{x.customers.retail}</option><option value="wholesale">{x.customers.wholesale}</option></select></label>
          <label><span className="label">{x.customers.creditLimit}</span><input name="credit_limit" inputMode="numeric" defaultValue={c?.credit_limit ?? 0} className="input" /></label>
          <label><span className="label">{x.customers.terms}</span><input name="terms_days" inputMode="numeric" defaultValue={c?.terms_days ?? 0} className="input" /></label>
        </div>
      ) : c ? <input type="hidden" name="kind" value={c.kind} /> : <input type="hidden" name="kind" value="retail" />}
      <div className="grid grid-cols-2 gap-2">
        <label><span className="label">{x.customers.region}</span><input name="region" defaultValue={c?.region ?? ""} className="input" /></label>
        <label><span className="label">{x.customers.source}</span><input name="source" defaultValue={c?.source ?? ""} className="input" placeholder="Instagram / WhatsApp / walk-in" /></label>
      </div>
      <label className="block"><span className="label">{x.customers.notes}</span><input name="notes" defaultValue={c?.notes ?? ""} className="input" /></label>
      <button className="btn btn-primary">{x.customers.save}</button>
    </form>
  );
}
