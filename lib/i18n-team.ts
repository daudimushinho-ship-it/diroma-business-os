import type { Lang } from "./i18n";

const sw = {
  title: "Utendaji wa timu", targets: "Malengo", content: "Maudhui (reels/posts)", tasks: "Kazi", inquiries: "Wateja watarajiwa", funnel: "Wanatoka wapi", commissions: "Commission",
  metric: { net_sales: "Mauzo halisi", units: "Vipande", collections: "Makusanyo", reels: "Reels", product_posts: "Posts za bidhaa", follow_ups: "Ufuatiliaji", new_customers: "Wateja wapya" } as Record<string, string>,
  period: { day: "Leo", week: "Wiki hii", month: "Mwezi huu" } as Record<string, string>,
  target: "Lengo", actual: "Halisi", verified: "Zimethibitishwa", source: { owner: "Imewekwa na Owner", default: "Lengo la msingi", none: "Hakuna lengo" } as Record<string, string>,
  setTarget: "Weka lengo", scope: "Kwa", business: "Biashara nzima", member: "Mfanyakazi", value: "Kiasi / idadi", note: "Maelezo", save: "Hifadhi",
  noSalesTarget: "Malengo ya mauzo hayabuniwi — Owner akiyaweka tu ndipo yanaonekana.",
  logContent: "Rekodi post", kind: "Aina", platform: "Jukwaa", url: "Kiungo (https://…)", design: "Design (hiari)", postedOn: "Tarehe ya post",
  reel: "Reel", product_post: "Post ya bidhaa", story: "Story", verify: "Thibitisha", reject: "Kataa", status: "Hali", by: "Na",
  contentNote: "Post inahesabiwa ikiwa na kiungo. Mtu mwingine anathibitisha.",
  newTask: "Kazi mpya", taskTitle: "Kazi", details: "Maelezo", assignee: "Mhusika", due: "Mwisho", priority: "Kipaumbele", complete: "Nimemaliza",
  evidence: "Ushahidi (kilichofanyika, kiungo)", reopen: "Rudisha", cancel: "Sitisha", overdue: "Imechelewa", myTasks: "Kazi zangu", review: "Zinasubiri ukaguzi",
  newInquiry: "Mteja mtarajiwa mpya", name: "Jina", phone: "Simu", channel: "Ametoka wapi", interest: "Anataka nini", nextFollowUp: "Ufuatiliaji unaofuata",
  followUp: "Nimefuatilia", visit: "Amefika dukani", lost: "Ameacha", linkSale: "Unganisha na mauzo", saleRef: "Namba ya risiti (RCP-…)",
  linkNote: "Unganisha tu ukiwa na uhakika — mfumo haukisii.", reason: "Sababu",
  plans: "Mipango ya commission", newPlan: "Mpango mpya", role: "Nafasi", rate: "Asilimia %", basis: "Msingi", minBasis: "Kiwango cha chini",
  requireTasks: "Lazima kazi zote zikamilike", calculate: "Hesabu commission", from: "Kuanzia", to: "Hadi", approve: "Idhinisha", pay: "Lipa", account: "Akaunti",
  myCommission: "Commission yangu", amount: "Kiasi", eligible: "Anastahili", returnsDeducted: "Marejesho yamekatwa",
  commissionNote: "Viwango huwekwa na Owner tu. Commission inahesabiwa → inaidhinishwa na mtu mwingine → inalipwa mara moja. Hakuna makato ya kisheria yanayobuniwa.",
  channels: { instagram: "Instagram", whatsapp: "WhatsApp", tiktok: "TikTok", facebook: "Facebook", walk_in: "Amepita dukani", phone: "Simu", referral: "Ameletwa na mtu", other: "Nyingine" } as Record<string, string>,
};
type TeamDict = typeof sw;
const en: TeamDict = {
  title: "Team performance", targets: "Targets", content: "Content (reels/posts)", tasks: "Tasks", inquiries: "Inquiries", funnel: "Where customers come from", commissions: "Commissions",
  metric: { net_sales: "Net sales", units: "Units", collections: "Collections", reels: "Reels", product_posts: "Product posts", follow_ups: "Follow-ups", new_customers: "New customers" },
  period: { day: "Today", week: "This week", month: "This month" },
  target: "Target", actual: "Actual", verified: "Verified", source: { owner: "Set by Owner", default: "Default target", none: "No target" },
  setTarget: "Set target", scope: "For", business: "Whole business", member: "Staff member", value: "Amount / count", note: "Note", save: "Save",
  noSalesTarget: "Sales targets are never invented — they appear only when the Owner sets them.",
  logContent: "Log a post", kind: "Type", platform: "Platform", url: "Link (https://…)", design: "Design (optional)", postedOn: "Posted on",
  reel: "Reel", product_post: "Product post", story: "Story", verify: "Verify", reject: "Reject", status: "Status", by: "By",
  contentNote: "A post counts only with a link. Someone else verifies it.",
  newTask: "New task", taskTitle: "Task", details: "Details", assignee: "Assignee", due: "Due", priority: "Priority", complete: "Mark done",
  evidence: "Evidence (what was done, link)", reopen: "Reopen", cancel: "Cancel", overdue: "Overdue", myTasks: "My tasks", review: "Awaiting review",
  newInquiry: "New inquiry", name: "Name", phone: "Phone", channel: "Came from", interest: "Interested in", nextFollowUp: "Next follow-up",
  followUp: "Followed up", visit: "Visited the shop", lost: "Lost", linkSale: "Link to sale", saleRef: "Receipt no. (RCP-…)",
  linkNote: "Link only when you are sure — the system never guesses.", reason: "Reason",
  plans: "Commission plans", newPlan: "New plan", role: "Role", rate: "Rate %", basis: "Basis", minBasis: "Minimum",
  requireTasks: "All tasks must be completed", calculate: "Calculate commissions", from: "From", to: "To", approve: "Approve", pay: "Pay", account: "Account",
  myCommission: "My commission", amount: "Amount", eligible: "Eligible", returnsDeducted: "Returns deducted",
  commissionNote: "Rates are set by the Owner only. Commissions are calculated → approved by someone else → paid once. No statutory deductions are invented.",
  channels: { instagram: "Instagram", whatsapp: "WhatsApp", tiktok: "TikTok", facebook: "Facebook", walk_in: "Walk-in", phone: "Phone", referral: "Referral", other: "Other" },
};
export const TEAM_DICTS: Record<Lang, TeamDict> = { sw, en };
export type { TeamDict };
