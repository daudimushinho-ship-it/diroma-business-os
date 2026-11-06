# DIROMA Business OS
## Screen-recording review and consolidated Claude implementation prompt

Prepared: 5 November 2026. Business timezone: Africa/Dar_es_Salaam.

## A. What this review establishes

Source: the user-provided `Screen_Recording_20261105_145712_MauzoTrack.mp4`, approximately 3 minutes 19 seconds. The review is grounded in visible screens across the recording, including enlarged representative frames. Time references below are approximate.

This is an interface/workflow review, not a source-code, database, security or accounting audit. A visible button does not prove its underlying behavior. Screens not opened are explicitly identified. Customer identities, staff contact details and business figures from the recording have deliberately not been copied into the proposed app's demo data.

The recommendation is to retain useful retail workflows, reorganize them around DIROMA's jobs, build an original DIROMA interface and implement a separate wholesale/consignment operation. It is not to clone MauzoTrack's design.

## B. Panel-by-panel decisions

| Visible panel | Approximate recording position | Decision for DIROMA | Specific adaptation |
|---|---|---|---|
| Home | 00:00 and 03:12–03:19 | Keep, redesign | Separate net sales, collections, physical cash, receivables and stock quantities/value. Owner-only profit. Prioritized exceptions instead of a large undifferentiated alert feed. |
| POS / Record Sale | 00:04–00:19 | Keep, improve | Desktop products/cart/checkout; mobile step flow; strong product images, mandatory color/size selection, scanner, controlled discounts, partial/split payment. |
| Stock Reconciliation / Adjustments | 00:20–00:23 | Keep, strengthen | Count by variant/location, freeze or reconcile intervening movements, record variance, independent approval, no silent quantity replacement. |
| My Stock | 00:24–00:31 | Keep as an Inventory view | Sizes in a matrix; physical/reserved/available separate; shop, warehouse, transit, partner and inspection locations. |
| Sales History / Sales Overview | 00:32–00:35 | Keep | Fast server-side filters, variant details, independent payment/fulfillment status, receipt reprint and controlled return request. |
| Customers / Clients & Credit | 00:36–00:47 | Keep, extend | Unified customer records with retail/wholesale/consignment relationships, terms, debt ageing, allocations, credits and statements. |
| Invoices | 00:48–00:51 | Keep within Sales/Finance | Quotes, invoices, receipts and credit notes; direct PDF generation; consistent order and payment links. |
| Manual Sale Entry | 00:52–00:55 | Restrict | Use for approved missed/backdated entries or migration; capture occurrence time and entry time; avoid posting an existing POS sale twice. |
| Delivery Cash Out | 00:56–00:59 | Keep within Cash & Delivery | Separate customer delivery charge, runner advance, carrier expense and money handed over. Require voucher, recipient, evidence and settlement. |
| Failed / Returned Orders | 01:00–01:07 | Redesign as separate exception types | Payment failure, cancelled order, failed delivery, sale return and refund are different events. A failed order is not proof of stock physically returned. |
| Suppliers & Purchases | 01:08–01:11 | Keep | Order now/receive later, partial delivery, supplier bills/payments, freight allocation and landed cost. |
| Manage Products | 01:12–01:19 | Keep, combine with catalogue | Same underlying product data as inventory; separate catalogue maintenance from quantities. Original codes, images, color/size variants, CSV and barcode printing. |
| Reports | 01:20–01:39 | Keep, improve definitions | Sales by sale date, collections by payment date, receivables as of a date, net/gross profit with complete costs; explain differences. Server-wide totals, not current-page totals. |
| Closing Reports / Register Closings | 01:40–01:43 | Essential | Shift closure, expected versus counted cash, discrepancy reason, manager review and period protection. Operational closing report is not a fiscal certification. |
| Activity Log / Movement History | 01:44–01:51 | Essential | Searchable stock/payment/user events with source document and actor; separate immutable security audit where appropriate. |
| Product Performance | 01:52–01:59 | Keep, extend | Best/slow movers by design/color/size; sell-through, ageing, stock cover and margin with cost-completeness labels. |
| Goals | 02:00–02:07 | Keep business targets; defer gamification | Configurable units, revenue, collections, conversion and staff tasks. Avoid treating streaks and transaction-count badges as business success. |
| Branches / Shops | 02:08–02:11 | Keep | Model physical branches/locations separately from sales channels and partner relationships. A branch named wholesale is not a wholesale ledger. |
| Shop Link | 02:12–02:15 | Optional later phase | Original DIROMA public catalogue, QR and WhatsApp inquiry. Explicit published prices; private wholesale terms, customer records and exact stock remain protected. |
| Employees | 02:16–02:31 | Essential, expand | Distinct Sales Staff, Manager and Storekeeper accounts plus Owner; controlled invitations, permissions, branch assignments, suspension and audit. |
| Global Ledger | 02:32–02:35 | Keep, rework controls | Separate financial journal from operational register. Posted records use correction/reversal workflows. Edit/delete icons alone do not establish what existing app safeguards are. |
| Cash Deposits | 02:36–02:39 | Essential inside Money | Trace cash-to-bank/mobile transfers with evidence and confirmation. Deposits are transfers of assets, not new revenue or operating expense. |
| Business Money | 02:40–02:47 | Essential | Opening balances, inflows/outflows, account transfers, reconciliations and separate cash/bank/mobile balances. “Per records” is distinct from reconciled provider statements. |
| Billing & Plan | 02:48–02:55 | Remove from staff navigation | DIROMA is the app owner, not a customer choosing a DIROMA SaaS subscription. Keep provider costs/renewal alerts only in Owner administration. |
| Help & Support | 02:56–02:59 | Keep, simplify | Short role-specific guides, search and an Owner-configured support contact; no fabricated staffed helpdesk. |
| My Profile | 03:00–03:11 | Keep | Personal account, language, security preferences and permitted notification settings. Company-wide exports belong to Owner-controlled settings. |
| Export My Data within profile | 03:00–03:11 | Essential, relocate | Owner-authorized complete portable export, secure download, manifest and audit; distinct from a verified backup/restore system. |

### Visible navigation, not enough detail to review the workflow

- **Transfers:** link visible under Quick Actions; no sufficiently detailed transfer screen was inspected. Retain the function with dispatch/receive custody controls as a DIROMA requirement.
- **Expenses / My Expenses:** links and expense totals/categories are visible; expense entry/approval was not demonstrated. Use one Expenses module with role-filtered “My requests” and approved company records.
- **Register:** link visible next to Closing Reports. Consolidate under Cash & Shift Closing unless a separate demonstrated workflow justifies another menu.
- **Payroll:** navigation visible; payroll detail was not demonstrated. Add configured salaries/commissions only after the core ledgers are working; do not invent statutory payroll calculations.
- **Academy:** navigation visible; content not demonstrated. Replace with a lightweight DIROMA staff guide rather than a large academy.
- **Refer a friend:** navigation visible. Omit; it does not support DIROMA's internal operations.
- **Profile Payments / Security / Permissions tabs:** tab labels visible, but their controls were not opened. The recording cannot validate authentication, MFA, authorization, encryption or recovery.
- **Language/theme icons and reminder preferences:** controls are visible; successful switching, message delivery and scheduling were not demonstrated.

