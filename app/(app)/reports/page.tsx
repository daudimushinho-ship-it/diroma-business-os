import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Stat } from "@/components/Stat";
import { ReportTable } from "@/components/ReportTable";
import { getLang } from "@/lib/lang";
import { DICTS } from "@/lib/i18n";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { REPORT_KINDS, reportLabels, reportSections, type ReportKind } from "@/lib/report-docs";
import { PRESETS, comparisonPeriod, pctChange, resolvePeriod } from "@/lib/periods";
import { businessToday, tzs } from "@/lib/format";
import { dataStartDate, fetchReport } from "@/lib/reports";

const PRESET_LABEL: Record<string, { sw: string; en: string }> = {
  today: { sw: "Leo", en: "Today" }, yesterday: { sw: "Jana", en: "Yesterday" }, week: { sw: "Wiki hii", en: "This week" },
  last7: { sw: "Siku 7", en: "Last 7 days" }, month: { sw: "Mwezi huu", en: "This month" }, last_month: { sw: "Mwezi uliopita", en: "Last month" },
  quarter: { sw: "Robo mwaka", en: "Quarter" }, half: { sw: "Nusu mwaka", en: "Half-year" }, year: { sw: "Mwaka", en: "Year" }, custom: { sw: "Chagua tarehe", en: "Custom" },
};
type SP = { kind?: string; preset?: string; from?: string; to?: string };

export default async function ReportsPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("reports.view");
  const lang = await getLang();
  const t = reportLabels(lang);
  const sp = await searchParams;
  const kinds = REPORT_KINDS.filter((k) => (k === "pnl" ? can(ws, "costs.view") : k === "trial_balance" ? can(ws, "journal.view") : true));
  const kind = (kinds as readonly string[]).includes(sp.kind ?? "") ? (sp.kind as ReportKind) : "sales";
  const p = resolvePeriod(sp.preset, businessToday(), sp.from, sp.to);
  const qs = (o: Record<string, string>) => new URLSearchParams({ kind, preset: p.preset, from: p.from, to: p.to, ...o }).toString();
  const { data, error } = await fetchReport(kind, p.from, p.to);
  const sections = reportSections(kind, data, lang);

  // like-for-like comparison for the headline figures
  let compare: { label: string; now: number; before: number | null; unit?: string }[] = [];
  if (kind === "sales" || kind === "collections") {
    const cp = comparisonPeriod(p, await dataStartDate());
    const prev = cp ? (await fetchReport(kind, cp.from, cp.to)).data as Record<string, Record<string, number>> | null : null;
    const now = data as Record<string, Record<string, number>> | null;
    if (kind === "sales" && now) compare = [
      { label: t.net, now: Number(now.totals.net_sales), before: prev ? Number(prev.totals.net_sales) : null },
      { label: t.count, now: Number(now.totals.sales), before: prev ? Number(prev.totals.sales) : null, unit: "" },
      { label: t.units, now: Number(now.totals.units), before: prev ? Number(prev.totals.units) : null, unit: "" },
      ...(now.costs ? [{ label: "Gross profit", now: Number(now.costs.gross_profit), before: prev?.costs ? Number(prev.costs.gross_profit) : null }] : []),
    ];
    if (kind === "collections" && now) compare = [
      { label: t.collections, now: Number(now.totals.collections), before: prev ? Number(prev.totals.collections) : null },
      { label: "Old debt", now: Number(now.totals.old_debt), before: prev ? Number(prev.totals.old_debt) : null },
    ];
    if (compare.length && !cp) compare = compare.map((c) => ({ ...c, before: null }));
  }

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <PageHeader title={DICTS[lang].nav.reports} subtitle={`${p.from} → ${p.to} · Africa/Dar_es_Salaam · TZS`}>
        <div className="flex gap-2">
          <a href={`/reports/export?${qs({ format: "csv" })}`} className="btn btn-ghost">CSV</a>
          <a href={`/reports/export?${qs({ format: "pdf" })}`} className="btn btn-primary">PDF</a>
        </div>
      </PageHeader>
      <nav aria-label="Report" className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        <ul className="flex min-w-max gap-1">
          {kinds.map((k) => <li key={k}><Link href={`/reports?${new URLSearchParams({ kind: k, preset: p.preset, from: p.from, to: p.to })}`} aria-current={k === kind ? "page" : undefined}
            className={`inline-block rounded-full border px-3 py-1.5 text-sm ${k === kind ? "border-espresso bg-espresso text-ivory" : "border-line bg-paper"}`}>{t[k]}</Link></li>)}
        </ul>
      </nav>
      <div className="flex flex-wrap items-end gap-2">
        {PRESETS.filter((x) => x !== "custom").map((x) => (
          <Link key={x} href={`/reports?${new URLSearchParams({ kind, preset: x })}`} className={`rounded-md px-2.5 py-1 text-sm ${p.preset === x ? "bg-champagne/30 font-semibold" : "hover:bg-paper"}`}>{PRESET_LABEL[x][lang]}</Link>
        ))}
        <form className="flex items-end gap-1">
          <input type="hidden" name="kind" value={kind} /><input type="hidden" name="preset" value="custom" />
          <input type="date" name="from" defaultValue={p.from} className="input h-9 min-h-0 py-1" aria-label="from" />
          <input type="date" name="to" defaultValue={p.to} className="input h-9 min-h-0 py-1" aria-label="to" />
          <button className="btn btn-ghost h-9 min-h-0 py-1">OK</button>
        </form>
      </div>
      {error && <p role="alert" className="rounded-lg bg-[#fdf1ef] px-3 py-2 text-sm text-bad">{error.message}</p>}
      {compare.length > 0 && (
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          {compare.map((c) => {
            const ch = pctChange(c.now, c.before);
            return <Stat key={c.label} label={c.label} value={c.unit === "" ? String(c.now) : tzs(c.now)}
              note={c.before === null ? (lang === "sw" ? "Ulinganisho haupatikani" : "Comparison unavailable") : `${ch === null ? "—" : `${ch > 0 ? "+" : ""}${ch}%`} ${lang === "sw" ? "dhidi ya kipindi kilichopita" : "vs previous like-for-like"}`} />;
          })}
        </div>
      )}
      {sections.map((s, i) => <ReportTable key={i} s={s} />)}
      <p className="text-xs text-muted">{t.fiscalNote} {!can(ws, "costs.view") && t.costsNote}</p>
    </div>
  );
}
