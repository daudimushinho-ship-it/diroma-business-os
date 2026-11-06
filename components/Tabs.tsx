import Link from "next/link";

export function Tabs({ items, active }: { items: { key: string; label: string; href: string; badge?: number }[]; active: string }) {
  return (
    <nav aria-label="Sections" className="-mx-4 mb-5 overflow-x-auto px-4 sm:mx-0 sm:px-0">
      <ul className="flex min-w-max gap-1 border-b border-line">
        {items.map((i) => (
          <li key={i.key}>
            <Link href={i.href} aria-current={i.key === active ? "page" : undefined}
              className={`inline-flex items-center gap-1.5 border-b-2 px-3 py-2.5 text-sm ${i.key === active ? "border-espresso font-semibold" : "border-transparent text-muted hover:text-ink"}`}>
              {i.label}
              {!!i.badge && <span className="badge bg-champagne/25 text-gold-ink">{i.badge}</span>}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
