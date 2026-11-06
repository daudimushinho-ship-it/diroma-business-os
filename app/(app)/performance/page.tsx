import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { getLang } from "@/lib/lang";
import { TEAM_DICTS } from "@/lib/i18n-team";
import { requireWorkspace } from "@/lib/workspace";
import { can, type Workspace } from "@/lib/roles";
import { db, listDesigns } from "@/lib/stock";
import { moneyAccounts } from "@/lib/sales";
import { addDays, businessToday, tzs } from "@/lib/format";
import {
  calculateCommissions, completeTask, createInquiry, createTask, decideCommission, inquiryEvent, linkInquirySale, logContent,
  reviewTask, saveCommissionPlan, setTarget, verifyContent,
} from "@/app/actions/team-work";

type SP = { tab?: string; ok?: string; err?: string };
type Progress = { metric: string; target: number | null; source: string; actual: number; verified: number | null; pct: number | null; period: { from: string; to: string } };

export default async function PerformancePage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("team.work");
  const lang = await getLang();
  const t = TEAM_DICTS[lang];
  const sp = await searchParams;
  const supabase = await db();
  const lead = can(ws, "tasks.assign");
  const tabs = [
    { key: "targets", label: t.targets }, { key: "content", label: t.content }, { key: "tasks", label: t.tasks }, { key: "inquiries", label: t.inquiries },
    ...(can(ws, "reports.view") ? [{ key: "funnel", label: t.funnel }] : []),
    { key: "commissions", label: t.commissions },
  ];
  const tab = tabs.some((x) => x.key === sp.tab) ? sp.tab! : "targets";
  const back = `/performance?tab=${tab}`;
  const today = businessToday();
  const { data: members } = await supabase.from("memberships").select("id, display_name, role, status").eq("status", "active").order("display_name");
  const staff = (members ?? []).length ? members! : [{ id: ws.membership_id, display_name: ws.display_name, role: ws.role, status: "active" }];
  const who = new Map(staff.map((m) => [m.id, m.display_name]));
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });

  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={t.title} subtitle={ws.display_name} />
      <Tabs active={tab} items={tabs.map((x) => ({ ...x, href: `/performance?tab=${x.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />
      {tab === "targets" && <Targets />}
      {tab === "content" && <Content />}
      {tab === "tasks" && <TasksTab />}
      {tab === "inquiries" && <Inquiries />}
      {tab === "funnel" && <Funnel />}
      {tab === "commissions" && <Commissions />}
    </div>
  );

  async function progress(metric: string, kind: string, scope: string, member: string | null) {
    const { data } = await supabase.rpc("target_progress", { p_metric: metric, p_kind: kind, p_date: today, p_scope: scope, p_location: null, p_member: member });
    return data as Progress | null;
  }

  function Bar({ p, money }: { p: Progress; money?: boolean }) {
    const pct = Math.min(100, p.pct ?? 0);
    const v = (n: number | null) => (n === null ? "—" : money ? tzs(n) : String(n));
    return (
      <div className="card p-4 text-sm">
        <div className="flex justify-between"><span className="font-semibold">{t.metric[p.metric]}</span><span className="text-xs text-muted">{t.source[p.source]}</span></div>
        <p className="mt-1 text-lg font-semibold tabular-nums">{v(p.actual)} <span className="text-sm font-normal text-muted">/ {v(p.target)}</span></p>
        {p.target ? <div className="mt-2 h-2 rounded-full bg-ivory" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
          <div className="h-2 rounded-full bg-champagne" style={{ width: `${pct}%` }} /></div> : null}
        <p className="mt-1 text-xs text-muted">{p.period.from} → {p.period.to}{p.verified !== null ? ` · ${t.verified}: ${p.verified}` : ""}{p.pct !== null ? ` · ${p.pct}%` : ""}</p>
      </div>
    );
  }

  async function Targets() {
    const content = await Promise.all([["reels", "day"], ["reels", "week"], ["reels", "month"], ["product_posts", "month"]]
      .map(([m, k]) => progress(m, k, "business", null)));
    const people = lead || can(ws, "reports.view") ? staff.filter((m) => m.role === "sales_staff" || m.role === "manager") : [{ id: ws.membership_id, display_name: ws.display_name }];
    const personal = await Promise.all(people.map(async (m) => ({ m, sales: await progress("net_sales", "month", "member", m.id), fu: await progress("follow_ups", "month", "member", m.id) })));
    return (
      <div className="space-y-5">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{content.filter(Boolean).map((p, i) => <Bar key={i} p={p!} />)}</div>
        <p className="text-xs text-muted">{t.noSalesTarget}</p>
        <div className="grid gap-3 sm:grid-cols-2">
          {personal.map(({ m, sales, fu }) => (
            <div key={m.id} className="space-y-2"><p className="text-sm font-semibold">{m.display_name}</p>
              {sales && <Bar p={sales} money />}{fu && <Bar p={fu} />}</div>
          ))}
        </div>
        {can(ws, "targets.manage") && (
          <form action={setTarget} className="card flex flex-wrap items-end gap-2 p-4">
            <input type="hidden" name="back" value={back} />
            <label><span className="label">{t.metric.net_sales.split(" ")[0]}…</span>
              <select name="metric" className="input">{Object.entries(t.metric).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
            <label><span className="label">{t.scope}</span>
              <select name="scope" className="input"><option value="business">{t.business}</option><option value="member">{t.member}</option></select></label>
            <label><span className="label">{t.member}</span>
              <select name="member" className="input"><option value="">—</option>{staff.map((m) => <option key={m.id} value={m.id}>{m.display_name}</option>)}</select></label>
            <label><span className="label">{t.period.month}</span>
              <select name="kind" className="input"><option value="month">{t.period.month}</option><option value="week">{t.period.week}</option><option value="day">{t.period.day}</option></select></label>
            <input type="hidden" name="date" value={today} />
            <label><span className="label">{t.value}</span><input name="value" inputMode="numeric" required className="input w-36" /></label>
            <label className="min-w-40 flex-1"><span className="label">{t.note}</span><input name="note" className="input" /></label>
            <button className="btn btn-primary">{t.setTarget}</button>
          </form>
        )}
      </div>
    );
  }

  async function Content() {
    const [{ data: posts }, designs] = await Promise.all([
      supabase.from("content_posts").select("id, kind, platform, url, posted_on, posted_by, status, verify_note").order("posted_on", { ascending: false }).limit(100),
      listDesigns(),
    ]);
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <ul className="card divide-y divide-line text-sm">
          {(posts ?? []).map((p) => (
            <li key={p.id} className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5">
              <span className="min-w-0"><strong>{t[p.kind as "reel"]}</strong> · {p.platform} · {p.posted_on} · {t.by} {who.get(p.posted_by) ?? "—"}
                <a href={p.url} target="_blank" rel="noopener noreferrer" className="ml-2 break-all text-gold-ink underline">{p.url.replace(/^https:\/\//, "").slice(0, 40)}</a></span>
              <span className="flex items-center gap-2">
                <span className={`badge ${p.status === "verified" ? "bg-[#e7f4ec] text-ok" : p.status === "rejected" ? "bg-[#fdf1ef] text-bad" : "bg-ivory"}`}>{p.status}</span>
                {p.status === "logged" && can(ws, "content.verify") && p.posted_by !== ws.membership_id && (
                  <form action={verifyContent} className="flex gap-1"><input type="hidden" name="post" value={p.id} /><input type="hidden" name="back" value={back} />
                    <input name="note" placeholder={t.reason} className="input h-8 min-h-0 w-28 py-0 text-xs" />
                    <button name="decision" value="verify" className="btn btn-ghost h-8 min-h-0 py-0 text-xs">{t.verify}</button>
                    <button name="decision" value="reject" className="btn btn-danger h-8 min-h-0 py-0 text-xs">{t.reject}</button></form>
                )}
              </span>
            </li>
          ))}
        </ul>
        <form action={logContent} className="card h-fit space-y-2 p-4">
          <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{t.logContent}</h2>
          <p className="text-xs text-muted">{t.contentNote}</p>
          <select name="kind" className="input"><option value="reel">{t.reel}</option><option value="product_post">{t.product_post}</option><option value="story">{t.story}</option></select>
          <select name="platform" className="input">{["instagram", "tiktok", "facebook", "whatsapp", "youtube", "other"].map((x) => <option key={x}>{x}</option>)}</select>
          <input name="url" type="url" required pattern="https://.+" placeholder={t.url} className="input" />
          <select name="design" className="input" defaultValue=""><option value="">{t.design}</option>{designs.map((d) => <option key={d.design_id} value={d.design_id}>{d.code} · {d.name}</option>)}</select>
          <input name="posted_on" type="date" required defaultValue={today} max={today} min={addDays(today, -31)} className="input" />
          <input name="note" placeholder={t.note} className="input" />
          <button className="btn btn-primary w-full">{t.save}</button>
        </form>
      </div>
    );
  }

  async function TasksTab() {
    const { data: tasks } = await supabase.from("team_tasks").select("id, title, details, assignee, due_at, priority, status, evidence, review_note").order("due_at").limit(200);
    const now = Date.now();
    const mine = (tasks ?? []).filter((x) => x.assignee === ws.membership_id && x.status === "open");
    const review = lead ? (tasks ?? []).filter((x) => x.status === "done" && x.assignee !== ws.membership_id) : [];
    const others = lead ? (tasks ?? []).filter((x) => x.status === "open" && x.assignee !== ws.membership_id) : [];
    const Row = ({ x, children }: { x: NonNullable<typeof tasks>[number]; children?: React.ReactNode }) => (
      <li className="space-y-1 px-4 py-3 text-sm">
        <p><strong>{x.title}</strong> · {who.get(x.assignee)} · {fmt.format(new Date(x.due_at))}
          {x.status === "open" && new Date(x.due_at).getTime() < now && <span className="ml-1 badge bg-[#fdf1ef] text-bad">{t.overdue}</span>}
          {x.priority === "high" && <span className="ml-1 badge bg-[#fff4de] text-warn">!</span>}</p>
        {x.details && <p className="text-muted">{x.details}</p>}{x.evidence && <p className="text-xs">✓ {x.evidence}</p>}{x.review_note && <p className="text-xs text-warn">{x.review_note}</p>}
        {children}
      </li>
    );
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="space-y-4">
          <section><h2 className="mb-2 font-semibold">{t.myTasks}</h2><ul className="card divide-y divide-line">
            {mine.map((x) => <Row key={x.id} x={x}><form action={completeTask} className="flex gap-2"><input type="hidden" name="task" value={x.id} /><input type="hidden" name="back" value={back} />
              <input name="evidence" required placeholder={t.evidence} className="input flex-1" /><button className="btn btn-primary">{t.complete}</button></form></Row>)}
            {mine.length === 0 && <li className="px-4 py-3 text-sm text-muted">—</li>}</ul></section>
          {review.length > 0 && <section><h2 className="mb-2 font-semibold">{t.review}</h2><ul className="card divide-y divide-line">
            {review.map((x) => <Row key={x.id} x={x}><form action={reviewTask} className="flex flex-wrap gap-2"><input type="hidden" name="task" value={x.id} /><input type="hidden" name="back" value={back} />
              <input name="note" placeholder={t.note} className="input min-w-40 flex-1" />
              <button name="decision" value="verify" className="btn btn-primary">{t.verify}</button><button name="decision" value="reopen" className="btn btn-ghost">{t.reopen}</button></form></Row>)}</ul></section>}
          {others.length > 0 && <section><h2 className="mb-2 font-semibold">{t.tasks}</h2><ul className="card divide-y divide-line">
            {others.map((x) => <Row key={x.id} x={x}><form action={reviewTask} className="flex gap-2"><input type="hidden" name="task" value={x.id} /><input type="hidden" name="back" value={back} />
              <input name="note" placeholder={t.reason} className="input flex-1" /><button name="decision" value="cancel" className="btn btn-danger">{t.cancel}</button></form></Row>)}</ul></section>}
        </div>
        {lead && (
          <form action={createTask} className="card h-fit space-y-2 p-4">
            <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{t.newTask}</h2>
            <input name="title" required placeholder={t.taskTitle} className="input" />
            <input name="details" placeholder={t.details} className="input" />
            <select name="assignee" required className="input">{staff.map((m) => <option key={m.id} value={m.id}>{m.display_name}</option>)}</select>
            <label className="block"><span className="label">{t.due}</span><input name="due" type="datetime-local" required className="input" /></label>
            <select name="priority" className="input"><option value="normal">normal</option><option value="high">high</option><option value="low">low</option></select>
            <button className="btn btn-primary w-full">{t.newTask}</button>
          </form>
        )}
      </div>
    );
  }

  async function Inquiries() {
    const [{ data: inq }, { data: customers }, designs] = await Promise.all([
      supabase.from("inquiries").select("id, ref_no, name, phone_e164, channel, interest, status, assigned_to, next_follow_up_on, linked_sale_id, lost_reason, customer_id").order("created_at", { ascending: false }).limit(100),
      can(ws, "customers.view") ? supabase.from("customers").select("id, name").order("name").limit(2000) : Promise.resolve({ data: [] as { id: string; name: string }[] }),
      listDesigns(),
    ]);
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <ul className="space-y-3">
          {(inq ?? []).map((q) => {
            const open = q.status !== "won" && q.status !== "lost";
            const due = open && q.next_follow_up_on && q.next_follow_up_on <= today;
            return (
              <li key={q.id} className="card space-y-2 p-4 text-sm">
                <p><strong>{q.name}</strong> {q.phone_e164 && <span className="text-muted">{q.phone_e164}</span>} · {t.channels[q.channel]} · <span className="badge border border-line bg-ivory">{q.status}</span>
                  {due && <span className="ml-1 badge bg-[#fff4de] text-warn">{t.nextFollowUp}: {q.next_follow_up_on}</span>}</p>
                {q.interest && <p className="text-muted">{q.interest}</p>}
                {q.lost_reason && <p className="text-xs text-bad">{q.lost_reason}</p>}
                {open && (
                  <>
                    <form action={inquiryEvent} className="flex flex-wrap gap-2"><input type="hidden" name="inquiry" value={q.id} /><input type="hidden" name="back" value={back} />
                      <input name="note" placeholder={t.note} className="input min-w-40 flex-1" /><input name="next" type="date" min={today} className="input w-40" aria-label={t.nextFollowUp} />
                      <button name="kind" value="follow_up" className="btn btn-ghost">{t.followUp}</button><button name="kind" value="visit" className="btn btn-ghost">{t.visit}</button>
                      <button name="kind" value="lost" className="btn btn-danger">{t.lost}</button></form>
                    <form action={linkInquirySale} className="flex flex-wrap gap-2"><input type="hidden" name="inquiry" value={q.id} /><input type="hidden" name="back" value={back} />
                      <input name="ref" required placeholder={t.saleRef} className="input w-40 font-mono uppercase" />
                      {!q.customer_id && <input name="note" placeholder={t.reason} className="input min-w-40 flex-1" />}
                      <button className="btn btn-primary">{t.linkSale}</button></form>
                    <p className="text-xs text-muted">{t.linkNote}</p>
                  </>
                )}
              </li>
            );
          })}
        </ul>
        <form action={createInquiry} className="card h-fit space-y-2 p-4">
          <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{t.newInquiry}</h2>
          <input name="name" required placeholder={t.name} className="input" />
          <input name="phone" type="tel" placeholder={t.phone} className="input" />
          <select name="customer" className="input" defaultValue=""><option value="">—</option>{(customers ?? []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
          <select name="channel" className="input">{Object.entries(t.channels).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
          <input name="interest" placeholder={t.interest} className="input" />
          <select name="design" className="input" defaultValue=""><option value="">{t.design}</option>{designs.map((d) => <option key={d.design_id} value={d.design_id}>{d.code} · {d.name}</option>)}</select>
          {lead && <select name="assigned_to" className="input" defaultValue={ws.membership_id}>{staff.map((m) => <option key={m.id} value={m.id}>{m.display_name}</option>)}</select>}
          <label className="block"><span className="label">{t.nextFollowUp}</span><input name="next" type="date" min={today} className="input" /></label>
          <button className="btn btn-primary w-full">{t.save}</button>
        </form>
      </div>
    );
  }

  async function Funnel() {
    const { data } = await supabase.rpc("inquiry_funnel", { p_from: addDays(today, -29), p_to: today });
    const rows = (data ?? []) as { channel: string; inquiries: number; followed_up: number; visited: number; won_linked: number; lost: number; linked_sales_value: number }[];
    return (
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">{t.channel}</th><th className="px-4 py-2 text-right font-medium">{t.inquiries}</th>
            <th className="px-4 py-2 text-right font-medium">{t.followUp}</th><th className="px-4 py-2 text-right font-medium">{t.visit}</th><th className="px-4 py-2 text-right font-medium">{t.linkSale}</th>
            <th className="px-4 py-2 text-right font-medium">{t.lost}</th><th className="px-4 py-2 text-right font-medium">TZS</th></tr></thead>
          <tbody className="divide-y divide-line tabular-nums">
            {rows.map((r) => <tr key={r.channel}><td className="px-4 py-2">{t.channels[r.channel]}</td><td className="px-4 py-2 text-right">{r.inquiries}</td><td className="px-4 py-2 text-right">{r.followed_up}</td>
              <td className="px-4 py-2 text-right">{r.visited}</td><td className="px-4 py-2 text-right">{r.won_linked}</td><td className="px-4 py-2 text-right">{r.lost}</td><td className="px-4 py-2 text-right">{tzs(Number(r.linked_sales_value))}</td></tr>)}
          </tbody>
        </table>
        <p className="px-4 py-2 text-xs text-muted">{addDays(today, -29)} → {today} · {t.linkNote}</p>
      </div>
    );
  }

  async function Commissions() {
    const staffView = !can(ws, "commissions.calculate") && !can(ws, "commissions.approve");
    const [{ data: runs }, { data: lines }, { data: plans }] = await Promise.all([
      supabase.from("commission_runs").select("id, ref_no, period_from, period_to, status, total, calculated_by, approved_by").order("calculated_at", { ascending: false }).limit(20),
      supabase.from("commission_lines").select("id, run_id, membership_id, basis, basis_amount, returns_deducted, net_basis, rate_pct, open_tasks, eligible, amount, note"),
      staffView ? Promise.resolve({ data: [] }) : supabase.from("commission_plans").select("id, name, applies_role, membership_id, basis, rate_pct, min_basis, require_tasks_done, is_active").order("created_at"),
    ]);
    const banks = (await moneyAccounts()).filter((a) => a.kind !== "cash");
    return (
      <div className="space-y-5">
        <p className="text-xs text-muted">{t.commissionNote}</p>
        {!staffView && (
          <div className="grid gap-4 lg:grid-cols-2">
            <section className="card p-4 text-sm"><h2 className="mb-2 font-semibold">{t.plans}</h2>
              {((plans ?? []) as { id: string; name: string; applies_role: string | null; membership_id: string | null; basis: string; rate_pct: number; min_basis: number; require_tasks_done: boolean; is_active: boolean }[]).map((p) => (
                <p key={p.id} className="border-t border-line py-1.5 first:border-0">{p.name} · {p.membership_id ? who.get(p.membership_id) : p.applies_role} · {p.basis} · <strong>{p.rate_pct}%</strong>
                  {p.min_basis > 0 && ` · ≥ ${tzs(p.min_basis)}`}{p.require_tasks_done && " · ✓ tasks"}{!p.is_active && " · (off)"}</p>))}
              {can(ws, "commissions.approve") && (
                <form action={saveCommissionPlan} className="mt-3 grid gap-2 border-t border-line pt-3 sm:grid-cols-2">
                  <input type="hidden" name="back" value={back} />
                  <input name="name" required placeholder={t.newPlan} className="input sm:col-span-2" />
                  <select name="role" className="input"><option value="sales_staff">sales_staff</option><option value="manager">manager</option></select>
                  <select name="member" className="input" defaultValue=""><option value="">{t.role}</option>{staff.map((m) => <option key={m.id} value={m.id}>{m.display_name}</option>)}</select>
                  <select name="basis" className="input"><option value="net_sales">{t.metric.net_sales}</option><option value="collections">{t.metric.collections}</option></select>
                  <input name="rate" required inputMode="decimal" placeholder={t.rate} className="input" />
                  <input name="min" inputMode="numeric" placeholder={t.minBasis} className="input" />
                  <label className="flex items-center gap-2"><input type="checkbox" name="require_tasks" /> {t.requireTasks}</label>
                  <button className="btn btn-primary sm:col-span-2">{t.save}</button>
                </form>
              )}
            </section>
            {can(ws, "commissions.calculate") && (
              <form action={calculateCommissions} className="card h-fit space-y-2 p-4 text-sm">
                <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{t.calculate}</h2>
                <div className="flex gap-2"><input type="date" name="from" required defaultValue={today.slice(0, 8) + "01"} className="input" aria-label={t.from} />
                  <input type="date" name="to" required defaultValue={today} max={today} className="input" aria-label={t.to} /></div>
                <button className="btn btn-primary w-full">{t.calculate}</button>
              </form>
            )}
          </div>
        )}
        {(runs ?? []).map((r) => {
          const ls = (lines ?? []).filter((l) => l.run_id === r.id);
          return (
            <section key={r.id} className="card p-4 text-sm">
              <p className="font-semibold">{r.ref_no} · {r.period_from} → {r.period_to} · <span className="badge border border-line bg-ivory">{r.status}</span> · {tzs(r.total)}</p>
              <table className="mt-2 w-full">
                <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{t.member}</th><th className="py-1 text-right font-medium">{t.basis}</th>
                  <th className="py-1 text-right font-medium">{t.returnsDeducted}</th><th className="py-1 text-right font-medium">%</th><th className="py-1 text-right font-medium">{t.amount}</th><th /></tr></thead>
                <tbody className="tabular-nums">{ls.map((l) => <tr key={l.id} className="border-t border-line"><td className="py-1">{who.get(l.membership_id) ?? "—"}</td>
                  <td className="py-1 text-right">{tzs(l.basis_amount)}</td><td className="py-1 text-right">{tzs(l.returns_deducted)}</td><td className="py-1 text-right">{l.rate_pct}</td>
                  <td className="py-1 text-right font-semibold">{tzs(l.amount)}</td><td className="py-1 pl-2 text-xs text-warn">{l.note}</td></tr>)}</tbody>
              </table>
              {can(ws, "commissions.approve") && (r.status === "calculated" || r.status === "approved") && (
                <form action={decideCommission} className="mt-3 flex flex-wrap gap-2"><input type="hidden" name="run" value={r.id} /><input type="hidden" name="back" value={back} />
                  <input name="note" placeholder={t.note} className="input min-w-40 flex-1" />
                  {r.status === "calculated" && <button name="action" value="approve" className="btn btn-primary">{t.approve}</button>}
                  {r.status === "approved" && <><select name="account" className="input w-auto">{banks.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
                    <button name="action" value="pay" className="btn btn-primary">{t.pay}</button></>}
                  <button name="action" value="cancel" className="btn btn-danger">{t.cancel}</button>
                </form>
              )}
            </section>
          );
        })}
      </div>
    );
  }
}