### Important observations to carry forward

1. **Some parent product cards show a zero price while identifying variants.** This is not proof that the effective variant price is zero. DIROMA should show “From …” or “Choose size” for parent records, and validate the actual chosen variant price. Unknown cost must not silently become zero-profit-cost.
2. **The visible reports distinguish money received from sales and explain that they differ.** Preserve this useful distinction and expose the actual linked causes: debt collections, advances, refunds and timing.
3. **Physical cash and M-Pesa are shown separately.** Keep this across dashboard, shift closing and deposits.
4. **The closing screen exposes a cash discrepancy field.** Preserve an explicit variance review workflow; the recording alone does not establish the reason for any displayed discrepancy.
5. **The stock and product screens are related views, not separate inventories.** Use one authoritative stock ledger and catalogue with views appropriate to each role.
6. **A “Wholesale” customer filter and a branch named “DIROMA WHOLESALE” are visible.** A full consignment settlement workflow was not demonstrated. Build the dedicated DIROMA wholesale panel described below without claiming the existing service lacks unshown features.
7. **No internal security conclusions follow from this video.** Security requirements in the prompt are implementation requirements for DIROMA, not allegations about the reviewed application.

## C. Proposed DIROMA navigation

| Main area | Tabs / primary work |
|---|---|
| Overview | Role-specific summaries, exceptions, quick actions |
| Sell | POS, sales register, invoices, returns/exchanges, controlled manual entry |
| Products | Catalogue, original codes, images, variants, prices and barcodes |
| Store / Stoo | Warehouse dashboard, physical receipts, size matrix, shop requisitions, dispatch/receipt handoffs, counts, inspection and reports |
| Shop Stock / Stoki ya Dukani | Retail availability, incoming receipt confirmation and location-specific movements |
| Wholesale Customers / Wateja wa Jumla | Dedicated partner dashboard, dispatches, settlements, returns, allocated payments, genuine debt, statements and reminders |
| Money | Cash/mobile/bank, collections, expenses, delivery advances, deposits/transfers, shift closing |
| Customers | Profiles, terms, ageing, credits, purchase history, statements |
| Reports | Sales, collections, profit, stock, wholesale, staff, reconciliation |
| Team | Staff access, assigned work, handoffs, targets; later commissions/payroll |
| Control Center | Approvals, audit, security events, reconciliation, backup/recovery |
| Settings & Help | Company, locations, policies, integrations, export, language, guides |

Navigation is filtered by server-enforced permissions. The Storekeeper's default landing page is the Store/Stoo Dashboard, the Sales Staff's is POS, the Manager's is Operations Overview and the Owner's is Business Overview.

---

# D. COPY THE FOLLOWING PROMPT INTO CLAUDE

The following is a standalone English implementation prompt. Attach the official DIROMA logo and, optionally, the DIROMA design-concept image. The recording is a workflow reference only; do not seed its personal or financial information into the app.

--- BEGIN CLAUDE MASTER PROMPT ---

# DIROMA BUSINESS OS — IMPLEMENT, VERIFY AND DELIVER

You are the lead product engineer and original interface designer responsible for delivering DIROMA Business OS, a secure shop-management application for an imported menswear business in Tanzania.

The business owner does not code. Take responsibility for architecture, implementation, tests, setup guidance and clear handover. Use plain instructions for the owner. Do not promise error-free software or absolute security. Prove critical behavior with test evidence.

This is a request to implement working software with a persistent backend. A dashboard mockup, browser-local records, a simulated login or a plan alone is not completion.

## 1. Authority, inputs and scope

Treat this prompt as the consolidated functional brief. Inspect any existing project before changing it; preserve valid records and working features. Use append-only migrations after deployment. Never delete live data, reset a production database or overwrite applied migration history without explicit approval.

Use the supplied video as evidence of visible retail workflows. Do not copy MauzoTrack branding, colors, proprietary design, code or private customer/staff records. Create an original DIROMA application.

The supplied DIROMA dashboard image is a visual concept, not an accounting source. Its sample values must not become real records. Correct any mockup inconsistencies: quantities use pcs; monetary valuation uses TZS in a separate metric.

Do not deploy an unrelated new app when an existing DIROMA project is clearly identified. If the target is new, build with an isolated staging environment first.

## 2. Fixed business and technology decisions

Brand: DIROMA. App: DIROMA Business OS. Slogan: Spirit of Fashion.
Business: ready-made imported menswear; retail, wholesale and consignment.
Primary location: Kariakoo, Dar es Salaam. No manufacturing or tailoring module.
Currency: TZS, displayed with thousands separators. Use exact integer/fixed-decimal accounting, never binary floating-point money.
Timezone: Africa/Dar_es_Salaam. Store timestamps consistently; use business timezone for reports and schedules.
Languages: English and Swahili, including core forms, validation and documents.

Use **Supabase Pro for production** for managed PostgreSQL, Supabase Auth and private Storage. Begin development/testing in a real isolated local environment or eligible free test project as required by Section 19; do not require a paid plan merely to start. Use TypeScript and a maintainable web application stack, preferably Next.js. Target Vercel Pro for app hosting if compatible with the existing project. Use durable server-side background execution for jobs that exceed request limits.

Verify current official provider/library documentation before implementation. Do not assume that a paid plan automatically supplies configured roles, application security, file backups or verified recovery.

Use one repository, a modular architecture, separate development/staging/production configuration and a reproducible deployment process. Avoid unnecessary microservices. Do not change providers or introduce paid add-ons without explaining the tradeoff and obtaining authorization where needed.

## 3. Original DIROMA design system

Use the exact supplied logo asset, preserving the emblem, lettering and aspect ratio. Do not regenerate or redraw it. Keep the complete original asset.

Design direction: dark espresso navigation, warm ivory operational surfaces, restrained champagne-gold accents, clear dark text, consistent line icons, readable tables and generous spacing. Suggested starting tokens: espresso #2D1C18, brown #4A2B22, champagne #C6A25D, ivory #F8F6F1; verify accessibility contrast and adjust functional colors when necessary.

Use readable contemporary sans-serif UI typography. Keep decoration restrained. Avoid tiny text, excessive cards, flashy animation and ornamental gold that reduces readability.

Desktop: efficient sidebar, compact header, date/location selector and task-focused content. Mobile: role-specific shortcuts, usable size selection, clear checkout stages and bottom navigation for frequent actions. Do not shrink a desktop table into an unreadable phone screen.

Show accessible loading, empty, failure, unsynced, pending and confirmed states. Support keyboard navigation, focus management, labels, contrast and appropriate touch targets.

