import "server-only";
import { db } from "./stock";
import type { ReportKind } from "./report-docs";

export async function fetchReport(kind: ReportKind, from: string, to: string, location?: string | null) {
  const supabase = await db();
  const { data, error } = await supabase.rpc("report", { p_kind: kind, p_from: from, p_to: to, p_location: location ?? null });
  return { data: data as unknown, error };
}

export async function dataStartDate(): Promise<string | null> {
  const supabase = await db();
  const { data } = await supabase.rpc("data_start_date");
  return (data as string | null) ?? null;
}
