import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFPage } from "pdf-lib";

export type PdfColumn = { label: string; width: number; align?: "left" | "right" };
export type PdfSection = { heading: string; columns?: PdfColumn[]; rows?: (string | number | null)[][]; totals?: (string | number | null)[]; lines?: string[] };
export type PdfReport = {
  title: string; subtitle?: string; period: string; timezone: string; generatedAt: string; generatedBy: string; reference: string;
  filters?: string; sections: PdfSection[]; notes?: string[];
};

const A4: [number, number] = [595.28, 841.89];
const M = 40;
const ESPRESSO = rgb(0.176, 0.11, 0.094);
const MUTED = rgb(0.42, 0.37, 0.35);
const LINE = rgb(0.9, 0.88, 0.83);

/** Standard PDF fonts only cover WinAnsi; map common symbols, drop anything else. */
export function pdfSafe(s: unknown): string {
  return String(s ?? "")
    .replace(/[→⇒]/g, "->").replace(/[←]/g, "<-").replace(/[×]/g, "x").replace(/[≤]/g, "<=").replace(/[≥]/g, ">=")
    .replace(/[−–]/g, "-").replace(/[Σ]/g, "Total").replace(/[✓]/g, "OK").replace(/[⚠]/g, "!").replace(/[·]/g, "-")
    .replace(/[^\x20-\x7E -ÿ—‘’“”•…€]/g, "");
}

export function fmtNum(v: string | number | null | undefined): string {
  if (v === null || v === undefined || v === "") return "";
  if (typeof v === "number") return Math.round(v).toLocaleString("en-US");
  return String(v);
}

function fit(font: PDFFont, text: string, size: number, width: number): string {
  let t = pdfSafe(text);
  if (font.widthOfTextAtSize(t, size) <= width) return t;
  while (t.length > 1 && font.widthOfTextAtSize(t + "...", size) > width) t = t.slice(0, -1);
  return t + "...";
}

/** Renders a branded, paginated report: header, sections with tables (header repeated per page), totals, "Page X of Y". */
export async function renderReportPdf(r: PdfReport): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle(pdfSafe(`DIROMA - ${r.title}`)); doc.setAuthor("DIROMA Business OS"); doc.setCreationDate(new Date(r.generatedAt));
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const W = A4[0] - 2 * M;
  let page: PDFPage = doc.addPage(A4);
  let y = A4[1] - M;

  const text = (t: string, x: number, size = 9, f: PDFFont = font, color = ESPRESSO) => page.drawText(pdfSafe(t), { x, y, size, font: f, color });
  const newPage = () => { page = doc.addPage(A4); y = A4[1] - M; };
  const ensure = (h: number, onBreak?: () => void) => { if (y - h < M + 24) { newPage(); onBreak?.(); } };

  // header (first page)
  text("DIROMA", M, 20, bold); y -= 12;
  text("Spirit of Fashion - Kariakoo, Dar es Salaam", M, 8, font, MUTED); y -= 22;
  text(r.title, M, 15, bold); y -= 15;
  if (r.subtitle) { text(r.subtitle, M, 9, font, MUTED); y -= 12; }
  for (const meta of [`Period: ${r.period}  |  Timezone: ${r.timezone}  |  Currency: TZS (whole shillings)`,
    `Generated: ${r.generatedAt} by ${r.generatedBy}  |  Ref: ${r.reference}`, ...(r.filters ? [`Filters: ${r.filters}`] : [])]) {
    text(meta, M, 8, font, MUTED); y -= 11;
  }
  y -= 8;

  for (const s of r.sections) {
    ensure(40);
    page.drawLine({ start: { x: M, y: y + 4 }, end: { x: M + W, y: y + 4 }, thickness: 0.6, color: LINE });
    y -= 10; text(s.heading, M, 11, bold); y -= 14;
    for (const l of s.lines ?? []) { ensure(12); text(l, M, 9); y -= 12; }
    if (s.columns && s.rows) {
      const cols = s.columns; const total = cols.reduce((a, c) => a + c.width, 0);
      const xs: number[] = []; let acc = M; for (const c of cols) { xs.push(acc); acc += (c.width / total) * W; }
      const widths = cols.map((c) => (c.width / total) * W - 4);
      const drawRow = (cells: (string | number | null)[], f: PDFFont, size = 8) => {
        cells.forEach((v, i) => {
          const s2 = fit(f, typeof v === "number" ? fmtNum(v) : String(v ?? ""), size, widths[i]);
          const x = cols[i].align === "right" ? xs[i] + widths[i] - f.widthOfTextAtSize(s2, size) : xs[i];
          page.drawText(s2, { x, y, size, font: f, color: ESPRESSO });
        });
      };
      const header = () => { drawRow(cols.map((c) => c.label), bold, 8); y -= 4; page.drawLine({ start: { x: M, y }, end: { x: M + W, y }, thickness: 0.4, color: LINE }); y -= 10; };
      header();
      for (const row of s.rows) { ensure(12, header); drawRow(row, font); y -= 11; }
      if (s.totals) { ensure(14, header); page.drawLine({ start: { x: M, y: y + 8 }, end: { x: M + W, y: y + 8 }, thickness: 0.6, color: ESPRESSO }); drawRow(s.totals, bold); y -= 13; }
      if (!s.rows.length) { text("(no records in this period)", M, 8, font, MUTED); y -= 11; }
    }
    y -= 8;
  }
  for (const n of r.notes ?? []) { ensure(12); text(n, M, 7.5, font, MUTED); y -= 10; }

  const pages = doc.getPages();
  pages.forEach((p, i) => {
    const footer = pdfSafe(`DIROMA Business OS  |  ${r.reference}  |  Page ${i + 1} of ${pages.length}`);
    p.drawText(footer, { x: M, y: M - 18, size: 7.5, font, color: MUTED });
  });
  return doc.save();
}
