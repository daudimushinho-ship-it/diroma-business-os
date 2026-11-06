export function Flash({ ok, err }: { ok?: string; err?: string }) {
  if (err) return <div role="alert" className="mb-4 rounded-[10px] border border-[#f0c7c2] bg-[#fdf1ef] px-3 py-2 text-sm text-bad">{err}</div>;
  if (ok) return <div role="status" className="mb-4 rounded-[10px] bg-[#e7f4ec] px-3 py-2 text-sm text-ok">{ok}</div>;
  return null;
}
