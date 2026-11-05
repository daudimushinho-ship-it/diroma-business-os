export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_LENGTH = 72; // bcrypt input limit used by Supabase Auth

export type PasswordCheck = { ok: true } | { ok: false; error: "password_too_short" | "password_too_long" | "password_mismatch" };

/**
 * Policy: long passphrases over composition rules. The password is used exactly
 * as typed (never trimmed); we only measure it.
 */
export function checkNewPassword(password: string, confirm: string): PasswordCheck {
  if (password !== confirm) return { ok: false, error: "password_mismatch" };
  if ([...password].length < PASSWORD_MIN_LENGTH) return { ok: false, error: "password_too_short" };
  if (new TextEncoder().encode(password).length > PASSWORD_MAX_LENGTH) return { ok: false, error: "password_too_long" };
  return { ok: true };
}

/** One-time activation / setup code: 10 chars from an unambiguous alphabet, CSPRNG. */
export function generateOneTimeCode(length = 10): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const out: string[] = [];
  const buf = new Uint8Array(length * 2);
  while (out.length < length) {
    crypto.getRandomValues(buf);
    for (const b of buf) {
      // rejection sampling to avoid modulo bias
      if (b < Math.floor(256 / alphabet.length) * alphabet.length) out.push(alphabet[b % alphabet.length]);
      if (out.length === length) break;
    }
  }
  return out.join("");
}

/** Random password nobody knows; used as a placeholder until the staff member sets their own. */
export function generateUnusablePassword(): string {
  const buf = new Uint8Array(32);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function normalizeCode(input: string): string {
  return (input ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}
