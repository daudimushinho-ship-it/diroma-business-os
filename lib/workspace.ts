import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "./supabase/server";
import { can, needsMfa, type Need, type Workspace } from "./roles";

/** Loads the caller's server-authorized workspace. Never trusts client-provided role data. */
export const getWorkspace = cache(async (): Promise<Workspace | null> => {
  const supabase = await createClient();
  if (!supabase) return null;
  const { data: userData } = await supabase.auth.getUser(); // validates the JWT with Supabase Auth
  if (!userData.user) return null;
  const { data, error } = await supabase.rpc("my_workspace");
  if (error || !data) return null;
  return data as Workspace;
});

/** Page guard: signed in, active, MFA satisfied for privileged roles, and holding the permission. */
export async function requireWorkspace(permission: Need = null): Promise<Workspace> {
  const supabase = await createClient();
  if (!supabase) redirect("/login?e=not_configured");
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) redirect("/login");
  const ws = await getWorkspace();
  if (!ws) redirect("/login?e=inactive");
  if (needsMfa(ws)) redirect("/security/mfa");
  if (!can(ws, permission)) redirect("/forbidden");
  return ws;
}