Use toasts for confirmations, persistent actionable messages for failures and explicit confirmations for consequential operations. Show a clear distinction between saving a draft and posting a transaction.

## 4. Accounts and permissions — mandatory first milestone

Implement individual **Sales Staff**, **Manager** and **Storekeeper** logins, plus a separate **Owner/CEO** administrator. The required login method for all four roles is **mobile phone number and password** using Supabase Auth. Employees must not require email or ChatGPT accounts for application login. Follow Section 4A for normalization, activation, recovery and security.

Use Supabase Auth with secure owner-controlled invitations, activation, recovery and session management. No hardcoded production credentials, shared accounts or public sign-up that grants privileged roles.

Store business membership, active state, branch/location scope and approved permissions in trusted server-controlled records. Do not trust a selected login role or user-editable profile metadata. Revalidate active membership for protected operations, including when an existing token remains technically valid.

Owner: all business administration, restricted costs/profit, limits, memberships, integrations and recovery.
Manager: daily operations, assigned locations, team monitoring and approvals within explicit owner-delegated limits. Financial visibility is separately granted. No self-promotion or permission escalation.
Sales Staff: POS, selling prices, relevant available shop stock, assigned customers, collections, own shift and controlled return/discount requests. No buying costs, company-wide profit or unrestricted customer/financial exports.
Storekeeper: physical receiving, stock quantities, transfers, counts and inspection at assigned locations. No changing customer collections or confidential supplier costs by default. Separate quantity receiving from purchasing/cost approval.

Provide optional read-only accountant and tightly scoped wholesale-client access after the staff flows are reliable. Scope marketing/content access through explicit limited permissions, not a cashier account with unnecessary financial visibility.

Require MFA for privileged roles, appropriate inactivity limits, sensitive-action reauthentication, disable/revoke controls and tested recovery. Record actual provider behavior and limitations rather than claiming unsupported session guarantees.

### 4A. Required login: phone number and password

This is a mandatory Owner decision and supersedes any earlier suggestion of email-only or ChatGPT-based employee login.

All four primary account types — Owner/CEO, Manager, Sales Staff and Storekeeper — sign in with **their own mobile phone number and password**. Do not require an email address from an employee to use the application. Provider administration/billing accounts may separately require an Owner email; explain this distinction plainly.

**Login interface**
- One branded DIROMA login page, with English/Swahili labels: Phone number / Namba ya simu; Password / Nenosiri; Sign in / Ingia; Forgot password? / Umesahau nenosiri?
- Default country selector Tanzania (+255), with a clear national-number example that is illustrative, not an existing user's contact details.
- Accept valid local and international input, normalize and validate with a maintained phone-number library, and store a unique canonical E.164 identity. For the same valid Tanzanian mobile number, local 0-prefixed and +255-prefixed forms must resolve to one account. Do not blindly prepend +255 to other international numbers or strip meaningful digits.
- Use phone-friendly inputs and password-manager/autofill support. Allow pasting strong passwords, provide a show/hide control, preserve the exact password without trimming, and never persist it in browser preferences or the application database.
- Do not let the person select Owner/Manager/Storekeeper privileges at login. After verified authentication, load their active server-controlled membership and route automatically: Sales Staff → POS; Storekeeper → Store/Stoo; Manager → Operations Overview; Owner → Business Overview.
- Use generic invalid-credentials responses that do not reveal whether a number exists. Provide clear network/configuration errors without logging credentials.

**Supabase implementation**
Use the supported Supabase Auth phone-and-password flow, such as `supabase.auth.signInWithPassword({ phone: normalizedPhone, password })`, with current supported session/SSR handling. Configure the Phone provider and verify real behavior in the target environment. Do not create fake email aliases to imitate phone authentication or implement a second custom password database.

Routine login is phone + password, not an SMS OTP on every visit. Keep required privileged MFA as a separate security step; authenticator-app TOTP is preferred where supported and verified. Do not weaken privileged MFA merely to avoid SMS costs.

**Owner-controlled onboarding**
Disable unrestricted public employee registration. Only authorized administration can provision a pending staff account and assign role/location/limits, using server-only Auth administration when necessary. Keep service-role secrets out of client code.

Define a complete, tested activation process: pending account → staff identity/phone verified → staff sets personal password → account activated. Prefer verified phone/SMS activation when a configured provider is available. Production SMS has separate provider configuration, delivery limits and possible charges; do not enable a paid provider without Owner approval.

If an Owner-supervised, in-person enrollment option is supported, document exactly how identity/phone possession is verified and audited. Administrative `phone_confirm` is not evidence that an SMS was delivered. Do not silently auto-confirm arbitrary phone numbers or turn off production verification globally.

Avoid permanent passwords known to the Owner. Any approved temporary activation credential must be individual, random, short-lived and one-use, require immediate replacement, and grant no business-data access before activation completes. Never display existing passwords or send them to ordinary logs, exports or shared chat. Treat Auth provisioning and membership creation as separate external operations: partial failure must leave the account restricted, with a safe retry/cleanup path.

The initial Owner must be established through a controlled one-time setup bound to verified ownership. Never make the first anonymous visitor an Owner. No hardcoded production phone numbers/passwords or unreviewed default accounts.

**Recovery and phone changes**
Implement password change with appropriate current-password/fresh-authentication checks and privileged MFA. Changing a password must not automatically reset or remove MFA.

Implement Forgot password with a documented supported verification method. Supabase's email reset API is not a phone-password reset API; do not invent a `resetPasswordForPhone` method. If an SMS recovery flow is used, verify number ownership, bind the short-lived recovery state to resetting the correct account and prevent it from granting normal business access or bypassing required MFA. Test direct Auth/API access as well as the screen flow.

If SMS is not configured, show an honest Owner-assisted recovery path. It requires the authorized Owner's fresh authentication, verified staff identity, a single-use recovery process, audit and session revocation policy. Knowing a phone number or answering a weak security question is not sufficient. Define separate secure Owner recovery using verified factors/recovery material; never allow a lower role to reset or take over the Owner account.

Number changes require controlled verification, uniqueness checks and audit. Bind roles, transactions and approvals to immutable user IDs so changing a phone number does not lose history. Address reassigned/SIM-swapped phone numbers with MFA, reviewed recovery and account-disable procedures rather than treating phone possession as permanent ownership.

**Security and tests**
Use Supabase-managed password hashing. Adopt a documented strong-password policy, initially at least 12 characters, allowing password managers and long passphrases. Configure practical account/IP throttling and alerts without an easy permanent lockout attack. Apply membership-disable checks on every protected path even if a previously issued token has not expired.

Before claiming this feature complete, demonstrate:
1. All four roles sign in using their own phone and password and reach the correct workspace.
2. Equivalent valid local/international phone forms normalize to one identity; duplicate or invalid numbers reject safely.
3. Unknown number and incorrect password do not leak account existence.
4. Editing role fields, request parameters or profile metadata cannot escalate access.
5. A pending, suspended, deactivated or offboarded user cannot access business data through UI, API, RPC, files or subscriptions.
6. Activation/temporary credentials expire and cannot be replayed; partial provisioning failures remain restricted.
7. Password reset/change and phone change are authorized, audited and do not bypass MFA or expose another account.
8. Ordinary phone/password login works without sending an OTP each time; required MFA remains enforced.
9. No plaintext password, service key, OTP or full session token appears in application tables, logs, source code, reports or demo fixtures.

