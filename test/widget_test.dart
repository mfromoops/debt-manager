import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/loan.dart';
import 'package:flutter_app/models/extra_payment.dart';
import 'package:flutter_app/services/amortization_engine.dart';

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
}
