import { parsePhoneNumberFromString, type CountryCode } from "libphonenumber-js/max";

export type PhoneResult = { ok: true; e164: string } | { ok: false; error: "invalid_phone" };

/**
 * Normalize user-typed phone input to a canonical E.164 identity.
 * - Local Tanzanian forms (0712..., 712...) resolve with the default country (TZ).
 * - "+..." or "00..." international input is parsed as-is; we never blindly
 *   prepend +255 to a number that already carries another country code.
 * - Only numbers that are valid mobile (or fixed-or-mobile) lines are accepted.
 */
export function normalizePhone(input: string, defaultCountry: CountryCode = "TZ"): PhoneResult {
  const raw = (input ?? "").trim();
  if (!raw || raw.length > 32) return { ok: false, error: "invalid_phone" };
  // allow spaces, dashes, dots, parentheses as visual separators only
  if (!/^[+0-9\s\-().]+$/.test(raw)) return { ok: false, error: "invalid_phone" };
  let candidate = raw.replace(/[\s\-().]/g, "");
  if (candidate.startsWith("00")) candidate = "+" + candidate.slice(2);
  // A bare "255..." with TZ-length is an international TZ number typed without "+".
  if (/^255\d{9}$/.test(candidate)) candidate = "+" + candidate;
  const parsed = candidate.startsWith("+")
    ? parsePhoneNumberFromString(candidate)
    : parsePhoneNumberFromString(candidate, defaultCountry);
  if (!parsed || !parsed.isValid()) return { ok: false, error: "invalid_phone" };
  const type = parsed.getType();
  if (type && type !== "MOBILE" && type !== "FIXED_LINE_OR_MOBILE") return { ok: false, error: "invalid_phone" };
  return { ok: true, e164: parsed.number };
}

/** Display form, e.g. +255 712 345 678 */
export function formatPhone(e164: string): string {
  const parsed = parsePhoneNumberFromString(e164);
  return parsed ? parsed.formatInternational() : e164;
}

/**
 * Supabase builds the TOTP QR code from the user's email; a phone-only user gets "Error generating QR Code".
 * Every auth user therefore carries a non-deliverable placeholder address derived from the phone
 * (RFC 2606 `.invalid` TLD; the email provider is disabled, so it can never be used to sign in or receive mail).
 * The authenticator app shows it as the account label, e.g. "DIROMA: 255712345678@phone.diroma.invalid".
 */
export function authPlaceholderEmail(e164: string): string {
  const digits = e164.replace(/\D/g, "");
  if (!/^\d{8,15}$/.test(digits)) throw new Error("invalid_phone");
  return `${digits}@phone.diroma.invalid`;
}
