import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/loan.dart';
import 'package:flutter_app/models/extra_payment.dart';
import 'package:flutter_app/models/progress_entry.dart';
import 'package:flutter_app/screens/dashboard_screen.dart';
import 'package:flutter_app/screens/loans_overview_screen.dart';
import 'package:flutter_app/services/app_state.dart';
import 'package:flutter_app/services/amortization_engine.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/payoff_planner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(
      comparison.accelerated.monthsToPayoff,
      lessThan(comparison.baseline.monthsToPayoff),
    );
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

  test('Loan progress entries round-trip through JSON', () {
    final loan = Loan(
      id: '6',
      name: 'Tracked Loan',
      type: LoanType.personalLoan,
      principal: 12000,
      annualRate: 8.5,
      startDate: DateTime(2026, 1, 15),
      paymentMode: PaymentMode.amortized,
      termYears: 5,
      progressEntries: [
        ProgressEntry(
          id: 'p1',
          date: DateTime(2026, 8, 19),
          paymentAmount: 300,
          balance: 10450,
          note: 'Statement',
        ),
      ],
    );

    final restored = Loan.fromJson(loan.toJson());
    expect(restored.progressEntries, hasLength(1));
    expect(restored.progressEntries.first.paymentAmount, 300);
    expect(restored.progressEntries.first.balance, 10450);
    expect(restored.progressEntries.first.note, 'Statement');
  });

  test('Balance checkpoints preserve amortized scheduled payment', () {
    final loan = Loan(
      id: '7',
      name: 'Checkpoint Loan',
      type: LoanType.autoLoan,
      principal: 30000,
      annualRate: 6.0,
      startDate: DateTime(2026, 1, 15),
      paymentMode: PaymentMode.amortized,
      termYears: 5,
      progressEntries: [
        ProgressEntry(id: 'p2', date: DateTime(2026, 8, 19), balance: 25000),
      ],
    );
    final state = AppState();
    final projected = state.projectedLoan(loan);

    expect(projected.principal, 25000);
    expect(projected.startDate, DateTime(2026, 8, 19));
    expect(projected.paymentMode, PaymentMode.fixedPayment);
    expect(projected.fixedMonthlyPayment, closeTo(loan.monthlyPayment, 0.01));
  });

  test('Current balance changes on the payment date, not month start', () {
    final loan = Loan(
      id: 'due-date-balance',
      name: 'Due-date loan',
      type: LoanType.personalLoan,
      principal: 12000,
      annualRate: 0,
      startDate: DateTime(2026, 7, 28),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 1000,
    );
    final state = AppState();

    expect(
      state.currentBalance(loan, asOf: DateTime(2026, 8, 1)),
      closeTo(11000, 0.01),
    );
    expect(
      state.currentBalance(loan, asOf: DateTime(2026, 8, 27)),
      closeTo(11000, 0.01),
    );
    expect(
      state.currentBalance(loan, asOf: DateTime(2026, 8, 28)),
      closeTo(10000, 0.01),
    );
  });

  test('Current balance stays unchanged before the first payment', () {
    final loan = Loan(
      id: 'future-first-payment',
      name: 'New loan',
      type: LoanType.personalLoan,
      principal: 12000,
      annualRate: 0,
      startDate: DateTime(2026, 8, 28),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 1000,
    );

    expect(
      AppState().currentBalance(loan, asOf: DateTime(2026, 8, 1)),
      closeTo(12000, 0.01),
    );
  });

  test('Projected debt curve starts at today and ends at zero', () async {
    SharedPreferences.setMockInitialValues({});
    final loan = Loan(
      id: 'projected-curve',
      name: 'Curve loan',
      type: LoanType.personalLoan,
      principal: 12000,
      annualRate: 0,
      startDate: DateTime(2026, 7, 28),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 1000,
    );
    final state = AppState();
    await state.addLoan(loan);

    final curve = state.projectedDebtBalances(asOf: DateTime(2026, 8, 1));

    expect(curve.first, closeTo(11000, 0.01));
    expect(curve.last, closeTo(0, 0.01));
    expect(curve, orderedEquals([...curve]..sort((a, b) => b.compareTo(a))));
  });

  test('Payment-only progress becomes a factual one-time extra', () {
    final loan = Loan(
      id: '8',
      name: 'Payment History Loan',
      type: LoanType.personalLoan,
      principal: 10000,
      annualRate: 6.0,
      startDate: DateTime(2026, 1, 10),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 350,
      progressEntries: [
        ProgressEntry(
          id: 'p3',
          date: DateTime(2026, 2, 10),
          paymentAmount: 500,
        ),
      ],
    );
    final state = AppState();
    final projected = state.projectedLoan(loan);

    expect(projected.extras, hasLength(1));
    expect(projected.extras.first.amount, 500);
    expect(projected.extras.first.oneTimeDate, DateTime(2026, 2, 10));
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

  test('Home summary includes strategy extras in the next payment', () async {
    SharedPreferences.setMockInitialValues({});
    final loan = Loan(
      id: 'home-summary',
      name: 'Card',
      type: LoanType.creditCard,
      principal: 5000,
      annualRate: 12,
      startDate: DateTime(2026, 1, 25),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 200,
      extras: const [
        ExtraPayment(
          id: 'monthly-extra',
          name: 'Monthly extra',
          amount: 75,
          cadence: CadenceType.monthly,
        ),
      ],
    );
    final state = AppState();
    await state.addLoan(loan);

    expect(
      state.nextPaymentDate(loan, asOf: DateTime(2026, 8, 19)),
      DateTime(2026, 8, 25),
    );
    expect(
      state.nextPaymentWithStrategies(loan, asOf: DateTime(2026, 8, 19)),
      closeTo(275, 0.01),
    );
    expect(state.minimumDue, closeTo(200, 0.01));
  });

  testWidgets('Redesigned home fits a narrow phone viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await state.addLoan(
      Loan(
        id: 'narrow-home',
        name: 'Everyday credit card',
        type: LoanType.creditCard,
        principal: 5000,
        annualRate: 12,
        startDate: DateTime(2026, 1, 25),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 200,
        extras: const [
          ExtraPayment(
            id: 'narrow-extra',
            name: 'Monthly extra',
            amount: 75,
            cadence: CadenceType.monthly,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ],
        child: const MaterialApp(home: LoansOverviewScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('strategy-payment-total')), findsOneWidget);
    expect(find.byKey(const Key('minimum-due')), findsOneWidget);
    expect(find.byKey(const Key('next-payment-date')), findsOneWidget);
    expect(find.byKey(const Key('debt-progress-card')), findsOneWidget);
    expect(find.byKey(const Key('debt-progress-chart')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('debt-progress-card'))).height,
      244,
    );
    expect(find.byKey(const Key('debt-narrow-home-minimum')), findsOneWidget);
    expect(find.byKey(const Key('debt-narrow-home-date')), findsOneWidget);
    expect(find.byKey(const Key('debt-narrow-home-strategy')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Debt detail shows payment information on a narrow phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final loan = Loan(
      id: 'detail-payment-summary',
      name: 'Everyday credit card',
      type: LoanType.creditCard,
      principal: 5000,
      annualRate: 12,
      startDate: DateTime(2026, 1, 25),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 200,
      extras: const [
        ExtraPayment(
          id: 'detail-extra',
          name: 'Monthly extra',
          amount: 75,
          cadence: CadenceType.monthly,
        ),
      ],
    );
    final state = AppState();
    await state.addLoan(loan);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: DashboardScreen(loan: loan)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('detail-minimum-due')), findsOneWidget);
    expect(find.byKey(const Key('detail-next-payment-date')), findsOneWidget);
    expect(find.byKey(const Key('detail-strategy-payment')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    Map<String, double> balancesOf(List<Loan> loans) => {
      for (final l in loans) l.id: l.principal,
    };

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
      expect(withBudget.monthsToDebtFree, lessThan(noBudget.monthsToDebtFree));
      expect(withBudget.totalInterest, lessThan(noBudget.totalInterest));
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
      expect(
        avalanche.totalInterest,
        lessThanOrEqualTo(snowball.totalInterest + 0.01),
      );
    });

    test('Tracks actual extra-payment recipients', () {
      final loans = [
        Loan(
          id: 'card',
          name: 'Card',
          type: LoanType.creditCard,
          principal: 80,
          annualRate: 22.0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 10,
        ),
        Loan(
          id: 'tiny',
          name: 'Tiny debt',
          type: LoanType.personalLoan,
          principal: 20,
          annualRate: 5.0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 1,
        ),
      ];

      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 100,
      );
      final cardResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'card',
      );
      final tinyResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'tiny',
      );

      expect(tinyResult.monthsToPayoff, 1);
      expect(tinyResult.totalExtraPaid, greaterThan(0));
      expect(tinyResult.targetedMonths, 1);
      expect(tinyResult.firstTargetMonth, 1);
      expect(cardResult.firstTargetMonth, 1);
    });

    test('Does not target debt cleared by its scheduled payment', () {
      final loans = [
        Loan(
          id: 'card',
          name: 'Card',
          type: LoanType.creditCard,
          principal: 5000,
          annualRate: 22.0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 200,
        ),
        Loan(
          id: 'tiny',
          name: 'Tiny debt',
          type: LoanType.personalLoan,
          principal: 100,
          annualRate: 0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 100,
        ),
      ];

      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 300,
      );
      final cardResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'card',
      );
      final tinyResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'tiny',
      );

      expect(tinyResult.firstTargetMonth, isNull);
      expect(tinyResult.targetedMonths, 0);
      expect(cardResult.firstTargetMonth, 1);
    });

    test('Applies only to recipients at their actual target month', () async {
      SharedPreferences.setMockInitialValues({});
      final loans = [
        Loan(
          id: 'card',
          name: 'Card',
          type: LoanType.creditCard,
          principal: 80,
          annualRate: 22.0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 10,
        ),
        Loan(
          id: 'tiny',
          name: 'Tiny debt',
          type: LoanType.personalLoan,
          principal: 20,
          annualRate: 5.0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 1,
        ),
        Loan(
          id: 'scheduled',
          name: 'Scheduled payoff',
          type: LoanType.autoLoan,
          principal: 50,
          annualRate: 0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 50,
        ),
      ];
      final state = AppState();
      for (final loan in loans) {
        await state.addLoan(loan);
      }
      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 100,
      );

      final added = await state.applyPayoffPlan(
        plan,
        startDate: DateTime(2026, 4, 19),
      );

      expect(added, 2);
      expect(
        state.loanById('card')!.extras.single.startDate,
        DateTime(2026, 4),
      );
      expect(
        state.loanById('tiny')!.extras.single.startDate,
        DateTime(2026, 4),
      );
      expect(state.loanById('scheduled')!.extras, isEmpty);
    });

    test(
      'Skips a target already paid off before its strategy starts',
      () async {
        SharedPreferences.setMockInitialValues({});
        final loan = Loan(
          id: 'short',
          name: 'Short debt',
          type: LoanType.personalLoan,
          principal: 100,
          annualRate: 0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 10,
        );
        final state = AppState();
        await state.addLoan(loan);
        final plan = PayoffPlanner.plan(
          loans: [loan],
          startingBalances: {loan.id: loan.principal},
          method: PlanMethod.snowball,
          monthlyBudget: 20,
        );

        final added = await state.applyPayoffPlan(
          plan,
          startDate: DateTime(2030, 4),
        );

        expect(plan.loanResults.single.firstTargetMonth, 1);
        expect(added, 0);
        expect(state.loanById(loan.id)!.extras, isEmpty);
      },
    );
  });
}
