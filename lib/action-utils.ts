import "server-only";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";

export function f(fd: FormData, k: string): string {
  const v = fd.get(k);
  return typeof v === "string" ? v.trim() : "";
}
/** Whole positive TZS amount; "" → null; anything else → NaN. */
export function money(fd: FormData, k: string): number | null {
  const raw = f(fd, k).replace(/[,\s]/g, "");
  if (!raw) return null;
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : NaN;
}
/** Whole TZS amount allowing zero. */
export function amount0(fd: FormData, k: string): number {
  const raw = f(fd, k).replace(/[,\s]/g, "");
  const n = Number(raw || "0");
  return Number.isInteger(n) && n >= 0 ? n : NaN;
}
export function backTo(fd: FormData, fallback: string): string {
  const b = f(fd, "back");
  return b.startsWith("/") && !b.startsWith("//") ? b : fallback;
}
function withMsg(path: string, key: "ok" | "err", msg: string): string {
  const u = new URL(path, "http://x");
  u.searchParams.delete("ok"); u.searchParams.delete("err");
  u.searchParams.set(key, msg.slice(0, 200));
  return u.pathname + u.search;
}
/** Database exceptions raised by our functions are written to be user-readable. */
export function dbMessage(e: { message?: string; code?: string } | null): string {
  if (!e) return "Error";
  if (e.code === "42501") return `Not allowed: ${e.message ?? ""}`;
  return e.message ?? "Error";
}
export async function done(fd: FormData, fallback: string, error: { message?: string; code?: string } | null, ok = "✓"): Promise<never> {
  const path = backTo(fd, fallback);
  revalidatePath(path.split("?")[0]);
  redirect(withMsg(path, error ? "err" : "ok", error ? dbMessage(error) : ok));
}
