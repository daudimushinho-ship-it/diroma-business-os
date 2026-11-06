import { NextResponse, type NextRequest } from "next/server";
import { createHash, timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";
import { dailyRunDate, renderDailyPdf, type DailyKind } from "@/lib/daily-report";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;

function authorized(req: NextRequest): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret || secret.length < 32) return false;
  const got = Buffer.from(req.headers.get("authorization") ?? "");
  const want = Buffer.from(`Bearer ${secret}`);
  return got.length === want.length && timingSafeEqual(got, want);
}

/**
 * Scheduled daily report (works with phones and browsers closed):
 *   23:30 Africa/Dar_es_Salaam → kind=interim (today so far)     cron "30 20 * * *" (UTC)
 *   00:15 Africa/Dar_es_Salaam → kind=final   (the previous day) cron "15 21 * * *" (UTC)
 * Each run: job_begin (dedupe by data fingerprint, versions late data, bounded retries) → snapshot → PDF →
 * private storage "reports/<business>/daily/<date>/<kind>-v<n>.pdf" → job_finish with SHA-256.
 */
async function run(req: NextRequest) {
  if (!authorized(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const admin = createAdminClient();
  if (!admin) return NextResponse.json({ error: "not configured" }, { status: 503 });
  const kind: DailyKind = req.nextUrl.searchParams.get("kind") === "final" ? "daily_final" : "daily_interim";
  const date = req.nextUrl.searchParams.get("date") ?? dailyRunDate(kind);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return NextResponse.json({ error: "bad date" }, { status: 400 });
  const trigger = req.nextUrl.searchParams.get("trigger") === "manual" ? "manual" : "schedule";
  const { data: businesses, error: bErr } = await admin.from("businesses").select("id");
  if (bErr) return NextResponse.json({ error: bErr.message }, { status: 500 });

  const results: unknown[] = [];
  for (const b of businesses ?? []) {
    const { data: begin, error: e1 } = await admin.rpc("job_begin", { p_business: b.id, p_kind: kind, p_date: date, p_trigger: trigger });
    if (e1) { results.push({ business: b.id, error: e1.message }); continue; }
    const j = begin as { skip: boolean; reason?: string; run_id: string; version?: number };
    if (j.skip) { results.push({ business: b.id, skipped: j.reason }); continue; }
    try {
      const { data: snap, error: e2 } = await admin.rpc("daily_snapshot", { p_business: b.id, p_date: date });
      if (e2 || !snap) throw new Error(e2?.message ?? "empty snapshot");
      const pdf = await renderDailyPdf(snap as Record<string, unknown>, kind, j.version ?? 1);
      const path = `${b.id}/daily/${date}/${kind}-v${j.version}.pdf`;
      let lastErr: string | null = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        const { error } = await admin.storage.from("reports").upload(path, Buffer.from(pdf), { contentType: "application/pdf", upsert: false });
        if (!error || /exists/i.test(error.message)) { lastErr = null; break; }
        lastErr = error.message;
        await new Promise((r) => setTimeout(r, 500 * attempt));
      }
      if (lastErr) throw new Error(`upload failed: ${lastErr}`);
      const sha = createHash("sha256").update(pdf).digest("hex");
      await admin.rpc("job_finish", { p_run: j.run_id, p_ok: true, p_path: path, p_sha256: sha, p_size: pdf.byteLength, p_error: null });
      results.push({ business: b.id, version: j.version, path, sha256: sha });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      await admin.rpc("job_finish", { p_run: j.run_id, p_ok: false, p_path: null, p_sha256: null, p_size: null, p_error: msg });
      results.push({ business: b.id, failed: msg });
    }
  }
  const failed = results.some((r) => typeof r === "object" && r !== null && ("failed" in r || "error" in r));
  return NextResponse.json({ kind, date, results }, { status: failed ? 500 : 200 });
}

export const GET = run;   // Vercel Cron sends GET with "Authorization: Bearer <CRON_SECRET>"
export const POST = run;
