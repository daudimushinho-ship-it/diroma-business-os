import { listDesigns } from "@/lib/stock";

/** GET form that sets ?design= while keeping the other query params. */
export async function DesignPicker({ label, keep, selected }: { label: string; keep: Record<string, string>; selected?: string }) {
  const designs = await listDesigns();
  return (
    <form className="flex flex-wrap items-end gap-2">
      {Object.entries(keep).map(([k, v]) => <input key={k} type="hidden" name={k} value={v} />)}
      <label className="min-w-64 flex-1"><span className="label">{label}</span>
        <select name="design" defaultValue={selected ?? ""} className="input">
          <option value="" disabled>—</option>
          {designs.map((d) => <option key={d.design_id} value={d.design_id}>{d.code} · {d.name}</option>)}
        </select></label>
      <button className="btn btn-ghost">OK</button>
    </form>
  );
}
