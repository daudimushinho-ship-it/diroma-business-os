import { redirect } from "next/navigation";
import { requireWorkspace } from "@/lib/workspace";
import { LANDING } from "@/lib/roles";

export default async function Home() {
  const ws = await requireWorkspace();
  redirect(LANDING[ws.role]);
}
