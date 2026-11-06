import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { getDocument } from "pdfjs-dist/legacy/build/pdf.mjs";
import { dailyRunDate, renderDailyPdf } from "@/lib/daily-report";

// Snapshot captured from the real PostgreSQL test database (synthetic data) — regenerate with REGEN_FIXTURES=1 npm run test:db
const snapshot = JSON.parse(readFileSync(join(__dirname, "..", "fixtures", "daily-snapshot.json"), "utf8"));

async function text(bytes: Uint8Array) {
  const doc = await getDocument({ data: bytes }).promise;
  const out: string[] = [];
  for (let i = 1; i <= doc.numPages; i++) out.push((await (await doc.getPage(i)).getTextContent()).items.map((x) => ("str" in x ? x.str : "")).join(" "));
  return { pages: doc.numPages, all: out.join(" ") };
}

describe("daily PDF", () => {
  it("renders the real database snapshot with the right totals and reference", async () => {
    const { pages, all } = await text(await renderDailyPdf(snapshot, "daily_interim", 2));
    expect(pages).toBeGreaterThanOrEqual(1);
    expect(all).toContain(`daily_interim-${snapshot.date}-v2`);
    expect(all).toContain(Number(snapshot.sales.totals.net_sales).toLocaleString("en-US"));
    expect(all).toContain(Number(snapshot.collections.totals.collections).toLocaleString("en-US"));
    expect(all).toContain("Unexplained difference");
    expect(all).toContain("not a tax");
    expect(all).toMatch(/Page 1 of \d+/);
  });
  it("interim covers today; final covers yesterday (business time, UTC+3)", () => {
    expect(dailyRunDate("daily_interim", new Date("2026-11-15T20:30:00Z"))).toBe("2026-11-15"); // 23:30 in Dar
    expect(dailyRunDate("daily_final", new Date("2026-11-15T21:15:00Z"))).toBe("2026-11-15");   // 00:15 on the 16th → final for the 15th
    expect(dailyRunDate("daily_final", new Date("2026-11-16T03:00:00Z"))).toBe("2026-11-15");
  });
});
