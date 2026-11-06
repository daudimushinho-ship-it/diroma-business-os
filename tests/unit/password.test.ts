import { describe, expect, it } from "vitest";
import { checkNewPassword, generateOneTimeCode, normalizeCode } from "@/lib/password";

describe("checkNewPassword", () => {
  it("requires at least 12 characters", () => {
    expect(checkNewPassword("short-pass1", "short-pass1")).toEqual({ ok: false, error: "password_too_short" });
    expect(checkNewPassword("long enough phrase", "long enough phrase")).toEqual({ ok: true });
  });
  it("requires confirmation to match exactly, without trimming", () => {
    expect(checkNewPassword("correct horse battery ", "correct horse battery")).toEqual({ ok: false, error: "password_mismatch" });
  });
  it("counts unicode characters, not bytes, for the minimum", () => {
    expect(checkNewPassword("nenosiri😀😀😀😀", "nenosiri😀😀😀😀").ok).toBe(true);
  });
  it("rejects passwords over the 72-byte hashing limit", () => {
    const p = "a".repeat(73);
    expect(checkNewPassword(p, p)).toEqual({ ok: false, error: "password_too_long" });
  });
});

describe("one-time codes", () => {
  it("are 10 unambiguous characters and not repeated", () => {
    const codes = new Set(Array.from({ length: 500 }, () => generateOneTimeCode()));
    expect(codes.size).toBe(500);
    for (const c of codes) expect(c).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{10}$/);
  });
  it("normalizes what people type", () => {
    expect(normalizeCode(" abcde-fgh23 ")).toBe("ABCDEFGH23");
  });
});
