import { NextResponse, type NextRequest } from "next/server";
import { getWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db } from "@/lib/stock";
import { createAdminClient } from "@/lib/supabase/admin";

/** Short-lived (60 s) signed download for a generated daily PDF. Ownership is checked through job_status() first. */
export async function GET(req: NextRequest) {
  const ws = await getWorkspace();
  if (!ws || ws.aal !== "aal2" || !can(ws, "audit.view")) return new NextResponse("Unauthorized", { status: 401 });
  const id = req.nextUrl.searchParams.get("run") ?? "";
  const supabase = await db();
  const { data } = await supabase.rpc("job_status");
  const run = ((data as { reports?: { id: string; file_path: string | null; status: string }[] } | null)?.reports ?? [])
    .find((r) => r.id === id && r.status === "succeeded" && r.file_path);
  if (!run?.file_path) return new NextResponse("Not found", { status: 404 });
  const admin = createAdminClient();
  if (!admin) return new NextResponse("Not configured", { status: 503 });
  const { data: signed, error } = await admin.storage.from("reports").createSignedUrl(run.file_path, 60, { download: true });
  if (error || !signed) return new NextResponse("Unavailable", { status: 502 });
  return NextResponse.redirect(signed.signedUrl);
}
