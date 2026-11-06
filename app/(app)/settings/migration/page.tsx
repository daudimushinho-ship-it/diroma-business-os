import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { getLang } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { businessToday } from "@/lib/format";
import { MigrationForm } from "./MigrationForm";

export default async function MigrationPage() {
  const ws = await requireWorkspace("settings.manage");
  const sw = (await getLang()) === "sw";
  const shops = ws.locations.filter((l) => l.kind === "shop");
  return (
    <div className="mx-auto max-w-5xl space-y-5">
      <PageHeader title={sw ? "Kuhamisha data kutoka MauzoTrack" : "Migrate data from MauzoTrack"}
        subtitle={sw ? "Hatua: 1) Bidhaa (Bidhaa → Import CSV)  2) Wateja na madeni  3) Stoki ya mwanzo  4) Salio za pesa (Fedha → Akaunti)" : "Steps: 1) Products (Products → Import CSV)  2) Customers & debts  3) Opening stock  4) Money opening balances (Money → Accounts)"} />
      <p className="text-sm"><Link href="/products/import" className="text-gold-ink underline">{sw ? "1. Import bidhaa →" : "1. Import products →"}</Link></p>
      <MigrationForm kind="customers" shops={shops} today={businessToday()} labels={{
        title: sw ? "2. Wateja na madeni ya mwanzo" : "2. Customers and opening debts",
        intro: sw ? "Madeni ya mwanzo yanaingia kama 'invoice ya salio la mwanzo' — si mauzo mapya. Yanalipwa kwanza (FIFO)." : "Opening debts are posted as opening-balance invoices — not new sales. They are collected first (FIFO).",
        preview: sw ? "Kagua kwanza" : "Preview", commit: sw ? "Ingiza sasa" : "Import now", template: sw ? "Pakua template" : "Download template" }} />
      <MigrationForm kind="stock" shops={shops} today={businessToday()} labels={{
        title: sw ? "3. Stoki ya mwanzo" : "3. Opening stock",
        intro: sw ? "Kila eneo linapata hati yake ya stoki ya mwanzo. Faili lenye kosa moja linakataliwa lote." : "Each location gets its own opening stock document. A file with any error is rejected entirely.",
        preview: sw ? "Kagua kwanza" : "Preview", commit: sw ? "Ingiza sasa" : "Import now", template: sw ? "Pakua template" : "Download template" }} />
    </div>
  );
}
