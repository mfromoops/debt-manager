import '../models/loan.dart';
import '../models/extra_payment.dart';
import '../models/strategy_schedule_override.dart';

enum PlanMethod { avalanche, snowball }

extension PlanMethodInfo on PlanMethod {
  String get label => this == PlanMethod.avalanche ? 'Avalanche' : 'Snowball';

  String get description => this == PlanMethod.avalanche
      ? 'Highest interest rate first — saves the most money.'
      : 'Smallest balance first — quick wins for motivation.';
}

/// One loan's outcome within a plan.
class PlanLoanResult {
  final String loanId;
  final String loanName;
  final int payoffOrder; // 1-based order of elimination
  final DateTime payoffDate;
  final int monthsToPayoff;
  final double totalInterest;
  final double totalExtraPaid;
  final int targetedMonths;
  final int? firstTargetMonth;

  const PlanLoanResult({
    required this.loanId,
    required this.loanName,
    required this.payoffOrder,
    required this.payoffDate,
    required this.monthsToPayoff,
    required this.totalInterest,
    required this.totalExtraPaid,
    required this.targetedMonths,
    required this.firstTargetMonth,
  });
}

/// A point in the combined debt curve.
class DebtPoint {
  final int monthIndex; // 1-based from plan start
  final double totalBalance;

  const DebtPoint(this.monthIndex, this.totalBalance);
}

class PlanResult {
  final PlanMethod method;
  final double monthlyBudget; // extra budget applied
  final List<PlanLoanResult> loanResults; // in payoff order
  final List<DebtPoint> curve; // combined balance over time
  final double totalInterest;
  final int monthsToDebtFree;
  final DateTime debtFreeDate;
  final bool neverPaysOff;
  final List<ExtraPayment> addons;
  final List<PlanAddonAllocation> addonAllocations;
  final List<PlanRolloverAllocation> rolloverAllocations;

  const PlanResult({
    required this.method,
    required this.monthlyBudget,
    required this.loanResults,
    required this.curve,
    required this.totalInterest,
    required this.monthsToDebtFree,
    required this.debtFreeDate,
    this.addons = const [],
    this.addonAllocations = const [],
    this.rolloverAllocations = const [],
    this.neverPaysOff = false,
  });
}

/// The part of a custom plan add-on that was actually sent to a loan.
class PlanAddonAllocation {
  final String addonId;
  final String loanId;
  final int monthIndex;
  final double amount;

  const PlanAddonAllocation({
    required this.addonId,
    required this.loanId,
    required this.monthIndex,
    required this.amount,
  });
}

/// A newly freed scheduled payment and the loan receiving it next month.
class PlanRolloverAllocation {
  final String sourceLoanId;
  final String loanId;
  final int monthIndex;
  final double amount;

  const PlanRolloverAllocation({
    required this.sourceLoanId,
    required this.loanId,
    required this.monthIndex,
    required this.amount,
  });
}

class _PendingRollover {
  final String sourceLoanId;
  final double amount;

  const _PendingRollover(this.sourceLoanId, this.amount);
}

class _SimLoan {
  final Loan loan;
  double balance;
  double totalInterest = 0;
  double totalExtraPaid = 0;
  final Set<int> targetedMonthIndexes = {};
  int? firstTargetMonth;
  int? payoffMonth;

  _SimLoan(this.loan, this.balance);
}

class PayoffPlanner {
  static const int _maxMonths = 600; // 50-year safety bound

