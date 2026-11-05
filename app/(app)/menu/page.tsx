import Link from "next/link";
import { Icon } from "@/components/Icon";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { navFor } from "@/lib/roles";
import { signOut } from "@/app/actions/auth";
import { LangSwitch } from "@/components/LangSwitch";

export default async function MenuPage() {
  const ws = await requireWorkspace();
  const { lang, t } = await getDict();
  return (
    <div className="mx-auto max-w-lg space-y-4">
      <ul className="card divide-y divide-line">
        {navFor(ws).map((n) => (
          <li key={n.key}>
            <Link href={n.href} className="flex items-center gap-3 px-4 py-3.5 hover:bg-ivory">
              <Icon name={n.icon} /><span>{t.nav[n.key]}</span>
            </Link>
          </li>
        ))}
      </ul>
      <div className="flex items-center justify-between">
        <LangSwitch lang={lang} />
        <form action={signOut}><button className="btn btn-ghost">{t.signOut}</button></form>
      </div>
    </div>
  );
}
