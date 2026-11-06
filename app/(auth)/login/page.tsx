import Link from "next/link";
import { getDict } from "@/lib/lang";
import type { ErrorKey } from "@/lib/i18n";
import { LoginForm } from "./LoginForm";

export const metadata = { title: "Ingia / Sign in" };

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ e?: string }> }) {
  const { t } = await getDict();
  const { e } = await searchParams;
  const initialError = e && e in t.errors ? (e as ErrorKey) : undefined;
  return (
    <div className="card p-6 sm:p-8">
      <h1 className="text-2xl font-semibold">{t.signIn}</h1>
      <p className="mt-1 text-sm text-muted">{t.appName}</p>
      <div className="mt-6"><LoginForm t={t} initialError={initialError} /></div>
      <details className="mt-5 text-sm">
        <summary className="cursor-pointer font-medium text-gold-ink">{t.forgotPassword}</summary>
        <p className="mt-2 text-muted">{t.forgotPasswordHelp}</p>
      </details>
      <p className="mt-4 text-sm">
        {t.haveCode} <Link href="/activate" className="font-semibold text-gold-ink underline underline-offset-4">{t.activateAccount}</Link>
      </p>
    </div>
  );
}
