"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabase } from "@/lib/supabase/browser";
import { FormError } from "@/components/FormError";
import type { Dict } from "@/lib/i18n";

type Mode = { kind: "loading" } | { kind: "enroll"; factorId: string; qr: string; secret: string } | { kind: "verify"; factorId: string };

/** TOTP enrollment / challenge using Supabase Auth MFA. Required for Owner and Manager. */
export function MfaClient({ t, next }: { t: Dict; next: string }) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>({ kind: "loading" });
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const supabase = createBrowserSupabase();
    if (!supabase) { setError(t.errors.not_configured); return; }
    (async () => {
      const { data, error } = await supabase.auth.mfa.listFactors();
      if (error) { setError(t.errors.generic); return; }
      const verified = data.totp.find((f) => f.status === "verified");
      if (verified) { setMode({ kind: "verify", factorId: verified.id }); return; }
      // Remove abandoned unverified factors before enrolling a fresh one.
      for (const f of data.all.filter((f) => f.status !== "verified")) await supabase.auth.mfa.unenroll({ factorId: f.id });
      const enrolled = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: "DIROMA" });
      if (enrolled.error) { setError(t.errors.generic); return; }
      setMode({ kind: "enroll", factorId: enrolled.data.id, qr: enrolled.data.totp.qr_code, secret: enrolled.data.totp.secret });
    })();
  }, [t]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (mode.kind === "loading") return;
    const supabase = createBrowserSupabase();
    if (!supabase) return;
    setBusy(true); setError(null);
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: mode.factorId, code: code.replace(/\s/g, "") });
    setBusy(false);
    if (error) { setError(t.mfa.invalid); return; }
    router.replace(next);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <FormError message={error} />
      {mode.kind === "loading" && !error && <p className="text-sm text-muted" role="status">…</p>}
      {mode.kind === "enroll" && (
        <div className="space-y-3">
          <p className="text-sm">{t.mfa.enrollIntro}</p>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={mode.qr} alt="QR code" width={192} height={192} className="mx-auto rounded-lg border border-line bg-white p-2" />
          <p className="text-xs text-muted">{t.mfa.secretLabel}</p>
          <code className="block break-all rounded-md bg-ivory p-2 text-center font-mono text-sm">{mode.secret}</code>
        </div>
      )}
      {mode.kind === "verify" && <p className="text-sm">{t.mfa.verifyIntro}</p>}
      {mode.kind !== "loading" && (
        <form onSubmit={submit} className="space-y-3">
          <label htmlFor="totp" className="label">{t.mfa.code}</label>
          <input id="totp" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code"
            pattern="[0-9 ]{6,7}" maxLength={7} required className="input text-center font-mono text-xl tracking-[0.4em]" />
          <button type="submit" disabled={busy} className="btn btn-primary w-full">{busy ? "…" : t.mfa.verify}</button>
        </form>
      )}
    </div>
  );
}
