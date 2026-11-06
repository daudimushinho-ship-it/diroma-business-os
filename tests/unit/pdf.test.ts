import { describe, expect, it } from "vitest";
import { getDocument } from "pdfjs-dist/legacy/build/pdf.mjs";
import { pdfSafe, renderReportPdf } from "@/lib/pdf";

async function extract(bytes: Uint8Array): Promise<{ pages: string[] }> {
  const doc = await getDocument({ data: bytes, useSystemFonts: false }).promise;
  const pages: string[] = [];
  for (let i = 1; i <= doc.numPages; i++) {
    const c = await (await doc.getPage(i)).getTextContent();
    pages.push(c.items.map((it) => ("str" in it ? it.str : "")).join(" "));
  }
  return { pages };
}

describe("PDF reports", () => {
  it("renders branded header, repeats table headers, totals and numbered pages", async () => {
    const rows = Array.from({ length: 140 }, (_, i) => [`2026-11-${String((i % 28) + 1).padStart(2, "0")}`, `RCP-${String(i + 1).padStart(6, "0")}`, 450000]);
    const bytes = await renderReportPdf({
      title: "Daily report", period: "2026-11-15", timezone: "Africa/Dar_es_Salaam", generatedAt: "2026-11-15T20:30:00.000Z",
      generatedBy: "scheduled job", reference: "daily_interim-2026-11-15-v1",
      sections: [{ heading: "Sales", columns: [{ label: "Date", width: 2 }, { label: "Receipt", width: 2 }, { label: "Total", width: 2, align: "right" }],
        rows, totals: ["Total", "", 140 * 450000] }],
      notes: ["Operational report - not a fiscal (TRA/EFD) certificate."],
    });
    const { pages } = await extract(bytes);
    expect(pages.length).toBeGreaterThan(2);
    expect(pages[0]).toContain("DIROMA");
    expect(pages[0]).toContain("Africa/Dar_es_Salaam");
    expect(pages[0]).toContain("daily_interim-2026-11-15-v1");
    pages.forEach((p, i) => expect(p).toContain(`Page ${i + 1} of ${pages.length}`));
    pages.forEach((p) => expect(p).toContain("Receipt")); // header repeated on every page
    expect(pages.join(" ")).toContain("63,000,000");
    expect(pages.join(" ")).toContain("RCP-000140");
  });
  it("never crashes on characters outside the PDF font", () => {
    expect(pdfSafe("Stoo → Duka × 2 — Σ ✓")).toBe("Stoo -> Duka x 2 — Total OK");
  });
});
