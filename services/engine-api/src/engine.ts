export type Method = "minimumOnly" | "avalanche" | "snowball";
export type Extra = {
  cadence: "monthly" | "annual" | "everyNMonths" | "everyNWeeks" | "oneTime";
  amount: number; startDate?: string; interval?: number; annualMonth?: number;
  oneTimeDate?: string; enabled?: boolean;
};
export type Debt = {
  id: string; name: string; type?: string; balance: number; annualRate: number;
  paymentMode?: "amortized" | "fixedPayment"; monthlyPayment: number;
  startDate: string; termMonths?: number; extras?: Extra[];
};
export type Strategy = { method: Method; extraMonthlyBudget?: number; startDate?: string };
type Row = { monthIndex: number; date: string; scheduledPayment: number; extraPayment: number; interest: number; principalPaid: number; balance: number };
export type Result = { summary: { debtFreeDate: string | null; monthsToDebtFree: number; totalInterest: number; totalPaid: number; neverPaysOff: boolean }; debts: Array<{ id: string; payoffOrder: number | null; payoffDate: string | null; monthsToPayoff: number | null; totalInterest: number; totalPaid: number; neverPaysOff: boolean; schedule?: Row[] }>; warnings: string[] };

const CAP = 600;
const iso = (d: Date) => d.toISOString().slice(0, 10);
const monthDate = (start: Date, n: number) => new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + n, 1));
const round = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;

function extraFor(extra: Extra, date: Date, start: Date) {
  if (extra.enabled === false) return 0;
  const eventStart = extra.startDate ? new Date(`${extra.startDate}T00:00:00Z`) : start;
  const diff = (date.getUTCFullYear() - eventStart.getUTCFullYear()) * 12 + date.getUTCMonth() - eventStart.getUTCMonth();
  if (extra.cadence === "monthly" && diff >= 0) return extra.amount;
  if (extra.cadence === "annual" && diff >= 0 && date.getUTCMonth() === (extra.annualMonth ?? eventStart.getUTCMonth() + 1) - 1) return extra.amount;
  if (extra.cadence === "everyNMonths" && diff >= 0 && diff % (extra.interval ?? 1) === 0) return extra.amount;
  if (extra.cadence === "oneTime" && extra.oneTimeDate === iso(date)) return extra.amount;
  if (extra.cadence === "everyNWeeks") {
    const days = Math.floor((date.getTime() - eventStart.getTime()) / 86400000);
    const interval = extra.interval ?? 1;
    const occurrences = days >= 0 ? Math.floor(days / (7 * interval)) : -1;
    const next = occurrences >= 0 ? new Date(eventStart.getTime() + occurrences * interval * 7 * 86400000) : eventStart;
    return occurrences >= 0 && next.getUTCFullYear() === date.getUTCFullYear() && next.getUTCMonth() === date.getUTCMonth() ? extra.amount : 0;
  }
  return 0;
}

export function simulate(debts: Debt[], strategy: Strategy, includeSchedule = false): Result {
  const start = new Date(`${strategy.startDate ?? debts[0].startDate}T00:00:00Z`);
  const state = debts.map((d) => ({ d, balance: d.balance, interest: 0, paid: 0, payoff: null as number | null, schedule: [] as Row[] }));
  const warnings: string[] = [];
  let months = 0;
  while (state.some((s) => s.balance > 0.005) && months < CAP) {
    const date = monthDate(start, months);
    const active = state.filter((s) => s.balance > 0.005).sort((a, b) => strategy.method === "avalanche" ? b.d.annualRate - a.d.annualRate || a.d.id.localeCompare(b.d.id) : strategy.method === "snowball" ? a.balance - b.balance || a.d.id.localeCompare(b.d.id) : a.d.id.localeCompare(b.d.id));
    let budget = strategy.method === "minimumOnly" ? 0 : strategy.extraMonthlyBudget ?? 0;
    for (const s of active) {
      const interest = s.balance * s.d.annualRate / 100 / 12;
      const scheduled = Math.min(s.d.monthlyPayment, s.balance + interest);
      const principal = Math.max(0, scheduled - interest);
      s.balance = Math.max(0, s.balance - principal);
      s.interest += interest; s.paid += scheduled;
      const extra = Math.min(s.balance, (s.d.extras ?? []).reduce((sum, e) => sum + extraFor(e, date, start), 0));
      s.balance -= extra; s.paid += extra;
      if (s.balance <= 0.005 && s.payoff === null) s.payoff = months + 1;
      if (includeSchedule) s.schedule.push({ monthIndex: months + 1, date: iso(date), scheduledPayment: scheduled, extraPayment: extra, interest, principalPaid: principal + extra, balance: s.balance });
    }
    for (const s of active) {
      if (budget <= 0 || s.balance <= 0.005) continue;
      const extra = Math.min(s.balance, budget); s.balance -= extra; s.paid += extra; budget -= extra;
      if (s.balance <= 0.005 && s.payoff === null) s.payoff = months + 1;
      const row = s.schedule[s.schedule.length - 1];
      if (row) { row.extraPayment += extra; row.principalPaid += extra; row.balance = s.balance; }
    }
    months++;
  }
  const never = state.some((s) => s.balance > 0.005);
  if (never) warnings.push(`Simulation reached the ${CAP}-month safety cap before all debts were paid off.`);
  const results = state.map((s) => ({ id: s.d.id, payoffOrder: s.payoff === null ? null : 0, payoffDate: s.payoff === null ? null : iso(monthDate(start, s.payoff - 1)), monthsToPayoff: s.payoff, totalInterest: round(s.interest), totalPaid: round(s.paid), neverPaysOff: s.payoff === null, ...(includeSchedule ? { schedule: s.schedule } : {}) }));
  [...results].filter((x) => x.payoffOrder === 0).sort((a, b) => (a.monthsToPayoff ?? CAP) - (b.monthsToPayoff ?? CAP)).forEach((x, i) => { x.payoffOrder = i + 1; });
  return { summary: { debtFreeDate: never ? null : iso(monthDate(start, months - 1)), monthsToDebtFree: never ? 0 : months, totalInterest: round(state.reduce((n, s) => n + s.interest, 0)), totalPaid: round(state.reduce((n, s) => n + s.paid, 0)), neverPaysOff: never }, debts: results, warnings };
}
