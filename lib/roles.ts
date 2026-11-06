export type AppRole = "owner" | "manager" | "sales_staff" | "storekeeper";

export type Workspace = {
  membership_id: string;
  business: { id: string; name: string; slogan: string | null; currency: string; timezone: string };
  display_name: string;
  role: AppRole;
  aal: "aal1" | "aal2";
  mfa_required: boolean;
  permissions: string[];
  locations: { id: string; code: string; name: string; kind: string }[];
};

/** Where each role lands after a verified sign-in. */
export const LANDING: Record<AppRole, string> = {
  owner: "/overview",
  manager: "/operations",
  sales_staff: "/pos",
  storekeeper: "/store",
};

export type NavKey =
  | "overview" | "operations" | "sell" | "products" | "store" | "shopStock" | "wholesale"
  | "purchasing" | "money" | "customers" | "sales" | "approvals" | "performance" | "reports" | "team" | "control" | "settings" | "help";

/** A permission requirement: one code, any of several codes, or none. */
export type Need = string | readonly string[] | null;

export type NavItem = { key: NavKey; href: string; permission: Need; icon: string };

export const MONEY_AREA = ["money.view", "money.transfer", "expenses.request", "expenses.approve", "expenses.pay", "shift.review", "deliveries.manage", "journal.view"] as const;
export const APPROVALS_AREA = ["approvals.decide", "returns.approve", "expenses.approve", "shift.review"] as const;

export const NAV: NavItem[] = [
  { key: "overview",   href: "/overview",   permission: "overview.business",   icon: "grid" },
  { key: "operations", href: "/operations", permission: "overview.operations", icon: "grid" },
  { key: "sell",       href: "/pos",        permission: "pos.sell",            icon: "cart" },
  { key: "sales",      href: "/sales",      permission: "sales.view",          icon: "receipt" },
  { key: "products",   href: "/products",   permission: "products.view",       icon: "tag" },
  { key: "store",      href: "/store",      permission: "store.operate",       icon: "box" },
  { key: "shopStock",  href: "/shop-stock", permission: "shop_stock.view",     icon: "shop" },
  { key: "wholesale",  href: "/wholesale",  permission: "wholesale.manage",    icon: "truck" },
  { key: "purchasing", href: "/purchasing", permission: "purchasing.manage",   icon: "receipt" },
  { key: "approvals",  href: "/approvals",  permission: [...APPROVALS_AREA, "pos.sell"], icon: "check" },
  { key: "money",      href: "/money",      permission: MONEY_AREA,            icon: "wallet" },
  { key: "customers",  href: "/customers",  permission: "customers.view",      icon: "users" },
  { key: "performance", href: "/performance", permission: "team.work",          icon: "chart" },
  { key: "reports",    href: "/reports",    permission: "reports.view",        icon: "chart" },
  { key: "team",       href: "/team",       permission: "team.view",           icon: "team" },
  { key: "control",    href: "/control",    permission: "audit.view",          icon: "shield" },
  { key: "settings",   href: "/settings",   permission: "settings.manage",     icon: "cog" },
  { key: "help",       href: "/help",       permission: null,                  icon: "help" },
];

export function can(ws: Pick<Workspace, "permissions">, permission: Need): boolean {
  if (permission === null) return true;
  if (typeof permission === "string") return ws.permissions.includes(permission);
  return permission.some((p) => ws.permissions.includes(p));
}

/** Navigation is a convenience filter only; the database enforces every permission independently. */
export function navFor(ws: Pick<Workspace, "permissions">): NavItem[] {
  return NAV.filter((n) => can(ws, n.permission));
}

export function needsMfa(ws: Pick<Workspace, "mfa_required" | "aal">): boolean {
  return ws.mfa_required && ws.aal !== "aal2";
}
