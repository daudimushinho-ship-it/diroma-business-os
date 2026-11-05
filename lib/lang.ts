import "server-only";
import { cookies } from "next/headers";
import { DEFAULT_LANG, DICTS, isLang, type Lang } from "./i18n";

export async function getLang(): Promise<Lang> {
  const v = (await cookies()).get("lang")?.value;
  return isLang(v) ? v : DEFAULT_LANG;
}

export async function getDict() {
  const lang = await getLang();
  return { lang, t: DICTS[lang] };
}
