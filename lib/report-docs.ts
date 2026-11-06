import type { PdfColumn, PdfSection } from "./pdf";
import type { Lang } from "./i18n";

export const REPORT_KINDS = ["sales", "collections", "reconciliation", "pnl", "products", "stock", "ageing", "expenses", "staff", "wholesale", "exceptions", "trial_balance"] as const;
export type ReportKind = (typeof REPORT_KINDS)[number];

const L = {
  sw: {
    sales: "Mauzo", collections: "Makusanyo", reconciliation: "Kulinganisha mauzo na makusanyo", pnl: "Faida na hasara (P&L)", products: "Utendaji wa bidhaa",
    stock: "Stoki na thamani", ageing: "Umri wa madeni", expenses: "Matumizi", staff: "Wafanyakazi", wholesale: "Wateja wa jumla", exceptions: "Mambo yasiyo ya kawaida",
    trial_balance: "Trial balance", date: "Tarehe", count: "Idadi", units: "Vipande", gross: "Jumla ghafi", discounts: "Punguzo", goods: "Bidhaa (net)",
    delivery: "Kupeleka", returns: "Marejesho", net: "Mauzo halisi", amount: "Kiasi", key: "Kundi", channel: "Bei (rejareja/jumla)", source: "Chanzo cha mteja",
    location: "Eneo", method: "Njia", account: "Akaunti", item: "Kipengele", customer: "Mteja", current: "Bado", total: "Jumla", code: "Code", name: "Jina",
    color: "Rangi", size: "Saizi", store: "Stoo", shop: "Duka", transit: "Njiani", inspection: "Ukaguzi", partners: "Kwa wabia", sold30: "Imeuzwa siku 30",
    cover: "Siku za stoki", age: "Umri (siku)", value: "Thamani", revenue: "Mapato", cogs: "Gharama ya bidhaa", margin: "Faida %", sellThrough: "Sell-through %",
    onHand: "Iliyopo", category: "Aina", paid: "Imelipwa", role: "Nafasi", collected: "Amekusanya", shifts: "Zamu", variance: "Tofauti ya pesa",
    partner: "Mbia", dispatched: "Ametumiwa", sold: "Ameuza", returned: "Amerudisha", lost: "Zimepotea", invoiced: "Invoices", held: "Bado anazo",
    outstanding: "Deni", debit: "Debit", credit: "Credit", balance: "Salio", reason: "Sababu", status: "Hali", totals: "Muhtasari",
    grossProfit: "Faida ghafi", unitsNoCost: "Vipande bila gharama inayojulikana", revenueNoCost: "Mapato bila gharama inayojulikana",
    forPeriod: "Kwa mauzo ya kipindi hiki", oldDebt: "Madeni ya zamani yaliyokusanywa", advances: "Malipo ya ziada (salio la mteja)",
    creditUsed: "Salio la mteja lililotumika (si pesa)", refundsPaid: "Pesa zilizorudishwa", manualUnverified: "Simu/benki zilizoingizwa kwa mkono (hazijathibitishwa)",
    recDelivery: "+ Kupeleka", recAr: "− Mabadiliko ya madeni (mwisho − mwanzo)", recCredit: "+ Mabadiliko ya salio za wateja", recRefunds: "+ Pesa zilizorudishwa",
    recExpected: "= Makusanyo yanayotarajiwa", recActual: "Makusanyo halisi", recDiff: "Tofauti isiyoelezeka",
    costsNote: "Gharama na faida zinaonyeshwa kwa wenye ruhusa ya gharama tu.",
    fiscalNote: "Ripoti ya uendeshaji — si ripoti ya kodi (TRA/EFD).",
  },
  en: {
    sales: "Sales", collections: "Collections", reconciliation: "Sales vs collections reconciliation", pnl: "Profit and loss (P&L)", products: "Product performance",
    stock: "Stock and value", ageing: "Receivables ageing", expenses: "Expenses", staff: "Staff", wholesale: "Wholesale partners", exceptions: "Exceptions",
    trial_balance: "Trial balance", date: "Date", count: "Count", units: "Units", gross: "Gross", discounts: "Discounts", goods: "Goods (net)",
    delivery: "Delivery", returns: "Returns", net: "Net sales", amount: "Amount", key: "Group", channel: "Price channel", source: "Customer source",
    location: "Location", method: "Method", account: "Account", item: "Item", customer: "Customer", current: "Not due", total: "Total", code: "Code", name: "Name",
    color: "Colour", size: "Size", store: "Store", shop: "Shop", transit: "Transit", inspection: "Inspection", partners: "With partners", sold30: "Sold 30d",
    cover: "Cover days", age: "Age (days)", value: "Value", revenue: "Revenue", cogs: "COGS", margin: "Margin %", sellThrough: "Sell-through %",
    onHand: "On hand", category: "Category", paid: "Paid", role: "Role", collected: "Collected", shifts: "Shifts", variance: "Cash variance",
    partner: "Partner", dispatched: "Dispatched", sold: "Sold", returned: "Returned", lost: "Lost", invoiced: "Invoiced", held: "Still held",
    outstanding: "Outstanding", debit: "Debit", credit: "Credit", balance: "Balance", reason: "Reason", status: "Status", totals: "Summary",
    grossProfit: "Gross profit", unitsNoCost: "Units without known cost", revenueNoCost: "Revenue without known cost",
    forPeriod: "For sales in this period", oldDebt: "Old debt collected", advances: "Advances (to customer credit)",
    creditUsed: "Customer credit used (not cash)", refundsPaid: "Refunds paid out", manualUnverified: "Mobile/bank entered manually (unverified)",
    recDelivery: "+ Delivery", recAr: "- Receivables change (closing - opening)", recCredit: "+ Customer credits change", recRefunds: "+ Refunds paid",
    recExpected: "= Expected collections", recActual: "Actual collections", recDiff: "Unexplained difference",
    costsNote: "Costs and profit are shown only to users with cost permission.",
    fiscalNote: "Operational report — not a tax (TRA/EFD) certificate.",
  },
};
export type ReportLabels = (typeof L)["en"];
export const reportLabels = (lang: Lang): ReportLabels => L[lang];

