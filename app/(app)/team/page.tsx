import { PageHeader } from "@/components/PageHeader";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";
import { can } from "@/lib/roles";
import { formatPhone } from "@/lib/phone";
import { InviteForm } from "./InviteForm";
import { MemberActions } from "./MemberActions";

const STATUS_TONE: Record<string, string> = {
  active: "bg-[#e7f4ec] text-ok", suspended: "bg-[#fdf1ef] text-bad", deactivated: "bg-ivory text-muted",
  invited: "bg-[#fff4de] text-warn", pending_activation: "bg-[#fff4de] text-warn",
};

export default async function TeamPage() {
  const ws = await requireWorkspace("team.view");
  const { t } = await getDict();
  const supabase = (await createClient())!;
  const [{ data: members }, { data: links }, { data: locations }] = await Promise.all([
    supabase.from("memberships").select("id, display_name, phone_e164, role, status, all_locations, activated_at").order("created_at"),
    supabase.from("membership_locations").select("membership_id, location_id"),
    supabase.from("locations").select("id, name, kind").eq("is_active", true).order("name"),
  ]);
  const locName = new Map((locations ?? []).map((l) => [l.id, l.name]));
  const manage = can(ws, "team.manage");

  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={t.team.title} subtitle={ws.business.name} />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="card overflow-hidden">
          {(members ?? []).length === 0 ? (
            <p className="p-6 text-sm text-muted">{t.team.noMembers}</p>
          ) : (
            <ul className="divide-y divide-line">
              {(members ?? []).map((m) => {
                const locs = m.all_locations ? [t.team.allLocations]
                  : (links ?? []).filter((l) => l.membership_id === m.id).map((l) => locName.get(l.location_id) ?? "—");
                return (
                  <li key={m.id} className="space-y-2 px-5 py-4">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="min-w-0">
                        <p className="font-semibold">{m.display_name}</p>
                        <p className="text-sm text-muted">{formatPhone(m.phone_e164)} · {t.roles[m.role as keyof typeof t.roles]}</p>
                      </div>
                      <span className={`badge ${STATUS_TONE[m.status] ?? ""}`}>{t.status[m.status] ?? m.status}</span>
                    </div>
                    <p className="text-xs text-muted">{t.team.locations}: {locs.join(", ") || "—"}</p>
                    {manage && m.role !== "owner" && <MemberActions t={t} id={m.id} status={m.status} />}
                  </li>
                );
              })}
            </ul>
          )}
        </section>
        {manage && (
          <section className="card h-fit p-5">
            <h2 className="mb-4 font-semibold">{t.team.invite}</h2>
            <InviteForm t={t} locations={locations ?? []} />
          </section>
        )}
      </div>
    </div>
  );
}
