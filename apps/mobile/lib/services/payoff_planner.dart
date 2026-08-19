import '../models/loan.dart';

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

  const PlanResult({
    required this.method,
    required this.monthlyBudget,
    required this.loanResults,
    required this.curve,
    required this.totalInterest,
    required this.monthsToDebtFree,
    required this.debtFreeDate,
    this.neverPaysOff = false,
  });
}

class _SimLoan {
  final Loan loan;
  double balance;
  double totalInterest = 0;
  double totalExtraPaid = 0;
  int targetedMonths = 0;
  int? firstTargetMonth;
  int? payoffMonth;

  _SimLoan(this.loan, this.balance);
}

class PayoffPlanner {
  static const int _maxMonths = 600; // 50-year safety bound

  /// Simulate all loans together from today.
  /// [monthlyBudget] is the shared extra amount applied each month to the
  /// target loan (chosen by [method]). When a loan pays off, its scheduled
  /// payment ROLLS OVER into the budget (debt-rollover effect).
  ///
  /// Individual loan strategies (extras) are intentionally excluded here —
  /// the planner answers "where should my extra budget go", independent of
  /// per-loan experiments.
  static PlanResult plan({
    required List<Loan> loans,
    required Map<String, double> startingBalances,
    required PlanMethod method,
    required double monthlyBudget,
  }) {
    final start = DateTime(DateTime.now().year, DateTime.now().month);
    final sims = loans
        .map((l) => _SimLoan(l, startingBalances[l.id] ?? l.principal))
        .where((s) => s.balance > 0.005)
        .toList();

    final curve = <DebtPoint>[];
    double rolledOver = 0; // freed-up scheduled payments from paid-off loans
    int m = 0;

    while (sims.any((s) => s.balance > 0.005) && m < _maxMonths) {
      m++;

      // Sort active loans by priority: the first is this month's target.
      final active = sims.where((s) => s.balance > 0.005).toList();
      active.sort(
        (a, b) => method == PlanMethod.avalanche
            ? b.loan.annualRate.compareTo(a.loan.annualRate)
            : a.balance.compareTo(b.balance),
      );

      double budget = monthlyBudget + rolledOver;

      // 1) Apply scheduled payments to every active loan.
      for (final s in active) {
        final interest = s.balance * s.loan.monthlyRate;
        s.totalInterest += interest;
        double principal = s.loan.monthlyPayment - interest;
        if (principal < 0) {
          // Payment doesn't cover interest — balance grows unless the
          // budget rescues it below.
          s.balance -= principal; // principal is negative -> grows
          principal = 0;
        } else if (principal >= s.balance) {
          // Overpayment on final month: leftover joins this month's budget.
          budget += principal - s.balance;
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
        final pay = budget >= s.balance ? s.balance : budget;
        s.balance -= pay;
        s.totalExtraPaid += pay;
        s.targetedMonths++;
        s.firstTargetMonth ??= m;
        budget -= pay;
      }

      // 3) Roll over scheduled payments of loans that just finished.
      for (final s in sims) {
        if (s.balance <= 0.005 && s.payoffMonth == null) {
          s.payoffMonth = m;
          rolledOver += s.loan.monthlyPayment;
        }
      }

      final total = sims.fold<double>(0, (sum, s) => sum + s.balance);
      curve.add(DebtPoint(m, total));

      // Divergence guard: if total debt hasn't decreased over the last
      // 12 months, the plan never pays off — stop early.
      if (m > 12 && total > 0 && total >= curve[m - 13].totalBalance) {
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
          targetedMonths: s.targetedMonths,
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
      monthsToDebtFree: m,
      debtFreeDate: DateTime(start.year, start.month + m - 1),
      neverPaysOff: neverPaysOff,
    );
  }

  static String monthsLabel(int months) {
    final years = months ~/ 12;
    final rem = months % 12;
    if (years == 0) return '$rem mo';
    if (rem == 0) return '$years yr';
    return '$years yr $rem mo';
  }
}
