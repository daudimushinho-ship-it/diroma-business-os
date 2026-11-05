#!/usr/bin/env node
// Emits SQL that runs every simple `.from("t").select("a, b")` used by the app with LIMIT 0,
// so a real PostgreSQL schema proves the columns exist. Embedded relations "x(…)" are checked as joins-free columns.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
const root = new URL("..", import.meta.url).pathname;
const files = [];
function walk(d) {
  for (const f of readdirSync(d)) {
    if (f === "node_modules" || f.startsWith(".")) continue;
    const p = join(d, f);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(ts|tsx)$/.test(f)) files.push(p);
  }
}
["app", "lib", "components"].forEach((d) => walk(join(root, d)));
const out = new Set();
for (const file of files) {
  const src = readFileSync(file, "utf8");
  for (const m of src.matchAll(/\.from\("([a-z_]+)"\)\s*\.select\("([^"]+)"\)/g)) {
    const [, table, sel] = m;
    // strip embedded relations like designs(code, name) / transfer_lines(variant_id, transfers(ref_no))
    let cols = sel; let prev;
    do { prev = cols; cols = cols.replace(/[a-z_]+\([^()]*\)/g, ""); } while (cols !== prev);
    const list = cols.split(",").map((c) => c.trim()).filter(Boolean);
    if (list.length) out.add(`select ${list.join(", ")} from public.${table} limit 0; -- ${file.slice(root.length)}`);
  }
}
console.log([...out].join("\n"));
