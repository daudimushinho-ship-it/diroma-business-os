import { describe, expect, it } from "vitest";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/** Every supabase.rpc("fn", { p_*: … }) call must match a SQL function's exact parameter names. */
const root = join(__dirname, "..", "..");

type Sig = { required: string[]; all: string[] };
function sqlFunctions(): Map<string, Sig> {
  const fns = new Map<string, Sig>();
  const dir = join(root, "supabase", "migrations");
  for (const f of readdirSync(dir).sort()) {
    const sql = readFileSync(join(dir, f), "utf8");
    for (const m of sql.matchAll(/create or replace function public\.([a-z_]+)\(([^)]*)\)/g)) {
      const parts = m[2].split(",").map((p) => p.trim()).filter((p) => p.startsWith("p_"));
      fns.set(m[1], {
        all: parts.map((p) => p.split(/\s+/)[0]),
        required: parts.filter((p) => !/\sdefault\s/i.test(p)).map((p) => p.split(/\s+/)[0]),
      });
    }
  }
  return fns;
}

function tsFiles(dir: string, out: string[] = []): string[] {
  for (const f of readdirSync(dir)) {
    if (f === "node_modules" || f.startsWith(".")) continue;
    const p = join(dir, f);
    if (statSync(p).isDirectory()) tsFiles(p, out);
    else if (/\.(ts|tsx|mjs)$/.test(f)) out.push(p);
  }
  return out;
}

describe("RPC contract", () => {
  const fns = sqlFunctions();
  const calls: { file: string; fn: string; args: string[] | null }[] = [];
  for (const file of [...tsFiles(join(root, "app")), ...tsFiles(join(root, "lib")), ...tsFiles(join(root, "components")), ...tsFiles(join(root, "scripts"))]) {
    const src = readFileSync(file, "utf8");
    for (const m of src.matchAll(/\.rpc\(\s*"([a-z_]+)"\s*(?:,\s*\{([^}]*)\})?/g)) {
      const args = m[2] === undefined ? null : [...m[2].matchAll(/\b(p_[a-z_]+)\s*:/g)].map((a) => a[1]);
      calls.push({ file: file.slice(root.length + 1), fn: m[1], args });
    }
  }

  it("finds the app's RPC calls", () => expect(calls.length).toBeGreaterThan(20));

  it.each(calls.map((c) => [`${c.file} → ${c.fn}`, c] as const))("%s", (_, c) => {
    expect(fns.has(c.fn), `function public.${c.fn} not found in migrations`).toBe(true);
    const sig = fns.get(c.fn)!;
    const args = c.args ?? [];
    for (const r of sig.required) expect(args, `${c.fn}: missing required ${r}`).toContain(r);
    for (const a of args) expect(sig.all, `${c.fn}: unknown parameter ${a}`).toContain(a);
  });
});
