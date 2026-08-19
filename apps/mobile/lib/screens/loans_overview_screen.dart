import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import 'loan_edit_screen.dart';
import 'loan_detail_shell.dart';
import 'planner_screen.dart';

class LoansOverviewScreen extends StatelessWidget {
  const LoansOverviewScreen({super.key});

  IconData _iconFor(LoanType t) {
    switch (t) {
      case LoanType.mortgage:
        return Icons.home_outlined;
      case LoanType.creditCard:
        return Icons.credit_card_outlined;
      case LoanType.personalLoan:
        return Icons.account_balance_wallet_outlined;
      case LoanType.autoLoan:
        return Icons.directions_car_outlined;
      case LoanType.studentLoan:
        return Icons.school_outlined;
      case LoanType.other:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final loans = state.sortedLoans;
    final upcomingLoan = state.upcomingPaymentLoan();
    final upcomingDate = upcomingLoan == null
        ? null
        : state.nextPaymentDate(upcomingLoan);

    return Scaffold(
      body: SafeArea(
        child: state.loans.isEmpty
            ? _emptyState(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w200,
                            color: kInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.syncing)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kAccent,
                                ),
                              )
                            else if (state.syncError != null)
                              Tooltip(
                                message: state.syncError!,
                                child: const Icon(
                                  Icons.cloud_off_outlined,
                                  size: 20,
                                  color: Color(0xFFB3402E),
                                ),
                              )
                            else if (auth.isAuthenticated)
                              const Tooltip(
                                message: 'Synced',
                                child: Icon(
                                  Icons.cloud_done_outlined,
                                  size: 20,
                                  color: kSubtle,
                                ),
                              )
                            else
                              const Tooltip(
                                message: 'Stored on this device',
                                child: Icon(
                                  Icons.phone_android_outlined,
                                  size: 20,
                                  color: kSubtle,
                                ),
                              ),
                            const SizedBox(width: 8),
                            _accountMenu(context, auth, state),
                            IconButton(
                              icon: const Icon(
                                Icons.add,
                                size: 22,
                                color: kAccent,
                              ),
                              onPressed: () => _addLoan(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _PaymentOverview(
                      minimumDue: state.minimumDue,
                      strategyPayment: state.paymentWithStrategies,
                      strategyExtra: state.strategyExtra,
                      upcomingLoan: upcomingLoan,
                      upcomingDate: upcomingDate,
                    ),
                    const SizedBox(height: 24),
                    _DebtProgressCard(
                      balance: state.totalDebt,
                      interestSaved: state.totalInterestSaved,
                      projectedBalances: state.projectedDebtBalances(),
                    ),
                    const SizedBox(height: 28),
                    // Payoff Planner entry
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlannerScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: kAccent),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.route_outlined,
                              size: 18,
                              color: kAccent,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payoff Planner',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: kAccent,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Avalanche vs snowball — where should extra money go?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w300,
                                      color: kSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: kSubtle),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'YOUR LOANS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w400,
                            color: kSubtle,
                          ),
                        ),
                        PopupMenuButton<LoanSortOption>(
                          tooltip: 'Sort loans',
                          initialValue: state.loanSort,
                          icon: const Icon(
                            Icons.sort,
                            size: 20,
                            color: kSubtle,
                          ),
                          onSelected: state.setLoanSort,
                          itemBuilder: (context) => LoanSortOption.values
                              .map(
                                (option) => PopupMenuItem<LoanSortOption>(
                                  value: option,
                                  child: Row(
                                    children: [
                                      Icon(
                                        state.loanSort == option
                                            ? Icons.check
                                            : Icons.circle_outlined,
                                        size: 16,
                                        color: state.loanSort == option
                                            ? kAccent
                                            : Colors.transparent,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(option.label),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...loans.map(
                      (loan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LoanRow(loan: loan, icon: _iconFor(loan.type)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  void _addLoan(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoanEditScreen()));
  }

  Widget _emptyState(BuildContext context) {
    final auth = context.watch<AuthService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Align(
            alignment: Alignment.centerRight,
            child: _accountMenu(context, auth, context.watch<AppState>()),
          ),
          const Text(
            'Debts',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w200,
              color: kInk,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track mortgages, credit cards and loans.\nSimulate strategies to pay them off sooner.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: kSubtle,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _addLoan(context),
              child: const Text('Add your first loan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountMenu(BuildContext context, AuthService auth, AppState state) {
    final hasStrategies = state.loans.any((loan) => loan.extras.isNotEmpty);
    return PopupMenuButton<String>(
      tooltip: auth.user?.displayName ?? 'Account',
      icon: const Icon(Icons.account_circle_outlined, size: 22, color: kSubtle),
      onSelected: (value) async {
        if (value == 'clear-strategies') {
          await _confirmClearStrategies(context);
        } else if (value == 'sign-out') {
          await auth.signOut();
        } else if (value == 'sign-in') {
          await auth.signIn();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            auth.user?.email ?? 'Stored on this device',
            style: const TextStyle(fontSize: 12, color: kSubtle),
          ),
        ),
        if (hasStrategies) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'clear-strategies',
            child: Text('Clear all strategies'),
          ),
        ],
        const PopupMenuDivider(),
        if (auth.isAuthenticated)
          const PopupMenuItem<String>(
            value: 'sign-out',
            child: Text('Sign out'),
          )
        else
          PopupMenuItem<String>(
            value: 'sign-in',
            enabled: auth.isConfigured && !auth.busy,
            child: const Text('Sign in to sync'),
          ),
      ],
    );
  }

  Future<void> _confirmClearStrategies(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all strategies?'),
        content: const Text(
          'This removes every extra payment strategy from every debt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AppState>().clearAllStrategies();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All strategies removed.')));
  }
}

class _DebtProgressCard extends StatelessWidget {
  final double balance;
  final double interestSaved;
  final List<double> projectedBalances;

  const _DebtProgressCard({
    required this.balance,
    required this.interestSaved,
    required this.projectedBalances,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: const Key('debt-progress-card'),
        height: 244,
        decoration: const BoxDecoration(color: Color(0xFFF7F9F7)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label:
                  'Projected balance over ${projectedBalances.length - 1} months',
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const Key('debt-progress-chart'),
                  painter: _ProjectedBalancePainter(projectedBalances),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEBT PROGRESS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w500,
                      color: kSubtle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          money.format(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w200,
                            color: kInk,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text(
                          'remaining',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: kSubtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    interestSaved > 0.5
                        ? '${money.format(interestSaved)} projected interest saved'
                        : 'Projected balance with your active plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: interestSaved > 0.5 ? kAccent : kSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectedBalancePainter extends CustomPainter {
  final List<double> balances;

  _ProjectedBalancePainter(this.balances);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(48, 136, size.width - 12, size.height - 28);
    final maxBalance = balances.isEmpty
        ? 0.0
        : balances.reduce((a, b) => a > b ? a : b);
    final axisPaint = Paint()
      ..color = kSubtle.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final gridPaint = Paint()
      ..color = kSubtle.withValues(alpha: 0.13)
      ..strokeWidth = 0.8;

    for (var i = 0; i <= 2; i++) {
      final y = plot.top + plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = maxBalance * (1 - i / 2);
      _paintLabel(
        canvas,
        _compactMoney(value),
        Offset(plot.left - 6, y),
        alignRight: true,
        centerVertically: true,
      );
    }
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    const axisStyle = TextStyle(
      fontSize: 7,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w500,
      color: kSubtle,
    );
    _paintLabel(canvas, 'BALANCE', Offset(8, plot.top - 14), style: axisStyle);
    _paintLabel(
      canvas,
      'TIME',
      Offset(plot.right, size.height - 11),
      style: axisStyle,
      alignRight: true,
    );

    final months = balances.isEmpty ? 0 : balances.length - 1;
    _paintLabel(canvas, 'Now', Offset(plot.left, plot.bottom + 6));
    if (months > 1) {
      _paintLabel(
        canvas,
        _timeLabel(months ~/ 2),
        Offset(plot.center.dx, plot.bottom + 6),
        centered: true,
      );
    }
    _paintLabel(
      canvas,
      _timeLabel(months),
      Offset(plot.right, plot.bottom + 6),
      alignRight: true,
    );

    if (balances.length < 2 || maxBalance <= 0) return;

    final line = Path();
    for (var i = 0; i < balances.length; i++) {
      final x = plot.left + plot.width * i / (balances.length - 1);
      final normalized = (balances[i] / maxBalance).clamp(0.0, 1.0);
      final y = plot.top + plot.height * (1 - normalized);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final area = Path.from(line)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1F2D6A4F), Color(0x052D6A4F)],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = kAccent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    TextStyle style = const TextStyle(fontSize: 8, color: kSubtle),
    bool alignRight = false,
    bool centered = false,
    bool centerVertically = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    var x = offset.dx;
    var y = offset.dy;
    if (alignRight) x -= painter.width;
    if (centered) x -= painter.width / 2;
    if (centerVertically) y -= painter.height / 2;
    painter.paint(canvas, Offset(x, y));
  }

  String _compactMoney(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}m';
    }
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}k';
    return '\$${value.toStringAsFixed(0)}';
  }

  String _timeLabel(int months) {
    if (months <= 0) return 'Now';
    if (months < 12) return '$months mo';
    final years = months ~/ 12;
    final remainder = months % 12;
    return remainder == 0 ? '$years yr' : '$years y ${remainder}m';
  }

  @override
  bool shouldRepaint(covariant _ProjectedBalancePainter oldDelegate) =>
      oldDelegate.balances != balances;
}

class _PaymentOverview extends StatelessWidget {
  final double minimumDue;
  final double strategyPayment;
  final double strategyExtra;
  final Loan? upcomingLoan;
  final DateTime? upcomingDate;

  const _PaymentOverview({
    required this.minimumDue,
    required this.strategyPayment,
    required this.strategyExtra,
    required this.upcomingLoan,
    required this.upcomingDate,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final hasStrategy = strategyExtra > 0.005;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS PAYMENT CYCLE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Plan to pay',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            money.format(strategyPayment),
            key: const Key('strategy-payment-total'),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: kInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasStrategy
                ? '${money.format(minimumDue)} minimum + ${money.format(strategyExtra)} from your strategies'
                : '${money.format(minimumDue)} minimum due · no extra strategy payments this cycle',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFDCE8E0)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PaymentFact(
                  label: 'MINIMUM DUE',
                  value: money.format(minimumDue),
                  valueKey: const Key('minimum-due'),
                ),
              ),
              Container(width: 1, height: 42, color: const Color(0xFFDCE8E0)),
              const SizedBox(width: 20),
              Expanded(
                child: _PaymentFact(
                  label: 'NEXT PAYMENT',
                  value: upcomingDate == null
                      ? 'All paid'
                      : DateFormat('MMM d').format(upcomingDate!),
                  detail: upcomingLoan?.name,
                  valueKey: const Key('next-payment-date'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentFact extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final Key? valueKey;

  const _PaymentFact({
    required this.label,
    required this.value,
    this.detail,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: kInk,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
        ],
      ],
    );
  }
}

class _LoanRow extends StatelessWidget {
  final Loan loan;
  final IconData icon;

  const _LoanRow({required this.loan, required this.icon});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final comparison = state.comparisonFor(loan);
    final balance = state.currentBalance(loan);
    final nextPayment = state.nextPaymentDate(loan);
    final strategyPayment = state.nextPaymentWithStrategies(loan);
    final pct = ((loan.principal - balance) / loan.principal * 100)
        .clamp(0, 100)
        .toDouble();
    final activeStrategies = loan.extras.where((e) => e.enabled).length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoanDetailShell(loanId: loan.id)),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kHairline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 19, color: kAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${loan.type.label} · ${loan.annualRate}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: kSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money.format(balance),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kInk,
                      ),
                    ),
                    const Text(
                      'balance',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: kSubtle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 3,
                backgroundColor: kHairline,
                valueColor: const AlwaysStoppedAnimation(kAccent),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '${pct.toStringAsFixed(0)}% paid',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: kSubtle,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    comparison.accelerated.neverPaysOff
                        ? 'Payment needs attention'
                        : activeStrategies > 0
                        ? '${comparison.timeSavedLabel} sooner'
                        : 'Payoff ${DateFormat('MMM yyyy').format(comparison.accelerated.payoffDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: comparison.accelerated.neverPaysOff
                          ? const Color(0xFFB3402E)
                          : activeStrategies > 0
                          ? kAccent
                          : kSubtle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DebtMetric(
                    label: 'MINIMUM DUE',
                    value: money.format(loan.monthlyPayment),
                    valueKey: Key('debt-${loan.id}-minimum'),
                  ),
                ),
                const _DebtMetricDivider(),
                Expanded(
                  child: _DebtMetric(
                    label: 'NEXT PAYMENT',
                    value: DateFormat('MMM d').format(nextPayment),
                    valueKey: Key('debt-${loan.id}-date'),
                  ),
                ),
                const _DebtMetricDivider(),
                Expanded(
                  child: _DebtMetric(
                    label: 'WITH STRATEGY',
                    value: money.format(strategyPayment),
                    valueKey: Key('debt-${loan.id}-strategy'),
                    highlighted: strategyPayment > loan.monthlyPayment + 0.005,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtMetric extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;
  final bool highlighted;

  const _DebtMetric({
    required this.label,
    required this.value,
    required this.valueKey,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: highlighted ? kAccent : kInk,
          ),
        ),
      ],
    );
  }
}

class _DebtMetricDivider extends StatelessWidget {
  const _DebtMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: kHairline,
    );
  }
}
