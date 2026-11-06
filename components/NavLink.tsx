"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Icon } from "./Icon";

export function NavLink({ href, icon, label, compact = false }: { href: string; icon: string; label: string; compact?: boolean }) {
  const path = usePathname();
  const active = path === href || path.startsWith(href + "/");
  if (compact) {
    return (
      <Link href={href} aria-current={active ? "page" : undefined}
        className={`flex min-w-0 flex-1 flex-col items-center gap-1 px-1 py-2 text-[0.7rem] ${active ? "text-champagne" : "text-ivory/75"}`}>
        <Icon name={icon} />
        <span className="w-full truncate text-center">{label}</span>
      </Link>
    );
  }
  return (
    <Link href={href} aria-current={active ? "page" : undefined}
      className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors ${
        active ? "bg-brown text-champagne font-semibold" : "text-ivory/80 hover:bg-brown/60 hover:text-ivory"}`}>
      <Icon name={icon} />
      <span>{label}</span>
    </Link>
  );
}
