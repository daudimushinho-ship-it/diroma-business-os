/**
 * Placeholder wordmark. The master brief requires the OFFICIAL DIROMA logo file —
 * drop it in /public/brand/diroma-logo.svg (or .png) and swap this component to an <img>.
 * We deliberately do not redraw or invent the emblem.
 */
export function Logo({ tone = "light", size = "md" }: { tone?: "light" | "dark"; size?: "md" | "lg" }) {
  const color = tone === "light" ? "text-champagne" : "text-espresso";
  const text = size === "lg" ? "text-3xl" : "text-xl";
  return (
    <div className="leading-none select-none" aria-label="DIROMA">
      <div className={`${text} ${color} font-semibold tracking-[0.35em]`}>DIROMA</div>
      <div className={`mt-1 text-[0.65rem] uppercase tracking-[0.3em] ${tone === "light" ? "text-ivory/70" : "text-muted"}`}>
        Spirit of Fashion
      </div>
    </div>
  );
}
