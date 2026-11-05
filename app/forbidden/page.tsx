import Link from "next/link";
import { getDict } from "@/lib/lang";

export default async function Forbidden() {
  const { t } = await getDict();
  return (
    <div className="flex min-h-dvh items-center justify-center px-4">
      <div className="card max-w-md p-8 text-center">
        <p className="text-4xl" aria-hidden>🔒</p>
        <h1 className="mt-3 text-xl font-semibold">{t.errors.forbidden}</h1>
        <Link href="/" className="btn btn-ghost mt-6">{t.backToLogin}</Link>
      </div>
    </div>
  );
}
