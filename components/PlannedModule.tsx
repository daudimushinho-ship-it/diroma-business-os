import { PageHeader } from "./PageHeader";
import type { Dict } from "@/lib/i18n";

export function PlannedModule({ t, title, milestone, scope }: { t: Dict; title: string; milestone: string; scope: string[] }) {
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader title={title} />
      <div className="card p-6">
        <span className="badge border border-line bg-ivory text-muted">{t.capability.planned} · {t.capability.milestone} {milestone}</span>
        <p className="mt-3 text-sm text-muted">{t.capability.plannedBody}</p>
        <ul className="mt-4 list-disc space-y-1.5 pl-5 text-sm">
          {scope.map((s) => <li key={s}>{s}</li>)}
        </ul>
      </div>
    </div>
  );
}
