# PROMPT: Build "Diroma Business OS"

> Copy everything below this line into your AI builder (Claude Code, Lovable, Bolt, v0, etc.).
> It is written in English because builders follow English most precisely. The app UI itself must be **Swahili-first**.

---

## Role
You are a senior full-stack engineer and product designer. Build **Diroma Business OS**, a multi-branch retail + wholesale management system for **DIROMA**, a Tanzanian fashion & accessories business (shirts, ties, bowties, watches, branded "DIROMA" product lines). It replaces MauzoTrack. Keep what MauzoTrack does well, fix its weaknesses, and add a professional **Wholesale** layer.

## Business context
- Currency: **TZS** (no decimals, thousands separator: `TZS 9,655,000`). Purchases may be in **USD or CNY** with an exchange rate.
- Payments: **Cash, M-Pesa, Lipa Namba (M-Pesa/Tigo/Airtel), Bank, Credit (mkopo)**. Split payments are common.
- Branches: `juliad` (Retail shop), `DIROMA WHOLESALE` (Wholesale shop). More branches and a **Warehouse** type later.
- ~230 customers (retail + wholesale), ~95 products with variants, 7+ staff.
- Language: **Swahili default**, English toggle. All labels go through i18n.
- Users mostly on **Android phones and cheap laptops** with unreliable internet → mobile-first, fast, **offline-capable POS (PWA)** that syncs when online.

## Tech stack (use unless I say otherwise)
- Next.js (App Router) + TypeScript + Tailwind + shadcn/ui
- Supabase (Postgres, Auth, Row-Level Security, Storage for receipt/product images)
- PWA with IndexedDB queue for offline sales
- Charts: Recharts. PDFs: react-pdf. Exports: CSV/XLSX.
- Money stored as integer TZS (bigint). All writes that touch stock or money go through **Postgres functions/transactions** — never trust the client for totals.

## Design language
- Dark green sidebar (`#0F2A1F`-ish), gold accent (DIROMA brand), clean white cards, rounded-2xl, generous spacing. Light + dark mode.
- Sidebar groups: **Nyumbani · Mauzo (POS) · Jumla (Wholesale) · Stock · Manunuzi · Fedha · Ripoti · Usimamizi**.
- Global top bar: branch switcher (All / Retail / Wholesale / each shop), date range, notifications, language, theme.
- No blocking tutorial pop-ups. Use small contextual tooltips and empty states that explain the next step.

## Roles & permissions (enforce with RLS + UI)
| Role | Can |
|---|---|
| Owner | Everything, all branches, see cost & profit |
| Manager | Own branch(es); approve discounts above limit, adjustments, closings, back-dated sales |
| Cashier | POS, own sales, open/close own register; cannot see cost price or profit |
| Wholesale Rep | Wholesale orders & collections for assigned customers |
| Storekeeper | Receive goods, transfers, stock counts |
| Driver | Assigned deliveries, record cash collected |

Each user has login + 4-digit **PIN** for fast POS switching. Every sensitive action (delete sale, price change, discount > limit, stock adjustment, back-date, credit over limit) requires a **reason** and is written to the **Audit Log**.

---

## Modules

### 1. Nyumbani (Home dashboard)
- KPI cards: **Cash Collected** (by payment date, with sparkline and % vs last period), **Expenses**, **True Net Profit** (by sale date, with margin %), **Pending Payments** (unpaid orders).
- Segment toggle: **All / Retail / Wholesale**.
- Monthly goal bar with "needed per day to hit goal".
- Till breakdown by payment account.
- Performance: items sold, AOV, top item, margin.
- **Smart Alerts (max 5, prioritized)**, each with one action button: overdue debt → "Send reminder"; out of stock → "Create PO"; register not closed → "Notify manager"; product without price → "Set price"; closing shortage → "Review".
- Recent sales, low-stock list.

