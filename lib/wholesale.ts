import "server-only";
import { db } from "./stock";

export type PartnerRow = {
  partner_id: string; name: string; phone: string | null; region: string | null; credit_limit: number; terms_days: number; consignment_enabled: boolean;
  dispatched: number; sold: number; returned: number; lost: number; pending_loss: number; held: number; held_value: number;
  invoiced: number; paid: number; outstanding: number; credit: number; oldest_due: string | null; last_report: string | null;
  next_update_due: string | null; last_reminder: string | null; unresolved: number;
};

export async function partnerOverview(partner: string | null = null): Promise<PartnerRow[]> {
  const supabase = await db();
  const { data } = await supabase.rpc("partner_overview", { p_partner: partner });
  return ((data ?? []) as PartnerRow[]).map((r) => ({ ...r,
    dispatched: Number(r.dispatched), sold: Number(r.sold), returned: Number(r.returned), lost: Number(r.lost), pending_loss: Number(r.pending_loss),
    held: Number(r.held), held_value: Number(r.held_value), invoiced: Number(r.invoiced), paid: Number(r.paid), outstanding: Number(r.outstanding),
    credit: Number(r.credit), unresolved: Number(r.unresolved) }));
}

/** wa.me link with a prefilled message; opening it does not mean it was delivered. */
export function whatsappLink(phone: string | null, text: string): string | null {
  if (!phone) return null;
  return `https://wa.me/${phone.replace(/[^0-9]/g, "")}?text=${encodeURIComponent(text)}`;
}
