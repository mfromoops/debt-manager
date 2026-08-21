import '../models/loan.dart';
import '../models/extra_payment.dart';
import '../models/strategy_schedule_override.dart';

class MonthRow {
  final int monthIndex; // 1-based
  final DateTime date;
  final double payment; // scheduled payment made
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

  /// True when the loan never pays off within the simulation bound
  /// (e.g. credit card payment doesn't cover interest).
  final bool neverPaysOff;

  const SimulationResult({
    required this.schedule,
    required this.totalInterest,
    required this.totalPaid,
    required this.monthsToPayoff,
    required this.payoffDate,
    this.neverPaysOff = false,
  });
}

class ComparisonResult {
  final SimulationResult baseline;
  final SimulationResult accelerated;

  const ComparisonResult({required this.baseline, required this.accelerated});

  double get interestSaved =>
      baseline.totalInterest - accelerated.totalInterest;

  int get monthsSaved => baseline.monthsToPayoff - accelerated.monthsToPayoff;

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
  /// Simulate the loan month-by-month.
  /// Extra payments with weekly cadences are mapped into the months in which
  /// they occur (a month may receive multiple every-N-weeks payments).
  static SimulationResult simulate(
    Loan loan,
    List<ExtraPayment> extras, {
    List<StrategyScheduleOverride> strategySchedule = const [],
  }) {
    final activeExtras = extras.where((e) => e.enabled).toList();
    final monthlyPayment = loan.monthlyPayment;
    final r = loan.monthlyRate;

    double balance = loan.principal;
    double totalInterest = 0;
    double totalPaid = 0;
    final schedule = <MonthRow>[];

    // Pre-compute week-based payment dates for everyNWeeks cadence.
    final weeklyExtraByMonth = <int, double>{};
    final weeklyLastDateByMonth = <int, DateTime>{};
    // Bound: amortized -> term + buffer; fixed payment -> 50 years max.
    final maxMonths = loan.paymentMode == PaymentMode.amortized
        ? loan.termMonths + 240
        : 600;
    for (final e in activeExtras) {
      if (e.cadence != CadenceType.everyNWeeks) continue;
      final start = e.startDate ?? loan.startDate;
      DateTime d = start;
      final end = DateTime(
        loan.startDate.year + (maxMonths ~/ 12) + 2,
        loan.startDate.month,
      );
      while (d.isBefore(end)) {
        final key = d.year * 12 + (d.month - 1);
        weeklyExtraByMonth[key] = (weeklyExtraByMonth[key] ?? 0) + e.amount;
        final previous = weeklyLastDateByMonth[key];
        if (previous == null || d.isAfter(previous)) {
          weeklyLastDateByMonth[key] = d;
        }
        d = d.add(Duration(days: 7 * e.interval));
      }
    }

    int m = 0;
    bool stalled = false;
    while (balance > 0.005 && m < maxMonths) {
      m++;
      final month = DateTime(loan.startDate.year, loan.startDate.month + m - 1);
      final scheduledDate = _dateInMonth(month, loan.startDate.day);
      var rowDate = scheduledDate;

      final interest = balance * r;
      double scheduled = monthlyPayment;
      double principalPart = scheduled - interest;

      // Extra principal for this month
      double extra = 0;
      DateTime? latestExtraDate;
      final monthKey = month.year * 12 + (month.month - 1);
      for (final e in activeExtras) {
        final start = e.startDate ?? loan.startDate;
        final startKey = start.year * 12 + (start.month - 1);
        DateTime? occurrenceDate;
        switch (e.cadence) {
          case CadenceType.monthly:
            if (monthKey >= startKey) {
              extra += e.amount;
              occurrenceDate = _dateInMonth(month, start.day);
            }
            break;
          case CadenceType.annual:
            if (monthKey >= startKey && month.month == e.annualMonth) {
              extra += e.amount;
              occurrenceDate = _dateInMonth(month, start.day);
            }
            break;
          case CadenceType.everyNMonths:
            if (monthKey >= startKey &&
                (monthKey - startKey) % e.interval == 0) {
              extra += e.amount;
              occurrenceDate = _dateInMonth(month, start.day);
            }
            break;
          case CadenceType.everyNWeeks:
            // handled via precomputed map
            break;
          case CadenceType.oneTime:
            final d = e.oneTimeDate;
            if (d != null && d.year == month.year && d.month == month.month) {
              extra += e.amount;
              occurrenceDate = d;
            }
            break;
        }
        if (occurrenceDate != null &&
            (latestExtraDate == null ||
                occurrenceDate.isAfter(latestExtraDate))) {
          latestExtraDate = occurrenceDate;
        }
      }
      extra += weeklyExtraByMonth[monthKey] ?? 0;
      final weeklyLastDate = weeklyLastDateByMonth[monthKey];
      if (weeklyLastDate != null &&
          (latestExtraDate == null ||
              weeklyLastDate.isAfter(latestExtraDate))) {
        latestExtraDate = weeklyLastDate;
      }
      extra *= StrategyScheduleOverride.factorFor(month, strategySchedule);

      // If principal part is not positive and no extra, the balance grows —
      // clamp scheduled payment to cover at least interest so the schedule
      // remains meaningful, and flag as stalled if nothing reduces principal.
      if (principalPart <= 0 && extra <= 0) {
        stalled = true;
        // Balance grows by unpaid interest.
        final unpaid = interest - scheduled;
        totalInterest += interest;
        totalPaid += scheduled;
        balance += unpaid;
        schedule.add(
          MonthRow(
            monthIndex: m,
            date: scheduledDate,
            payment: scheduled,
            extra: 0,
            interest: interest,
            principalPaid: principalPart,
            balance: balance,
          ),
        );
        // If it's clearly diverging, stop early after a year of growth.
        if (m > 12 && schedule.length > 12) {
          final prev = schedule[schedule.length - 13].balance;
          if (balance >= prev) break;
        }
        continue;
      }

      // Final payment adjustment
      if (principalPart + extra >= balance) {
        if (principalPart >= balance) {
          principalPart = balance;
          scheduled = principalPart + interest;
          extra = 0;
        } else {
          extra = balance - principalPart;
          if (latestExtraDate != null && latestExtraDate.isAfter(rowDate)) {
            rowDate = latestExtraDate;
          }
        }
        balance = 0;
      } else {
        balance -= (principalPart + extra);
      }

      totalInterest += interest;
      totalPaid += scheduled + extra;

      schedule.add(
        MonthRow(
          monthIndex: m,
          date: rowDate,
          payment: scheduled,
          extra: extra,
          interest: interest,
          principalPaid: principalPart,
          balance: balance,
        ),
      );
    }

    final neverPaysOff = balance > 0.005 || stalled && balance > 0.005;
    final payoffDate = schedule.isNotEmpty
        ? schedule.last.date
        : loan.startDate;

    return SimulationResult(
      schedule: schedule,
      totalInterest: totalInterest,
      totalPaid: totalPaid,
      monthsToPayoff: schedule.length,
      payoffDate: payoffDate,
      neverPaysOff: neverPaysOff,
    );
  }

  static DateTime _dateInMonth(DateTime month, int day) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, day.clamp(1, lastDay));
  }

  static ComparisonResult compare(
    Loan loan, {
    List<StrategyScheduleOverride> strategySchedule = const [],
  }) {
    final baseline = simulate(loan, const []);
    final accelerated = simulate(
      loan,
      loan.extras,
      strategySchedule: strategySchedule,
    );
    return ComparisonResult(baseline: baseline, accelerated: accelerated);
  }
}