  /// Simulate all loans together from [planStart] (the current month by
  /// default).
  /// [monthlyBudget] is the shared extra amount applied each month to the
  /// target loan (chosen by [method]). When a loan pays off, its scheduled
  /// payment ROLLS OVER into the budget (debt-rollover effect).
  ///
  /// Existing loan strategies are intentionally excluded. [addons] are
  /// scenario-specific shared cash events and follow the selected priority.
  static PlanResult plan({
    required List<Loan> loans,
    required Map<String, double> startingBalances,
    required PlanMethod method,
    required double monthlyBudget,
    List<ExtraPayment> addons = const [],
    List<StrategyScheduleOverride> strategySchedule = const [],
    DateTime? planStart,
  }) {
    final requestedStart = planStart ?? DateTime.now();
    final start = DateTime(
      requestedStart.year,
      requestedStart.month,
      requestedStart.day,
    );
    final activeAddons = addons.where((addon) => addon.enabled).toList();
    final sims = loans
        .map((l) => _SimLoan(l, startingBalances[l.id] ?? l.principal))
        .where((s) => s.balance > 0.005)
        .toList();

    final curve = <DebtPoint>[];
    double rolledOver = 0; // freed-up scheduled payments from paid-off loans
    int currentMonth = 0;
    final addonAllocations = <PlanAddonAllocation>[];
    final rolloverAllocations = <PlanRolloverAllocation>[];
    final pendingRollovers = <_PendingRollover>[];

    while (sims.any((s) => s.balance > 0.005) && currentMonth < _maxMonths) {
      currentMonth++;

      final monthDate = DateTime(start.year, start.month + currentMonth - 1);

      // Sort active loans by priority: the first is this month's target.
      // A future-tracked debt remains part of the total balance, but cannot
      // accrue interest, receive a scheduled payment, or consume shared cash
      // until its tracking month begins.
      final active = sims
          .where(
            (s) =>
                s.balance > 0.005 &&
                _trackingHasStartedForMonth(s.loan, monthDate),
          )
          .toList();
      active.sort(
        (a, b) => method == PlanMethod.avalanche
            ? b.loan.annualRate.compareTo(a.loan.annualRate)
            : a.balance.compareTo(b.balance),
      );

      final strategyFactor = StrategyScheduleOverride.factorFor(
        monthDate,
        strategySchedule,
      );
      double budget = (monthlyBudget + rolledOver) * strategyFactor;

      // 1) Apply scheduled payments to every active loan.
      for (final s in active) {
        final scheduledDate = _scheduledDateForMonth(s.loan, monthDate);
        if (currentMonth == 1 && scheduledDate.isBefore(start)) continue;
        final interest = s.balance * s.loan.monthlyRate;
        s.totalInterest += interest;
        double principal = s.loan.monthlyPayment - interest;
        if (principal < 0) {
          // Payment doesn't cover interest — balance grows unless the
          // budget rescues it below.
          s.balance -= principal; // principal is negative -> grows
          principal = 0;
        } else if (principal >= s.balance) {
          // The unused part of a final scheduled payment is not available
          // until the following month. Keep it with the deferred rollover
          // amount instead of cascading it into this month's target.
          s.balance = 0;
        } else {
          s.balance -= principal;
        }
      }

      // 2) Apply the extra budget cascading through loans in priority
      //    order (target first). If the target dies mid-month, the
      //    remainder flows to the next priority loan.
      for (final s in active) {
        if (budget <= 0.005) break;
        if (s.balance <= 0.005) continue;
        if (pendingRollovers.isNotEmpty) {
          for (final rollover in pendingRollovers) {
            rolloverAllocations.add(
              PlanRolloverAllocation(
                sourceLoanId: rollover.sourceLoanId,
                loanId: s.loan.id,
                monthIndex: currentMonth,
                amount: rollover.amount,
              ),
            );
          }
          pendingRollovers.clear();
        }
        final pay = budget >= s.balance ? s.balance : budget;
        s.balance -= pay;
        s.totalExtraPaid += pay;
        s.targetedMonthIndexes.add(currentMonth);
        s.firstTargetMonth ??= currentMonth;
        budget -= pay;
      }

      // 3) Apply custom cash events after the regular monthly budget. Keeping
      // these allocations separate lets Apply Strategy reproduce them later.
      for (final addon in activeAddons) {
        double addonBudget =
            _addonAmountForMonth(addon, start, currentMonth) * strategyFactor;
        if (addonBudget <= 0.005) continue;
        for (final s in active) {
          if (addonBudget <= 0.005) break;
          if (s.balance <= 0.005) continue;
          final pay = addonBudget >= s.balance ? s.balance : addonBudget;
          s.balance -= pay;
          s.totalExtraPaid += pay;
          s.targetedMonthIndexes.add(currentMonth);
          s.firstTargetMonth ??= currentMonth;
          addonAllocations.add(
            PlanAddonAllocation(
              addonId: addon.id,
              loanId: s.loan.id,
              monthIndex: currentMonth,
              amount: pay,
            ),
          );
          addonBudget -= pay;
        }
      }

      // 4) Roll over scheduled payments of loans that just finished.
      for (final s in sims) {
        if (s.balance <= 0.005 && s.payoffMonth == null) {
          s.payoffMonth = currentMonth;
          rolledOver += s.loan.monthlyPayment;
          pendingRollovers.add(
            _PendingRollover(s.loan.id, s.loan.monthlyPayment),
          );
        }
      }

      final total = sims.fold<double>(0, (sum, s) => sum + s.balance);
      curve.add(DebtPoint(currentMonth, total));

      // Divergence guard: if total debt hasn't decreased over the last
      // 12 months, the plan never pays off — stop early.
      final waitingForFutureTracking = sims.any(
        (s) =>
            s.balance > 0.005 &&
            !_trackingHasStartedForMonth(s.loan, monthDate),
      );
      if (!waitingForFutureTracking &&
          currentMonth > 12 &&
          total > 0 &&
          total >= curve[currentMonth - 13].totalBalance) {
        break;
      }
    }

    final neverPaysOff = sims.any((s) => s.balance > 0.005);

    // Build per-loan results in payoff order.
    final finished = sims.where((s) => s.payoffMonth != null).toList()
      ..sort((a, b) => a.payoffMonth!.compareTo(b.payoffMonth!));
    final results = <PlanLoanResult>[];
    for (int i = 0; i < finished.length; i++) {
      final s = finished[i];
      results.add(
        PlanLoanResult(
          loanId: s.loan.id,
          loanName: s.loan.name,
          payoffOrder: i + 1,
          payoffDate: DateTime(start.year, start.month + s.payoffMonth! - 1),
          monthsToPayoff: s.payoffMonth!,
          totalInterest: s.totalInterest,
          totalExtraPaid: s.totalExtraPaid,
          targetedMonths: s.targetedMonthIndexes.length,
          firstTargetMonth: s.firstTargetMonth,
        ),
      );
    }

    final totalInterest = sims.fold<double>(
      0,
      (sum, s) => sum + s.totalInterest,
    );

    return PlanResult(
      method: method,
      monthlyBudget: monthlyBudget,
      loanResults: results,
      curve: curve,
      totalInterest: totalInterest,
      monthsToDebtFree: currentMonth,
      debtFreeDate: DateTime(start.year, start.month + currentMonth - 1),
      addons: List.unmodifiable(activeAddons),
      addonAllocations: List.unmodifiable(addonAllocations),
      rolloverAllocations: List.unmodifiable(rolloverAllocations),
      neverPaysOff: neverPaysOff,
    );
  }

