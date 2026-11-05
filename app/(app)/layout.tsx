import Link from "next/link";
import { Logo } from "@/components/Logo";
import { NavLink } from "@/components/NavLink";
import { LangSwitch } from "@/components/LangSwitch";
import { Icon } from "@/components/Icon";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { navFor } from "@/lib/roles";
import { signOut } from "@/app/actions/auth";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const ws = await requireWorkspace();
  const { lang, t } = await getDict();
  const items = navFor(ws);
  const mobileItems = items.filter((i) => i.key !== "help").slice(0, 4);

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[260px_minmax(0,1fr)]">
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:bg-paper focus:p-2">Skip to content</a>
      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-dvh flex-col bg-espresso text-ivory lg:flex">
        <div className="px-6 pb-4 pt-6"><Logo /></div>
        <nav aria-label="Main" className="flex-1 space-y-0.5 overflow-y-auto px-3">
          {items.map((n) => <NavLink key={n.key} href={n.href} icon={n.icon} label={t.nav[n.key]} />)}
        </nav>
        <div className="border-t border-brown px-4 py-4 text-sm">
          <Link href="/profile" className="flex items-center gap-2 rounded-lg px-2 py-2 hover:bg-brown/60">
            <Icon name="user" />
            <span className="min-w-0">
              <span className="block truncate font-medium">{ws.display_name}</span>
              <span className="block text-xs text-champagne">{t.roles[ws.role]}</span>
            </span>
          </Link>
          <div className="mt-2 flex items-center justify-between px-2">
            <LangSwitch lang={lang} tone="light" />
            <form action={signOut}><button className="text-ivory/70 underline-offset-4 hover:underline">{t.signOut}</button></form>
          </div>
        </div>
      </aside>

      <div className="flex min-w-0 flex-col">
        {/* Mobile header */}
        <header className="sticky top-0 z-30 flex items-center justify-between bg-espresso px-4 py-3 text-ivory lg:hidden">
          <Logo />
          <Link href="/profile" className="flex items-center gap-2 text-sm">
            <span className="text-right leading-tight">
              <span className="block max-w-[9rem] truncate">{ws.display_name}</span>
              <span className="block text-xs text-champagne">{t.roles[ws.role]}</span>
            </span>
            <Icon name="user" />
          </Link>
        </header>
        {/* Desktop header */}
        <header className="hidden items-center justify-between border-b border-line bg-paper px-8 py-3 lg:flex">
          <p className="text-sm text-muted">{ws.business.name} · {ws.business.timezone}</p>
          <p className="text-sm text-muted">{ws.locations.map((l) => l.name).join(" · ")}</p>
        </header>
        <main id="main" className="flex-1 px-4 pb-24 pt-6 sm:px-6 lg:px-8 lg:pb-10">{children}</main>
        {/* Mobile bottom nav: role's most frequent destinations */}
        <nav aria-label="Quick" className="fixed inset-x-0 bottom-0 z-30 flex border-t border-brown bg-espresso pb-[env(safe-area-inset-bottom)] lg:hidden">
          {mobileItems.map((n) => <NavLink key={n.key} href={n.href} icon={n.icon} label={t.nav[n.key]} compact />)}
          <NavLink href="/menu" icon="grid" label="Menu" compact />
        </nav>
      </div>
    </div>
  );
}
