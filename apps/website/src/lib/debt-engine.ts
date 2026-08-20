export type Strategy = 'avalanche' | 'snowball';

export type DemoDebt = {
  name: string;
  balance: number;
  apr: number;
  minimum: number;
};

export type Simulation = {
  months: number;
  interest: number;
  totalPaid: number;
  payoffDate: Date | null;
  neverPaysOff: boolean;
  order: string[];
  balances: number[];
};

const MAX_MONTHS = 1200;

/** Deterministic monthly debt forecast used by the public synthetic demo. */
export function simulateDebts(debts: DemoDebt[], extra = 0, strategy: Strategy = 'avalanche', oneTime = 0, start = new Date('2026-01-01T00:00:00Z')): Simulation {
  const accounts = debts.map((debt) => ({ ...debt, balance: Math.max(0, debt.balance) }));
  let interest = 0;
  let totalPaid = Math.max(0, oneTime);
  const order: string[] = [];
  const balances: number[] = [accounts.reduce((sum, account) => sum + account.balance, 0)];
  let month = 0;
  let availableOneTime = Math.max(0, oneTime);

  while (accounts.some((a) => a.balance > 0.005) && month < MAX_MONTHS) {
    month += 1;
    for (const account of accounts) {
      if (account.balance <= 0.005) continue;
      const monthlyInterest = account.balance * (account.apr / 100 / 12);
      account.balance += monthlyInterest;
      interest += monthlyInterest;
    }

    if (availableOneTime > 0) {
      const target = chooseTarget(accounts, strategy);
      if (target) {
        const payment = Math.min(availableOneTime, target.balance);
        target.balance -= payment;
        availableOneTime -= payment;
        totalPaid += payment;
      }
    }

    let budget = accounts.reduce((sum, account) => {
      if (account.balance <= 0.005) return sum;
      const payment = Math.min(account.minimum, account.balance);
      account.balance -= payment;
      totalPaid += payment;
      return sum;
    }, Math.max(0, extra));

    while (budget > 0.005 && accounts.some((a) => a.balance > 0.005)) {
      const target = chooseTarget(accounts, strategy);
      if (!target) break;
      const payment = Math.min(budget, target.balance);
      target.balance -= payment;
      budget -= payment;
      totalPaid += payment;
      if (target.balance <= 0.005 && !order.includes(target.name)) order.push(target.name);
    }

    accounts.forEach((account) => { if (account.balance <= 0.005 && !order.includes(account.name)) order.push(account.name); });
    balances.push(accounts.reduce((sum, account) => sum + Math.max(0, account.balance), 0));
  }

  const neverPaysOff = month >= MAX_MONTHS && accounts.some((a) => a.balance > 0.005);
  const payoffDate = neverPaysOff ? null : new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + month, 1));
  return { months: neverPaysOff ? 0 : month, interest, totalPaid, payoffDate, neverPaysOff, order, balances };
}

function chooseTarget(accounts: DemoDebt[], strategy: Strategy): DemoDebt | undefined {
  return accounts.filter((account) => account.balance > 0.005).sort((a, b) => strategy === 'avalanche' ? b.apr - a.apr || a.balance - b.balance : a.balance - b.balance || b.apr - a.apr)[0];
}

export const DEMO_DEBTS: DemoDebt[] = [
  { name: 'Credit card', balance: 8400, apr: 24.99, minimum: 250 },
  { name: 'Auto loan', balance: 18000, apr: 7.25, minimum: 420 },
  { name: 'Student loan', balance: 24000, apr: 5.5, minimum: 275 },
];
