import { CAPABILITIES, type CapState } from "@/lib/capabilities";
import type { Dict, Lang } from "@/lib/i18n";

const TONE: Record<CapState, string> = {
  implemented: "bg-[#e7f4ec] text-ok",
  unverified: "bg-[#fff4de] text-warn",
  external: "bg-[#eef0ff] text-[#3b47a8]",
  planned: "bg-ivory text-muted border border-line",
};

export function CapabilityTable({ t, lang }: { t: Dict; lang: Lang }) {
  return (
    <section className="card overflow-hidden">
      <h2 className="border-b border-line px-5 py-3 font-semibold">{t.capability.title}</h2>
      <ul className="divide-y divide-line">
        {CAPABILITIES.map((c) => (
          <li key={c.key} className="flex flex-wrap items-center justify-between gap-2 px-5 py-2.5 text-sm">
            <span className="min-w-0 flex-1">
              <span className="mr-2 font-mono text-xs text-muted">{c.milestone}</span>{lang === "sw" ? c.sw : c.en}
            </span>
            <span className={`badge ${TONE[c.state]}`}>{t.capability[c.state]}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
