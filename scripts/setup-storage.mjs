#!/usr/bin/env node
// Creates the PRIVATE storage bucket for generated report PDFs (idempotent).
//   NEXT_PUBLIC_SUPABASE_URL=... SUPABASE_SECRET_KEY=... node scripts/setup-storage.mjs
import { createClient } from "@supabase/supabase-js";
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) { console.error("Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SECRET_KEY"); process.exit(1); }
const s = createClient(url, key, { auth: { persistSession: false } });
const { data: existing } = await s.storage.getBucket("reports");
if (existing) { console.log(`bucket "reports" exists (public=${existing.public})`); if (existing.public) process.exit(2); process.exit(0); }
const { error } = await s.storage.createBucket("reports", { public: false, fileSizeLimit: "20MB", allowedMimeTypes: ["application/pdf"] });
if (error) { console.error(error.message); process.exit(1); }
console.log('created private bucket "reports"');
