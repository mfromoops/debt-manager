import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/mortgage.dart';
import 'package:flutter_app/models/extra_payment.dart';
import 'package:flutter_app/services/amortization_engine.dart';

void main() {
  test('Amortization engine computes standard payoff', () {
    final mortgage = Mortgage(
      principal: 300000,
      annualRate: 6.0,
      termYears: 30,
      startDate: DateTime(2024, 1),
    );
    final result = AmortizationEngine.simulate(mortgage, const []);
    expect(result.monthsToPayoff, 360);
    // Monthly payment for 300k @6% 30yr ≈ 1798.65
    expect(mortgage.monthlyPayment, closeTo(1798.65, 0.5));
  });

  test('Extra payments shorten payoff and save interest', () {
    final mortgage = Mortgage(
      principal: 300000,
      annualRate: 6.0,
      termYears: 30,
      startDate: DateTime(2024, 1),
    );
    final extras = [
      ExtraPayment(
        id: '1',
        name: 'Every 8 weeks',
        amount: 500,
        cadence: CadenceType.everyNWeeks,
        interval: 8,
      ),
    ];
    final comparison = AmortizationEngine.compare(mortgage, extras);
    expect(comparison.accelerated.monthsToPayoff,
        lessThan(comparison.baseline.monthsToPayoff));
    expect(comparison.interestSaved, greaterThan(0));
  });
}
