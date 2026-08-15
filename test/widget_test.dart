import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/loan.dart';
import 'package:flutter_app/models/extra_payment.dart';
import 'package:flutter_app/services/amortization_engine.dart';
import 'package:flutter_app/services/payoff_planner.dart';

void main() {
  test('Amortized loan computes standard payoff', () {
    final loan = Loan(
      id: '1',
      name: 'Test Mortgage',
      type: LoanType.mortgage,
      principal: 300000,
      annualRate: 6.0,
      termYears: 30,
      startDate: DateTime(2024, 1),
      paymentMode: PaymentMode.amortized,
    );
    final result = AmortizationEngine.simulate(loan, const []);
    expect(result.monthsToPayoff, 360);
    expect(loan.monthlyPayment, closeTo(1798.65, 0.5));
    expect(result.neverPaysOff, isFalse);
  });

  test('Extra payments shorten payoff and save interest', () {
    final loan = Loan(
      id: '2',
      name: 'Test Mortgage',
      type: LoanType.mortgage,
      principal: 300000,
      annualRate: 6.0,
      termYears: 30,
      startDate: DateTime(2024, 1),
      paymentMode: PaymentMode.amortized,
      extras: [
        ExtraPayment(
          id: 'e1',
          name: 'Every 8 weeks',
          amount: 500,
          cadence: CadenceType.everyNWeeks,
          interval: 8,
        ),
      ],
    );
    final comparison = AmortizationEngine.compare(loan);
    expect(comparison.accelerated.monthsToPayoff,
        lessThan(comparison.baseline.monthsToPayoff));
    expect(comparison.interestSaved, greaterThan(0));
  });

  test('Credit card with fixed payment pays off', () {
    final card = Loan(
      id: '3',
      name: 'Test Card',
      type: LoanType.creditCard,
      principal: 8000,
      annualRate: 22.0,
      startDate: DateTime(2025, 1),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 300,
    );
    final result = AmortizationEngine.simulate(card, const []);
    expect(result.neverPaysOff, isFalse);
    expect(result.monthsToPayoff, greaterThan(12));
    expect(result.schedule.last.balance, closeTo(0, 0.01));
  });

  test('Credit card payment below interest never pays off', () {
    final card = Loan(
      id: '4',
      name: 'Bad Card',
      type: LoanType.creditCard,
      principal: 10000,
      annualRate: 24.0, // monthly interest = $200
      startDate: DateTime(2025, 1),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 150, // below interest
    );
    final result = AmortizationEngine.simulate(card, const []);
    expect(result.neverPaysOff, isTrue);
  });

  test('Extra payments rescue an under-paying credit card', () {
    final card = Loan(
      id: '5',
      name: 'Card with extras',
      type: LoanType.creditCard,
      principal: 10000,
      annualRate: 24.0,
      startDate: DateTime(2025, 1),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 210,
      extras: [
        ExtraPayment(
          id: 'e2',
          name: 'Monthly extra',
          amount: 200,
          cadence: CadenceType.monthly,
        ),
      ],
    );
    final result = AmortizationEngine.simulate(card, card.extras);
    expect(result.neverPaysOff, isFalse);
  });

  group('PayoffPlanner', () {
    List<Loan> makeLoans() => [
          Loan(
            id: 'm',
            name: 'Mortgage',
            type: LoanType.mortgage,
            principal: 200000,
            annualRate: 5.0,
            termYears: 30,
            startDate: DateTime(2024, 1),
            paymentMode: PaymentMode.amortized,
          ),
          Loan(
            id: 'c',
            name: 'Card',
            type: LoanType.creditCard,
            principal: 5000,
            annualRate: 22.0,
            startDate: DateTime(2025, 1),
            paymentMode: PaymentMode.fixedPayment,
            fixedMonthlyPayment: 200,
          ),
          Loan(
            id: 'p',
            name: 'Personal',
            type: LoanType.personalLoan,
            principal: 12000,
            annualRate: 9.0,
            termYears: 5,
            startDate: DateTime(2024, 6),
            paymentMode: PaymentMode.amortized,
          ),
        ];

    Map<String, double> balancesOf(List<Loan> loans) =>
        {for (final l in loans) l.id: l.principal};

    test('Avalanche targets highest rate first', () {
      final loans = makeLoans();
      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 300,
      );
      expect(plan.neverPaysOff, isFalse);
      // Card (22%) must be first to pay off under avalanche.
      expect(plan.loanResults.first.loanId, 'c');
      expect(plan.loanResults.length, 3);
    });

    test('Snowball targets smallest balance first', () {
      final loans = makeLoans();
      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.snowball,
        monthlyBudget: 300,
      );
      // Card also has the smallest balance here, so it's first too.
      expect(plan.loanResults.first.loanId, 'c');
    });

    test('Budget reduces time to debt-free and interest', () {
      final loans = makeLoans();
      final noBudget = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 0,
      );
      final withBudget = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 500,
      );
      expect(withBudget.monthsToDebtFree,
          lessThan(noBudget.monthsToDebtFree));
      expect(
          withBudget.totalInterest, lessThan(noBudget.totalInterest));
    });

    test('Avalanche saves at least as much interest as snowball', () {
      final loans = makeLoans();
      final avalanche = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 400,
      );
      final snowball = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.snowball,
        monthlyBudget: 400,
      );
      expect(avalanche.totalInterest,
          lessThanOrEqualTo(snowball.totalInterest + 0.01));
    });
  });
}
