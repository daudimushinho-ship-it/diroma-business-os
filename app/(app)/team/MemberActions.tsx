"use client";
import { useActionState } from "react";
import { reissueCode, setMemberStatus } from "@/app/actions/team";
import { FormError } from "@/components/FormError";
import { CodeReveal } from "./CodeReveal";
import type { Dict } from "@/lib/i18n";

export function MemberActions({ t, id, status }: { t: Dict; id: string; status: string }) {
  const [state, reissue] = useActionState(reissueCode, undefined);
  if (state?.ok) return <CodeReveal t={t} name={state.name} phone={state.phone} code={state.code} />;
  return (
    <details className="text-sm">
      <summary className="cursor-pointer font-medium text-gold-ink">⋯</summary>
      <div className="mt-3 space-y-3">
        <FormError message={state?.error ? t.errors[state.error] : null} />
        <form action={setMemberStatus} className="flex flex-wrap items-end gap-2">
          <input type="hidden" name="membership" value={id} />
          <label className="min-w-40 flex-1">
            <span className="label">{t.team.reason}</span>
            <input name="reason" required maxLength={200} className="input" />
          </label>
          {status === "active" && <button name="status" value="suspended" className="btn btn-danger">{t.team.suspend}</button>}
          {status === "suspended" && <button name="status" value="active" className="btn btn-ghost">{t.team.reactivate}</button>}
          {status !== "deactivated" && <button name="status" value="deactivated" className="btn btn-danger">{t.team.deactivate}</button>}
        </form>
        {status !== "deactivated" && (
          <form action={reissue} className="flex flex-wrap items-end gap-2">
            <input type="hidden" name="membership" value={id} />
            <label className="min-w-40 flex-1">
              <span className="label">{t.team.reason}</span>
              <input name="reason" maxLength={200} className="input" placeholder={t.forgotPassword} />
            </label>
            <button className="btn btn-ghost">{t.team.newCode}</button>
          </form>
        )}
      </div>
    </details>
  );
}