  static double _addonAmountForMonth(
    ExtraPayment addon,
    DateTime planStart,
    int monthIndex,
  ) {
    final date = DateTime(planStart.year, planStart.month + monthIndex - 1);
    final monthKey = date.year * 12 + date.month - 1;
    final configuredStart = addon.startDate ?? planStart;
    final startKey = configuredStart.year * 12 + configuredStart.month - 1;
    if (monthKey < startKey) return 0;

    switch (addon.cadence) {
      case CadenceType.monthly:
        return addon.amount;
      case CadenceType.annual:
        return date.month == addon.annualMonth ? addon.amount : 0;
      case CadenceType.everyNMonths:
        return (monthKey - startKey) % addon.interval == 0 ? addon.amount : 0;
      case CadenceType.oneTime:
        final paymentDate = addon.oneTimeDate;
        return paymentDate != null &&
                paymentDate.year == date.year &&
                paymentDate.month == date.month
            ? addon.amount
            : 0;
      case CadenceType.everyNWeeks:
        final intervalDays = 7 * addon.interval;
        var occurrence = configuredStart;
        var total = 0.0;
        final monthEnd = DateTime(date.year, date.month + 1);
        while (occurrence.isBefore(monthEnd)) {
          if (occurrence.year == date.year && occurrence.month == date.month) {
            total += addon.amount;
          }
          occurrence = occurrence.add(Duration(days: intervalDays));
        }
        return total;
    }
  }

  static DateTime _scheduledDateForMonth(Loan loan, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(
      month.year,
      month.month,
      loan.startDate.day.clamp(1, lastDay),
    );
  }

  static bool _trackingHasStartedForMonth(Loan loan, DateTime month) {
    final monthKey = month.year * 12 + month.month - 1;
    final trackingKey = loan.startDate.year * 12 + loan.startDate.month - 1;
    return monthKey >= trackingKey;
  }

  static String monthsLabel(int months) {
    final years = months ~/ 12;
    final rem = months % 12;
    if (years == 0) return '$rem mo';
    if (rem == 0) return '$years yr';
    return '$years yr $rem mo';
  }
}
