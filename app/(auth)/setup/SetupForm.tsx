"use client";
import { useActionState } from "react";
import { setupOwner } from "@/app/actions/auth";
import { PhoneInput } from "@/components/PhoneInput";
import { PasswordInput } from "@/components/PasswordInput";
import { SubmitButton } from "@/components/SubmitButton";
import { FormError } from "@/components/FormError";
import type { Dict } from "@/lib/i18n";

export function SetupForm({ t }: { t: Dict }) {
  const [state, action] = useActionState(setupOwner, undefined);
  return (
    <form action={action} className="space-y-4" noValidate>
      <FormError message={state?.error ? t.errors[state.error] : null} />
      <div>
        <label htmlFor="code" className="label">{t.setupCode}</label>
        <input id="code" name="code" required autoComplete="one-time-code" spellCheck={false} maxLength={20}
          className="input font-mono tracking-widest uppercase" />
      </div>
      <div>
        <label htmlFor="name" className="label">{t.fullName}</label>
        <input id="name" name="name" required maxLength={80} autoComplete="name" className="input" />
      </div>
      <PhoneInput label={t.phone} hint={t.phoneHint} />
      <PasswordInput id="password" name="password" label={t.newPassword} autoComplete="new-password"
        showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <PasswordInput id="confirm" name="confirm" label={t.confirmPassword} autoComplete="new-password"
        showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <SubmitButton>{t.createOwner}</SubmitButton>
    </form>
  );
}
