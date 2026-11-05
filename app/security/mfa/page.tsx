import { redirect } from "next/navigation";
import { Logo } from "@/components/Logo";
import { getDict } from "@/lib/lang";
import { getWorkspace } from "@/lib/workspace";
import { LANDING } from "@/lib/roles";
import { signOut } from "@/app/actions/auth";
import { MfaClient } from "./MfaClient";

export const metadata = { title: "MFA" };

export default async function MfaPage() {
  const { t } = await getDict();
  const ws = await getWorkspace();
  if (!ws) redirect("/login?e=inactive");
  if (!ws.mfa_required || ws.aal === "aal2") redirect(LANDING[ws.role]);
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-6 px-4 py-10">
      <div className="rounded-xl bg-espresso px-5 py-4"><Logo /></div>
      <div className="card w-full max-w-md p-6 sm:p-8">
        <h1 className="text-xl font-semibold">{t.mfa.title}</h1>
        <p className="mt-1 text-sm text-muted">{t.mfa.whyRequired}</p>
        <div className="mt-5"><MfaClient t={t} next={LANDING[ws.role]} /></div>
        <form action={signOut} className="mt-4"><button className="text-sm text-muted underline">{t.signOut}</button></form>
      </div>
    </div>
  );
}
