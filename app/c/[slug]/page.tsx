import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { createClient } from "@supabase/supabase-js";
import { publicSupabaseEnv } from "@/lib/env";

type Size = { color: string; size: string; available: boolean };
type Design = { code: string; name: string; category: string; description: string | null; from_price: number | null; colors: string[]; sizes: Size[] };
type Catalogue = { business: string; slogan: string | null; whatsapp: string | null; designs: Design[] };

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "DIROMA — Catalogue", robots: { index: true, follow: true } };

/** Public catalogue: anonymous read of explicitly published fields only (no costs, no wholesale prices, no exact stock). */
async function load(slug: string): Promise<Catalogue | null> {
  const env = publicSupabaseEnv();
  if (!env || !/^[a-z0-9-]{3,40}$/.test(slug)) return null;
  const anon = createClient(env.url, env.key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data } = await anon.rpc("public_catalogue", { p_slug: slug });
  return (data as Catalogue | null) ?? null;
}

export default async function PublicCatalogue({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const c = await load(slug);
  if (!c) notFound();
  const wa = (d: Design) => c.whatsapp
    ? `https://wa.me/${c.whatsapp.replace(/\D/g, "")}?text=${encodeURIComponent(`Habari DIROMA, napenda kuuliza kuhusu ${d.name} (${d.code}).`)}` : null;
  return (
    <div className="min-h-dvh bg-ivory">
      <header className="bg-espresso px-4 py-6 text-center text-ivory">
        <p className="text-3xl font-semibold tracking-[0.35em] text-champagne">DIROMA</p>
        <p className="mt-1 text-xs uppercase tracking-[0.3em] text-ivory/70">{c.slogan ?? "Spirit of Fashion"}</p>
      </header>
      <main className="mx-auto grid max-w-5xl gap-4 px-4 py-6 sm:grid-cols-2 lg:grid-cols-3">
        {c.designs.map((d) => (
          <article key={d.code} className="card flex flex-col p-4">
            <p className="font-mono text-xs text-muted">{d.code}</p>
            <h2 className="text-lg font-semibold">{d.name}</h2>
            {d.description && <p className="mt-1 text-sm text-muted">{d.description}</p>}
            {d.from_price !== null && <p className="mt-2 text-sm">Kuanzia <strong>TZS {Math.round(d.from_price).toLocaleString("en-US")}</strong></p>}
            <div className="mt-3 space-y-1">
              {d.colors.map((col) => (
                <div key={col}><p className="text-xs font-medium">{col}</p>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {d.sizes.filter((s) => s.color === col).map((s) => (
                      <span key={s.size} className={`rounded border px-2 py-0.5 text-xs ${s.available ? "border-espresso" : "border-line text-muted line-through"}`}
                        title={s.available ? "Inapatikana" : "Haipo kwa sasa"}>{s.size}</span>
                    ))}
                  </div></div>
              ))}
            </div>
            {wa(d) && <a href={wa(d)!} target="_blank" rel="noopener noreferrer" className="btn btn-primary mt-4">Uliza WhatsApp</a>}
          </article>
        ))}
        {c.designs.length === 0 && <p className="text-sm text-muted">—</p>}
      </main>
      <footer className="px-4 pb-8 text-center text-xs text-muted">
        Bei na upatikanaji vinaweza kubadilika. Ombi la WhatsApp si oda iliyothibitishwa. · Prices and availability may change; an inquiry is not a confirmed order.
      </footer>
    </div>
  );
}
