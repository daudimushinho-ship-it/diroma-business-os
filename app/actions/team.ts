"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { requireWorkspace } from "@/lib/workspace";
import { normalizePhone } from "@/lib/phone";
import { generateOneTimeCode, generateUnusablePassword } from "@/lib/password";
import type { ErrorKey } from "@/lib/i18n";

export type InviteState =
  | { error?: ErrorKey; ok?: false }
  | { ok: true; code: string; name: string; phone: string }
  | undefined;

const STAFF_ROLES = ["manager", "sales_staff", "storekeeper"] as const;

function mapDbError(code: string | undefined): ErrorKey {
  if (code === "23505") return "duplicate_phone";
  if (code === "42501") return "forbidden";
  if (code === "22023") return "generic";
  return "generic";
}

/**
 * Ensures the invited membership has a Supabase Auth identity and issues a fresh one-time code.
 * The auth identity gets a random password nobody knows; the worker sets their own on /activate.
 * Phone possession is verified in person by the Owner (documented in docs/SETUP.md) — not by SMS.
 */
async function issueActivationCode(membershipId: string): Promise<{ code: string } | { error: ErrorKey }> {
  const supabase = await createClient();
  const admin = createAdminClient();
  if (!supabase || !admin) return { error: "not_configured" };

  // Read through the Owner's own session: RLS proves the membership is in the Owner's business.
  const { data: m } = await supabase
    .from("memberships").select("id, user_id, phone_e164, status").eq("id", membershipId).maybeSingle();
  if (!m || !["invited", "pending_activation"].includes(m.status)) return { error: "forbidden" };

  let userId = m.user_id as string | null;
  if (!userId) {
    const { data, error } = await admin.auth.admin.createUser({
      phone: m.phone_e164,
      password: generateUnusablePassword(),
      phone_confirm: true,
      app_metadata: { enrolled_via: "owner_in_person" },
    });
    if (error || !data.user) return { error: error?.code === "phone_exists" ? "duplicate_phone" : "generic" };
    userId = data.user.id;
  }

  const code = generateOneTimeCode();
  const { error } = await admin.rpc("team_attach_auth_user", { p_membership: m.id, p_user: userId, p_code: code });
  if (error) return { error: "generic" }; // membership stays restricted; Owner can retry "Issue new code"
  return { code };
}

export async function inviteStaff(_prev: InviteState, fd: FormData): Promise<InviteState> {
  await requireWorkspace("team.manage");
  const supabase = await createClient();
  if (!supabase) return { error: "not_configured" };

  const phone = normalizePhone(String(fd.get("phone") ?? ""));
  if (!phone.ok) return { error: "invalid_phone" };
  const name = String(fd.get("name") ?? "").trim();
  if (name.length < 2 || name.length > 80) return { error: "generic" };
  const role = String(fd.get("role") ?? "");
  if (!STAFF_ROLES.includes(role as (typeof STAFF_ROLES)[number])) return { error: "forbidden" };
  const locations = fd.getAll("locations").map(String);

  const { data: membershipId, error } = await supabase.rpc("team_invite", {
    p_phone: phone.e164, p_name: name, p_role: role, p_location_ids: locations, p_reason: null,
  });
  if (error || !membershipId) return { error: mapDbError(error?.code) };

  const issued = await issueActivationCode(membershipId as string);
  revalidatePath("/team");
  if ("error" in issued) return { error: issued.error };
  return { ok: true, code: issued.code, name, phone: phone.e164 };
}

export async function reissueCode(_prev: InviteState, fd: FormData): Promise<InviteState> {
  await requireWorkspace("team.manage");
  const supabase = await createClient();
  if (!supabase) return { error: "not_configured" };
  const id = String(fd.get("membership") ?? "");
  const reason = String(fd.get("reason") ?? "").trim();

  const { data: m } = await supabase.from("memberships").select("id, status, display_name, phone_e164").eq("id", id).maybeSingle();
  if (!m) return { error: "forbidden" };
  if (m.status === "active" || m.status === "suspended") {
    // Owner-assisted password recovery: cuts access first, then a new code is issued.
    if (!reason) return { error: "reason_required" };
    const { error } = await supabase.rpc("team_reset_access", { p_membership: id, p_reason: reason });
    if (error) return { error: mapDbError(error.code) };
  }
  const issued = await issueActivationCode(id);
  revalidatePath("/team");
  if ("error" in issued) return { error: issued.error };
  return { ok: true, code: issued.code, name: m.display_name, phone: m.phone_e164 };
}

export async function setMemberStatus(fd: FormData) {
  await requireWorkspace("team.manage");
  const supabase = await createClient();
  if (!supabase) return;
  const reason = String(fd.get("reason") ?? "").trim();
  if (!reason) return;
  await supabase.rpc("team_set_status", {
    p_membership: String(fd.get("membership") ?? ""), p_status: String(fd.get("status") ?? ""), p_reason: reason,
  });
  revalidatePath("/team");
}
