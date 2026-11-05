import Link from "next/link";

export function LocationPicker({ locations, active, base }: { locations: { id: string; name: string }[]; active: string; base: string }) {
  if (locations.length < 2) return null;
  return (
    <div className="flex flex-wrap gap-2">
      {locations.map((l) => (
        <Link key={l.id} href={`${base}${base.includes("?") ? "&" : "?"}loc=${l.id}`}
          className={`rounded-full border px-3 py-1 text-sm ${l.id === active ? "border-espresso bg-espresso text-ivory" : "border-line bg-paper"}`}>
          {l.name}
        </Link>
      ))}
    </div>
  );
}
