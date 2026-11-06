import { PageHeader } from "@/components/PageHeader";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";

export default async function ControlPage() {
  const ws = await requireWorkspace("audit.view");
  const { lang, t } = await getDict();
  const supabase = (await createClient())!;
  const [{ data: rows }, { data: members }] = await Promise.all([
    supabase.from("audit_log").select("id, created_at, actor_membership_id, action, entity, reason").order("created_at", { ascending: false }).limit(200),
    supabase.from("memberships").select("id, display_name"),
  ]);
  const who = new Map((members ?? []).map((m) => [m.id, m.display_name]));
  const { data: jobs } = await supabase.rpc("job_status");
  type Run = { id: string; kind: string; date: string; version: number; status: string; attempt: number; started_at: string; finished_at: string | null; sha256: string | null; error: string | null; triggered_by: string };
  type Bk = { kind: string; status: string; started_at: string; finished_at: string | null; location: string | null; error: string | null };
  const js = (jobs ?? {}) as { reports?: Run[]; backups?: Bk[]; last_report_success?: string | null; report_failures_7d?: number; last_backup_success?: string | null; last_restore_test_success?: string | null };
  const sw = lang === "sw";
  const fmt = new Intl.DateTimeFormat(lang === "sw" ? "sw-TZ" : "en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={t.nav.control} subtitle={t.control.audit} />
      <section className="card mb-6 p-4 text-sm">
        <h2 className="mb-3 font-semibold">{sw ? "Ripoti za kila siku na backup" : "Daily reports and backups"}</h2>
        <div className="mb-3 grid gap-2 sm:grid-cols-4">
          <p>{sw ? "Ripoti ya mwisho iliyofanikiwa" : "Last report success"}: <strong>{js.last_report_success ? fmt.format(new Date(js.last_report_success)) : "—"}</strong></p>
          <p className={js.report_failures_7d ? "text-bad" : ""}>{sw ? "Zilizoshindwa (siku 7)" : "Failures (7 days)"}: <strong>{js.report_failures_7d ?? 0}</strong></p>
          <p className={!js.last_backup_success ? "text-warn" : ""}>{sw ? "Backup ya mwisho" : "Last backup"}: <strong>{js.last_backup_success ? fmt.format(new Date(js.last_backup_success)) : (sw ? "Bado" : "None yet")}</strong></p>
          <p className={!js.last_restore_test_success ? "text-warn" : ""}>{sw ? "Jaribio la kurejesha" : "Last restore test"}: <strong>{js.last_restore_test_success ? fmt.format(new Date(js.last_restore_test_success)) : (sw ? "Bado" : "None yet")}</strong></p>
        </div>
        <ul className="divide-y divide-line">
          {(js.reports ?? []).slice(0, 10).map((r) => (
            <li key={r.id} className="flex flex-wrap justify-between gap-2 py-1.5">
              <span>{r.date} · {r.kind} · v{r.version} · {r.triggered_by}</span>
              <span className={r.status === "failed" ? "text-bad" : r.status === "succeeded" ? "text-ok" : "text-warn"}>
                {r.status}{r.attempt > 1 ? ` (attempt ${r.attempt})` : ""}{r.error ? ` — ${r.error}` : ""}
                {r.status === "succeeded" && <a href={`/control/report-file?run=${r.id}`} className="ml-2 text-gold-ink underline">PDF</a>}
              </span>
            </li>
          ))}
          {(js.reports ?? []).length === 0 && <li className="py-1.5 text-muted">{sw ? "Hakuna ripoti iliyotengenezwa bado (inahitaji CRON_SECRET na storage kusanidiwa)." : "No report generated yet (requires CRON_SECRET and storage to be configured)."}</li>}
        </ul>
      </section>
      <section className="card overflow-x-auto">
        {(rows ?? []).length === 0 ? <p className="p-6 text-sm text-muted">{t.control.empty}</p> : (
          <table className="w-full min-w-[640px] text-sm">
            <thead className="bg-ivory text-left text-muted">
              <tr><th className="px-4 py-2 font-medium">{t.control.when}</th><th className="px-4 py-2 font-medium">{t.control.who}</th>
                <th className="px-4 py-2 font-medium">{t.control.action}</th><th className="px-4 py-2 font-medium">{t.control.reason}</th></tr>
            </thead>
            <tbody className="divide-y divide-line">
              {(rows ?? []).map((r) => (
                <tr key={r.id}>
                  <td className="whitespace-nowrap px-4 py-2.5">{fmt.format(new Date(r.created_at))}</td>
                  <td className="px-4 py-2.5">{(r.actor_membership_id && who.get(r.actor_membership_id)) || "system"}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{r.action}</td>
                  <td className="px-4 py-2.5 text-muted">{r.reason ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
