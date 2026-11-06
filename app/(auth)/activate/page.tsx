import Link from "next/link";
import { getDict } from "@/lib/lang";
import { ActivateForm } from "./ActivateForm";

export const metadata = { title: "Wezesha akaunti / Activate" };

export default async function ActivatePage() {
  const { t } = await getDict();
  return (
    <div className="card p-6 sm:p-8">
      <h1 className="text-2xl font-semibold">{t.activateAccount}</h1>
      <p className="mt-1 text-sm text-muted">{t.activateIntro}</p>
      <div className="mt-6"><ActivateForm t={t} /></div>
      <p className="mt-4 text-sm"><Link href="/login" className="font-semibold text-gold-ink underline underline-offset-4">{t.backToLogin}</Link></p>
    </div>
  );
}
