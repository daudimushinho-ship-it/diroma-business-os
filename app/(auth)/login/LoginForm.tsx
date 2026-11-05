"use client";
import { useActionState } from "react";
import { signIn } from "@/app/actions/auth";
import { PhoneInput } from "@/components/PhoneInput";
import { PasswordInput } from "@/components/PasswordInput";
import { SubmitButton } from "@/components/SubmitButton";
import { FormError } from "@/components/FormError";
import type { Dict, ErrorKey } from "@/lib/i18n";

export function LoginForm({ t, initialError }: { t: Dict; initialError?: ErrorKey }) {
  const [state, action] = useActionState(signIn, initialError ? { error: initialError } : undefined);
  return (
    <form action={action} className="space-y-4" noValidate>
      <FormError message={state?.error ? t.errors[state.error] : null} />
      <PhoneInput label={t.phone} hint={t.phoneHint} />
      <PasswordInput id="password" name="password" label={t.password} autoComplete="current-password"
        showLabel={t.show} hideLabel={t.hide} />
      <SubmitButton>{t.signIn}</SubmitButton>
    </form>
  );
}
