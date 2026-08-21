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
import 'income_freedom_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';
import 'strategy_schedule_screen.dart';

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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final useWideOverview = viewportWidth >= 1000;
    final useWideActions = viewportWidth >= 720;
    final pagePadding = viewportWidth >= 1100
        ? 32.0
        : viewportWidth >= 600
            ? 24.0
            : 16.0;

    return Scaffold(
      body: SafeArea(
        child: state.loans.isEmpty
            ? _emptyState(context)
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    key: const Key('overview-content'),
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: viewportWidth >= 600 ? 24 : 16),
                          Container(
                      key: const Key('payoff-forecast-panel'),
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        useWideOverview ? 24 : 20,
                        18,
                        useWideOverview ? 24 : 20,
                        useWideOverview ? 24 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: kInk,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x241D2521),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/icon/app_icon.png',
                                    width: 28,
                                    height: 28,
                                    semanticLabel: 'DebtFold logo',
                                  ),
                                  const SizedBox(width: 9),
                                  const Text(
                                    'DebtFold',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
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
                                        color: kAccentPale,
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
                                        color: Color(0xFFB4C0B9),
                                      ),
                                    )
                                  else
                                    const Tooltip(
                                      message: 'Stored on this device',
                                      child: Icon(
                                        Icons.phone_android_outlined,
                                        size: 20,
                                        color: Color(0xFFB4C0B9),
                                      ),
                                    ),
                                  _accountMenu(
                                    context,
                                    auth,
                                    state,
                                    inverse: true,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      size: 22,
                                      color: kAccentPale,
                                    ),
                                    onPressed: () => _addLoan(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'YOUR PAYOFF FORECAST',
                            style: TextStyle(
                              color: kAccentPale,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 22),
                          if (useWideOverview)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 360,
                                    child: _PaymentOverview(
                                      minimumDue: state.minimumDue,
                                      strategyPayment:
                                          state.paymentWithStrategies,
                                      strategyExtra: state.strategyExtra,
                                      upcomingLoan: upcomingLoan,
                                      upcomingDate: upcomingDate,
                                      monthlyIncome: state.monthlyIncome,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _DebtProgressCard(
                                    balance: state.totalDebt,
                                    interestSaved: state.totalInterestSaved,
                                    projectedBalances:
                                        state.projectedDebtBalances(),
                                    height: 360,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: SizedBox(
                                    height: 360,
                                    child: _IncomeFreedomCard(
                                      monthlyIncome: state.monthlyIncome,
                                      minimumDue: state.minimumDue,
                                      releases:
                                          state.strategyPaymentReleases(),
                                      compact: true,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _PaymentOverview(
                              minimumDue: state.minimumDue,
                              strategyPayment: state.paymentWithStrategies,
                              strategyExtra: state.strategyExtra,
                              upcomingLoan: upcomingLoan,
                              upcomingDate: upcomingDate,
                              monthlyIncome: state.monthlyIncome,
                            ),
                            const SizedBox(height: 14),
                            _DebtProgressCard(
                              balance: state.totalDebt,
                              interestSaved: state.totalInterestSaved,
                              projectedBalances: state.projectedDebtBalances(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!useWideOverview) ...[
                      const SizedBox(height: 20),
                      _IncomeFreedomCard(
                        monthlyIncome: state.monthlyIncome,
                        minimumDue: state.minimumDue,
                        releases: state.strategyPaymentReleases(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (useWideActions)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _strategyScheduleEntry(context, state),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _plannerEntry(context)),
                        ],
                      )
                    else ...[
                      _strategyScheduleEntry(context, state),
                      const SizedBox(height: 12),
                      _plannerEntry(context),
                    ],
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Loans',
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

  Widget _strategyScheduleEntry(BuildContext context, AppState state) {
    return _OverviewEntry(
      entryKey: const Key('strategy-schedule-entry'),
      icon: Icons.calendar_month_outlined,
      title: 'Strategy schedule',
      subtitle: state.strategySchedule.isEmpty
          ? 'Plan a pause or temporary reduction'
          : '${state.strategySchedule.length} scheduled window${state.strategySchedule.length == 1 ? '' : 's'}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StrategyScheduleScreen()),
      ),
    );
  }

  Widget _plannerEntry(BuildContext context) {
    return _OverviewEntry(
      entryKey: const Key('payoff-planner-entry'),
      icon: Icons.route_outlined,
      title: 'Payoff Planner',
      subtitle: 'Avalanche vs snowball — where should extra money go?',
      emphasized: true,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PlannerScreen())),
    );
  }

  Widget _emptyState(BuildContext context) {
    final auth = context.watch<AuthService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kPagePadding, vertical: 24),
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
              fontWeight: FontWeight.w500,
              color: kInk,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track mortgages, credit cards and loans.\nSimulate strategies to pay them off sooner.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
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

  Widget _accountMenu(
    BuildContext context,
    AuthService auth,
    AppState state, {
    bool inverse = false,
  }) {
    final hasStrategies =
        state.loans.any((loan) => loan.extras.isNotEmpty) ||
        state.strategySchedule.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: auth.user?.displayName ?? 'Account',
      icon: Icon(
        Icons.account_circle_outlined,
        size: 22,
        color: inverse ? const Color(0xFFB4C0B9) : kSubtle,
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        } else if (value == 'clear-strategies') {
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
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline, size: 19),
            title: Text('Profile'),
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
          'This removes every extra payment strategy and all scheduled pause or reduction windows.',
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

class _OverviewEntry extends StatelessWidget {
  final Key? entryKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  const _OverviewEntry({
    this.entryKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: entryKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: emphasized ? kSoft : kSurface,
            border: Border.all(color: emphasized ? kAccent : kBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: emphasized ? kAccent : kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: kSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: kSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomeFreedomCard extends StatelessWidget {
  final double? monthlyIncome;
  final double minimumDue;
  final List<IncomeRelease> releases;
  final bool compact;

  const _IncomeFreedomCard({
    required this.monthlyIncome,
    required this.minimumDue,
    required this.releases,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final income = monthlyIncome;
    final projectedAvailable = income == null
        ? null
        : income -
              minimumDue +
              releases.fold<double>(0, (sum, release) => sum + release.amount);
    final inverse = compact;
    final primaryText = inverse ? Colors.white : kInk;
    final mutedText = inverse ? const Color(0xFFB4C0B9) : kSubtle;
    final accentText = inverse ? kAccentPale : kAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('income-freedom-open'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => income == null || income <= 0
                ? const ProfileScreen()
                : const IncomeFreedomScreen(),
          ),
        ),
        child: Container(
          key: const Key('income-freedom-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: inverse ? const Color(0xFF15201B) : kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inverse
                  ? Colors.white.withValues(alpha: 0.12)
                  : kBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: accentText),
                  SizedBox(width: 8),
                  Text(
                    'INCOME FREEDOM',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w500,
                      color: accentText,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: mutedText),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'How your monthly income opens up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Strategy-adjusted release timeline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 18),
              if (income == null || income <= 0)
                Row(
                  key: Key('income-freedom-add-salary'),
                  children: [
                    Expanded(
                      child: Text(
                        'Add your salary to see your available income rise as each minimum payment ends.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: accentText,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward, size: 17, color: accentText),
                  ],
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _IncomeFreedomValue(
                        label: 'AVAILABLE NOW',
                        value: money.format(income - minimumDue),
                        valueKey: const Key('income-freedom-now'),
                        inverse: inverse,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: mutedText,
                      ),
                    ),
                    Expanded(
                      child: _IncomeFreedomValue(
                        label: 'AFTER PAYOFFS',
                        value: money.format(projectedAvailable),
                        alignEnd: true,
                        valueKey: const Key('income-freedom-final'),
                        inverse: inverse,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                if (releases.isEmpty)
                  Text(
                    'No minimum-payment release can be projected yet. Check any payment that does not cover its monthly interest.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedText,
                    ),
                  )
                else ...[
                  Semantics(
                    label:
                        '${releases.length} strategy-adjusted payment release dates',
                    child: SizedBox(
                      key: const Key('income-freedom-chart'),
                      height: compact ? 76 : 96,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _IncomeFreedomPainter(
                          initialAvailable: income - minimumDue,
                          releases: releases,
                          inverse: inverse,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  ...releases
                      .take(compact ? 1 : 2)
                      .map(
                        (release) => Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Row(
                            key: Key(
                              'income-release-${release.date.year}-${release.date.month}',
                            ),
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: accentText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM yyyy').format(release.date)} · ${release.loanNames.join(', ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: mutedText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${money.format(release.amount)}/mo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: accentText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (releases.length > (compact ? 1 : 2))
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        '+ ${releases.length - (compact ? 1 : 2)} more milestone${releases.length - (compact ? 1 : 2) == 1 ? '' : 's'} shown in the timeline',
                        style: TextStyle(fontSize: 10, color: mutedText),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomeFreedomValue extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final Key? valueKey;
  final bool inverse;

  const _IncomeFreedomValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueKey,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1,
          fontWeight: FontWeight.w500,
          color: inverse ? const Color(0xFFB4C0B9) : kSubtle,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        key: valueKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: inverse ? Colors.white : kInk,
          letterSpacing: -0.3,
        ),
      ),
    ],
  );
}

class _IncomeFreedomPainter extends CustomPainter {
  final double initialAvailable;
  final List<IncomeRelease> releases;
  final bool inverse;

  _IncomeFreedomPainter({
    required this.initialAvailable,
    required this.releases,
    this.inverse = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (releases.isEmpty) return;
    final plot = Rect.fromLTRB(3, 4, size.width - 3, size.height - 22);
    final totalFreed = releases.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final low = initialAvailable < 0 ? initialAvailable : 0.0;
    final high = initialAvailable + totalFreed;
    final range = (high - low).abs() < 0.01 ? 1.0 : high - low;
    final startKey = DateTime.now().year * 12 + DateTime.now().month;
    final end = releases.last.date;
    final endKey = end.year * 12 + end.month;
    final monthRange = (endKey - startKey).clamp(1, 1000000);
    double yFor(double value) =>
        plot.bottom - ((value - low) / range).clamp(0.0, 1.0) * plot.height;
    double xFor(DateTime date) {
      final key = date.year * 12 + date.month;
      return plot.left +
          ((key - startKey) / monthRange).clamp(0.0, 1.0) * plot.width;
    }

    final gridPaint = Paint()
      ..color = (inverse ? const Color(0xFFB4C0B9) : kSubtle).withValues(
        alpha: 0.14,
      )
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, gridPaint);
    canvas.drawLine(plot.topLeft, plot.topRight, gridPaint);

    var available = initialAvailable;
    final path = Path()..moveTo(plot.left, yFor(available));
    for (final release in releases) {
      final x = xFor(release.date);
      path.lineTo(x, yFor(available));
      available += release.amount;
      path.lineTo(x, yFor(available));
    }
    path.lineTo(plot.right, yFor(available));
    final area = Path.from(path)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4D91C2A8), Color(0x0091C2A8)],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = inverse ? kAccentPale : kAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _label(canvas, 'NOW', Offset(plot.left, plot.bottom + 7));
    _label(
      canvas,
      DateFormat('MMM yy').format(end).toUpperCase(),
      Offset(plot.right, plot.bottom + 7),
      alignRight: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 8,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w500,
          color: inverse ? const Color(0xFFB4C0B9) : kSubtle,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _IncomeFreedomPainter oldDelegate) =>
      oldDelegate.initialAvailable != initialAvailable ||
      oldDelegate.releases != releases;
}

class _DebtProgressCard extends StatelessWidget {
  final double balance;
  final double interestSaved;
  final List<double> projectedBalances;
  final double height;

  const _DebtProgressCard({
    required this.balance,
    required this.interestSaved,
    required this.projectedBalances,
    this.height = 252,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: const Key('debt-progress-card'),
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF15201B),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
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
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: kAccentFocus,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BALANCE REMAINING',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB4C0B9),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'YOUR PLAN',
                          style: TextStyle(
                            color: Color(0xFFB4C0B9),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
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
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFB4C0B9),
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
                      color: interestSaved > 0.5
                          ? kAccentPale
                          : const Color(0xFFB4C0B9),
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
    // Keep the chart below the summary copy. Previously the plot began at 136,
    // which put its BALANCE label on top of the interest-saved line.
    final plot = Rect.fromLTRB(48, 148, size.width - 12, size.height - 28);
    final maxBalance = balances.isEmpty
        ? 0.0
        : balances.reduce((a, b) => a > b ? a : b);
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
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
      color: Color(0xFF78877F),
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
          colors: [Color(0x4D91C2A8), Color(0x0091C2A8)],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = kAccentPale
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
    TextStyle style = const TextStyle(
      fontSize: 8,
      color: Color(0xFF78877F),
    ),
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
  final double? monthlyIncome;

  const _PaymentOverview({
    required this.minimumDue,
    required this.strategyPayment,
    required this.strategyExtra,
    required this.upcomingLoan,
    required this.upcomingDate,
    required this.monthlyIncome,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final hasStrategy = strategyExtra > 0.005;
    final income = monthlyIncome;
    final debtRatio = income == null || income <= 0
        ? null
        : strategyPayment / income;
    final remainingIncome = income == null ? null : income - strategyPayment;

    return Container(
      key: const Key('payment-overview-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'THIS PAYMENT CYCLE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w500,
                  color: kAccentPale,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentFocus.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SELECTED PLAN',
                  style: TextStyle(
                    color: kAccentPale,
                    fontSize: 8,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Plan to pay',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFFB4C0B9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            money.format(strategyPayment),
            key: const Key('strategy-payment-total'),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
              fontWeight: FontWeight.w400,
              color: Color(0xFFB4C0B9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (debtRatio != null)
            Row(
              key: const Key('payment-income-ratio'),
              children: [
                const Icon(
                  Icons.pie_chart_outline,
                  size: 16,
                  color: kAccentPale,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(debtRatio * 100).toStringAsFixed(1)}% of monthly income · ${money.format(remainingIncome)} remaining',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: kAccentPale,
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              key: const Key('add-salary-prompt'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: const Text(
                'Add your salary in Profile to see the share of income going to debt.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: kAccentPale,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PaymentFact(
                  label: 'MINIMUM DUE',
                  value: money.format(minimumDue),
                  valueKey: const Key('minimum-due'),
                  inverse: true,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _PaymentFact(
                  label: 'NEXT PAYMENT',
                  value: upcomingDate == null
                      ? 'All paid'
                      : DateFormat('MMM d').format(upcomingDate!),
                  detail: upcomingLoan?.name,
                  valueKey: const Key('next-payment-date'),
                  inverse: true,
                ),
              ),
            ],
          ),
          if (hasStrategy) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kAccentDark,
                  border: Border.all(
                    color: kAccentFocus.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_outward,
                      size: 16,
                      color: kAccentPale,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${money.format(strategyExtra)} extra applied',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  final bool inverse;

  const _PaymentFact({
    required this.label,
    required this.value,
    this.detail,
    this.valueKey,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
            color: inverse ? const Color(0xFFB4C0B9) : kSubtle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: inverse ? Colors.white : kInk,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: inverse ? const Color(0xFFB4C0B9) : kSubtle,
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
          color: kSurface,
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
                    color: kSoft,
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
                          fontWeight: FontWeight.w400,
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
                        fontWeight: FontWeight.w400,
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
                    fontWeight: FontWeight.w400,
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
