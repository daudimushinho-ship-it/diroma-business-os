import { setLanguage } from "@/app/actions/lang";
import type { Lang } from "@/lib/i18n";

export function LangSwitch({ lang, tone = "dark" }: { lang: Lang; tone?: "dark" | "light" }) {
  const base = tone === "light" ? "text-ivory/80" : "text-muted";
  return (
    <form action={setLanguage} className={`flex gap-1 text-sm ${base}`}>
      {(["sw", "en"] as const).map((l) => (
        <button key={l} name="lang" value={l} aria-pressed={lang === l}
          className={`rounded-md px-2 py-1 ${lang === l ? "font-semibold underline underline-offset-4" : "hover:underline"}`}>
          {l === "sw" ? "Kiswahili" : "English"}
        </button>
      ))}
    </form>
  );
}