### 2. POS (Mauzo)
- Three panes: Products (search, barcode scan, recent, categories) · Cart · Checkout. On mobile it becomes a stepper.
- Customer picker (default "Walk-in"). **Selecting a customer auto-applies their price tier.**
- Quantity in **piece / dozen / carton** (unit conversion per product).
- Payment status: Full / Partial amount / Credit. **Split payments** across accounts.
- Discount (line or order) limited by role; delivery fee; notes.
- Modes: Standard · **Cross-branch** (sell stock from another branch → auto transfer).
- **Hold / park sale**, resume later.
- **Block selling a product with price 0 or below cost** unless Manager PIN.
- Back-dating only for Manager/Owner, logged (replaces MauzoTrack's separate "Manual Sale Entry").
- Receipt: print (58/80mm thermal), PDF, or share on WhatsApp.
- Works **offline**; queued sales sync with conflict handling for stock.

### 3. Jumla (Wholesale Center) ⭐ new
- **Price tiers** per product: Retail, Wholesale, Dealer, VIP + **quantity breaks** (e.g. 1–11 retail, 12+ wholesale, carton = dealer). Customers are assigned a default tier.
- **MOQ** per product for wholesale.
- **Sales Order pipeline (kanban + list):** Quote/Proforma → Confirmed (stock **reserved**) → Picking (picking list PDF) → Dispatched (Delivery Note) → Invoiced → Paid / Partially paid.
- **Credit control:** credit limit, payment terms (7/14/30 days). Block new credit orders if over limit or has overdue invoices, unless Owner approves.
- **Collections:** debt aging buckets (0–7, 8–30, 31–60, 60+). One-click WhatsApp/SMS reminder with amount & invoice list. Payments allocate to oldest invoice first (FIFO) with manual override.
- **Customer statement** (PDF / WhatsApp link) for any date range.
- **Wholesale reps:** assigned customers, targets, orders, collections, commission %.
- **Re-order suggestions:** based on 30-day sales velocity, current stock, reserved stock and supplier lead time.
- **B2B catalog link (phase 2):** wholesale customers log in by phone OTP, see their own prices and stock availability, and place orders that land in the pipeline.

### 4. Stock
- Single **Products & Stock** screen (merges "My Stock" + "Manage Products"): filter by branch, status (Out / Critical / Low / Healthy), category; tabs for Active / Inactive.
- Product: name, SKU, barcode, category, brand/line, **variants** (size, colour), images, cost (auto from landed cost, weighted average), price tiers, units & conversions, reorder level per branch, MOQ.
- **Stock adjustments** (count, damage, loss, found) with reason; large ones need Manager approval.
- **Stock counts (stocktake):** blind count per branch, variance report.
- **Transfers:** Request → Approved → Sent → Received (with received-qty and shortage). Retail ↔ Wholesale ↔ Warehouse.
- **Movement history** per product (every in/out with who/why).
- Barcode label printing.

### 5. Manunuzi (Purchases & Suppliers)
- Suppliers with balances owed.
- **Purchase Orders** in TZS/USD/CNY with exchange rate.
- **Shipments:** track goods in transit (supplier → cargo → Dar → shop), ETA, status.
- **Landed cost:** add freight, duty/TRA, clearing, local transport; allocate across items by value, qty or weight → updates product cost.
- **Goods Received Note:** received vs ordered, partial receipts.
- Supplier payments and supplier statement.
- KPIs: Owed to suppliers, Purchases this period, Paid, Waiting to arrive.

### 6. Fedha (Money)
- **Accounts:** Physical cash per branch, M-Pesa, Lipa Namba lines, Bank accounts. Opening balances.
- **Transfers between accounts**, bank deposits (replaces "Cash Deposits").
- **Cashbook:** every money in/out, filterable (replaces "Global Ledger").
- **M-Pesa reconciliation:** import statement CSV, auto-match to sales, flag unmatched.
- **Expenses:** branch, category (manageable), amount, account, date/period (one-off or monthly), optional product link, **receipt photo**, owner-only flag. List + totals.
- **Payroll:** staff salaries, **advances (deducted on next payroll)**, commissions from sales/collections, pay status per month, payslip PDF.

### 7. Daily Closing ⭐ improved (merges Register + Closing Reports)
- Open register with float. Close with **blind count** per payment account (cashier doesn't see expected).
- System shows expected vs counted → shortage/over, attributed to the cashier.
- Manager approves; disputes need a note.
- Calendar view per branch: Closed ✅ / Not closed ⚠️ / Not opened ❌ / Shortage 🔴.
- At 21:00 if a branch isn't closed → alert Manager & Owner.
- After close → **automatic daily summary to Owner on WhatsApp/email** (sales, profit, cash by account, debts collected, new debts, shortages, low stock).

### 8. Ripoti (Reports)
- Main report (keep MauzoTrack's excellent layout): KPIs (Sales, Gross profit, Net profit, Expenses, # sales, Owed to you), sales trend, "Where the money is", P&L (this period / 6 months), most profitable products, staff leaderboard, regions, categories, discounts, deliveries, "Things to do". Compare with previous period. Download PDF/XLSX.
- **Separate "sales" from "debt collections"** so money-in vs sales mismatches are explained.
- **Retail vs Wholesale** comparison report.
- **Product Performance:** units, revenue, landed cost, profit, margin, vs previous period, stock left, days of stock left; "Best performer" & "Needs attention".
- **Customer report:** top customers, lifetime value, dormant customers (no purchase in 60 days) → reactivation list.
- **Debtors aging** and **supplier payables** reports.
- **Goals:** monthly target per business/branch/person, daily calendar, streaks, milestones.
- **Audit Log:** searchable list of sensitive actions.

### 9. Usimamizi (Settings / Manage)
- Branches (type: Retail / Wholesale / Warehouse), receipt header/footer, TIN/VRN.
- Employees: role, branches, PIN, commission %, active/inactive.
- Customers: import/export CSV, type (Retail/Wholesale), tier, region, credit limit & terms, TIN.
- Categories, units, expense categories, payment accounts.
- Tax: optional VAT 18%, TRA-compliant invoice fields; design invoices so **EFD/VFD integration** can be added later.
- Notification settings (WhatsApp/SMS provider, reminder templates in Swahili).
- Data backup/export.

### 10. Deliveries & Returns
- **Deliveries:** assign order to driver/bodaboda, status (Pending → On the way → Delivered/Failed), COD collected, driver hands over cash (replaces "Delivery Cash Out").
- **Returns & exchanges:** link to original sale, reason, restock or mark damaged, refund to account or issue **credit note** on customer balance (replaces "Failed/Returned Orders").

---

## Do NOT build (deliberately dropped from MauzoTrack)
Billing/subscription page, Academy, Refer-a-friend, Support chat, separate "My Expenses" page, separate "Manual Sale Entry", "Global Ledger", and any auto-playing tutorial video pop-ups.

## Data & integrity rules
- Stock is stored in base units (pieces). Every change is a row in `stock_movements`; on-hand quantity = sum of movements (cached per branch).
- Reserved stock (confirmed wholesale orders) is excluded from "available".
- Sales, payments and invoices are **never hard-deleted**; they are voided with reason.
- Cost of goods sold uses the cost **at time of sale** (stored on the sale line).
- Profit = net sales − COGS − expenses. Show "True net profit" by sale date and "Cash collected" by payment date. Never mix them.
- All timestamps in `Africa/Dar_es_Salaam`.

## Seed / migration
- Provide a CSV import for products, customers, opening stock, and opening customer debts so we can move off MauzoTrack (it exports Products, Customers and Sales to CSV).
- Seed demo data: 2 branches, 20 products with variants & price tiers, 30 customers (10 wholesale), 7 staff with roles, 60 days of sales.

## Build order (deliver in phases, each one working and deployable)
1. Auth, roles, branches, products/stock, POS (with tiers, split payment, offline), receipts.
2. Customers & credit, Wholesale Center (orders, invoices, collections, statements), Daily Closing.
3. Purchases, landed cost, transfers, stocktake, Money (accounts, cashbook, expenses, payroll).
4. Reports, goals, smart alerts, owner daily WhatsApp summary, audit log.
5. Deliveries, returns, B2B catalog link, M-Pesa reconciliation, EFD/VFD readiness.

For each phase: show the database schema/migrations, RLS policies, main screens, and a short test checklist. Ask me before making assumptions that change money or stock logic.