Use synthetic accounts in an isolated development Auth environment to test before paying for hosting or SMS. Verify actual hosted phone-provider activation/recovery after external configuration. Clearly report those real delivery tests as pending until performed. A local fixture or mocked provider must never be presented as successful production SMS delivery.

Official implementation references checked for this requirement: https://supabase.com/docs/guides/auth/passwords ; https://supabase.com/docs/reference/javascript/auth-signinwithpassword ; https://supabase.com/docs/reference/javascript/auth-admin-createuser . Recheck current documentation when implementing.


## 5. Navigation and role workspaces

Use these main areas, consolidating overlapping views:
- Overview.
- Sell: POS, sales register, invoices, returns/exchanges, controlled manual entry.
- Products: catalogue, images, variants, prices and barcodes.
- Store / Stoo: dedicated warehouse dashboard, receipts, shop requests, dispatch/receipt handoffs, counts and inspection.
- Shop Stock: retail location balances and incoming receipt confirmations.
- Wholesale Customers / Wateja wa Jumla: a dedicated partner operation covering dispatches, settlements, returns, payments and statements.
- Money: accounts, collections, expenses, delivery advances, deposits and closing.
- Customers.
- Reports.
- Team.
- Control Center: approvals, audit, reconciliation and recovery.
- Settings & Help.

Only show accessible actions, while enforcing all restrictions on the server/database independently.

Default landing pages: Sales Staff → POS; Storekeeper → Store/Stoo Dashboard; Manager → Operations Overview; Owner → Business Overview.

Owner overview separates net sales, collections, physical cash, receivables, saleable stock units, inventory cost and profit. Each financial metric has a definition, date basis and drill-down. A hidden-balance preference is convenience, not authorization.

Manager/Storekeeper exception queues identify pending transfers, delivery shortages, unapproved counts, uninspected returns and overdue partner updates. Group/deduplicate alerts and prioritize actionable exceptions.

## 6. Catalogue, garment identity and migration

Support suits 2pc/3pc, tuxedos, jackets, waistcoats, trousers, shirts, shoes and accessories.

A design has an original code, name, category, supplier, images and active/archive state. A variant has its own color, size, SKU/barcode, selling prices and quantity by location. Preserve original codes containing characters such as #; use internal immutable IDs separately.

Suit sizes: 42,44,46,48,50,52,54,56,58,60. Shoes: 39–46. Allow configured additional sizes and editable size charts. Never invent a trouser-waist mapping where one has not been configured.

Use a size/color matrix for bulk quantity entry and visibility. Parent designs show “From [price]” or “Choose size” when appropriate. Checkout must use a selected variant's validated effective price. Unknown cost is not automatically zero cost; flag incomplete profit calculations.

Full suits sold as sets must have a clearly defined stock unit. Do not deduct one whole suit and also deduct included components unless an explicit assembly/bundle rule defines that behavior. Sell standalone garments separately when they actually have independent stock.

Provide barcode generation and printing without prices. Store barcode as text, preserve significant characters/leading zeros and prevent collisions. Support scanners and manual search. Verify labels with a decoder and shop hardware before claiming scanner readiness.

CSV import: template, mapping, preview, per-row errors, explicit duplicate/create/update rules, atomicity policy, import IDs and outcome reports. Preserve source references for migration. Opening quantities, cash, receivables and partner custody must be posted as controlled opening documents, not silent overwrites.

Keep demo records in a separate environment or clearly isolated demo workspace. Never copy real customer contacts or account figures from the video as demo seeds.

## 7. Purchasing, costs and physical custody

Implement supplier records, purchase orders, partial receipts, supplier invoices and supplier payments as distinct documents. Support order-now/receive-later and allocated landed costs such as freight/import costs. Document allocation and rounding.

Track physical location and ownership independently. Initial locations: warehouse, shop, transit, each consignment partner, inspection and damaged/quarantine.

Represent physical on-hand, reserved and available quantities separately. Partner-held and inspection stock are not available to sell from the shop.

Every posted stock change must be linked to a source, actor and server timestamp. Enforce nonnegative stock and concurrent final-unit protection in PostgreSQL.

Transfers: request → authorize where required → dispatch → in transit → partial/full receipt → discrepancy resolution. Record sender and receiver; do not silently assume receipt at dispatch. Preserve quantities across company locations. A stock transfer is not revenue.

Counts: support blind counts, cut-off rules or intervening-movement reconciliation, variant-level variances, reason/evidence and independent approval. Do not let a stock count erase movements occurring during the count.

Returns enter inspection. Authorized inspection release restores saleable stock; damage/write-off uses a controlled approval and financial treatment. Provide slow-stock ageing, low stock by size/location and movement drill-down.

### 7A. Mandatory standalone Store / Stoo panel

The Owner explicitly requires a **standalone Store / Stoo panel** as a primary navigation destination, separate from the product catalogue, the retail shop and the Wholesale Customers panel. Do not satisfy this requirement with only a stock card on the Owner dashboard.

In this application, **Store/Stoo means the warehouse or stockroom**; **Shop/Dukani means the retail selling location**. Use these labels consistently in English and Swahili. A product catalogue defines designs/variants; it is not itself a physical stock location.

Provide Store tabs:
- Store Overview.
- Receive Goods.
- Stock by Design / Color / Size.
- Shop Requisitions.
- Dispatches and In-Transit Goods.
- Receipt Confirmations / Discrepancies.
- Counts and Adjustment Requests.
- Returns Inspection / Damaged Goods.
- Movement History.
- Store Reports.

The Store Overview shows warehouse on-hand, reserved, available, in-transit, inspection/damaged quantities, pending requests and unconfirmed receipts. Show quantities in pcs or their configured unit. Owner-approved financial roles may also see cost/value; do not disclose confidential costs to the Storekeeper by default.

Physical receipt must record supplier/source, receipt or purchase reference, receiver, timestamp, original design/code, color, size and quantities expected/received. Support bulk size-matrix entry, partial receipts, shortages and supporting evidence. Purchasing-cost approval is a separate permission. Never silently invent missing costs.

**Warehouse-to-shop handoff:**
1. Sales Staff or Manager raises a shop stock requisition for actual variants and quantities.
2. Storekeeper sees the request, availability and required authorization. Reserve stock explicitly when the workflow requires it; reservation is not physical dispatch.
3. Storekeeper dispatches the approved available quantity and records the sender/reference/time. Move it from warehouse to in-transit exactly once; release corresponding reservations correctly.
4. The authorized shop recipient confirms actual quantities received. Move confirmed goods from in-transit to shop exactly once.
5. Partial receipts, damage or shortages remain visible with a responsible person and resolution workflow. Do not automatically accept a missing quantity or count it as sold.
6. Record requester, authorizer if required, dispatcher and receiver as distinct event identities. Shared accounts are not acceptable. A separate receiver is the default custody policy; any necessary Owner override requires explicit reason and audit.

