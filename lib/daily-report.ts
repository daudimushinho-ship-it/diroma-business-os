import { renderReportPdf, type PdfSection } from "./pdf";
import { reportSections } from "./report-docs";

export type DailyKind = "daily_interim" | "daily_final";
type J = Record<string, unknown>;

/** Builds the daily owner PDF from public.daily_snapshot(). Pure function: same snapshot → same document content. */
export async function renderDailyPdf(snapshot: J, kind: DailyKind, version: number): Promise<Uint8Array> {
  const date = String(snapshot.date);
  const money = (snapshot.money as J[]) ?? [];
  const shifts = (snapshot.shifts as J[]) ?? [];
  const stock = (snapshot.stock as J) ?? {};
  const ageing = (snapshot.ageing as J) ?? {};
  const n = (v: unknown) => (v === null || v === undefined ? null : Number(v));
  const sections: PdfSection[] = [
    ...reportSections("sales", snapshot.sales, "en").slice(0, 3),
    ...reportSections("collections", snapshot.collections, "en").slice(0, 2),
    ...reportSections("reconciliation", snapshot.reconciliation, "en"),
    ...reportSections("pnl", snapshot.pnl, "en"),
    { heading: "Money accounts (book balance at end of day, not reconciled to statements)",
      columns: [{ label: "Account", width: 4 }, { label: "Type", width: 2 }, { label: "Balance", width: 3, align: "right" }],
      rows: money.map((m) => [String(m.account), String(m.kind), n(m.balance)]),
      totals: ["Total", "", money.reduce((a, m) => a + Number(m.balance ?? 0), 0)] },
    { heading: "Shifts", columns: [{ label: "Ref", width: 2 }, { label: "Cashier", width: 3 }, { label: "Status", width: 2 },
        { label: "Expected", width: 2, align: "right" }, { label: "Counted", width: 2, align: "right" }, { label: "Variance", width: 2, align: "right" }],
      rows: shifts.map((s) => [String(s.ref), String(s.cashier), String(s.status), n(s.expected), n(s.counted), n(s.variance)]) },
    { heading: "Stock (units, now)", columns: [{ label: "Location type", width: 4 }, { label: "Units", width: 2, align: "right" }],
      rows: [["Store", n(stock.store)], ["Shop", n(stock.shop)], ["In transit", n(stock.transit)], ["Inspection / damaged", n(stock.inspection)],
             ["With partners", n(stock.partners)], ["Units without known cost", n(stock.units_without_cost)]],
      totals: ["Total", n(stock.total)] },
    { heading: "Receivables ageing (as of this date)", columns: [{ label: "Bucket", width: 4 }, { label: "Amount", width: 2, align: "right" }],
      rows: [["Not yet due", n(ageing.current)], ["1-7 days overdue", n(ageing.d1_7)], ["8-30", n(ageing.d8_30)], ["31-60", n(ageing.d31_60)],
             ["61-90", n(ageing.d61_90)], ["90+", n(ageing.d90p)]], totals: ["Total", n(ageing.total)] },
    ...reportSections("exceptions", snapshot.exceptions, "en").slice(0, 1),
  ];
  const label = kind === "daily_final" ? "Final daily report" : "Daily report (23:30, day-to-time)";
  return renderReportPdf({
    title: `${label} — ${date}`, subtitle: kind === "daily_interim" ? "Transactions after 23:30 appear in the final report generated after midnight." : undefined,
    period: date, timezone: String((snapshot.business as J)?.timezone ?? "Africa/Dar_es_Salaam"), generatedAt: String(snapshot.generated_at),
    generatedBy: "scheduled job", reference: `${kind}-${date}-v${version}-${String(snapshot.fingerprint).slice(0, 8)}`, sections,
    notes: ["Operational report - not a tax (TRA/EFD) certificate.", "Costs/profit computed at average cost; units without a known cost are flagged."],
  });
}

/** Business calendar dates for the two runs, given the current instant. */
export function dailyRunDate(kind: DailyKind, now: Date = new Date()): string {
  const local = new Date(now.getTime() + 3 * 3600_000); // Africa/Dar_es_Salaam, UTC+03:00, no DST
  if (kind === "daily_final") local.setUTCDate(local.getUTCDate() - 1);
  return local.toISOString().slice(0, 10);
}
