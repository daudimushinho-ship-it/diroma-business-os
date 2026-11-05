import { describe, expect, it } from "vitest";
import { LANDING, navFor, needsMfa } from "@/lib/roles";

const perms = {
  owner: ["overview.business", "pos.sell", "store.operate", "team.view", "team.manage", "audit.view", "settings.manage", "money.view", "costs.view"],
  sales_staff: ["pos.sell", "sales.view", "shop_stock.view", "products.view", "customers.view"],
  storekeeper: ["store.operate", "shop_stock.view", "products.view"],
};

describe("role routing", () => {
  it("lands each role in its workspace", () => {
    expect(LANDING).toEqual({ owner: "/overview", manager: "/operations", sales_staff: "/pos", storekeeper: "/store" });
  });
  it("sales staff never see team, control, settings or money", () => {
    const keys = navFor({ permissions: perms.sales_staff }).map((n) => n.key);
    expect(keys).toEqual(expect.arrayContaining(["sell", "shopStock", "products", "customers", "help"]));
    for (const k of ["team", "control", "settings", "money", "overview", "store"]) expect(keys).not.toContain(k);
  });
  it("storekeeper sees Store but not POS", () => {
    const keys = navFor({ permissions: perms.storekeeper }).map((n) => n.key);
    expect(keys).toContain("store");
    expect(keys).not.toContain("sell");
  });
  it("privileged roles need MFA (aal2); staff do not", () => {
    expect(needsMfa({ mfa_required: true, aal: "aal1" })).toBe(true);
    expect(needsMfa({ mfa_required: true, aal: "aal2" })).toBe(false);
    expect(needsMfa({ mfa_required: false, aal: "aal1" })).toBe(false);
  });
});
