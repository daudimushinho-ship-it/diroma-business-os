#!/usr/bin/env node
// One-time Owner bootstrap: creates the DIROMA business row and prints a single-use setup code.
// Run by the installer with the server secret key; the Owner then opens /setup and uses the code.
//   NEXT_PUBLIC_SUPABASE_URL=... SUPABASE_SECRET_KEY=... node scripts/setup-owner.mjs
import { createClient } from "@supabase/supabase-js";
import { randomInt } from "node:crypto";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SECRET_KEY first.");
  process.exit(1);
}
const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const code = Array.from({ length: 10 }, () => alphabet[randomInt(alphabet.length)]).join("");

const supabase = createClient(url, key, { auth: { persistSession: false } });
const { error } = await supabase.rpc("setup_create_business", {
  p_name: "DIROMA", p_slogan: "Spirit of Fashion", p_code: code, p_ttl_minutes: 1440,
});
if (error) {
  console.error("Setup failed:", error.message);
  process.exit(1);
}
console.log("\nOne-time Owner setup code (valid 24h, 5 attempts):\n");
console.log("   " + code.replace(/(.{5})/, "$1 ") + "\n");
console.log("Give it to the Owner in person. They open <app-url>/setup and create their account.\n");
