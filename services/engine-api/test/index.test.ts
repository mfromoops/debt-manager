import { describe, expect, it } from "vitest";
import worker from "../src/index";

const env = { ALLOWED_ORIGIN: "https://example.com" };
const debt = { id: "card", name: "Card", balance: 1000, annualRate: 0, monthlyPayment: 100, startDate: "2026-08-01" };

describe("worker API", () => {
  it("serves health and CORS preflight", async () => {
    const health = await worker.fetch(new Request("https://engine.test/health"), env);
    expect(health.status).toBe(200);
    expect(await health.json() as { ok: boolean; service: string }).toMatchObject({ ok: true, service: "debt-engine-api" });
    const options = await worker.fetch(new Request("https://engine.test/v1/simulations", { method: "OPTIONS" }), env);
    expect(options.status).toBe(204);
    expect(options.headers.get("access-control-allow-origin")).toBe("https://example.com");
  });

  it("runs a simulation and returns stable errors", async () => {
    const request = new Request("https://engine.test/v1/simulations", { method: "POST", body: JSON.stringify({ debts: [debt], strategy: { method: "minimumOnly" } }) });
    const result = await worker.fetch(request, env);
    expect(result.status).toBe(200);
    expect((await result.json() as { summary: { monthsToDebtFree: number } }).summary.monthsToDebtFree).toBe(10);
    const invalid = await worker.fetch(new Request("https://engine.test/v1/simulations", { method: "POST", body: "{" }), env);
    expect(invalid.status).toBe(400);
    expect((await invalid.json() as { error: { code: string } }).error.code).toBe("INVALID_REQUEST");
  });

  it("rejects invalid nested dates, extras, and strategy values", async () => {
    const body = { debts: [{ ...debt, startDate: "2026-02-30", extras: [{ cadence: "everyNWeeks", amount: 10, interval: 0 }] }], strategy: { method: "avalanche", startDate: "not-a-date" } };
    const result = await worker.fetch(new Request("https://engine.test/v1/simulations", { method: "POST", body: JSON.stringify(body) }), env);
    expect(result.status).toBe(400);
    expect((await result.json() as { error: { field?: string; message: string } }).error.message).toContain("startDate");
  });
});
