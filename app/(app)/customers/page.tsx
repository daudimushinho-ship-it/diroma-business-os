import { PlannedModule } from "@/components/PlannedModule";
import { getDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { plannedScope } from "@/lib/modules";

export default async function Page() {
  const { lang, t } = await getDict();
  const s = plannedScope("customers", lang);
  await requireWorkspace(s.permission);
  return <PlannedModule t={t} title={t.nav.customers} milestone={s.milestone} scope={s.scope} />;
}
