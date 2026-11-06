import { describe, expect, it } from "vitest";
import { parseCustomers, parseStock } from "@/lib/migration-csv";

describe("migration CSV parsing", () => {
  it("accepts export-style headings and normalises Tanzanian phones", () => {
    const { rows } = parseCustomers("Customer,Phone,Owed to you,Type\nMteja Test,0712 345 678,\"120,000\",jumla\n");
    expect(rows[0].errors).toEqual([]);
    expect(rows[0].row).toMatchObject({ name: "Mteja Test", phone: "+255712345678", opening_balance: 120000, kind: "wholesale" });
  });
  it("flags duplicates and bad values per line", () => {
    const { rows } = parseCustomers("name,phone,opening_balance\nA Test,0712345678,abc\nB Test,+255712345678,\n");
    expect(rows[0].errors.join()).toMatch(/opening_balance/);
    expect(rows[1].errors.join()).toMatch(/same phone as line 2/);
  });
  it("stock rows require every column and a positive quantity", () => {
    expect(parseStock("code,colour,size,location\nX,Black,48,WH\n").fatal).toMatch(/qty/);
    const { rows } = parseStock("design_code,color,size,location_code,qty\nDR#1,Black,48,wh,0\n");
    expect(rows[0].errors.join()).toMatch(/qty must be positive/);
    expect(rows[0].row.location_code).toBe("WH");
  });
});
