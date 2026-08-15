import '../models/mortgage.dart';
import '../models/extra_payment.dart';

class MonthRow {
  final int monthIndex; // 1-based
  final DateTime date;
  final double payment; // scheduled P&I payment made
  final double extra; // extra principal paid this month
  final double interest;
  final double principalPaid; // from scheduled payment
  final double balance; // remaining after this month

  const MonthRow({
    required this.monthIndex,
    required this.date,
    required this.payment,
    required this.extra,
    required this.interest,
    required this.principalPaid,
    required this.balance,
  });
}

class SimulationResult {
  final List<MonthRow> schedule;
  final double totalInterest;
  final double totalPaid;
  final int monthsToPayoff;
  final DateTime payoffDate;

  const SimulationResult({
    required this.schedule,
    required this.totalInterest,
    required this.totalPaid,
    required this.monthsToPayoff,
    required this.payoffDate,
  });
}

class ComparisonResult {
  final SimulationResult baseline;
  final SimulationResult accelerated;

  const ComparisonResult({required this.baseline, required this.accelerated});

  double get interestSaved =>
      baseline.totalInterest - accelerated.totalInterest;

  int get monthsSaved =>
      baseline.monthsToPayoff - accelerated.monthsToPayoff;

  String get timeSavedLabel {
    final years = monthsSaved ~/ 12;
    final months = monthsSaved % 12;
    if (years == 0 && months == 0) return '0 mo';
    if (years == 0) return '$months mo';
    if (months == 0) return '$years yr';
    return '$years yr $months mo';
  }
}

class AmortizationEngine {
  /// Simulate the mortgage month-by-month.
  /// Extra payments with weekly cadences are mapped into the months in which
  /// they occur (a month may receive multiple every-N-weeks payments).
  static SimulationResult simulate(
    Mortgage mortgage,
    List<ExtraPayment> extras,
  ) {
    final activeExtras = extras.where((e) => e.enabled).toList();
    final monthlyPayment = mortgage.monthlyPayment;
    final r = mortgage.monthlyRate;

    double balance = mortgage.principal;
    double totalInterest = 0;
    double totalPaid = 0;
    final schedule = <MonthRow>[];

    // Pre-compute week-based payment dates for everyNWeeks cadence.
    // Map: monthKey (year*12+month) -> total extra from weekly cadences
    final weeklyExtraByMonth = <int, double>{};
    for (final e in activeExtras) {
      if (e.cadence != CadenceType.everyNWeeks) continue;
      final start = e.startDate ?? mortgage.startDate;
      DateTime d = start;
      // generate far enough into the future (termYears + buffer)
      final end = DateTime(
          mortgage.startDate.year + mortgage.termYears + 2,
          mortgage.startDate.month);
      while (d.isBefore(end)) {
        final key = d.year * 12 + (d.month - 1);
        weeklyExtraByMonth[key] = (weeklyExtraByMonth[key] ?? 0) + e.amount;
        d = d.add(Duration(days: 7 * e.interval));
      }
    }

    final maxMonths = mortgage.termMonths + 240; // safety bound
    int m = 0;
    while (balance > 0.005 && m < maxMonths) {
      m++;
      final date = DateTime(
          mortgage.startDate.year, mortgage.startDate.month + m - 1, 1);

      final interest = balance * r;
      double scheduled = monthlyPayment;
      double principalPart = scheduled - interest;

      // Extra principal for this month
      double extra = 0;
      final monthKey = date.year * 12 + (date.month - 1);
      for (final e in activeExtras) {
        final start = e.startDate ?? mortgage.startDate;
        final startKey = start.year * 12 + (start.month - 1);
        switch (e.cadence) {
          case CadenceType.monthly:
            if (monthKey >= startKey) extra += e.amount;
            break;
          case CadenceType.annual:
            if (monthKey >= startKey && date.month == e.annualMonth) {
              extra += e.amount;
            }
            break;
          case CadenceType.everyNMonths:
            if (monthKey >= startKey &&
                (monthKey - startKey) % e.interval == 0) {
              extra += e.amount;
            }
            break;
          case CadenceType.everyNWeeks:
            // handled via precomputed map
            break;
          case CadenceType.oneTime:
            final d = e.oneTimeDate;
            if (d != null &&
                d.year == date.year &&
                d.month == date.month) {
              extra += e.amount;
            }
            break;
        }
      }
      extra += weeklyExtraByMonth[monthKey] ?? 0;

      // Final payment adjustment
      if (principalPart + extra >= balance) {
        // Only pay what's needed
        if (principalPart >= balance) {
          principalPart = balance;
          scheduled = principalPart + interest;
          extra = 0;
        } else {
          extra = balance - principalPart;
        }
        balance = 0;
      } else {
        balance -= (principalPart + extra);
      }

      totalInterest += interest;
      totalPaid += scheduled + extra;

      schedule.add(MonthRow(
        monthIndex: m,
        date: date,
        payment: scheduled,
        extra: extra,
        interest: interest,
        principalPaid: principalPart,
        balance: balance,
      ));
    }

    final payoffDate = schedule.isNotEmpty
        ? schedule.last.date
        : mortgage.startDate;

    return SimulationResult(
      schedule: schedule,
      totalInterest: totalInterest,
      totalPaid: totalPaid,
      monthsToPayoff: schedule.length,
      payoffDate: payoffDate,
    );
  }

  static ComparisonResult compare(
    Mortgage mortgage,
    List<ExtraPayment> extras,
  ) {
    final baseline = simulate(mortgage, const []);
    final accelerated = simulate(mortgage, extras);
    return ComparisonResult(baseline: baseline, accelerated: accelerated);
  }
}
