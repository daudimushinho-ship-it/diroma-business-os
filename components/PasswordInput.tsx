"use client";
import { useState } from "react";

export function PasswordInput(props: {
  id: string; name: string; label: string; autoComplete: "current-password" | "new-password";
  showLabel: string; hideLabel: string; minLength?: number;
}) {
  const [visible, setVisible] = useState(false);
  return (
    <div>
      <label htmlFor={props.id} className="label">{props.label}</label>
      <div className="relative">
        <input
          id={props.id} name={props.name} type={visible ? "text" : "password"} required
          autoComplete={props.autoComplete} minLength={props.minLength} maxLength={200}
          spellCheck={false} autoCapitalize="none" className="input pr-24"
        />
        <button
          type="button" onClick={() => setVisible((v) => !v)} aria-pressed={visible} aria-controls={props.id}
          className="absolute right-1.5 top-1/2 -translate-y-1/2 rounded-md px-3 py-1.5 text-sm font-medium text-gold-ink hover:bg-ivory"
        >
          {visible ? props.hideLabel : props.showLabel}
        </button>
      </div>
    </div>
  );
}
