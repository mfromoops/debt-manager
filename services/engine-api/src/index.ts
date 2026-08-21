import { simulate, type Debt, type Strategy, type Result } from "./engine";
export interface Env { ALLOWED_ORIGIN?: string }
const disclaimer = "Illustrative projection based on the supplied inputs; not financial advice."; const headers = (env: Env): HeadersInit => ({ "content-type": "application/json", "access-control-allow-origin": env.ALLOWED_ORIGIN ?? "http://localhost:4321", "access-control-allow-methods": "GET,POST,OPTIONS", "access-control-allow-headers": "content-type" }); const response = (body: unknown, status: number, env: Env, requestId: string) => new Response(JSON.stringify(body), { status, headers: { ...headers(env), "x-request-id": requestId } }); const fail = (code: string, message: string, status: number, env: Env, requestId: string, field?: string) => response({ error: { code, message, ...(field ? { field } : {}) }, requestId }, status, env, requestId);
function validDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}
function validateExtra(extra: any, field: string): string | undefined {
  const cadences = ["monthly", "annual", "everyNMonths", "everyNWeeks", "oneTime"];
  if (!extra || !cadences.includes(extra.cadence)) return `${field}.cadence is unsupported`;
  if (typeof extra.amount !== "number" || !Number.isFinite(extra.amount) || extra.amount <= 0) return `${field}.amount must be a finite positive number`;
  if (extra.startDate !== undefined && !validDate(extra.startDate)) return `${field}.startDate must be a valid ISO date`;
  if (extra.oneTimeDate !== undefined && !validDate(extra.oneTimeDate)) return `${field}.oneTimeDate must be a valid ISO date`;
  if (["everyNMonths", "everyNWeeks"].includes(extra.cadence) && (!Number.isInteger(extra.interval) || extra.interval < 1 || extra.interval > 120)) return `${field}.interval must be an integer from 1 to 120`;
  if (extra.cadence === "annual" && (!Number.isInteger(extra.annualMonth) || extra.annualMonth < 1 || extra.annualMonth > 12)) return `${field}.annualMonth must be from 1 to 12`;
  if (extra.enabled !== undefined && typeof extra.enabled !== "boolean") return `${field}.enabled must be boolean`;
}
function validateStrategy(strategy: any, field: string): string | undefined {
  if (!strategy || !["minimumOnly", "avalanche", "snowball"].includes(strategy.method)) return `${field}.method is unsupported`;
  if (strategy.extraMonthlyBudget !== undefined && (typeof strategy.extraMonthlyBudget !== "number" || !Number.isFinite(strategy.extraMonthlyBudget) || strategy.extraMonthlyBudget < 0)) return `${field}.extraMonthlyBudget must be a finite non-negative number`;
  if (strategy.startDate !== undefined && !validDate(strategy.startDate)) return `${field}.startDate must be a valid ISO date`;
}
function validate(body: any, compare = false): string | undefined {
  if (!body || !Array.isArray(body.debts) || body.debts.length < 1 || body.debts.length > 20) return "debts must contain between 1 and 20 items";
  const ids = new Set<string>();
  for (const [i, d] of body.debts.entries()) {
    const field = `debts[${i}]`;
    if (typeof d.id !== "string" || d.id.length < 1 || d.id.length > 64 || ids.has(d.id)) return `${field}.id must be unique and 1–64 characters`;
    ids.add(d.id);
    if (typeof d.name !== "string" || d.name.length < 1 || d.name.length > 120) return `${field}.name must be 1–120 characters`;
    for (const k of ["balance", "annualRate", "monthlyPayment"]) if (typeof d[k] !== "number" || !Number.isFinite(d[k]) || d[k] < 0) return `${field}.${k} must be a finite non-negative number`;
    if (d.annualRate > 1000) return `${field}.annualRate must not exceed 1000`;
    if (!validDate(d.startDate)) return `${field}.startDate must be a valid ISO date`;
    if (d.paymentMode !== undefined && !["amortized", "fixedPayment"].includes(d.paymentMode)) return `${field}.paymentMode is unsupported`;
    if (d.termMonths !== undefined && (!Number.isInteger(d.termMonths) || d.termMonths < 1 || d.termMonths > 1200)) return `${field}.termMonths must be an integer from 1 to 1200`;
    if (d.extras !== undefined) { if (!Array.isArray(d.extras) || d.extras.length > 20) return `${field}.extras must contain at most 20 items`; for (const [j, extra] of d.extras.entries()) { const invalid = validateExtra(extra, `${field}.extras[${j}]`); if (invalid) return invalid; } }
  }
  if (compare) { if (!Array.isArray(body.strategies) || body.strategies.length < 1 || body.strategies.length > 5) return "strategies must contain between 1 and 5 items"; for (const [i, strategy] of body.strategies.entries()) { const invalid = validateStrategy(strategy, `strategies[${i}]`); if (invalid) return invalid; } } else { const invalid = validateStrategy(body.strategy, "strategy"); if (invalid) return invalid; }
}

export default { async fetch(request: Request, env: Env) { const requestId = crypto.randomUUID(); if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: { ...headers(env), "x-request-id": requestId } }); const url = new URL(request.url); if (url.pathname === "/health" && request.method === "GET") return response({ ok: true, service: "debt-engine-api", version: "1" }, 200, env, requestId); if (!["/v1/simulations", "/v1/simulations/compare"].includes(url.pathname)) return fail("NOT_FOUND", "Route not found", 404, env, requestId); if (request.method !== "POST") return fail("METHOD_NOT_ALLOWED", "Method not allowed", 405, env, requestId); if (Number(request.headers.get("content-length") ?? 0) > 1_000_000) return fail("REQUEST_TOO_LARGE", "Request body exceeds 1 MB", 413, env, requestId); let body: any; try { body = await request.json(); } catch { return fail("INVALID_REQUEST", "Request body must be valid JSON", 400, env, requestId); } const invalid = validate(body, url.pathname.endsWith("compare")); if (invalid) return fail("INVALID_REQUEST", invalid, 400, env, requestId); try { const base = { schemaVersion: "1.0", disclaimer }; if (url.pathname.endsWith("compare")) {  const baseline = simulate(body.debts, { method: "minimumOnly" }, body.options?.includeSchedule); const scenarios = body.strategies.map((s: Strategy) => { const result = simulate(body.debts, s, body.options?.includeSchedule); return { id: `${s.method}-${s.extraMonthlyBudget ?? 0}`, method: s.method, ...result, deltaVsBaseline: { monthsSaved: baseline.summary.monthsToDebtFree - result.summary.monthsToDebtFree, interestSaved: Math.round((baseline.summary.totalInterest - result.summary.totalInterest) * 100) / 100 } }; }); return response({ ...base, requestId, baseline, scenarios, warnings: scenarios.flatMap((s: Result & { method: string; id: string; deltaVsBaseline: unknown }) => s.warnings) }, 200, env, requestId); } const strategy = body.strategy as Strategy; if (!strategy || !["minimumOnly", "avalanche", "snowball"].includes(strategy.method)) return fail("INVALID_REQUEST", "strategy.method is unsupported", 400, env, requestId, "strategy.method"); return response({ ...base, requestId, simulationId: requestId, assumptions: { currency: "USD", interestModel: "monthly-rate", paymentTiming: "monthly", resultsAreEstimates: true }, ...simulate(body.debts as Debt[], strategy, body.options?.includeSchedule) }, 200, env, requestId); } catch { return fail("INTERNAL_ERROR", "Unable to run simulation", 500, env, requestId); } } } satisfies ExportedHandler<Env>;
