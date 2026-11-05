import { describe, expect, it } from "vitest";
import { parseCatalogueCsv } from "@/lib/csv-import";
import { csvCell, toCsv } from "@/lib/format";

const cats = new Set(["suit_2pc", "shirt"]);
const sizes = new Map([["suit_2pc", new Set(["48", "50"])], ["shirt", new Set(["M", "L"])]]);

describe("catalogue CSV import", () => {
  it("parses valid rows, keeps codes with # and leading-zero barcodes", () => {
    const { rows, fatal } = parseCatalogueCsv(
      "design_code,design_name,category,color,size,retail_price,barcode\nDR#2516-43,Slim,suit_2pc,Black,48,\"450,000\",0001234\n", cats, sizes);
    expect(fatal).toBeUndefined();
    expect(rows[0].errors).toEqual([]);
    expect(rows[0].row).toMatchObject({ design_code: "DR#2516-43", retail_price: 450000, barcode: "0001234" });
  });
  it("reports per-row errors with spreadsheet line numbers", () => {
    const { rows } = parseCatalogueCsv("design_code,category,color,size,retail_price\nA,shirt,White,XXL,abc\nA,shirt,White,M,1\nA,shirt,white,M,1\n", cats, sizes);
    expect(rows[0].line).toBe(2);
    expect(rows[0].errors.join()).toMatch(/size XXL/);
    expect(rows[0].errors.join()).toMatch(/retail_price/);
    expect(rows[2].errors.join()).toMatch(/duplicate of line 3/);
  });
  it("rejects files missing required columns", () => {
    expect(parseCatalogueCsv("code,colour\nA,B\n", cats, sizes).fatal).toMatch(/design_code/);
  });
});

describe("CSV export safety", () => {
  it("neutralises spreadsheet formulas and quotes separators", () => {
    expect(csvCell("=HYPERLINK(\"x\")")).toBe("\"'=HYPERLINK(\"\"x\"\")\"");
    expect(csvCell("-5")).toBe("'-5");
    expect(csvCell(-5)).toBe("-5");
    expect(csvCell("a,b")).toBe("\"a,b\"");
    expect(toCsv([["x", 1], ["@y", null]])).toBe("x,1\r\n'@y,\r\n");
  });
});