Physical stock requests and transfers must support repeated design/size lines where necessary while validating aggregate availability. Dispatch cannot exceed approved remaining quantities or available stock. Repeated clicks, scans, retries or confirmations cannot multiply a movement.

A Storekeeper may receive physical stock, dispatch authorized requests and submit counts/inspection results within assigned locations. They may not silently rewrite quantities, change buying costs, approve their own variances, alter customer payments or delete posted movements. Sales Staff may request stock and confirm authorized shop receipts but cannot manufacture warehouse quantities. Managers review exceptions and approval requests within delegated limits; the Owner controls policy and complete visibility.

Direct warehouse-to-wholesale-partner dispatch may be supported with authorization. Link it to the partner's consignment/order and identify the physical source location; do not route a fictional quantity through the shop simply to satisfy the interface.

### 7B. One stock ledger across Store, Shop and Wholesale Customers

All three panels must use the **same authoritative variant/location/ownership ledger**. They are different operational views, not independent copies of inventory.

For a location, closing quantity = opening quantity + posted inbound movements − posted outbound movements. Reserved quantity is an allocation of eligible on-hand stock, not an additional physical unit. Available quantity follows the documented reservation and quarantine rules.

Company-owned physical stock includes relevant warehouse, shop, transit, unsold consignment and inspection/damaged custody. Confirmed sales remove the appropriate company-owned quantity according to the documented sale/fulfillment policy. A transfer or partner dispatch alone does not create revenue.

Mandatory Store acceptance examples:
- Receive 50 sample units into warehouse; dispatch 10 to shop: warehouse 40, transit 10, shop 0. Confirm receipt of 10: warehouse 40, transit 0, shop 10. Sell 3 from shop: warehouse 40, shop 7. Company-owned remaining stock is 47; do not subtract the transfer again.
- After a 10-unit warehouse dispatch, receive 8 into shop: warehouse 40, shop 8, transit/discrepancy 2 until properly resolved. Do not silently erase or sell the missing 2.
- Dispatch consignment stock from its actual warehouse/shop source. Subsequent partner settlement reduces partner custody; it must not deduct the same quantity again from the warehouse or shop.
- Attempt a second confirmation/replayed dispatch; quantities remain unchanged after the original successful operation.

Weekly reports and exports show original product/order names, codes, colors, sizes, locations, opening/inbound/outbound/closing quantities, pending handoffs and discrepancy status. Exports are read operations, not a second inventory deduction mechanism.

The standalone Wholesale Customers / Wateja wa Jumla panel in Section 10 is equally mandatory. It must be accessible as its own navigation destination and reconcile partner custody, confirmed sales, accepted returns, payment allocations and genuine receivables with the Store/Shop ledger. Do not replace it with a branch named wholesale, a generic customer-type filter or an isolated spreadsheet-style balance.


## 8. POS, sales and fulfillment

POS: desktop products/cart/checkout, mobile staged flow. Search barcode, name, original code, color and size, with clear product images.

Support retail and wholesale price policies, cart quantities, controlled discounts, customer association, delivery charges and explicit order fulfillment. A price channel is not a physical branch.

Separate order state, fulfillment state and payment state. For example: posted + awaiting delivery + partially paid is valid and understandable.

Only authorized transactions can override price, margin, credit terms or historical date. Capture the actual sale time, entry time, actor and reason for approved manual/backdated entries. Manual entry is an alternate entry workflow into the same ledger, not a second sale engine.

Receipts/invoices have unique references and immutable item/price/cost snapshots. Reprints do not repost anything. Prevent double-submit/network-retry duplicates.

Distinguish a payment failure, a cancelled reservation, failed delivery, returned goods and refunded money. Do not return stock to saleable inventory because a payment or delivery failed.

## 9. Payments, accounts and cash custody

Payment methods: physical cash, configured mobile money accounts, bank and split payments. Distinguish manual entries from independently verified provider transactions. Never imply that selecting M-Pesa confirms receipt from the provider.

Store invoices, payments, allocations, customer advances/credits and outstanding receivables separately. Old-debt collection is not new sales revenue. Support partial collection, overpayment as controlled customer credit, allocation and reversal. Do not allocate one payment twice.

Account balances require validated opening balances and all inflows/outflows. Label unreconciled book balances honestly; provider reconciliation is a separate process.

Deposits/transfers: cash drawer → bank/mobile account is an asset transfer, not revenue and not an ordinary operating expense. Record sender, receiver, voucher/provider reference, evidence, confirmation and any actual service fee separately. Handle unconfirmed funds in transit.

Delivery: separate the customer's delivery fee from actual courier expense and a runner advance. Link issue/acknowledgment/settlement to the order where applicable, with recipient, proof and unused-money return. Avoid recognizing the same expense at advance issuance and settlement.

Refunds require original transaction eligibility, previous-refund totals, reason, authorized approval and real provider/cash outcome. Prevent duplicate refunds under retries or webhook replays.

## 10. Dedicated DIROMA wholesale and consignment panel

This is a first-class operational module, not just a customer filter or a branch named wholesale.

Offer two explicit transaction modes:
A. Outright wholesale sale under agreed cash/credit terms.
B. Consignment: DIROMA-owned goods placed with a partner for later approved settlement.

A partner profile includes identity/contact/region, terms, credit policy, next update due and complete history.

The partner overview must show, without opening each partner:
- Goods dispatched.
- Confirmed sold.
- Unsold returns accepted.
- Goods still with partner.
- Approved custody losses.
- Amount invoiced.
- Payments allocated.
- Outstanding sale debt.
- Customer credit/advance.
- Oldest due date, last update and unresolved issues.

Do not label unsold partner goods as an already-earned money balance. Consignment dispatch moves custody and does not automatically recognize revenue or sale debt.

For a consignment line: confirmed dispatched − confirmed sold − accepted unsold returns − approved custody losses = quantity still held. Handle later returns of previously sold goods as separate linked events with their own custody and financial effects.

Support repeated size lines, partial dispatch, partial settlement, multiple payments, partial returns and partner statements. Returns cannot exceed physical/financial eligibility.

Every line retains original order name/code/color/size for inventory reconciliation and export. One shared stock ledger is authoritative. Weekly exports must never deduct previously-posted quantities again.

Provide customer-specific and combined PDFs, period reports and reconciliation schedules. Customer portal data must be strictly isolated; submitted changes need approval before affecting controlled records.

Optional no-update reminders every two days must include the relevant pending dates, follow channel consent/configuration, avoid duplicates and stop/escalate according to policy. Do not send reminders merely because a menu exists.

## 11. Returns, expenses and accounting

