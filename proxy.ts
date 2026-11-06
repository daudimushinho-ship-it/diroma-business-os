import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

const PUBLIC_PATHS = ["/login", "/activate", "/setup", "/forbidden", "/lang", "/c"];

/**
 * Per-request Content-Security-Policy (Next.js 16 proxy pattern):
 *  - scripts: only with this request's nonce ('strict-dynamic'); no inline/eval in production
 *  - styles: self + inline (style attributes for progress bars/SVG); no remote styles
 *  - connections: self + the Supabase project (browser MFA calls)
 *  - no framing, no plugins, forms post only to self
 */
function csp(nonce: string, https: boolean): string {
  const supabase = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const ws = supabase.replace(/^https:/, "wss:");
  const dev = process.env.NODE_ENV === "development";
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ""}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' blob: data:",
    "font-src 'self'",
    `connect-src 'self'${supabase ? ` ${supabase} ${ws}` : ""}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    ...(https ? ["upgrade-insecure-requests"] : []),
  ].join("; ");
}

/** Refreshes the Supabase session cookie, sends unauthenticated visitors to /login, and applies the CSP. */
export async function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");
  const https = request.nextUrl.protocol === "https:" || request.headers.get("x-forwarded-proto") === "https";
  const policy = csp(nonce, https);
  const next = () => {
    const headers = new Headers(request.headers);
    headers.set("x-nonce", nonce);
    headers.set("Content-Security-Policy", policy);
    return NextResponse.next({ request: { headers } });
  };
  const finish = (res: NextResponse) => { res.headers.set("Content-Security-Policy", policy); return res; };

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const isPublic = PUBLIC_PATHS.some((p) => request.nextUrl.pathname === p || request.nextUrl.pathname.startsWith(p + "/"));

  if (!url || !key) {
    if (isPublic) return finish(next());
    const to = request.nextUrl.clone();
    to.pathname = "/login";
    to.search = "?e=not_configured";
    return finish(NextResponse.redirect(to));
  }

  let response = next();
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (toSet) => {
        toSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = next();
        toSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const { data } = await supabase.auth.getUser();
  if (!data.user && !isPublic) {
    const to = request.nextUrl.clone();
    to.pathname = "/login";
    to.search = "";
    return finish(NextResponse.redirect(to));
  }
  return finish(response);
}

export const config = {
  matcher: [
    {
      source: "/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp|ico)$).*)",
      missing: [{ type: "header", key: "next-router-prefetch" }, { type: "header", key: "purpose", value: "prefetch" }],
    },
  ],
};
