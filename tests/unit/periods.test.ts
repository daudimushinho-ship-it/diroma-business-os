import { describe, expect, it } from "vitest";
import { comparisonPeriod, pctChange, resolvePeriod } from "@/lib/periods";

const today = "2026-11-15"; // a Sunday

describe("report periods", () => {
  it("resolves presets in the business calendar", () => {
    expect(resolvePeriod("today", today)).toMatchObject({ from: today, to: today });
    expect(resolvePeriod("week", today)).toMatchObject({ from: "2026-11-09", to: today }); // Monday start
    expect(resolvePeriod("month", today)).toMatchObject({ from: "2026-11-01", to: today });
    expect(resolvePeriod("last_month", today)).toMatchObject({ from: "2026-10-01", to: "2026-10-31" });
    expect(resolvePeriod("quarter", today)).toMatchObject({ from: "2026-10-01", to: today });
    expect(resolvePeriod("half", today)).toMatchObject({ from: "2026-07-01", to: today });
    expect(resolvePeriod("year", today)).toMatchObject({ from: "2026-01-01", to: today });
  });
  it("custom periods are ordered, capped at today and at 10 years", () => {
    expect(resolvePeriod("custom", today, "2026-11-20", "2026-11-01")).toMatchObject({ from: "2026-11-01", to: today });
    expect(resolvePeriod("custom", today, "1990-01-01", "2026-01-01").from > "2015-01-01").toBe(true);
    expect(resolvePeriod("nonsense", today).preset).toBe("month");
  });
  it("compares month-to-date with the same elapsed days of last month, not the whole month", () => {
    expect(comparisonPeriod(resolvePeriod("month", today), "2020-01-01")).toMatchObject({ from: "2026-10-01", to: "2026-10-15" });
    expect(comparisonPeriod(resolvePeriod("month", "2026-03-31"), "2020-01-01")).toMatchObject({ from: "2026-02-01", to: "2026-02-28" });
  });
  it("compares other periods with the same number of days just before", () => {
    expect(comparisonPeriod(resolvePeriod("last7", today), "2020-01-01")).toMatchObject({ from: "2026-11-02", to: "2026-11-08" });
    expect(comparisonPeriod(resolvePeriod("last_month", today), "2020-01-01")).toMatchObject({ from: "2026-09-01", to: "2026-09-30" });
  });
  it("marks comparison unavailable before the business has data", () => {
    expect(comparisonPeriod(resolvePeriod("month", today), "2026-11-03")).toBeNull();
    expect(comparisonPeriod(resolvePeriod("month", today), null)).toBeNull();
  });
  it("percent change is unavailable against zero", () => {
    expect(pctChange(150, 100)).toBe(50);
    expect(pctChange(50, 0)).toBeNull();
  });
});
