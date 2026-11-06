import { describe, expect, it, vi } from "vitest";
import bwipjs from "bwip-js/node";
import { PNG } from "pngjs";
import { BarcodeFormat, BinaryBitmap, DecodeHintType, HybridBinarizer, MultiFormatReader, RGBLuminanceSource } from "@zxing/library";

vi.mock("server-only", () => ({}));

/** Render the exact barcode settings used for labels, then decode with an independent reader (ZXing). */
async function roundTrip(text: string): Promise<string> {
  const png = PNG.sync.read(await bwipjs.toBuffer({ bcid: "code128", text, scale: 3, height: 12, paddingwidth: 10, paddingheight: 10, backgroundcolor: "FFFFFF" }));
  const lum = new Uint8ClampedArray(png.width * png.height);
  for (let i = 0; i < lum.length; i++) lum[i] = png.data[i * 4]; // greyscale: take red channel
  const source = new RGBLuminanceSource(lum, png.width, png.height);
  const reader = new MultiFormatReader();
  reader.setHints(new Map<DecodeHintType, unknown>([[DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.CODE_128]], [DecodeHintType.TRY_HARDER, true]]));
  return reader.decode(new BinaryBitmap(new HybridBinarizer(source))).getText();
}

describe("barcode labels", () => {
  it.each(["DR00100001", "DR00100042", "0001234567", "DR#2516-43"])("decodes back to the stored text exactly: %s", async (text) => {
    expect(await roundTrip(text)).toBe(text);
  });

  it("label SVG renders and contains no price", async () => {
    const { barcodeSvg } = await import("@/lib/barcode");
    const svg = barcodeSvg("DR00100001");
    expect(svg.startsWith("<svg")).toBe(true);
    expect(svg).not.toMatch(/TZS|price/i);
  });
});

describe("catalogue QR code", () => {
  it("decodes back to the public catalogue URL", async () => {
    const url = "https://diroma.example/c/diroma";
    const png = PNG.sync.read(await bwipjs.toBuffer({ bcid: "qrcode", text: url, scale: 4, paddingwidth: 8, paddingheight: 8, backgroundcolor: "FFFFFF" }));
    const lum = new Uint8ClampedArray(png.width * png.height);
    for (let i = 0; i < lum.length; i++) lum[i] = png.data[i * 4];
    const reader = new MultiFormatReader();
    reader.setHints(new Map<DecodeHintType, unknown>([[DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.QR_CODE]]]));
    expect(reader.decode(new BinaryBitmap(new HybridBinarizer(new RGBLuminanceSource(lum, png.width, png.height)))).getText()).toBe(url);
  });
});
