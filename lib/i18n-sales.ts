import type { Lang } from "./i18n";

const sw = {
  pos: {
    title: "Uza (POS)", openShift: "Fungua zamu", openShiftIntro: "Hesabu pesa iliyopo kwenye droo kabla ya kuanza kuuza.",
    shop: "Duka", drawer: "Droo ya pesa", float: "Pesa ya kuanzia (float)", noDrawer: "Duka hili halina droo ya pesa. Owner aiunde kwenye Fedha → Akaunti.",
    search: "Tafuta: code, jina, rangi, barcode", chooseSize: "Chagua saizi", inStock: "zipo", cart: "Kikapu", empty: "Kikapu kiko tupu",
    customer: "Mteja", walkIn: "Mteja wa kupita (walk-in)", channel: "Bei", retail: "Rejareja", wholesale: "Jumla",
    discount: "Punguzo (TZS)", delivery: "Peleka kwa mteja", deliveryFee: "Gharama ya kupeleka", total: "Jumla", paid: "Imelipwa",
    due: "Inadaiwa", payments: "Malipo", addPayment: "Ongeza njia ya malipo", payAll: "Lipa yote", method: "Njia", amount: "Kiasi",
    customerCredit: "Salio la mteja", submit: "Kamilisha mauzo", approvalNeeded: "Inahitaji idhini ya Meneja",
    approvalWhy: { discount: "punguzo kubwa", backdate: "tarehe ya nyuma", credit_limit: "mkopo juu ya kikomo" } as Record<string, string>,
    checkApproval: "Nimeidhinishwa — kamilisha", posted: "Mauzo yamekamilika", newSale: "Mauzo mapya", printReceipt: "Chapisha risiti",
    backdate: "Mauzo yaliyosahaulika (tarehe/saa halisi)", note: "Maelezo", source: "Mteja ametoka wapi", myShift: "Zamu yangu",
    providerRef: "Namba ya muamala (M-Pesa/benki)", unpriced: "haina bei",
  },
  shift: {
    title: "Zamu yangu", opened: "Ilifunguliwa", salesCount: "Mauzo", salesTotal: "Jumla ya mauzo", byMethod: "Kwa njia ya malipo",
    close: "Funga zamu", counted: "Pesa taslimu uliyohesabu kwenye droo", reason: "Maelezo ya tofauti (kama ipo)",
    closedOk: "Zamu imefungwa.", expected: "Inatarajiwa", variance: "Tofauti", noShift: "Huna zamu iliyo wazi.",
    blind: "Hesabu pesa kwanza; mfumo utaonyesha kinachotarajiwa baada ya kuhesabu.",
  },
  sales: {
    title: "Mauzo", receipt: "Risiti", date: "Tarehe", cashier: "Muuzaji", status: "Malipo", fulfilment: "Kupeleka",
    lines: "Bidhaa", qty: "Idadi", price: "Bei", lineTotal: "Jumla", settlements: "Malipo yaliyopokelewa",
    requestReturn: "Omba kurudisha", returnQty: "Idadi ya kurudisha", settlement: "Malipo ya marejesho",
    credit: "Salio kwa mteja (credit note)", refund: "Rudisha pesa", reason: "Sababu", markDelivered: "Imefika", markFailed: "Haikufika",
    returns: "Marejesho", deliveryNote: "Bidhaa zisizofika hurudi kupitia marejesho + ukaguzi, si moja kwa moja stoo.",
  },
  customers: {
    title: "Wateja", newCustomer: "Mteja mpya", name: "Jina", phone: "Simu", kind: "Aina", retail: "Rejareja", wholesale: "Jumla",
    creditLimit: "Kikomo cha mkopo (TZS)", terms: "Siku za mkopo", region: "Mkoa", source: "Chanzo", notes: "Maelezo",
    receivable: "Anadaiwa", credit: "Salio lake", oldest: "Deni la zamani zaidi", openSales: "Mauzo yasiyolipwa",
    collect: "Pokea malipo", account: "Akaunti", amount: "Kiasi", collectNote: "Malipo yanalipa deni la zamani kwanza. Ziada inakuwa salio la mteja, si mauzo mapya.",
    save: "Hifadhi", history: "Historia",
  },
  money: {
    title: "Fedha", accounts: "Akaunti", transfers: "Kuweka benki / uhamisho", expenses: "Matumizi", shifts: "Zamu", advances: "Posho za usafirishaji",
    journal: "Journal", balance: "Salio (kwa rekodi)", newAccount: "Akaunti mpya", code: "Code", name: "Jina", kind: "Aina", location: "Duka (kwa cash)",
    opening: "Salio la kuanzia", asOf: "Tarehe", reason: "Sababu", unreconciled: "Salio kwa rekodi za mfumo — halijalinganishwa na statement ya benki/M-Pesa.",
    from: "Kutoka", to: "Kwenda", amount: "Kiasi", reference: "Namba ya slip / rejea", evidence: "Ushahidi (maelezo)", send: "Tuma",
    confirm: "Thibitisha kupokea", fee: "Ada (TZS)", inTransit: "Njiani", transferNote: "Kuweka benki ni uhamisho wa mali — si mapato wala matumizi.",
    category: "Aina ya matumizi", payee: "Aliyelipwa", description: "Maelezo", date: "Tarehe", request: "Omba", approve: "Idhinisha",
    reject: "Kataa", pay: "Lipa", status: "Hali", review: "Kagua zamu", reviewNote: "Maelezo ya ukaguzi",
    runner: "Msafirishaji (jina)", sale: "Mauzo (hiari)", issue: "Toa posho", settle: "Funga posho", spent: "Ilitumika",
    returned: "Imerudishwa", receiptNote: "Ushahidi (risiti, aliyepokea)",
    cash: "Taslimu", mobile: "Simu (M-Pesa n.k.)", bank: "Benki",
  },
  approvals: {
    title: "Idhini", sales: "Mauzo yanayohitaji idhini", returns: "Marejesho", expenses: "Matumizi", shifts: "Zamu zenye tofauti",
    mine: "Maombi yangu", none: "Hakuna kinachosubiri.", approve: "Idhinisha", reject: "Kataa", note: "Maelezo / sababu",
    requested: "Ameomba", amount: "Kiasi", reasons: "Sababu", status: "Hali",
  },
  inspection: { title: "Ukaguzi wa marejesho", restock: "Rudisha dukani", quarantine: "Zimeharibika", reason: "Matokeo ya ukaguzi" },
  overview: {
    today: "Leo", month: "Mwezi huu", netSales: "Mauzo halisi", netSalesNote: "kwa tarehe ya mauzo, baada ya marejesho",
    collections: "Makusanyo", collectionsNote: "kwa tarehe ya malipo", oldDebt: "ambayo ni madeni ya zamani",
    grossProfit: "Faida ghafi", costIncomplete: "vipande vimeuzwa bila gharama inayojulikana — faida haijakamilika",
    cash: "Pesa", receivables: "Madeni ya wateja", credits: "Salio za wateja", stock: "Stoki inayouzika", stockValue: "Thamani ya stoki (gharama)",
    notSaleable: "njiani / ukaguzi / zilizoharibika", noCost: "bila gharama", expenses: "Matumizi", approvals: "Idhini zinazosubiri",
    shifts: "Zamu wazi", reviews: "Zamu zinasubiri ukaguzi", inTransit: "Pesa njiani",
  },
};

