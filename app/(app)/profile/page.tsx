import { PageHeader } from "@/components/PageHeader";
import { LangSwitch } from "@/components/LangSwitch";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { signOut } from "@/app/actions/auth";
import { PasswordForm } from "./PasswordForm";

export default async function ProfilePage() {
  const ws = await requireWorkspace();
  const { lang, t } = await getDict();
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title={t.profile.title} subtitle={`${ws.display_name} · ${t.roles[ws.role]}`} />
      <section className="card p-5">
        <h2 className="font-semibold">{t.language}</h2>
        <div className="mt-3"><LangSwitch lang={lang} /></div>
      </section>
      <section className="card p-5">
        <h2 className="font-semibold">{t.security}</h2>
        {ws.aal === "aal2" && <p className="mt-1 text-sm text-ok">✓ {t.mfaOn}</p>}
        <h3 className="mb-3 mt-4 text-sm font-semibold">{t.profile.changePassword}</h3>
        <PasswordForm t={t} />
      </section>
      <form action={signOut}><button className="btn btn-ghost">{t.signOut}</button></form>
    </div>
  );
}
