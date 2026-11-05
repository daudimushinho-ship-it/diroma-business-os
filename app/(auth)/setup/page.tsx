import { getDict } from "@/lib/lang";
import { SetupForm } from "./SetupForm";

export const metadata = { title: "Owner setup" };

export default async function SetupPage() {
  const { t } = await getDict();
  return (
    <div className="card p-6 sm:p-8">
      <h1 className="text-2xl font-semibold">{t.ownerSetup}</h1>
      <p className="mt-1 text-sm text-muted">{t.ownerSetupIntro}</p>
      <div className="mt-6"><SetupForm t={t} /></div>
    </div>
  );
}