type J = Record<string, unknown>;
const n = (v: unknown) => (v === null || v === undefined ? null : Number(v));
const arr = (v: unknown) => (Array.isArray(v) ? (v as J[]) : []);
const col = (label: string, width = 2, align: "left" | "right" = "right"): PdfColumn => ({ label, width, align });
const left = (label: string, width = 3): PdfColumn => ({ label, width, align: "left" });
const sum = (rows: J[], k: string) => rows.reduce((a, r) => a + (Number(r[k]) || 0), 0);

/** One description of every report → tables shared by the screen, CSV and PDF. */
export function reportSections(kind: ReportKind, data: unknown, lang: Lang): PdfSection[] {
  const t = L[lang];
  if (data === null || data === undefined) return [];
  const d = data as J;
  const totals = (d.totals ?? {}) as J;
  const groupTable = (heading: string, rows: J[], valueKey = "goods_net"): PdfSection => ({
    heading, columns: [left(t.key, 4), col(t.count), col(t.amount, 3)],
    rows: rows.map((r) => [String(r.key ?? "—"), n(r.sales ?? r.count), n(r[valueKey] ?? r.amount ?? r.paid ?? r.total)]),
    totals: [t.total, sum(rows, rows[0]?.sales !== undefined ? "sales" : "count"), sum(rows, rows[0]?.[valueKey] !== undefined ? valueKey : rows[0]?.amount !== undefined ? "amount" : rows[0]?.paid !== undefined ? "paid" : "total")],
  });
  switch (kind) {
    case "sales": {
      const days = arr(d.by_day);
      const out: PdfSection[] = [
        { heading: t.totals, columns: [left(t.item, 4), col(t.amount, 3)], rows: [
          [t.count, n(totals.sales)], [t.units, n(totals.units)], [t.gross, n(totals.gross)], [t.discounts, n(totals.discounts)],
          [t.goods, n(totals.goods_net)], [t.delivery, n(totals.delivery)], [t.returns, n(totals.returns)], [t.net, n(totals.net_sales)]] },
        { heading: `${t.sales} — ${t.date}`, columns: [left(t.date, 2), col(t.count, 1), col(t.units, 1), col(t.gross), col(t.discounts), col(t.goods), col(t.delivery)],
          rows: days.map((r) => [String(r.date), n(r.sales), n(r.units), n(r.gross), n(r.discounts), n(r.goods_net), n(r.delivery)]),
          totals: [t.total, sum(days, "sales"), sum(days, "units"), sum(days, "gross"), sum(days, "discounts"), sum(days, "goods_net"), sum(days, "delivery")] },
        groupTable(t.channel, arr(d.by_channel)), groupTable(t.source, arr(d.by_source)), groupTable(t.location, arr(d.by_location)),
      ];
      const c = d.costs as J | undefined;
      if (c) out.splice(1, 0, { heading: t.cogs, columns: [left(t.item, 4), col(t.amount, 3)], rows: [
        [t.cogs, n(c.cogs)], [t.grossProfit, n(c.gross_profit)], [t.margin, c.margin_pct === null ? "—" : `${c.margin_pct}%`],
        [t.unitsNoCost, n(c.units_cost_unknown)], [t.revenueNoCost, n(c.revenue_cost_unknown)]] });
      return out;
    }
    case "collections": return [
      { heading: t.totals, columns: [left(t.item, 4), col(t.amount, 3)], rows: [
        [t.collections, n(totals.collections)], [t.forPeriod, n(totals.for_period_sales)], [t.oldDebt, n(totals.old_debt)],
        [t.advances, n(totals.advances_to_credit)], [t.creditUsed, n(totals.credit_applied)],
        [t.refundsPaid, n(totals.refunds_paid)], [t.manualUnverified, n(totals.manual_unverified)]] },
      groupTable(t.method, arr(d.by_method), "amount"), groupTable(t.account, arr(d.by_account), "amount"),
      { heading: `${t.collections} — ${t.date}`, columns: [left(t.date, 3), col(t.amount, 3)], rows: arr(d.by_day).map((r) => [String(r.date), n(r.amount)]),
        totals: [t.total, sum(arr(d.by_day), "amount")] },
    ];
    case "reconciliation": return [{ heading: t.reconciliation, columns: [left(t.item, 5), col(t.amount, 3)], rows: [
      [t.net, n(d.net_sales)], [t.recDelivery, n(d.delivery_income)], [t.recAr, n(d.receivables_change)],
      [t.recCredit, n(d.credits_change)], [t.recRefunds, n(d.refunds_paid)], [t.recExpected, n(d.expected_collections)],
      [t.recActual, n(d.actual_collections)], [t.recDiff, n(d.unexplained_difference)]] }];
    case "ageing": {
      const rows = arr(d.rows);
      return [{ heading: `${t.ageing} — ${String(d.as_of)}`, columns: [left(t.customer, 4), col(t.current), col("1-7"), col("8-30"), col("31-60"), col("61-90"), col("90+"), col(t.total)],
        rows: rows.map((r) => [String(r.customer), n(r.current), n(r.d1_7), n(r.d8_30), n(r.d31_60), n(r.d61_90), n(r.d90p), n(r.total)]),
        totals: [t.total, n(totals.current), n(totals.d1_7), n(totals.d8_30), n(totals.d31_60), n(totals.d61_90), n(totals.d90p), n(totals.total)] }];
    }
    case "pnl": {
      const ex = arr(d.expenses);
      return [{ heading: t.pnl, columns: [left(t.item, 5), col(t.amount, 3)], rows: [
        [t.revenue, n(d.revenue)], ["- " + t.returns, n(d.returns)], ["= Net revenue", n(d.net_revenue)], ["- " + t.cogs, n(d.cogs)],
        ["= " + t.grossProfit, n(d.gross_profit)], ["+ " + t.delivery, n(d.delivery_income)],
        ...ex.map((e) => [`- ${String(e.name)}${e.category ? ` (${String(e.category)})` : ""}`, n(e.amount)] as (string | number | null)[]),
        ["= Operating profit", n(d.operating_profit)], [t.unitsNoCost, n(d.units_cost_unknown)]] ,
        totals: undefined }, { heading: "", lines: [String(d.basis ?? "")] }];
    }
    case "stock": {
      const rows = arr(d.rows);
      return [{ heading: t.stock, columns: [left(t.code, 3), left(t.color, 2), left(t.size, 1), col(t.store, 1), col(t.shop, 1), col(t.transit, 1), col(t.inspection, 1),
          col(t.partners, 1), col(t.total, 1), col(t.sold30, 1), col(t.cover, 1), col(t.age, 1), col(t.value, 2)],
        rows: rows.map((r) => [String(r.code), String(r.color), String(r.size), n(r.store), n(r.shop), n(r.transit), n(r.inspection), n(r.partners), n(r.total),
          n(r.sold_30), n(r.cover_days), n(r.age_days), n(r.value)]),
        totals: [t.total, "", "", n(totals.store), n(totals.shop), n(totals.transit), n(totals.inspection), n(totals.partners), n(totals.total), "", "", "", n(totals.value_known)] }];
    }
    case "products": {
      const rows = arr(d.rows);
      return [{ heading: t.products, columns: [left(t.code, 3), left(t.color, 2), left(t.size, 1), col(t.units, 1), col(t.revenue), col(t.cogs), col(t.margin, 1),
          col(t.onHand, 1), col(t.sellThrough, 1)],
        rows: rows.map((r) => [String(r.code), String(r.color), String(r.size), n(r.units), n(r.revenue), n(r.cogs), r.margin_pct === null || r.margin_pct === undefined ? "—" : `${r.margin_pct}%`,
          n(r.on_hand), r.sell_through_pct === null ? "—" : `${r.sell_through_pct}%`]),
        totals: [t.total, "", "", n(totals.units), n(totals.revenue), n(totals.cogs), "", "", ""] }];
    }
    case "expenses": {
      const o = (d.other_costs ?? {}) as J;
      return [groupTable(t.category, arr(d.by_category), "paid"), groupTable(t.location, arr(d.by_location), "paid"),
        { heading: t.totals, columns: [left(t.item, 4), col(t.amount, 3)], rows: [[t.paid, n(totals.paid)], ["Approved, not paid", n(totals.approved_unpaid)],
          ["Awaiting approval", n(totals.awaiting_approval)], ["Courier", n(o.courier)], ["Stock losses", n(o.stock_losses)], ["Cash over/short", n(o.cash_over_short)], ["Fees", n(o.fees)]] }];
    }
    case "staff": {
      const rows = arr(d);
      return [{ heading: t.staff, columns: [left(t.name, 3), left(t.role, 2), col(t.count, 1), col(t.goods), col(t.discounts), col(t.returns), col(t.collected), col(t.shifts, 1), col(t.variance)],
        rows: rows.map((r) => [String(r.name), String(r.role), n(r.sales), n(r.goods_net), n(r.discounts), n(r.returns_on_their_sales), n(r.collections), n(r.shifts_closed), n(r.cash_variance)]),
        totals: [t.total, "", sum(rows, "sales"), sum(rows, "goods_net"), sum(rows, "discounts"), sum(rows, "returns_on_their_sales"), sum(rows, "collections"), sum(rows, "shifts_closed"), sum(rows, "cash_variance")] }];
    }
    case "wholesale": {
      const rows = arr(d);
      return [{ heading: t.wholesale, columns: [left(t.partner, 3), col(t.dispatched, 1), col(t.sold, 1), col(t.returned, 1), col(t.lost, 1), col(t.invoiced), col(t.collected), col(t.held, 1), col(t.outstanding)],
        rows: rows.map((r) => [String(r.partner), n(r.dispatched), n(r.reported_sold), n(r.reported_returned), n(r.reported_lost), n(r.invoiced), n(r.collected), n(r.held_now), n(r.outstanding_now)]),
        totals: [t.total, sum(rows, "dispatched"), sum(rows, "reported_sold"), sum(rows, "reported_returned"), sum(rows, "reported_lost"), sum(rows, "invoiced"), sum(rows, "collected"), sum(rows, "held_now"), sum(rows, "outstanding_now")] }];
    }
    case "exceptions": {
      const ds = (d.discounted_sales ?? {}) as J, ts = (d.transit_shortages ?? {}) as J, rf = (d.refunds ?? {}) as J, cl = (d.consignment_losses ?? {}) as J;
      return [
        { heading: t.exceptions, columns: [left(t.item, 5), col(t.count, 1), col(t.amount, 2)], rows: [
          ["Discounted sales", n(ds.count), n(ds.amount)], ["Backdated sales", arr(d.backdated_sales).length, sum(arr(d.backdated_sales), "total")],
          ["Shift cash variances", arr(d.shift_variances).length, sum(arr(d.shift_variances), "variance")], ["Stock count variances", arr(d.count_variances).length, sum(arr(d.count_variances), "variance")],
          ["Transit shortages (units)", n(ts.count), n(ts.units)], ["Stock losses (value)", null, n(d.stock_losses_value)], ["Refunds", n(rf.count), n(rf.amount)],
          ["Failed deliveries", n(d.failed_deliveries), null], ["Consignment losses (units)", n(cl.count), n(cl.units)]] },
        { heading: "Approvals", columns: [left(t.reason, 3), left(t.status, 2), col(t.count, 1)], rows: arr(d.approvals).map((r) => [String(r.reason), String(r.status), n(r.count)]) },
        { heading: "Shift variances", columns: [left("Ref", 2), left(t.name, 3), col(t.variance, 2), left(t.reason, 4)], rows: arr(d.shift_variances).map((r) => [String(r.ref), String(r.cashier), n(r.variance), String(r.reason ?? "")]) },
      ];
    }
    case "trial_balance": {
      const rows = arr(d.rows);
      return [{ heading: `${t.trial_balance} — ${String(d.as_of)}`, columns: [left(t.code, 1), left(t.name, 4), col(t.debit, 2), col(t.credit, 2), col(t.balance, 2)],
        rows: rows.map((r) => [String(r.code), String(r.name), n(r.debit), n(r.credit), n(r.balance)]), totals: [t.total, "", n(d.total_debit), n(d.total_credit), ""] }];
    }
  }
}

/** CSV rows for any report: every table, with its heading, one after another. */
export function reportCsvRows(sections: PdfSection[]): unknown[][] {
  const out: unknown[][] = [];
  for (const s of sections) {
    if (s.heading) out.push([s.heading]);
    for (const l of s.lines ?? []) out.push([l]);
    if (s.columns) out.push(s.columns.map((c) => c.label));
    for (const r of s.rows ?? []) out.push(r);
    if (s.totals) out.push(s.totals);
    out.push([]);
  }
  return out;
}
