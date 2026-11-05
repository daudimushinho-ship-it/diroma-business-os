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
  const fmt = new Intl.DateTimeFormat(lang === "sw" ? "sw-TZ" : "en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={t.nav.control} subtitle={t.control.audit} />
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
