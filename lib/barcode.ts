import "server-only";
import bwipjs from "bwip-js/node";

/** Code 128 label SVG (no price encoded or printed). Barcode text is stored and rendered verbatim. */
export function barcodeSvg(text: string): string {
  return bwipjs.toSVG({ bcid: "code128", text, scale: 2, height: 12, includetext: true, textxalign: "center" });
}

/** QR code SVG for a URL (e.g. the public catalogue). */
export function qrSvg(text: string): string {
  return bwipjs.toSVG({ bcid: "qrcode", text, scale: 3 });
}
