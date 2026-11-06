import "server-only";
import { cookies } from "next/headers";
import { DEFAULT_LANG, DICTS, isLang, type Lang } from "./i18n";
import { STOCK_DICTS } from "./i18n-stock";

export async function getLang(): Promise<Lang> {
  const v = (await cookies()).get("lang")?.value;
  return isLang(v) ? v : DEFAULT_LANG;
}

export async function getDict() {
  const lang = await getLang();
  return { lang, t: DICTS[lang] };
}

export async function getStockDict() {
  const lang = await getLang();
  return { lang, t: DICTS[lang], s: STOCK_DICTS[lang] };
}

export async function getSalesDict() {
  const lang = await getLang();
  const { SALES_DICTS } = await import("./i18n-sales");
  return { lang, t: DICTS[lang], s: STOCK_DICTS[lang], x: SALES_DICTS[lang] };
}
