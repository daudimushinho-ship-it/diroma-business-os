"use client";
import { useActionState } from "react";
import { changePassword } from "@/app/actions/settings";
import { PasswordInput } from "@/components/PasswordInput";
import { SubmitButton } from "@/components/SubmitButton";
import { FormError } from "@/components/FormError";
import type { Dict } from "@/lib/i18n";

export function PasswordForm({ t }: { t: Dict }) {
  const [state, action] = useActionState(changePassword, undefined);
  return (
    <form action={action} className="space-y-4">
      <FormError message={state?.error ? t.errors[state.error] : null} />
      {state?.ok && <p role="status" className="rounded-lg bg-[#e7f4ec] px-3 py-2 text-sm text-ok">{t.profile.saved}</p>}
      <PasswordInput id="current" name="current" label={t.currentPassword} autoComplete="current-password" showLabel={t.show} hideLabel={t.hide} />
      <PasswordInput id="password" name="password" label={t.newPassword} autoComplete="new-password" showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <PasswordInput id="confirm" name="confirm" label={t.confirmPassword} autoComplete="new-password" showLabel={t.show} hideLabel={t.hide} minLength={12} />
      <SubmitButton className="btn btn-primary">{t.profile.save}</SubmitButton>
    </form>
  );
}
