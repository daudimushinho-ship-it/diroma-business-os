"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { normalizePhone } from "@/lib/phone";
import { checkNewPassword } from "@/lib/password";
import type { ErrorKey } from "@/lib/i18n";

const KINDS = ["warehouse", "shop", "transit", "partner", "inspection", "quarantine"];

export async function createLocation(fd: FormData) {
  await requireWorkspace("settings.manage");
  const supabase = await createClient();
  const code = String(fd.get("code") ?? "").trim();
  const name = String(fd.get("name") ?? "").trim();
  const kind = String(fd.get("kind") ?? "");
  if (!supabase || !/^[A-Za-z0-9_-]{2,20}$/.test(code) || name.length < 2 || !KINDS.includes(kind)) return;
  await supabase.rpc("location_create", { p_code: code, p_name: name, p_kind: kind });
  revalidatePath("/settings");
}

export type PwState = { error?: ErrorKey; ok?: boolean } | undefined;

/** Change own password: re-verifies the current password first (fresh authentication). */
export async function changePassword(_prev: PwState, fd: FormData): Promise<PwState> {
  await requireWorkspace();
  const supabase = await createClient();
  if (!supabase) return { error: "not_configured" };
  const { data: me } = await supabase.from("memberships").select("phone_e164").limit(1).maybeSingle();
  const phone = normalizePhone(me?.phone_e164 ?? "");
  if (!phone.ok) return { error: "generic" };
  const next = String(fd.get("password") ?? "");
  const check = checkNewPassword(next, String(fd.get("confirm") ?? ""));
  if (!check.ok) return { error: check.error };
  const { error: reauth } = await supabase.auth.signInWithPassword({ phone: phone.e164, password: String(fd.get("current") ?? "") });
  if (reauth) return { error: "invalid_credentials" };
  const { error } = await supabase.auth.updateUser({ password: next });
  if (error) return { error: "generic" };
  return { ok: true };
}
