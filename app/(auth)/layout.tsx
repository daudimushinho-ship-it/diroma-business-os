import { Logo } from "@/components/Logo";
import { LangSwitch } from "@/components/LangSwitch";
import { getDict } from "@/lib/lang";

export default async function AuthLayout({ children }: { children: React.ReactNode }) {
  const { lang, t } = await getDict();
  return (
    <div className="grid min-h-dvh lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
      <aside className="hidden flex-col justify-between bg-espresso p-10 text-ivory lg:flex">
        <Logo size="lg" />
        <div className="max-w-sm">
          <p className="text-2xl font-semibold leading-snug">{t.appName}</p>
          <p className="mt-3 text-ivory/70">Kariakoo · Dar es Salaam</p>
        </div>
        <LangSwitch lang={lang} tone="light" />
      </aside>
      <main className="flex flex-col">
        <div className="flex items-center justify-between bg-espresso px-4 py-4 lg:hidden">
          <Logo />
          <LangSwitch lang={lang} tone="light" />
        </div>
        <div className="flex flex-1 items-center justify-center px-4 py-10">
          <div className="w-full max-w-md">{children}</div>
        </div>
      </main>
    </div>
  );
}
