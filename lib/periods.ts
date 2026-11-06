// Report periods in the business calendar (dates are YYYY-MM-DD in Africa/Dar_es_Salaam).
export type Preset = "today" | "yesterday" | "week" | "last7" | "month" | "last_month" | "quarter" | "half" | "year" | "custom";
export const PRESETS: Preset[] = ["today", "yesterday", "week", "last7", "month", "last_month", "quarter", "half", "year", "custom"];
export type Period = { preset: Preset; from: string; to: string };

const d = (s: string) => new Date(`${s}T00:00:00Z`);
const iso = (x: Date) => x.toISOString().slice(0, 10);
export const addDays = (s: string, n: number) => { const x = d(s); x.setUTCDate(x.getUTCDate() + n); return iso(x); };
export const daysBetween = (a: string, b: string) => Math.round((d(b).getTime() - d(a).getTime()) / 86_400_000);
const isDate = (s?: string) => !!s && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(d(s).getTime());
function monthStart(s: string, back = 0) { const x = d(s); return iso(new Date(Date.UTC(x.getUTCFullYear(), x.getUTCMonth() - back, 1))); }
function lastDayOfMonth(y: number, m0: number) { return new Date(Date.UTC(y, m0 + 1, 0)).getUTCDate(); }

/** Resolve a preset against "today". Period-to-date presets end today (never in the future). */
export function resolvePeriod(preset: string | undefined, today: string, from?: string, to?: string): Period {
  const p = (PRESETS as string[]).includes(preset ?? "") ? (preset as Preset) : "month";
  const t = d(today);
  switch (p) {
    case "today": return { preset: p, from: today, to: today };
    case "yesterday": return { preset: p, from: addDays(today, -1), to: addDays(today, -1) };
    case "week": { const dow = (t.getUTCDay() + 6) % 7; return { preset: p, from: addDays(today, -dow), to: today }; } // Monday start
    case "last7": return { preset: p, from: addDays(today, -6), to: today };
    case "month": return { preset: p, from: monthStart(today), to: today };
    case "last_month": { const f = monthStart(today, 1); return { preset: p, from: f, to: addDays(monthStart(today), -1) }; }
    case "quarter": { const q = Math.floor(t.getUTCMonth() / 3) * 3; return { preset: p, from: iso(new Date(Date.UTC(t.getUTCFullYear(), q, 1))), to: today }; }
    case "half": { const h = t.getUTCMonth() < 6 ? 0 : 6; return { preset: p, from: iso(new Date(Date.UTC(t.getUTCFullYear(), h, 1))), to: today }; }
    case "year": return { preset: p, from: `${t.getUTCFullYear()}-01-01`, to: today };
    case "custom": {
      let f = isDate(from) ? from! : addDays(today, -6), e = isDate(to) ? to! : today;
      if (f > e) [f, e] = [e, f];
      if (e > today) e = today;
      if (f > e) f = e;
      if (daysBetween(f, e) > 3660) f = addDays(e, -3660);
      return { preset: p, from: f, to: e };
    }
  }
}

/**
 * Like-for-like comparison period.
 * - Calendar period-to-date (month, quarter, half, year): the same elapsed days of the previous period
 *   (e.g. 1–15 Nov vs 1–15 Oct; day numbers clamped to the shorter month).
 * - Everything else: the same number of days immediately before.
 * Returns null ("comparison unavailable") when the business has no data that early.
 */
export function comparisonPeriod(p: Period, dataStart: string | null): Period | null {
  let from: string, to: string;
  const span = { month: 1, quarter: 3, half: 6, year: 12 } as Record<string, number>;
  if (span[p.preset]) {
    const shift = (s: string) => {
      const x = d(s); const y = x.getUTCFullYear(), m = x.getUTCMonth() - span[p.preset];
      const target = new Date(Date.UTC(y, m, 1));
      const day = Math.min(x.getUTCDate(), lastDayOfMonth(target.getUTCFullYear(), target.getUTCMonth()));
      return iso(new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth(), day)));
    };
    from = shift(p.from); to = shift(p.to);
  } else if (p.preset === "last_month") {
    from = monthStart(p.from, 1); to = addDays(p.from, -1);
  } else {
    const len = daysBetween(p.from, p.to) + 1;
    to = addDays(p.from, -1); from = addDays(to, -(len - 1));
  }
  if (!dataStart || to < dataStart) return null;
  return { preset: "custom", from, to };
}

export function pctChange(now: number, before: number | null | undefined): number | null {
  if (before === null || before === undefined || before === 0) return null;
  return Math.round(((now - before) / Math.abs(before)) * 1000) / 10;
}
