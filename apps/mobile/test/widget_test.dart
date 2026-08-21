import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/loan.dart';
import 'package:flutter_app/models/extra_payment.dart';
import 'package:flutter_app/models/progress_entry.dart';
import 'package:flutter_app/models/financial_profile.dart';
import 'package:flutter_app/models/strategy_schedule_override.dart';
import 'package:flutter_app/screens/dashboard_screen.dart';
import 'package:flutter_app/screens/loans_overview_screen.dart';
import 'package:flutter_app/screens/planner_screen.dart';
import 'package:flutter_app/screens/profile_screen.dart';
import 'package:flutter_app/screens/strategy_edit_screen.dart';
import 'package:flutter_app/services/app_state.dart';
import 'package:flutter_app/services/amortization_engine.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/payoff_planner.dart';
import 'package:flutter_app/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  test('guest debts merge into the account on first sign in', () async {
    SharedPreferences.setMockInitialValues({});
    final localLoan = _testLoan('local', 'Local debt');
    final remoteLoan = _testLoan('remote', 'Account debt');
    final state = AppState();
    await state.load();
    await state.addLoan(localLoan);
    await state.saveProfile(
      const FinancialProfile(salary: 60000, salaryPeriod: SalaryPeriod.annual),
    );
    final sync = _FakeSyncService(
      remote: SyncDocument(
        loans: [remoteLoan.toJson()],
        updatedAt: DateTime.utc(2026, 8, 1),
        rev: 'remote-rev',
      ),
    );
    state.configureSync(sync);

    await state.setSyncSession(
      ({bool forceRefresh = false}) async => 'token',
      userId: 'user-1',
    );

    expect(
      state.loans.map((loan) => loan.id),
      containsAll(['local', 'remote']),
    );
    expect(
      sync.pushed!.loans.map((item) => (item as Map<String, dynamic>)['id']),
      containsAll(['local', 'remote']),
    );
    expect(sync.pushed!.profile?['salary'], 60000);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('loans.syncOwnerId'), 'user-1');
  });

  test(
    'signing into a different account does not upload cached debts',
    () async {
      final oldLoan = _testLoan('old', 'Previous account debt');
      final newLoan = _testLoan('new', 'New account debt');
      SharedPreferences.setMockInitialValues({
        'loans': '[${_jsonFor(oldLoan)}]',
        'loans.syncOwnerId': 'user-1',
        'loans.syncUpdatedAt': DateTime.utc(2026, 8, 18).toIso8601String(),
        'loans.syncRev': 'old-rev',
      });
      final state = AppState();
      await state.load();
      final sync = _FakeSyncService(
        remote: SyncDocument(
          loans: [newLoan.toJson()],
          profile: const {'salary': 9000, 'salaryPeriod': 'monthly'},
          updatedAt: DateTime.utc(2026, 8, 1),
          rev: 'new-rev',
        ),
      );
      state.configureSync(sync);

      await state.setSyncSession(
        ({bool forceRefresh = false}) async => 'token',
        userId: 'user-2',
      );

      expect(state.loans.map((loan) => loan.id), ['new']);
      expect(state.monthlyIncome, 9000);
      expect(sync.pushed, isNull);
    },
  );

  testWidgets('sync status button pulls and pushes state on demand', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    await state.addLoan(_testLoan('manual-sync', 'Manual sync debt'));
    final sync = _FakeSyncService();
    state.configureSync(sync);
    final auth = _AuthenticatedAuthService();

    await state.setSyncSession(auth.validAccessToken, userId: auth.user!.id);
    expect(sync.fetchCount, 1);

    sync.pushed = null;
    sync.remote = SyncDocument(
      loans: const [],
      updatedAt: DateTime.utc(2000),
      rev: 'stale-remote',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: LoansOverviewScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('sync-button')));
    await tester.pumpAndSettle();

    expect(sync.fetchCount, 2);
    expect(sync.pushed, isNotNull);
    expect(
      sync.pushed!.loans.map((item) => (item as Map<String, dynamic>)['id']),
      contains('manual-sync'),
    );
  });

  test('continue as guest is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    await auth.continueAsGuest();

    expect(auth.guestMode, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auth.guestMode'), isTrue);
    auth.dispose();
  });

  test('annual salary is persisted and normalized to monthly income', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.saveProfile(
      const FinancialProfile(salary: 60000, salaryPeriod: SalaryPeriod.annual),
    );

    final reloaded = AppState();
    await reloaded.load();

    expect(reloaded.profile?.salary, 60000);
    expect(reloaded.profile?.salaryPeriod, SalaryPeriod.annual);
    expect(reloaded.monthlyIncome, 5000);
  });

  testWidgets('Profile page saves annual salary and previews monthly income', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('profile-salary')), '60000');
    await tester.tap(find.text('Annual'));
    await tester.pump();

    expect(find.text(r'$5,000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pump();
    expect(state.monthlyIncome, 5000);
  });

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

  test('Amortized loan supports a duration in months', () {
    final loan = Loan(
      id: 'monthly-term',
      name: '18-month loan',
      type: LoanType.personalLoan,
      principal: 18000,
      annualRate: 0,
      startDate: DateTime(2026, 1, 1),
      paymentMode: PaymentMode.amortized,
      termMonths: 18,
    );

    expect(loan.monthlyPayment, 1000);
    expect(AmortizationEngine.simulate(loan, const []).monthsToPayoff, 18);
    expect(Loan.fromJson(loan.toJson()).termMonths, 18);
  });

  test('Loan JSON still reads legacy durations stored in years', () {
    final legacyJson = _testLoan('legacy', 'Legacy loan').toJson()
      ..remove('termMonths')
      ..['termYears'] = 5;

    expect(Loan.fromJson(legacyJson).termMonths, 60);
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

  test('Individual strategy does not apply before its exact start day', () {
    final loan = Loan(
      id: 'dated-individual-strategy',
      name: 'Dated strategy loan',
      type: LoanType.personalLoan,
      principal: 200,
      annualRate: 0,
      startDate: DateTime(2026, 8, 1),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 100,
    );
    final result = AmortizationEngine.simulate(loan, [
      ExtraPayment(
        id: 'starts-late',
        name: 'Starts August 28',
        amount: 100,
        cadence: CadenceType.monthly,
        startDate: DateTime(2026, 8, 28),
      ),
    ]);

    expect(result.schedule.first.extra, 100);
    expect(result.payoffDate, DateTime(2026, 8, 28));
  });

  testWidgets('New individual strategies default to today', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(
          home: StrategyEditScreen(loanId: 'new-strategy-loan'),
        ),
      ),
    );

    expect(find.text(DateFormat('MMM d, yyyy').format(now)), findsOneWidget);
    expect(find.text('From loan start'), findsNothing);
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

  test('Minimum due sort prioritizes the largest required payment', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.addLoan(
      Loan(
        id: 'small-minimum',
        name: 'Smaller payment',
        type: LoanType.creditCard,
        principal: 2000,
        annualRate: 10,
        startDate: DateTime(2026, 1, 10),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 100,
      ),
    );
    await state.addLoan(
      Loan(
        id: 'large-minimum',
        name: 'Larger payment',
        type: LoanType.creditCard,
        principal: 4000,
        annualRate: 10,
        startDate: DateTime(2026, 1, 20),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 350,
      ),
    );

    await state.setLoanSort(LoanSortOption.minimumDue);

    expect(state.sortedLoans.map((loan) => loan.id), [
      'large-minimum',
      'small-minimum',
    ]);
  });

  test('Interest rate sort prioritizes the highest rate', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.addLoan(
      Loan(
        id: 'low-interest',
        name: 'Lower interest',
        type: LoanType.personalLoan,
        principal: 5000,
        annualRate: 6,
        startDate: DateTime(2026, 1, 10),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 200,
      ),
    );
    await state.addLoan(
      Loan(
        id: 'high-interest',
        name: 'Higher interest',
        type: LoanType.creditCard,
        principal: 3000,
        annualRate: 24,
        startDate: DateTime(2026, 1, 20),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 150,
      ),
    );

    await state.setLoanSort(LoanSortOption.interestRate);

    expect(state.sortedLoans.map((loan) => loan.id), [
      'high-interest',
      'low-interest',
    ]);
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

  testWidgets('Payment cycle shows debt share and remaining income', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.addLoan(
      Loan(
        id: 'income-cycle',
        name: 'Income cycle loan',
        type: LoanType.personalLoan,
        principal: 5000,
        annualRate: 0,
        startDate: DateTime(2026, 1),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 500,
        extras: [
          ExtraPayment(
            id: 'income-cycle-strategy',
            name: 'Future acceleration',
            amount: 100,
            cadence: CadenceType.monthly,
            startDate: DateTime(2100, 1),
          ),
        ],
      ),
    );
    await state.saveProfile(
      const FinancialProfile(salary: 5000, salaryPeriod: SalaryPeriod.monthly),
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

    expect(find.byKey(const Key('payment-income-ratio')), findsOneWidget);
    expect(find.textContaining('10.0% of monthly income'), findsOneWidget);
    expect(find.textContaining(r'$4,500 remaining'), findsOneWidget);
    expect(find.byKey(const Key('income-freedom-card')), findsOneWidget);
    expect(find.byKey(const Key('income-freedom-now')), findsOneWidget);
    expect(find.byKey(const Key('income-freedom-final')), findsOneWidget);

    await tester.tap(find.byKey(const Key('income-freedom-open')));
    await tester.pumpAndSettle();

    expect(find.text('Income freedom'), findsOneWidget);
    expect(find.byKey(const Key('income-freedom-timeline')), findsOneWidget);
    expect(find.byKey(const Key('income-timeline-now')), findsOneWidget);
    expect(find.byKey(const Key('income-timeline-release-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('income-mode-strategy-only')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('income-strategy-timeline-release-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('income-mode-strategies')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('income-strategy-comparison')), findsOneWidget);
    expect(find.byKey(const Key('income-strategy-row-0')), findsOneWidget);
    expect(find.text('MINIMUM'), findsOneWidget);
    expect(find.text('STRATEGY'), findsOneWidget);
  });

  test('Income releases use minimum payments and ignore strategies', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.addLoan(
      Loan(
        id: 'release-first',
        name: 'Short loan',
        type: LoanType.personalLoan,
        principal: 1000,
        annualRate: 0,
        startDate: DateTime(2026, 9, 15),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 500,
        extras: const [
          ExtraPayment(
            id: 'ignored-strategy',
            name: 'Pay it immediately',
            amount: 1000,
            cadence: CadenceType.monthly,
          ),
        ],
      ),
    );
    await state.addLoan(
      Loan(
        id: 'release-second',
        name: 'Three month loan',
        type: LoanType.personalLoan,
        principal: 300,
        annualRate: 0,
        startDate: DateTime(2026, 9, 20),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 100,
      ),
    );

    final releases = state.minimumPaymentReleases(asOf: DateTime(2026, 8, 19));

    expect(releases, hasLength(2));
    expect(releases.first.date, DateTime(2026, 10, 15));
    expect(releases.first.amount, closeTo(500, 0.01));
    expect(releases.first.loanNames, ['Short loan']);
    expect(releases.last.date, DateTime(2026, 11, 20));
    expect(releases.last.amount, closeTo(100, 0.01));

    final comparisons = state.strategyIncomeReleases(
      asOf: DateTime(2026, 8, 19),
    );
    final accelerated = comparisons.firstWhere(
      (comparison) => comparison.loanName == 'Short loan',
    );
    expect(accelerated.minimumOnlyDate, DateTime(2026, 10, 15));
    expect(accelerated.strategyDate, DateTime(2026, 9, 15));
    expect(accelerated.minimumPayment, closeTo(500, 0.01));

    final strategyReleases = state.strategyPaymentReleases(
      asOf: DateTime(2026, 8, 19),
    );
    expect(strategyReleases.first.date, DateTime(2026, 9, 15));
    expect(strategyReleases.first.amount, closeTo(500, 0.01));
    expect(strategyReleases.first.loanNames, ['Short loan']);
  });

  testWidgets('Redesigned home reflows between phone and tablet viewports', (
    tester,
  ) async {
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
      252,
    );
    expect(find.byKey(const Key('debt-narrow-home-minimum')), findsOneWidget);
    expect(find.byKey(const Key('debt-narrow-home-date')), findsOneWidget);
    expect(find.byKey(const Key('debt-narrow-home-strategy')), findsOneWidget);
    final narrowPayment = tester.getRect(
      find.byKey(const Key('payment-overview-card')),
    );
    final narrowProgress = tester.getRect(
      find.byKey(const Key('debt-progress-card')),
    );
    final narrowSchedule = tester.getRect(
      find.byKey(const Key('strategy-schedule-entry')),
    );
    final narrowPlanner = tester.getRect(
      find.byKey(const Key('payoff-planner-entry')),
    );
    expect(narrowProgress.top, greaterThan(narrowPayment.bottom));
    expect(narrowPlanner.top, greaterThan(narrowSchedule.bottom));

    tester.view.physicalSize = const Size(1100, 900);
    await tester.pump();

    final widePayment = tester.getRect(
      find.byKey(const Key('payment-overview-card')),
    );
    final wideProgress = tester.getRect(
      find.byKey(const Key('debt-progress-card')),
    );
    final wideIncome = tester.getRect(
      find.byKey(const Key('income-freedom-card')),
    );
    final wideSchedule = tester.getRect(
      find.byKey(const Key('strategy-schedule-entry')),
    );
    final widePlanner = tester.getRect(
      find.byKey(const Key('payoff-planner-entry')),
    );
    expect(wideProgress.left, greaterThan(widePayment.right));
    expect(wideProgress.top, widePayment.top);
    expect(wideIncome.left, greaterThan(wideProgress.right));
    expect(wideIncome.top, widePayment.top);
    expect(widePlanner.left, greaterThan(wideSchedule.right));
    expect(widePlanner.top, wideSchedule.top);
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

    test('Annual and periodic add-ons become shared plan cash', () {
      final loan = Loan(
        id: 'addon-loan',
        name: 'Addon loan',
        type: LoanType.personalLoan,
        principal: 5000,
        annualRate: 0,
        startDate: DateTime(2026, 1),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 50,
      );
      final plan = PayoffPlanner.plan(
        loans: [loan],
        startingBalances: {loan.id: loan.principal},
        method: PlanMethod.snowball,
        monthlyBudget: 0,
        planStart: DateTime(2026, 1),
        addons: [
          ExtraPayment(
            id: 'annual',
            name: 'Annual installment',
            amount: 500,
            cadence: CadenceType.annual,
            annualMonth: 3,
          ),
          ExtraPayment(
            id: 'quarterly',
            name: 'Quarterly payment',
            amount: 100,
            cadence: CadenceType.everyNMonths,
            interval: 3,
            startDate: DateTime(2026, 1),
          ),
        ],
      );

      final annualMonths = plan.addonAllocations
          .where((allocation) => allocation.addonId == 'annual')
          .map((allocation) => allocation.monthIndex)
          .toList();
      final quarterlyMonths = plan.addonAllocations
          .where((allocation) => allocation.addonId == 'quarterly')
          .map((allocation) => allocation.monthIndex)
          .toList();

      expect(annualMonths.take(2), [3, 15]);
      expect(quarterlyMonths.take(4), [1, 4, 7, 10]);
      expect(plan.monthsToDebtFree, lessThan(100));
    });

    test(
      'Applying a plan persists allocated add-ons as dated payments',
      () async {
        SharedPreferences.setMockInitialValues({});
        final loan = Loan(
          id: 'apply-addon',
          name: 'Apply addon',
          type: LoanType.personalLoan,
          principal: 1000,
          annualRate: 0,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 100,
        );
        final state = AppState();
        await state.addLoan(loan);
        final plan = PayoffPlanner.plan(
          loans: [loan],
          startingBalances: {loan.id: loan.principal},
          method: PlanMethod.snowball,
          monthlyBudget: 0,
          planStart: DateTime(2026, 1),
          addons: [
            ExtraPayment(
              id: 'bonus',
              name: 'February bonus',
              amount: 200,
              cadence: CadenceType.oneTime,
              oneTimeDate: DateTime(2026, 2),
            ),
          ],
        );

        final added = await state.applyPayoffPlan(
          plan,
          startDate: DateTime(2026, 1),
        );
        final savedAddon = state.loanById(loan.id)!.extras.single;

        expect(added, 1);
        expect(savedAddon.name, 'February bonus');
        expect(savedAddon.cadence, CadenceType.oneTime);
        expect(savedAddon.oneTimeDate, DateTime(2026, 2));
        expect(savedAddon.amount, 200);
      },
    );

    testWidgets('Planner can add a custom annual installment', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.addLoan(
        Loan(
          id: 'planner-ui',
          name: 'Planner loan',
          type: LoanType.personalLoan,
          principal: 5000,
          annualRate: 5,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 150,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: PlannerScreen()),
        ),
      );

      await tester.tap(find.byKey(const Key('add-plan-addon')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('plan-addon-amount')),
        '1200',
      );
      await tester.tap(find.byKey(const Key('save-plan-addon')));
      await tester.pumpAndSettle();

      expect(find.text('Annual installment'), findsOneWidget);
      expect(find.textContaining(r'$1,200 every'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Planner rates the plan against monthly income', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.addLoan(
        Loan(
          id: 'planner-income',
          name: 'Planner income loan',
          type: LoanType.personalLoan,
          principal: 5000,
          annualRate: 5,
          startDate: DateTime(2026, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 500,
        ),
      );
      await state.saveProfile(
        const FinancialProfile(
          salary: 5000,
          salaryPeriod: SalaryPeriod.monthly,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: PlannerScreen()),
        ),
      );

      expect(find.byKey(const Key('planner-income-ratio')), findsOneWidget);
      expect(find.text('14.0% of monthly income'), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
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

    test(
      'Defers a future-tracked debt and its rollover until valid months',
      () {
        final loans = [
          Loan(
            id: 'final',
            name: 'Citi Diamond',
            type: LoanType.personalLoan,
            principal: 180,
            annualRate: 0,
            startDate: DateTime(2026, 9, 23),
            paymentMode: PaymentMode.fixedPayment,
            fixedMonthlyPayment: 180,
          ),
          Loan(
            id: 'target',
            name: 'Next target',
            type: LoanType.personalLoan,
            principal: 2000,
            annualRate: 0.5,
            startDate: DateTime(2026, 8, 1),
            paymentMode: PaymentMode.amortized,
            termMonths: 24,
          ),
        ];

        final plan = PayoffPlanner.plan(
          loans: loans,
          startingBalances: balancesOf(loans),
          method: PlanMethod.snowball,
          monthlyBudget: 0,
          planStart: DateTime(2026, 8, 20),
        );

        final finalResult = plan.loanResults.firstWhere(
          (result) => result.loanId == 'final',
        );
        final targetResult = plan.loanResults.firstWhere(
          (result) => result.loanId == 'target',
        );

        expect(finalResult.payoffDate, DateTime(2026, 9));
        expect(finalResult.monthsToPayoff, 2);
        expect(targetResult.targetedMonths, 7);
        expect(targetResult.firstTargetMonth, 3);
      },
    );

    test(
      'Applies each naturally released Avalanche payment as a new rollover',
      () async {
        SharedPreferences.setMockInitialValues({});
        final loans = [
          Loan(
            id: 'final',
            name: 'Citi Diamond 1',
            type: LoanType.personalLoan,
            principal: 180,
            annualRate: 0,
            startDate: DateTime(2026, 9, 23),
            paymentMode: PaymentMode.fixedPayment,
            fixedMonthlyPayment: 180,
          ),
          Loan(
            id: 'final-1',
            name: 'Citi Diamond 2',
            type: LoanType.personalLoan,
            principal: 200,
            annualRate: 0,
            startDate: DateTime(2026, 9, 23),
            paymentMode: PaymentMode.fixedPayment,
            fixedMonthlyPayment: 100,
          ),
          Loan(
            id: 'final-2',
            name: 'Citi Diamond 3',
            type: LoanType.personalLoan,
            principal: 300,
            annualRate: 0,
            startDate: DateTime(2026, 9, 23),
            paymentMode: PaymentMode.fixedPayment,
            fixedMonthlyPayment: 100,
          ),
          Loan(
            id: 'target',
            name: 'Next target',
            type: LoanType.personalLoan,
            principal: 2000,
            annualRate: 0.5,
            startDate: DateTime(2026, 8, 1),
            paymentMode: PaymentMode.amortized,
            termMonths: 24,
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
          monthlyBudget: 0,
          planStart: DateTime(2026, 8, 20),
        );

        expect(
          ['final', 'final-1', 'final-2']
              .map(
                (loanId) => plan.loanResults
                    .firstWhere((result) => result.loanId == loanId)
                    .monthsToPayoff,
              )
              .toList(),
          [2, 3, 4],
        );
        expect(
          plan.loanResults
              .firstWhere((result) => result.loanId == 'target')
              .firstTargetMonth,
          3,
        );

        await state.applyPayoffPlan(plan, startDate: DateTime(2026, 8, 20));

        final targetExtras = state.loanById('target')!.extras;
        expect(targetExtras, hasLength(3));
        expect(targetExtras.map((extra) => extra.startDate).toList(), [
          DateTime(2026, 10, 1),
          DateTime(2026, 11, 1),
          DateTime(2026, 12, 1),
        ]);
        expect(targetExtras.map((extra) => extra.amount).toList(), [
          180,
          100,
          100,
        ]);
      },
    );

    test('Does not target a debt before its future tracking month', () {
      final loans = [
        Loan(
          id: 'future',
          name: 'Future-tracked debt',
          type: LoanType.personalLoan,
          principal: 50,
          annualRate: 0,
          startDate: DateTime(2026, 9, 23),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 10,
        ),
        Loan(
          id: 'current',
          name: 'Current debt',
          type: LoanType.personalLoan,
          principal: 500,
          annualRate: 0,
          startDate: DateTime(2026, 8, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 10,
        ),
      ];

      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.snowball,
        monthlyBudget: 100,
        planStart: DateTime(2026, 8, 20),
      );
      final futureResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'future',
      );

      expect(futureResult.firstTargetMonth, 2);
    });

    test('Waits beyond the divergence window for future tracking', () {
      final loan = Loan(
        id: 'far-future',
        name: 'Far-future debt',
        type: LoanType.personalLoan,
        principal: 100,
        annualRate: 0,
        startDate: DateTime(2027, 10, 1),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 100,
      );

      final plan = PayoffPlanner.plan(
        loans: [loan],
        startingBalances: {loan.id: loan.principal},
        method: PlanMethod.snowball,
        monthlyBudget: 0,
        planStart: DateTime(2026, 8, 20),
      );

      expect(plan.neverPaysOff, isFalse);
      expect(plan.loanResults.single.monthsToPayoff, 15);
    });

    test('Does not replay payments due before a mid-month plan start', () {
      final loans = [
        Loan(
          id: 'early',
          name: 'Early-month debt',
          type: LoanType.creditCard,
          principal: 1000,
          annualRate: 0,
          startDate: DateTime(2026, 1, 1),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 133,
        ),
        Loan(
          id: 'late',
          name: 'Late-month debt',
          type: LoanType.personalLoan,
          principal: 180,
          annualRate: 0,
          startDate: DateTime(2026, 1, 23),
          paymentMode: PaymentMode.fixedPayment,
          fixedMonthlyPayment: 180,
        ),
      ];

      final plan = PayoffPlanner.plan(
        loans: loans,
        startingBalances: balancesOf(loans),
        method: PlanMethod.avalanche,
        monthlyBudget: 0,
        planStart: DateTime(2026, 8, 28),
      );
      final lateResult = plan.loanResults.firstWhere(
        (result) => result.loanId == 'late',
      );

      expect(lateResult.monthsToPayoff, 2);
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
        DateTime(2026, 5),
      );
      expect(
        state.loanById('tiny')!.extras.single.startDate,
        DateTime(2026, 5),
      );
      expect(state.loanById('scheduled')!.extras, isEmpty);
    });

    test('Starts an applied strategy on each debt payment date', () async {
      SharedPreferences.setMockInitialValues({});
      final loan = Loan(
        id: 'late',
        name: 'Late-month debt',
        type: LoanType.creditCard,
        principal: 5000,
        annualRate: 22,
        startDate: DateTime(2026, 1, 23),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 180,
      );
      final state = AppState();
      await state.addLoan(loan);
      final plan = PayoffPlanner.plan(
        loans: [loan],
        startingBalances: {loan.id: loan.principal},
        method: PlanMethod.avalanche,
        monthlyBudget: 100,
        planStart: DateTime(2026, 9),
      );

      await state.applyPayoffPlan(plan, startDate: DateTime(2026, 9));

      expect(
        state.loanById(loan.id)!.extras.single.startDate,
        DateTime(2026, 9, 23),
      );
    });

    test('Never backdates an applied strategy before its plan start', () async {
      SharedPreferences.setMockInitialValues({});
      final loan = Loan(
        id: 'month-start',
        name: 'Month-start debt',
        type: LoanType.creditCard,
        principal: 5000,
        annualRate: 22,
        startDate: DateTime(2026, 1, 1),
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: 133,
      );
      final state = AppState();
      await state.addLoan(loan);
      final plan = PayoffPlanner.plan(
        loans: [loan],
        startingBalances: {loan.id: loan.principal},
        method: PlanMethod.avalanche,
        monthlyBudget: 100,
        planStart: DateTime(2026, 8, 28),
      );

      await state.applyPayoffPlan(plan, startDate: DateTime(2026, 8, 28));

      expect(
        state.loanById(loan.id)!.extras.single.startDate,
        DateTime(2026, 9, 1),
      );
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

  group('Strategy schedule', () {
    final loan = Loan(
      id: 'scheduled-strategy',
      name: 'Scheduled strategy',
      type: LoanType.personalLoan,
      principal: 1000,
      annualRate: 0,
      startDate: DateTime(2026, 1),
      paymentMode: PaymentMode.fixedPayment,
      fixedMonthlyPayment: 100,
      extras: [
        ExtraPayment(
          id: 'monthly-extra',
          name: 'Monthly extra',
          amount: 100,
          cadence: CadenceType.monthly,
        ),
      ],
    );

    test('pause suppresses extras only inside its inclusive month window', () {
      final result = AmortizationEngine.simulate(
        loan,
        loan.extras,
        strategySchedule: [
          StrategyScheduleOverride(
            id: 'summer',
            name: 'Summer vacation',
            startMonth: DateTime(2026, 2),
            endMonth: DateTime(2026, 3),
            mode: StrategyOverrideMode.paused,
          ),
        ],
      );

      expect(result.schedule[0].extra, closeTo(100, 0.01));
      expect(result.schedule[1].extra, closeTo(0, 0.01));
      expect(result.schedule[2].extra, closeTo(0, 0.01));
      expect(result.schedule[3].extra, closeTo(100, 0.01));
    });

    test('reduction scales planned extras while minimums continue', () {
      final result = AmortizationEngine.simulate(
        loan,
        loan.extras,
        strategySchedule: [
          StrategyScheduleOverride(
            id: 'reduced',
            name: 'Reduced summer budget',
            startMonth: DateTime(2026, 2),
            endMonth: DateTime(2026, 2),
            mode: StrategyOverrideMode.reduced,
            factor: 0.5,
          ),
        ],
      );

      expect(result.schedule[1].payment, closeTo(100, 0.01));
      expect(result.schedule[1].extra, closeTo(50, 0.01));
    });

    test('payoff planner includes scheduled pauses in its preview', () {
      final plan = PayoffPlanner.plan(
        loans: [loan.copyWith(extras: const [])],
        startingBalances: {loan.id: loan.principal},
        method: PlanMethod.snowball,
        monthlyBudget: 100,
        planStart: DateTime(2026, 1),
        strategySchedule: [
          StrategyScheduleOverride(
            id: 'first-two-months',
            name: 'Initial pause',
            startMonth: DateTime(2026, 1),
            endMonth: DateTime(2026, 2),
            mode: StrategyOverrideMode.paused,
          ),
        ],
      );

      expect(plan.loanResults.single.firstTargetMonth, 3);
    });

    test('scheduled windows persist locally', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      await state.addStrategyScheduleOverride(
        StrategyScheduleOverride(
          id: 'persisted-window',
          name: 'Summer vacation',
          startMonth: DateTime(2027, 6),
          endMonth: DateTime(2027, 8),
          mode: StrategyOverrideMode.paused,
        ),
      );

      final reloaded = AppState();
      await reloaded.load();

      expect(reloaded.strategySchedule, hasLength(1));
      expect(reloaded.strategySchedule.single.name, 'Summer vacation');
      expect(reloaded.strategySchedule.single.endMonth, DateTime(2027, 8));
    });

    test('resuming an open pause preserves its completed history', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      await state.addStrategyScheduleOverride(
        StrategyScheduleOverride(
          id: 'open-pause',
          name: 'Time away',
          startMonth: DateTime(2026, 6),
          mode: StrategyOverrideMode.paused,
        ),
      );

      await state.resumeStrategyScheduleOverride(
        'open-pause',
        asOf: DateTime(2026, 9, 10),
      );

      expect(state.strategySchedule.single.endMonth, DateTime(2026, 8));
    });

    test('schedule-only state is included in account sync', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      await state.addStrategyScheduleOverride(
        StrategyScheduleOverride(
          id: 'synced-pause',
          name: 'Synced vacation',
          startMonth: DateTime(2027, 7),
          endMonth: DateTime(2027, 7),
          mode: StrategyOverrideMode.paused,
        ),
      );
      final sync = _FakeSyncService();
      state.configureSync(sync);

      await state.setSyncSession(
        ({bool forceRefresh = false}) async => 'token',
        userId: 'schedule-user',
      );

      expect(sync.pushed, isNotNull);
      expect(
        (sync.pushed!.strategySchedule.single as Map<String, dynamic>)['id'],
        'synced-pause',
      );
    });
  });
}

Loan _testLoan(String id, String name) => Loan(
  id: id,
  name: name,
  type: LoanType.personalLoan,
  principal: 1000,
  annualRate: 5,
  startDate: DateTime(2026, 1),
  paymentMode: PaymentMode.fixedPayment,
  fixedMonthlyPayment: 100,
);

String _jsonFor(Loan loan) => jsonEncode(loan.toJson());

class _FakeSyncService extends SyncService {
  _FakeSyncService({this.remote});

  SyncDocument? remote;
  SyncDocument? pushed;
  int fetchCount = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<SyncDocument?> fetchState(String accessToken) async {
    fetchCount += 1;
    return remote;
  }

  @override
  Future<SyncDocument> pushState(
    String accessToken,
    SyncDocument document,
  ) async {
    pushed = document;
    remote = document;
    return document;
  }
}

class _AuthenticatedAuthService extends AuthService {
  static const _authenticatedUser = AuthUser(
    id: 'manual-sync-user',
    email: 'sync@example.com',
  );

  @override
  bool get isAuthenticated => true;

  @override
  AuthUser? get user => _authenticatedUser;

  @override
  Future<String?> validAccessToken({bool forceRefresh = false}) async =>
      'token';
}
