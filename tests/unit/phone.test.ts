import { describe, expect, it } from "vitest";
import { normalizePhone } from "@/lib/phone";

const TZ = "+255712345678";

describe("normalizePhone", () => {
  it.each(["0712345678", "0712 345 678", "712345678", "+255712345678", "+255 712 345 678", "255712345678", "00255712345678", "(0712) 345-678"])(
    "local and international forms of one Tanzanian mobile resolve to one identity: %s",
    (input) => expect(normalizePhone(input)).toEqual({ ok: true, e164: TZ }),
  );

  it("keeps other countries' numbers intact (no blind +255 prefix)", () => {
    expect(normalizePhone("+254712345678")).toEqual({ ok: true, e164: "+254712345678" });
  });

  it.each(["", "   ", "abc", "07123", "0712345678901234", "+255 712 34", "0712-345-67x", "+2551234"])("rejects invalid input: %j", (input) => {
    expect(normalizePhone(input).ok).toBe(false);
  });

  it("rejects a Tanzanian landline (mobile login only)", () => {
    expect(normalizePhone("0222123456").ok).toBe(false);
  });
});

import { authPlaceholderEmail } from "@/lib/phone";
describe("authPlaceholderEmail", () => {
  it("derives a non-deliverable address from the E.164 phone", () => {
    expect(authPlaceholderEmail("+255712345678")).toBe("255712345678@phone.diroma.invalid");
  });
  it("is stable for the same phone and distinct across phones", () => {
    expect(authPlaceholderEmail("+255712345678")).toBe(authPlaceholderEmail("+255712345678"));
    expect(authPlaceholderEmail("+255712345678")).not.toBe(authPlaceholderEmail("+255712345679"));
  });
  it("rejects garbage", () => {
    expect(() => authPlaceholderEmail("abc")).toThrow();
  });
});