Returns/exchanges: original sale linkage, eligibility, independent approval, inspection, credit note, credit allocation or refund and linked replacement sale as appropriate. Preserve historical revenue/COGS treatment and reconcile inventory valuation when historical-cost returns enter an average-cost pool.

Expenses: one canonical module with employee requests, approval, category, payment account, receipt/evidence, beneficiary and accounting period. Employees see their requests; authorized managers/Owner see appropriate company records. Payment and expense recognition must not be confused.

Use a balanced double-entry posting model for supported business events. Document inventory method, rounding, revenue, refunds, advances, credits, supplier payables, expenses, stock losses and owner capital/drawings. Weighted average is the initial inventory method unless justified otherwise.

Buying stock creates inventory/payables or cash effects; cost enters COGS when sold. Do not expense the purchase again in P&L and double-count it. Potential stock markup is not realized profit. Gross profit and operating/net profit have explicit definitions and cost completeness indicators.

Operational sales register, general journal and security audit are separate views of linked records. Posted entries are corrected through reversal/amendment/credit documents with reasons and approvals. Do not implement unrestricted edit/delete of posted records.

Do not invent TRA/EFD or statutory payroll compliance. Any fiscal/tax integration requires applicable current documentation and verified configuration.

## 12. Shift closing and reconciliation

Link each cashier's postings to a defined shift. Opening cash + cash receipts/additions − cash refunds/payouts/deposits-out = expected closing physical cash. Exclude mobile/bank receipts from physical cash.

Record actual count, variance, explanation, manager review and numbered closing report. Preserve payment-account reconciliation separately. Prevent new postings from racing a close and silently changing the closed totals. Authorized reopening or dated adjustments require history and independent policy.

A register that is not closed needs an actionable alert. A cash discrepancy is an investigation item, not an automatic accusation of theft. Distinguish an operational closing report from a certified fiscal report.

## 13. Reports, targets and team performance

Date filters: daily, weekly, monthly, quarterly, half-year, annual and custom range, with business timezone. Compare like-for-like elapsed periods; explicitly distinguish calendar month from a four-week target. Label comparisons as unavailable when no valid baseline exists.

Calculate totals server-side across the full requested data, never only a paginated/truncated list. Let totals drill down to exactly the records that compose them.

Provide sales, collections, receivables ageing, advances/credits, returns/refunds, stock value/ageing, supplier/payable, wholesale custody/settlement, expenses/P&L, staff and exception reports. Show selling channel separately from origin source (Instagram/WhatsApp/walk-in), branch and fulfillment method.

Keep sale date, collection date and as-of balance bases distinct. Explain why collections differ from sales with linked debt collections, advances, returns and timing. Define sales units by category; optionally show suit equivalents/sets separately from accessories.

Product performance: design, color, size, units, net revenue, COGS, gross margin, sell-through, ageing, stock cover and location. Any allocated marketing/transport expenses use documented rules to avoid counting landed freight twice.

Produce professional server-generated PDF/CSV/Excel exports as applicable. Include brand, date range, timezone, generation time, reference, filters, units, readable tables, totals and page numbers. Support individual and consolidated customer statements. Protect download authorization and spreadsheet formula injection.

Team: tasks, assignee, due time, evidence, completion and unresolved handoffs. Track inquiry → follow-up → visit → linked purchase without fabricated attribution. Default content targets: 3 reels/day, 21/week, monthly calendar-based or Owner override; 100 product posts/month. Do not automatically insert historical sales targets as current targets.

Commissions/payroll are a later controlled module after the financial core. Configure rates, eligibility, returns, task prerequisites, calculated/approved/paid states. No guessed salaries, rates or legal deductions. Remove nonessential sales streaks/badges from the first release.

## 14. Supabase security and transaction architecture

Use Supabase Auth to establish identity; server-controlled membership establishes business authority. Enable and test RLS on exposed business tables and Storage policies for private files. Deny direct client writes to financial ledgers, audit, protected balances and role assignments.

RLS filters rows, not automatically confidential columns. Store sensitive costs/profit data separately or expose carefully permissioned views/RPC/server DTOs so an otherwise-authorized cashier cannot query hidden cost fields directly.

Never place service-role/secret keys in frontend code. If the server uses an elevated key that bypasses RLS, it must explicitly authenticate and authorize each action. Prefer the narrowest feasible privilege boundary.

Implement posting as a real PostgreSQL transaction or tightly permissioned database function. Multiple independent Supabase HTTP calls are not an atomic stock/financial transaction. Use row locking or validated conditional updates and database constraints for concurrency.

If SECURITY DEFINER functions are necessary, fix search_path, fully qualify objects, check auth/membership/scope inside the function, narrowly grant execution and prevent caller-controlled ownership or role escalation. Never leave privileged functions executable by anonymous users by default.

Use idempotency keys bound to actor/business/operation and payload fingerprints. Same key/same payload returns the original result; same key/different payload rejects. Preserve identifiers on uncertain client retries. Validate webhook signatures, replay IDs and out-of-order events; use durable job/outbox processing.

Use exact money calculations, referential integrity, immutable posting snapshots, positive quantity checks and explicit state transitions. A failed posting must leave no orphan stock, accounting or payment records.

Add private short-lived file/download access, bounded uploads, file validation, malware scanning where supported, secure headers, input/output safeguards, appropriate CSRF/CORS, rate limits, secrets management and dependency/secret scanning. Separate production secrets and test identities. Never log passwords, OTPs, tokens or unnecessary personal data.

Do not claim complete security because an RLS policy exists. Test direct API/RPC/file access with real role sessions. Authorization must also cover reports, exports, real-time subscriptions, cached responses and background jobs.

## 15. Approvals, audit and recovery

Sensitive actions need configured limits and independent approval: discounts/price overrides, refunds, credit limits/forgiveness, stock adjustment/write-off, historical entries and reopening periods. Bind approval to a record version and exact values; editing invalidates it. A normal requester cannot approve their own request. Any exceptional Owner override is a separately authorized, reasoned, prominently audited event.

Audit actor, server timestamp, affected record, action, relevant before/after values, reason, approval and correlation ID. Protect ordinary updates/deletes; forward critical audit events to a separately protected destination where feasible. Do not claim immunity from infrastructure administrators.

Monitor login abuse, unusual exports, repeated refunds/discounts, stock anomalies, failed jobs and backup failures. Alerts are evidence for review, not proof of misconduct. Provide incident response, disable/revoke, evidence retention, secret rotation and recovery instructions.

At 23:30 Africa/Dar_es_Salaam each day, run a server-side job to produce the day-to-time PDF and create/verify a consistent recoverable database-and-file snapshot. After midnight, generate the final previous-day report. Version revisions for late-arriving transactions; flag unsynced devices.

The job must work when phones and browsers are closed. Use authenticated scheduled execution, run IDs, deduplication, bounded retries, last successful run, next run, integrity manifest and failure alert. Browser downloads are optional delivery, not the job mechanism.

