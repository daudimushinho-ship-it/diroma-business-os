"use client";
import { useActionState } from "react";
import { inviteStaff } from "@/app/actions/team";
import { PhoneInput } from "@/components/PhoneInput";
import { SubmitButton } from "@/components/SubmitButton";
import { FormError } from "@/components/FormError";
import { CodeReveal } from "./CodeReveal";
import type { Dict } from "@/lib/i18n";

export function InviteForm({ t, locations }: { t: Dict; locations: { id: string; name: string; kind: string }[] }) {
  const [state, action] = useActionState(inviteStaff, undefined);
  if (state?.ok) return <CodeReveal t={t} name={state.name} phone={state.phone} code={state.code} />;
  return (
    <form action={action} className="space-y-4">
      <FormError message={state?.error ? t.errors[state.error] : null} />
      <div>
        <label htmlFor="name" className="label">{t.fullName}</label>
        <input id="name" name="name" required maxLength={80} className="input" />
      </div>
      <PhoneInput label={t.phone} hint={t.phoneHint} />
      <div>
        <label htmlFor="role" className="label">{t.team.role}</label>
        <select id="role" name="role" className="input" defaultValue="sales_staff">
          <option value="sales_staff">{t.roles.sales_staff}</option>
          <option value="storekeeper">{t.roles.storekeeper}</option>
          <option value="manager">{t.roles.manager}</option>
        </select>
      </div>
      <fieldset>
        <legend className="label">{t.team.locations}</legend>
        <div className="space-y-2">
          {locations.map((l) => (
            <label key={l.id} className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="locations" value={l.id} className="h-4 w-4 accent-[#2d1c18]" />
              {l.name} <span className="text-muted">({t.locationKinds[l.kind] ?? l.kind})</span>
            </label>
          ))}
        </div>
      </fieldset>
      <SubmitButton>{t.team.sendInvite}</SubmitButton>
    </form>
  );
}
