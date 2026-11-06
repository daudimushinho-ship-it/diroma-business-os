import { describe, expect, it } from "vitest";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

/** Fails if anything that looks like a real secret is committed. Synthetic test identities are allowed. */
const root = join(__dirname, "..", "..");
const SKIP = new Set(["node_modules", ".next", ".git", "backups", "fixtures"]);
const PATTERNS: [string, RegExp][] = [
  ["Supabase secret key", /sb_secret_[A-Za-z0-9_-]{20,}/],
  ["JWT (service role / anon key)", /eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/],
  ["Private key block", /-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----/],
  ["Postgres URL with password", /postgres(ql)?:\/\/[^:\s/]+:[^@\s<.]{6,}@/],
  ["Hard-coded CRON secret", /CRON_SECRET\s*=\s*['"]?[A-Fa-f0-9]{32,}/],
  ["AWS access key", /AKIA[0-9A-Z]{16}/],
];

function files(dir: string, out: string[] = []): string[] {
  for (const f of readdirSync(dir)) {
    if (SKIP.has(f)) continue;
    const p = join(dir, f);
    const st = statSync(p);
    if (st.isDirectory()) files(p, out);
    else if (st.size < 2_000_000 && /\.(ts|tsx|js|mjs|cjs|json|sql|sh|md|ya?ml|env|example|txt)$|^\.env/.test(f)) out.push(p);
  }
  return out;
}

describe("secret scan", () => {
  it("no secrets in the repository", () => {
    const hits: string[] = [];
    for (const f of files(root)) {
      const text = readFileSync(f, "utf8");
      for (const [name, re] of PATTERNS) if (re.test(text)) hits.push(`${relative(root, f)}: ${name}`);
    }
    expect(hits).toEqual([]);
  });
  it(".env files are git-ignored", () => {
    const gi = readFileSync(join(root, ".gitignore"), "utf8");
    expect(gi).toMatch(/^\.env$/m);
    expect(gi).toMatch(/^\.env\*\.local$/m);
  });
});
