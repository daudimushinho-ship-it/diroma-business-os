import { matrixAxes } from "@/lib/stock";

type V = { id: string; color: string; size: string };

/** Colour × size grid. With `inputPrefix` it renders number inputs; otherwise it shows `values`. */
export function VariantMatrix({ variants, values, inputPrefix, defaults, max }: {
  variants: V[]; values?: Record<string, number | string>; inputPrefix?: string;
  defaults?: Record<string, number>; max?: Record<string, number>;
}) {
  const { colors, sizes } = matrixAxes(variants);
  const byKey = new Map(variants.map((v) => [`${v.color}|${v.size}`, v]));
  return (
    <div className="overflow-x-auto">
      <table className="text-sm">
        <thead>
          <tr>
            <th className="sticky left-0 bg-paper px-2 py-1.5 text-left font-medium text-muted" />
            {sizes.map((s) => <th key={s} className="min-w-14 px-2 py-1.5 text-center font-semibold">{s}</th>)}
          </tr>
        </thead>
        <tbody>
          {colors.map((c) => (
            <tr key={c} className="border-t border-line">
              <th scope="row" className="sticky left-0 bg-paper px-2 py-1.5 text-left font-medium">{c}</th>
              {sizes.map((s) => {
                const v = byKey.get(`${c}|${s}`);
                if (!v) return <td key={s} className="px-2 py-1.5 text-center text-line">·</td>;
                if (inputPrefix) {
                  return (
                    <td key={s} className="px-1 py-1">
                      <input name={`${inputPrefix}${v.id}`} type="number" inputMode="numeric" min={0} max={max?.[v.id]} step={1}
                        defaultValue={defaults?.[v.id] ?? ""} aria-label={`${c} ${s}`}
                        className="h-10 w-16 rounded-md border border-line px-2 text-center" />
                    </td>
                  );
                }
                const val = values?.[v.id];
                return <td key={s} className={`px-2 py-1.5 text-center tabular-nums ${!val ? "text-muted" : "font-semibold"}`}>{val ?? 0}</td>;
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
