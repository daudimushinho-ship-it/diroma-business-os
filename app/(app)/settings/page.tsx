import { PageHeader } from "@/components/PageHeader";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";
import { createLocation } from "@/app/actions/settings";

const KINDS = ["warehouse", "shop", "transit", "partner", "inspection", "quarantine"];

export default async function SettingsPage() {
  const ws = await requireWorkspace("settings.manage");
  const { t } = await getDict();
  const supabase = (await createClient())!;
  const { data: locations } = await supabase.from("locations").select("id, code, name, kind, is_active").order("code");
  return (
    <div className="mx-auto max-w-5xl">
      <PageHeader title={t.nav.settings} subtitle={`${ws.business.name} · ${ws.business.currency} · ${ws.business.timezone}`} />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section className="card overflow-hidden">
          <h2 className="border-b border-line px-5 py-3 font-semibold">{t.settings.locations}</h2>
          <table className="w-full text-sm">
            <thead className="bg-ivory text-left text-muted">
              <tr><th className="px-5 py-2 font-medium">{t.settings.code}</th><th className="px-5 py-2 font-medium">{t.settings.name}</th><th className="px-5 py-2 font-medium">{t.settings.kind}</th></tr>
            </thead>
            <tbody className="divide-y divide-line">
              {(locations ?? []).map((l) => (
                <tr key={l.id}><td className="px-5 py-2.5 font-mono">{l.code}</td><td className="px-5 py-2.5">{l.name}</td><td className="px-5 py-2.5">{t.locationKinds[l.kind] ?? l.kind}</td></tr>
              ))}
            </tbody>
          </table>
        </section>
        <section className="card h-fit p-5">
          <h2 className="mb-4 font-semibold">{t.settings.addLocation}</h2>
          <form action={createLocation} className="space-y-3">
            <div><label htmlFor="code" className="label">{t.settings.code}</label>
              <input id="code" name="code" required pattern="[A-Za-z0-9_\-]{2,20}" className="input font-mono uppercase" placeholder="SHOP2" /></div>
            <div><label htmlFor="lname" className="label">{t.settings.name}</label>
              <input id="lname" name="name" required maxLength={80} className="input" /></div>
            <div><label htmlFor="kind" className="label">{t.settings.kind}</label>
              <select id="kind" name="kind" className="input">{KINDS.map((k) => <option key={k} value={k}>{t.locationKinds[k]}</option>)}</select></div>
            <button className="btn btn-primary w-full">{t.settings.add}</button>
          </form>
        </section>
      </div>
    </div>
  );
}
