import { PageHeader } from "@/components/PageHeader";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { categories } from "@/lib/stock";
import { ImportForm } from "./ImportForm";

export default async function ImportPage() {
  await requireWorkspace("products.manage");
  const { s } = await getStockDict();
  const { cats } = await categories();
  return (
    <div className="mx-auto max-w-5xl">
      <PageHeader title={s.importCsv} />
      <ImportForm s={s} categories={cats.map((c) => c.code)} />
    </div>
  );
}
