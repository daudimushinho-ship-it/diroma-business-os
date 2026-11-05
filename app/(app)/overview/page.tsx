import { PageHeader } from "@/components/PageHeader";
import { CapabilityTable } from "@/components/CapabilityTable";
import { Stat } from "@/components/Stat";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";

export default async function Page() {
  const ws = await requireWorkspace("overview.business");
  const { lang, t } = await getDict();
  const supabase = (await createClient())!;
  const { data: members } = await supabase.from("memberships").select("status");
  const count = (s: string[]) => (members ?? []).filter((m) => s.includes(m.status)).length;
  const sw = lang === "sw";
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader title={t.nav.overview} subtitle={`${t.welcome}, ${ws.display_name}`} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label={sw ? "Wafanyakazi hai" : "Active staff"} value={String(count(["active"]))} />
        <Stat label={sw ? "Wanasubiri kuwezeshwa" : "Awaiting activation"} value={String(count(["invited", "pending_activation"]))} />
        <Stat label={sw ? "Waliosimamishwa" : "Suspended"} value={String(count(["suspended"]))} />
        <Stat label={t.locationsAssigned} value={String(ws.locations.length)} />
      </div>
      <div className="card border-dashed p-5 text-sm text-muted">
        {sw
          ? "Mauzo, makusanyo, pesa taslimu, madeni na thamani ya stoki yataonekana hapa baada ya Hatua B–C kujengwa. Hatuonyeshi namba za kubuni."
          : "Net sales, collections, physical cash, receivables and stock value appear here once Milestones B–C are built. No invented figures are shown."}
      </div>
      <CapabilityTable t={t} lang={lang} />
    </div>
  );
}