type SalesDict = typeof sw;

const en: SalesDict = {
  pos: {
    title: "Sell (POS)", openShift: "Open shift", openShiftIntro: "Count the cash in the drawer before you start selling.",
    shop: "Shop", drawer: "Cash drawer", float: "Opening float", noDrawer: "This shop has no cash drawer yet. The Owner creates it in Money → Accounts.",
    search: "Search: code, name, colour, barcode", chooseSize: "Choose size", inStock: "in stock", cart: "Cart", empty: "Cart is empty",
    customer: "Customer", walkIn: "Walk-in customer", channel: "Price", retail: "Retail", wholesale: "Wholesale",
    discount: "Discount (TZS)", delivery: "Deliver to customer", deliveryFee: "Delivery fee", total: "Total", paid: "Paid",
    due: "Due", payments: "Payments", addPayment: "Add payment method", payAll: "Pay all", method: "Method", amount: "Amount",
    customerCredit: "Customer credit", submit: "Complete sale", approvalNeeded: "Needs a manager's approval",
    approvalWhy: { discount: "large discount", backdate: "past date", credit_limit: "credit above limit" },
    checkApproval: "Approved — complete sale", posted: "Sale completed", newSale: "New sale", printReceipt: "Print receipt",
    backdate: "Missed sale (actual date/time)", note: "Note", source: "Customer came from", myShift: "My shift",
    providerRef: "Transaction no. (M-Pesa/bank)", unpriced: "no price",
  },
  shift: {
    title: "My shift", opened: "Opened", salesCount: "Sales", salesTotal: "Sales total", byMethod: "By payment method",
    close: "Close shift", counted: "Cash you counted in the drawer", reason: "Explain any difference",
    closedOk: "Shift closed.", expected: "Expected", variance: "Variance", noShift: "You have no open shift.",
    blind: "Count the cash first; the system shows what was expected after you count.",
  },
  sales: {
    title: "Sales register", receipt: "Receipt", date: "Date", cashier: "Cashier", status: "Payment", fulfilment: "Delivery",
    lines: "Items", qty: "Qty", price: "Price", lineTotal: "Total", settlements: "Payments received",
    requestReturn: "Request return", returnQty: "Qty to return", settlement: "Settle return by",
    credit: "Customer credit (credit note)", refund: "Refund money", reason: "Reason", markDelivered: "Delivered", markFailed: "Failed",
    returns: "Returns", deliveryNote: "Undelivered goods come back through a return + inspection, never straight into stock.",
  },
  customers: {
    title: "Customers", newCustomer: "New customer", name: "Name", phone: "Phone", kind: "Type", retail: "Retail", wholesale: "Wholesale",
    creditLimit: "Credit limit (TZS)", terms: "Credit days", region: "Region", source: "Source", notes: "Notes",
    receivable: "Owes", credit: "Credit balance", oldest: "Oldest open debt", openSales: "Unpaid sales",
    collect: "Collect payment", account: "Account", amount: "Amount", collectNote: "Payments clear the oldest debt first. Any extra becomes customer credit, not new sales.",
    save: "Save", history: "History",
  },
  money: {
    title: "Money", accounts: "Accounts", transfers: "Deposits / transfers", expenses: "Expenses", shifts: "Shifts", advances: "Delivery advances",
    journal: "Journal", balance: "Balance (per records)", newAccount: "New account", code: "Code", name: "Name", kind: "Type", location: "Shop (for cash)",
    opening: "Opening balance", asOf: "As of", reason: "Reason", unreconciled: "Book balances from system records — not yet reconciled to bank/M-Pesa statements.",
    from: "From", to: "To", amount: "Amount", reference: "Slip / reference no.", evidence: "Evidence (note)", send: "Send",
    confirm: "Confirm received", fee: "Fee (TZS)", inTransit: "In transit", transferNote: "A deposit is an asset transfer — not revenue and not an expense.",
    category: "Category", payee: "Payee", description: "Description", date: "Date", request: "Request", approve: "Approve",
    reject: "Reject", pay: "Pay", status: "Status", review: "Review shift", reviewNote: "Review note",
    runner: "Runner (name)", sale: "Sale (optional)", issue: "Issue advance", settle: "Settle advance", spent: "Spent",
    returned: "Returned", receiptNote: "Evidence (receipt, recipient)",
    cash: "Cash", mobile: "Mobile money", bank: "Bank",
  },
  approvals: {
    title: "Approvals", sales: "Sales needing approval", returns: "Returns", expenses: "Expenses", shifts: "Shifts with a variance",
    mine: "My requests", none: "Nothing waiting.", approve: "Approve", reject: "Reject", note: "Note / reason",
    requested: "Requested by", amount: "Amount", reasons: "Reasons", status: "Status",
  },
  inspection: { title: "Returns inspection", restock: "Back to shop", quarantine: "Damaged", reason: "Inspection result" },
  overview: {
    today: "Today", month: "This month", netSales: "Net sales", netSalesNote: "by sale date, after returns",
    collections: "Collections", collectionsNote: "by payment date", oldDebt: "of which old debt",
    grossProfit: "Gross profit", costIncomplete: "units sold without a known cost — profit incomplete",
    cash: "Money", receivables: "Customer debts", credits: "Customer credits", stock: "Saleable stock", stockValue: "Stock value (cost)",
    notSaleable: "in transit / inspection / damaged", noCost: "without cost", expenses: "Expenses", approvals: "Pending approvals",
    shifts: "Open shifts", reviews: "Shifts awaiting review", inTransit: "Money in transit",
  },
};

export const SALES_DICTS: Record<Lang, SalesDict> = { sw, en };
export type { SalesDict };
