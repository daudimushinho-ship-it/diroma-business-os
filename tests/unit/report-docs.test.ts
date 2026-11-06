import { describe, expect, it } from "vitest";
import { REPORT_KINDS, reportCsvRows, reportSections } from "@/lib/report-docs";
import { renderReportPdf } from "@/lib/pdf";

const sales = {
  totals: { sales: 3, units: 4, gross: 1350000, discounts: 45000, goods_net: 1305000, delivery: 10000, invoiced_total: 1315000, returns: 450000, net_sales: 855000 },
  by_day: [{ date: "2026-11-14", sales: 1, units: 1, gross: 450000, discounts: 0, goods_net: 450000, delivery: 0 },
           { date: "2026-11-15", sales: 2, units: 3, gross: 900000, discounts: 45000, goods_net: 855000, delivery: 10000 }],
  by_channel: [{ key: "retail", sales: 3, goods_net: 1305000 }], by_source: [{ key: "Instagram", sales: 1, goods_net: 450000 }, { key: "—", sales: 2, goods_net: 855000 }],
  by_location: [{ key: "Shop", sales: 3, goods_net: 1305000 }],
};

describe("report documents", () => {
  it("sales tables carry totals that match the database totals", () => {
    const s = reportSections("sales", sales, "en");
    const byDay = s.find((x) => x.heading.startsWith("Sales —"))!;
    expect(byDay.totals?.[5]).toBe(1305000);
    expect(s.find((x) => x.heading === "Customer source")!.totals?.[2]).toBe(1305000);
    expect(s.some((x) => x.heading === "COGS")).toBe(false); // no costs object → no cost section
  });
  it("cost section appears only when the database included costs", () => {
    const s = reportSections("sales", { ...sales, costs: { cogs: 600000, gross_profit: 255000, margin_pct: 29.8, units_cost_unknown: 1, revenue_cost_unknown: 30000 } }, "sw");
    expect(s.some((x) => x.heading === "Gharama ya bidhaa")).toBe(true);
  });
  it("every report kind renders to CSV and PDF without crashing on empty data", async () => {
    for (const k of REPORT_KINDS) {
      const empty = k === "staff" || k === "wholesale" ? [] : { totals: {}, rows: [], by_day: [], expenses: [] };
      const sections = reportSections(k, empty, "en");
      expect(Array.isArray(reportCsvRows(sections))).toBe(true);
      const pdf = await renderReportPdf({ title: k, period: "x", timezone: "Africa/Dar_es_Salaam", generatedAt: new Date(0).toISOString(), generatedBy: "t", reference: k, sections });
      expect(pdf.byteLength).toBeGreaterThan(500);
    }
  });
});
