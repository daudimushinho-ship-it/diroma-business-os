"use client";
import { useActionState } from "react";
import { activateAccount } from "@/app/actions/auth";
import { PhoneInput } from "@/components/PhoneInput";
import { PasswordInput } from "@/components/PasswordInput";
import { SubmitButton } from "@/components/SubmitButton";
import { FormError } from "@/components/FormError";
import type { Dict } from "@/lib/i18n";

export function ActivateForm({ t }: { t: Dict }) {
  const [state, action] = useActionState(activateAccount, undefined);
  return (
    <form action={action} className="space-y-4" noValidate>
      <FormError message={state?.error ? t.errors[state.error] : null} />
      <PhoneInput label={t.phone} hint={t.phoneHint} />
      <div>
        <label htmlFor="code" className="label">{t.activationCode}</label>
        <input id="code" name="code" required autoComplete="one-time-code" autoCapitalize="characters"
          spellCheck={false} maxLength={20} className="input font-mono tracking-widest uppercase" />
      </div>
      <PasswordInput id="password" name="password" label={t.newPassword} autoComplete="new-password"
        showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <PasswordInput id="confirm" name="confirm" label={t.confirmPassword} autoComplete="new-password"
        showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <p className="text-xs text-muted">{t.errors.password_too_short}</p>
      <SubmitButton>{t.activate}</SubmitButton>
    </form>
  );
}
