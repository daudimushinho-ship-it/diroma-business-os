import { notFound } from "next/navigation";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { getDesign } from "@/lib/stock";
import { barcodeSvg } from "@/lib/barcode";
import { PrintButton } from "@/components/PrintButton";

export default async function LabelsPage({ params }: { params: Promise<{ id: string }> }) {
  await requireWorkspace("products.view");
  const { s } = await getStockDict();
  const { id } = await params;
  const { design, variants } = await getDesign(id);
  if (!design) notFound();
  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3 print:hidden">
        <p className="text-sm text-muted">{s.labelsNote}</p>
        <PrintButton label={s.printLabels} />
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 print:grid-cols-3 print:gap-2">
        {variants.map((v) => (
          <figure key={v.id} className="break-inside-avoid rounded-lg border border-line bg-white p-3 text-center">
            <figcaption className="mb-1 text-xs leading-tight">
              <span className="block font-semibold tracking-widest">DIROMA</span>
              <span className="block font-mono">{design.code}</span>
              <span className="block">{v.color} · <strong>{v.size}</strong></span>
            </figcaption>
            <div className="mx-auto [&>svg]:mx-auto [&>svg]:h-auto [&>svg]:max-w-full" dangerouslySetInnerHTML={{ __html: barcodeSvg(v.barcode) }} />
          </figure>
        ))}
      </div>
    </div>
  );
}
