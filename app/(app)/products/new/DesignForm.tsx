"use client";
import { useState } from "react";
import { createDesign } from "@/app/actions/stock";
import { SubmitButton } from "@/components/SubmitButton";
import type { StockDict } from "@/lib/i18n-stock";

type Cat = { code: string; name: string; size_set: string };

export function DesignForm({ s, cats, sizes, suppliers }: {
  s: StockDict; cats: Cat[]; sizes: { size_set: string; size: string }[]; suppliers: { id: string; name: string }[];
}) {
  const [cat, setCat] = useState(cats[0]?.code ?? "");
  const set = cats.find((c) => c.code === cat)?.size_set;
  const options = sizes.filter((z) => z.size_set === set).map((z) => z.size);
  return (
    <form action={createDesign} className="card space-y-4 p-5">
      <input type="hidden" name="back" value="/products/new" />
      <div className="grid gap-4 sm:grid-cols-2">
        <div><label className="label" htmlFor="code">{s.code}</label>
          <input id="code" name="code" required maxLength={60} className="input font-mono" placeholder="DR#2516-43" /></div>
        <div><label className="label" htmlFor="name">{s.name}</label>
          <input id="name" name="name" required maxLength={120} className="input" /></div>
        <div><label className="label" htmlFor="category">{s.category}</label>
          <select id="category" name="category" value={cat} onChange={(e) => setCat(e.target.value)} className="input">
            {cats.map((c) => <option key={c.code} value={c.code}>{c.name}</option>)}
          </select></div>
        <div><label className="label" htmlFor="supplier">{s.supplier} ({s.optional})</label>
          <select id="supplier" name="supplier" className="input" defaultValue="">
            <option value="">—</option>
            {suppliers.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
          </select></div>
      </div>
      <div><label className="label" htmlFor="colors">{s.colors}</label>
        <input id="colors" name="colors" required className="input" placeholder="Black, Navy" />
        <p className="mt-1 text-xs text-muted">{s.colorsHint}</p></div>
      <fieldset>
        <legend className="label">{s.sizes}</legend>
        <div className="flex flex-wrap gap-2">
          {options.map((z) => (
            <label key={`${set}-${z}`} className="flex min-w-14 cursor-pointer items-center justify-center gap-1.5 rounded-lg border border-line px-3 py-2 text-sm has-[:checked]:border-espresso has-[:checked]:bg-espresso has-[:checked]:text-ivory">
              <input type="checkbox" name="sizes" value={z} className="sr-only" defaultChecked={options.length === 1} />{z}
            </label>
          ))}
        </div>
      </fieldset>
      <div className="grid gap-4 sm:grid-cols-2">
        <div><label className="label" htmlFor="retail">{s.retail}</label>
          <input id="retail" name="retail" inputMode="numeric" className="input" placeholder="450000" /></div>
        <div><label className="label" htmlFor="wholesale">{s.wholesale}</label>
          <input id="wholesale" name="wholesale" inputMode="numeric" className="input" placeholder="380000" /></div>
      </div>
      <SubmitButton className="btn btn-primary">{s.create}</SubmitButton>
    </form>
  );
}
