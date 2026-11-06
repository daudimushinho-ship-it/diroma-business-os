import type { Dict } from "@/lib/i18n";

export function CodeReveal({ t, name, phone, code }: { t: Dict; name: string; phone: string; code: string }) {
  return (
    <div role="status" className="space-y-3 rounded-xl border-2 border-champagne bg-[#fffaf0] p-4">
      <p className="text-sm font-semibold">{name} · {phone}</p>
      <p className="text-xs text-muted">{t.team.codeOnce}</p>
      <p className="select-all rounded-lg bg-white p-3 text-center font-mono text-2xl tracking-[0.3em]">{code.replace(/(.{5})/, "$1 ")}</p>
      <p className="text-sm">{t.team.codeInstructions}</p>
    </div>
  );
}
