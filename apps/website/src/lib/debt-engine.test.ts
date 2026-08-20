import { describe, expect, it } from 'vitest';
import { DEMO_DEBTS, simulateDebts } from './debt-engine';

describe('synthetic debt engine', () => {
  it('pays off the demo with minimum payments plus extra budget', () => {
    const result = simulateDebts(DEMO_DEBTS, 200, 'avalanche');
    expect(result.neverPaysOff).toBe(false);
    expect(result.months).toBeGreaterThan(0);
    expect(result.interest).toBeGreaterThan(0);
  });
  it('supports both payoff strategies and deterministic output', () => {
    const first = simulateDebts(DEMO_DEBTS, 200, 'avalanche');
    const second = simulateDebts(DEMO_DEBTS, 200, 'snowball');
    expect(first).toEqual(simulateDebts(DEMO_DEBTS, 200, 'avalanche'));
    expect(first.order[0]).toBe('Credit card');
    expect(second.order[0]).toBe('Credit card');
  });
  it('returns a total balance series for charting', () => {
    const result = simulateDebts(DEMO_DEBTS, 200, 'avalanche');
    const initialBalance = DEMO_DEBTS.reduce((sum, debt) => sum + debt.balance, 0);
    expect(result.balances[0]).toBe(initialBalance);
    expect(result.balances.at(-1)).toBe(0);
  });
  it('surfaces a never-pays-off case', () => {
    const result = simulateDebts([{ name: 'High APR', balance: 1000, apr: 100, minimum: 1 }]);
    expect(result.neverPaysOff).toBe(true);
  });
});
