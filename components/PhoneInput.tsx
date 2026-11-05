export function PhoneInput({ label, hint, name = "phone" }: { label: string; hint: string; name?: string }) {
  return (
    <div>
      <label htmlFor={name} className="label">{label}</label>
      <div className="flex">
        <span className="inline-flex shrink-0 items-center gap-1 whitespace-nowrap rounded-l-[10px] border border-r-0 border-line bg-ivory px-3 text-sm text-muted" aria-hidden>
          🇹🇿 +255
        </span>
        <input
          id={name} name={name} type="tel" inputMode="tel" autoComplete="tel" required maxLength={32}
          className="input rounded-l-none" aria-describedby={`${name}-hint`} placeholder="0712 345 678"
        />
      </div>
      <p id={`${name}-hint`} className="mt-1 text-xs text-muted">{hint}</p>
    </div>
  );
}