Supabase database backup and Storage object backup are distinct concerns. Verify actual plan capabilities and implement protection for images/documents, an encrypted offsite copy, retention, independent credentials and restore testing. Daily retention target 30 days, monthly 12 months; desired RPO 15 minutes/RTO 4 hours require supported infrastructure, cost approval and evidence. Do not represent those targets as active by default.

Demonstrate isolated restoration including files, permissions and reconciled balances. A JSON/CSV export or PDF alone is not proof of recovery. Keep restore environments from sending actual messages/payments. Document backup key custody, account ownership and an exit export.

## 16. Optional catalogue, help and integrations

Defer the public Shop Link until core operations pass. Later provide an original branded catalogue/QR/WhatsApp inquiry flow using explicit publishable fields and verified stock policy. Do not publish buying costs, credit terms, private records or wholesale prices accidentally. Public inquiry/order intent must not automatically become a paid sale.

Use official supported WhatsApp/SMS/email/payment integrations. Owner enables destination, consent and schedule. Show configured/not configured, queued, provider accepted, delivered/verified and failed honestly. Do not claim a message was delivered merely because a share window opened.

Help should provide short role-specific instructions and a real configured contact. Keep profile/language/theme/security preferences. Remove referral marketing, software subscription-plan upselling, unnecessary academy pages and promotional support videos. Owner-only infrastructure costs/renewal notices can remain under Settings.

Offline work initially supports explicit drafts only unless a tested stock-allocation strategy is implemented. Never promise safe unlimited offline sales against shared inventory. Show queued/syncing/confirmed/conflicted states; sensitive approvals require online verification.

An optional AI assistant comes later, read-only at first. Enforce permissions before model retrieval, minimize/redact external data, identify sources/period/freshness, treat documents/messages as untrusted and never run unrestricted model-generated SQL. State missing data instead of inventing figures.

## 17. Acceptance tests and release evidence

Use a real PostgreSQL/Supabase test environment for transactional, RLS and concurrency tests, not only mocked responses. Keep it separate from production.

Prove at least:
1. Sales Staff, Manager, Storekeeper and Owner authenticate with their own normalized phone number and password and receive their server-authorized workspace; uninvited users cannot grant themselves access. Run the additional Section 4A activation, recovery and phone-security tests.
2. Cashier sessions cannot retrieve confidential cost/profit fields through table queries, RPC, APIs, reports, real-time events or files.
3. Storekeepers cannot alter collections/cost approval; Managers cannot self-escalate; inactive memberships lose protected access.
4. Location/client isolation works, including customer A versus B.
5. Two concurrent sales of the last unit produce only one valid commitment.
6. Retried requests/webhooks do not duplicate sale, stock, payment, deposit, return or refund; mismatched payload keys reject.
7. Partial payments, customer advances/credits, allocations, returns and refunds reconcile.
8. Transfers conserve company stock; consignment dispatch creates no sales/debt; 10 dispatched/6 sold/2 returned leaves 2 held.
9. Counts correctly account for intervening movements; inspection goods are not available until released.
10. No return/refund exceeds eligibility; approval is independent and invalidates on edit.
11. Deposits are not revenue/expense; runner advance settlement does not double-count costs.
12. Shift closure handles concurrent postings and excludes noncash methods from drawer cash.
13. Full-period reports reconcile with journals/ledgers across midnight and are not truncated.
14. Failed postings roll back every related entry; CSV duplicates/import retries do not silently corrupt stock.
15. Unknown cost does not produce misleading profit and parent design placeholders cannot bypass variant selection.
16. Scheduled backup runs without a browser; restore reproduces database/files and verified totals.
17. External integration failures never display false success.
18. Actual device, accessibility, PDF pagination and barcode decoder/hardware checks pass before their readiness is claimed.

Produce a relevant OWASP ASVS control-to-test map, test commands/results, actual load-test environment/results and remaining gaps. Do not invent certification, zero-error claims or performance numbers.

## 18. Execution milestones and completion criteria

Deliver sequentially:
A. Architecture, schema, original design system, Supabase Auth and essential role/location permissions.
B. Catalogue, size matrix, purchasing, standalone Store/Stoo panel, shop requisitions, stock custody and CSV/barcodes.
C. POS, payments, expenses, returns, cash accounts and shift reconciliation.
D. Mandatory standalone Wholesale Customers panel, consignment settlements, statements and Store/Shop reconciliation.
E. Full-period reporting, scheduled PDFs/backups and verified restoration.
F. Team targets, configured commissions, optional catalogue/integrations.
G. Security hardening, migration rehearsal, role/device testing and deployment handover.

For each milestone: implement working code, migrate safely, run meaningful tests, demonstrate behavior and update a capability matrix. Continue to the next milestone without asking “shall I continue?” when the work is already authorized. If session limits require pausing, save a concrete progress file listing exact completed work, failures and the next executable task.

Capability states: implemented and tested; implemented but unverified; needs external configuration; planned; unsupported. A frontend panel without its backend must not be called implemented. Account credentials, paid services, destructive actions and legally binding provider acceptance may require Owner involvement; make all independent work reviewable first.

Deliver the working staging app, source repository, reproducible setup, migrations, data dictionary, permission/approval matrix, stock/financial posting rules, test evidence, recovery evidence, incident/monitoring runbooks, migration/rollback plan and simple Owner/employee guides. Identify actual recurring cost components and assumptions; do not invent a fixed total.

All repository/hosting/database/storage/domain/integration accounts must be DIROMA-controlled. Developers receive revocable access. Keep provider keys out of chat and source. Explain only the secure setup steps the nontechnical Owner must perform.

Do not declare production readiness until critical workflows, direct access controls, opening balances, complete reporting and a restore rehearsal are verified. State any remaining limitations prominently and specifically.

## 19. NONTECHNICAL OWNER, TEST BEFORE PAYMENT, AND COMPLETE HOSTING HANDOVER

This section is a mandatory delivery requirement. The Owner has no coding, database, command-line, deployment or server-administration experience. Do not assume technical participation from the Owner. Implement the technical work using the tools actually available to you; be explicit when you cannot execute an action. Never claim that you connected, tested or deployed a service you cannot access.

### A. Owner interaction contract

- Explain progress and owner actions in plain Swahili; keep source code and technical documentation in English where appropriate.
- Give the Owner one small, concrete step at a time when a human action is necessary. State the service, exact screen/control, purpose, expected result and how to recognize success. Verify current provider UI/documentation instead of inventing button names.
- Do not hand the Owner SQL, migration errors, Git commands or configuration snippets and expect them to debug the system. Execute and verify such work yourself when tools permit. If execution is unavailable, identify the precise blocker and supply a packaged reproducible handover for a competent implementer.
- The Owner may need to create accounts, verify their email, enter credentials through a secure provider flow, enable MFA, approve costs and supply actual business policies/opening figures. Do not pretend those actions are already complete.
- Never request passwords, OTPs, recovery codes, card details or secret API keys in ordinary chat. Use approved secure credential/configuration mechanisms.
- When a test fails, diagnose and fix it, rerun the relevant tests and explain its business impact simply. Do not use the Owner as the first technical debugger.
- Maintain a short progress board: Completed, Testing, Blocked, Next. Record verifiable results rather than percentages unsupported by completed work.

