export function tzs(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "TZS " + Math.round(n).toLocaleString("en-US");
}

/** Spreadsheet formula-injection guard for CSV exports. */
export function csvCell(v: unknown): string {
  if (typeof v === "number" || typeof v === "bigint") return String(v); // real numbers stay numeric
  let s = v === null || v === undefined ? "" : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(rows: unknown[][]): string {
  return rows.map((r) => r.map(csvCell).join(",")).join("\r\n") + "\r\n";
}

export function sizeSort(a: string, b: string): number {
  const order = ["S", "M", "L", "XL", "2XL", "3XL", "ONE"];
  const na = Number(a), nb = Number(b);
  if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
  return order.indexOf(a) - order.indexOf(b) || a.localeCompare(b);
}

/** Africa/Dar_es_Salaam is UTC+03:00 all year (no DST). Business-day boundaries as ISO timestamps. */
export const BUSINESS_UTC_OFFSET = "+03:00";
export function businessDayStart(isoDate: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(isoDate)) throw new Error("invalid date");
  return `${isoDate}T00:00:00${BUSINESS_UTC_OFFSET}`;
}
export function businessToday(): string {
  return new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);
}
export function addDays(isoDate: string, days: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
