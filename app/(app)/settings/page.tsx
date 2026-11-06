import { PageHeader } from "@/components/PageHeader";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";
import { createLocation } from "@/app/actions/settings";
import { configureCatalogue } from "@/app/actions/team-work";
import { qrSvg } from "@/lib/barcode";
import { headers } from "next/headers";

const KINDS = ["warehouse", "shop", "transit", "partner", "inspection", "quarantine"];

export default async function SettingsPage() {
  const ws = await requireWorkspace("settings.manage");
  const { t } = await getDict();
  const supabase = (await createClient())!;
  const { data: locations } = await supabase.from("locations").select("id, code, name, kind, is_active").order("code");
  const { data: biz } = await supabase.from("businesses").select("catalogue_enabled, catalogue_slug, catalogue_whatsapp").maybeSingle();
  const h = await headers();
  const origin = `${h.get("x-forwarded-proto") ?? "https"}://${h.get("host") ?? "localhost"}`;
  const publicUrl = biz?.catalogue_enabled && biz.catalogue_slug ? `${origin}/c/${biz.catalogue_slug}` : null;
  const integrations: [string, boolean, string][] = [
    ["Supabase (database & login)", !!process.env.NEXT_PUBLIC_SUPABASE_URL && !!(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY), "NEXT_PUBLIC_SUPABASE_URL / key"],
    ["Server key (staff invitations, jobs)", !!(process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY), "SUPABASE_SECRET_KEY"],
    ["Scheduled daily reports", !!process.env.CRON_SECRET && process.env.CRON_SECRET.length >= 32, "CRON_SECRET (≥ 32 chars) + vercel.json crons"],
    ["SMS provider (activation / recovery by SMS)", false, "Not configured — Owner-supervised activation is used"],
    ["WhatsApp Business API (automatic messages)", false, "Not configured — reminders open WhatsApp links only"],
    ["M-Pesa statement / API reconciliation", false, "Not configured — mobile payments are marked 'manual'"],
    ["TRA / EFD fiscal integration", false, "Not configured — reports are operational, not fiscal"],
  ];
  return (
    <div className="mx-auto max-w-5xl">
      <PageHeader title={t.nav.settings} subtitle={`${ws.business.name} · ${ws.business.currency} · ${ws.business.timezone}`}>
        <a href="/settings/migration" className="btn btn-ghost">MauzoTrack → DIROMA</a>
      </PageHeader>
      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <section className="card p-5 text-sm">
          <h2 className="mb-3 font-semibold">Integrations</h2>
          <ul className="divide-y divide-line">
            {integrations.map(([name, ok, hint]) => (
              <li key={name} className="flex flex-wrap justify-between gap-2 py-2">
                <span>{name}<span className="block text-xs text-muted">{hint}</span></span>
                <span className={`badge h-fit ${ok ? "bg-[#e7f4ec] text-ok" : "border border-line bg-ivory text-muted"}`}>{ok ? "configured" : "not configured"}</span>
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs text-muted">"Configured" means the setting is present, not that delivery was tested.</p>
        </section>
        <section className="card p-5 text-sm">
          <h2 className="mb-3 font-semibold">Public catalogue</h2>
          <form action={configureCatalogue} className="space-y-2">
            <label className="flex items-center gap-2"><input type="checkbox" name="enabled" defaultChecked={!!biz?.catalogue_enabled} /> Published</label>
            <input name="slug" defaultValue={biz?.catalogue_slug ?? "diroma"} pattern="[a-z0-9\-]{3,40}" className="input font-mono" aria-label="slug" />
            <input name="whatsapp" type="tel" defaultValue={biz?.catalogue_whatsapp ?? ""} placeholder="WhatsApp +255…" className="input" />
            <button className="btn btn-primary">Save</button>
          </form>
          {publicUrl && (
            <div className="mt-4 flex flex-wrap items-center gap-4">
              <div className="w-32 [&>svg]:h-auto [&>svg]:w-full" dangerouslySetInnerHTML={{ __html: qrSvg(publicUrl) }} />
              <a href={publicUrl} target="_blank" rel="noopener noreferrer" className="break-all text-gold-ink underline">{publicUrl}</a>
            </div>
          )}
          <p className="mt-2 text-xs text-muted">Only designs marked "published" appear, with retail "from" prices and yes/no availability. No costs, wholesale prices or exact stock.</p>
        </section>
      </div>
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