### B. No hosting purchase required to begin

Use a development-first workflow. Do not ask the Owner to buy Supabase Pro, Vercel Pro, a custom domain or optional integrations before demonstrating meaningful functionality.

Use local development with a real isolated PostgreSQL/Supabase development environment, or a Supabase Free test project within its current limits. Confirm the permitted usage and current limits from official documentation. A free test project is a temporary test environment, not a claim that production reliability/recovery is configured.

Keep all synthetic sample records separate from real DIROMA data. No real customer reminders, money transfers, live charges or production inventory changes during acceptance testing.

Run the application in a permitted development/review environment. Do not assume Vercel Hobby is allowed for a commercial DIROMA project or its business-related staging. Use local development or another environment whose terms permit the use. Explain any optional trial, its expiry, card requirement and automatic billing before activation. Do not promise that a trial exists or is entirely free without verification.

The initial review must show working authentication, a persistent database and actual transactional tests. A clickable frontend alone does not satisfy the pre-payment review.

### C. Guided business acceptance rehearsal

Provide a simple Swahili walkthrough with expected outcomes:

1. Sign in separately with phone number and password as Sales Staff, Manager, Storekeeper and Owner; demonstrate equivalent valid local/international formatting and role-based routing.
2. Create a sample design with several sizes and receive sample stock.
3. Transfer a known quantity from warehouse to shop and confirm receipt.
4. Sell one unit; prove the selected size decreases once and the receipt/payment totals match.
5. Record a partial payment and later collect the remainder without creating another sale.
6. Dispatch 10 sample consignment units, settle 6, accept 2 unsold returns and show 2 still held.
7. Submit a return, require another authorized approver and inspect the returned goods.
8. Open/close a cash shift, explain a deliberately introduced variance and keep bank/mobile amounts separate.
9. Generate a customer statement and a full-period report that reconcile with the underlying events.
10. Demonstrate direct permission failures, not only hidden buttons.
11. Produce and restore a development backup into a separate environment and compare the restored records/files.
12. Disconnect the network briefly and show the actual draft/retry behavior without duplicate transactions.

Report each scenario as Pass, Fail or Not Tested with evidence. Keep a separate synthetic-data automated test suite covering the financial and security invariants already specified.

Some production capabilities can only be verified after a paid plan/provider is enabled, such as the selected managed recovery option, production email delivery, actual domain callbacks or provider-side scheduled execution. Clearly distinguish:
- Verified before payment.
- Requires production configuration.
- Verified after deployment.

Do not mark production-dependent features as passed based only on local mocks. A successful local restore is useful evidence but does not prove hosted disaster recovery.

### D. Concrete purchase and deployment gate

After the pre-payment review passes, present a concrete deployment package:
- Working review version and acceptance results.
- Remaining production configuration and test steps.
- The exact hosting/database plans proposed and verified current recurring costs.
- Taxes, usage-based charges, additional projects, email, backups, messaging, domains and optional add-ons identified separately.
- Cost alerts/limits and the service interruption consequences of any hard spending cap.
- Account ownership, access delegation and recovery arrangements.
- Migration, go-live and rollback plan.

Only activate paid services after explicit approval of the actual plans/costs. This approval must not be interpreted as permission to buy unlimited add-ons. The Owner completes binding provider/payment steps securely where necessary.

Supabase Pro remains the intended production database/auth/storage service. Upgrade an eligible project or create a separate production project through a documented migration, whichever preserves test/production separation and reduces risk. Do not assume upgrading is a safe substitute for environment separation, and do not silently overwrite test or live data. Explain the compute cost of extra projects.

### E. End-to-end server setup responsibilities

Complete and verify the following as authorized and supported:
1. Establish DIROMA-controlled provider and source-repository ownership; enable account MFA and secure recovery.
2. Select appropriate database and application regions using documented availability and measured performance, while considering applicable data-location obligations. Do not choose a region on geographical distance alone.
3. Create production configuration, private storage, migrations, role policies and restricted service credentials.
4. Configure app hosting, environment variables, connection pooling and production Auth callback/redirect URLs.
5. Configure and test actual phone/password login and the approved phone activation/recovery method. If SMS is selected, configure its provider only after cost approval and verify real delivery. Employee email is optional; provider/billing administration or optional notifications may separately use Owner email.
6. Configure HTTPS and a provider-issued address; a custom domain is optional until the Owner chooses to buy/use one.
7. Configure authenticated schedules, monitoring, alerts, database/file recovery and an isolated hosted restore test.
8. Execute production smoke tests without artificial business revenue or unwanted messages; document cleanup of designated disposable test records and preserve required audits.
9. Reconcile verified opening stock, debts, cash/account balances and partner custody before accepting real transactions.
10. Give the Owner the working login link, demonstrate adding/disabling staff through the app, and confirm access to the provider/repository accounts.

Any step needing a human-controlled account, payment, legal acceptance or unavailable tool must remain visibly pending until completed. Do not hide it behind a working-looking button.

### F. Shop launch and maintenance

Provide short Swahili guides for Owner, Manager, Sales Staff and Storekeeper. Include screen-based instructions for their essential daily jobs. Keep technical infrastructure details out of ordinary staff screens unless they affect a decision.

Pilot with a small, known product set and agreed users. Keep the existing operational record during the pilot, choose one authoritative posting process for each sale and reconcile daily; do not let parallel systems silently deduct shared stock twice.

Define the conditions for full migration, an escalation contact/process and a rollback/export procedure. Address patches, monitoring, failed backups, account suspension, routine reconciliation and who will actually provide maintenance. Do not invent a staffed support team or guarantee free ongoing maintenance.

Final Owner handover must answer in plain language:
- Where do I sign in?
- How do I add, restrict or disable a worker?
- How do I record sales, receive/transfer stock and follow wholesale partners?
- Where do I see money, reports and cash differences?
- How do I know backups succeeded, and who can restore them?
- What do I pay, when, and to whom?
- What do I do if the app or internet is unavailable?
- Who owns the source, data and provider accounts?
- What is still incomplete or unverified?

The project is complete only when the implemented scope is operationally usable and the handover is accurate. Do not claim zero risk or guaranteed absence of errors. Optimize for verified correctness, clear ownership and manageable daily operations.


START NOW: inspect the project and tools, establish a no-hosting-payment development/test path, and begin Milestone A. Build DIROMA's original design and real phone-number-and-password login/workspaces for Owner, Manager, Sales Staff and Storekeeper. Maintain a living implementation checklist. Follow Section 19 for the nontechnical Owner, acceptance testing before purchases, secure provider setup and full handover.

--- END CLAUDE MASTER PROMPT ---
