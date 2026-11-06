import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { categories, db } from "@/lib/stock";
import { DesignForm } from "./DesignForm";

export default async function NewDesignPage({ searchParams }: { searchParams: Promise<{ err?: string }> }) {
  await requireWorkspace("products.manage");
  const { lang, s } = await getStockDict();
  const { err } = await searchParams;
  const { cats, sizes } = await categories();
  const { data: suppliers } = await (await db()).from("suppliers").select("id, name").eq("is_active", true).order("name");
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader title={s.newDesign} />
      <Flash err={err} />
      <DesignForm s={s} sizes={sizes} suppliers={suppliers ?? []}
        cats={cats.map((c) => ({ code: c.code, size_set: c.size_set, name: lang === "sw" ? c.name_sw : c.name_en }))} />
    </div>
  );
}
