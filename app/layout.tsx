import type { Metadata, Viewport } from "next";
import "./globals.css";
import { getLang } from "@/lib/lang";

export const metadata: Metadata = {
  title: { default: "DIROMA Business OS", template: "%s · DIROMA" },
  description: "DIROMA Business OS — Spirit of Fashion",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = { themeColor: "#2d1c18", width: "device-width", initialScale: 1 };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const lang = await getLang();
  return (
    <html lang={lang}>
      <body className="min-h-dvh">{children}</body>
    </html>
  );
}
