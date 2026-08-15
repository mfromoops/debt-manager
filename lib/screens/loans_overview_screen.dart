import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../services/app_state.dart';
import 'loan_edit_screen.dart';
import 'loan_detail_shell.dart';

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
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

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
                          'Debts',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w200,
                            color: kInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.add, size: 22, color: kAccent),
                          onPressed: () => _addLoan(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      money.format(state.totalDebt),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w200,
                        color: kInk,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'total debt · ${money.format(state.totalMonthlyPayment)}/mo scheduled',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: kSubtle,
                      ),
                    ),
                    if (state.totalInterestSaved > 0.5) ...[
                      const SizedBox(height: 4),
                      Text(
                        'saving ${money.format(state.totalInterestSaved)} in interest with strategies',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: kAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    const Text(
                      'YOUR LOANS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                        color: kSubtle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...state.loans.expand((loan) sync* {
                      yield const Divider();
                      yield _LoanRow(
                        loan: loan,
                        icon: _iconFor(loan.type),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  void _addLoan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoanEditScreen()),
    );
  }

  Widget _emptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
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
    final pct = ((loan.principal - balance) / loan.principal * 100)
        .clamp(0, 100)
        .toDouble();
    final activeStrategies = loan.extras.where((e) => e.enabled).length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoanDetailShell(loanId: loan.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: kSubtle),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loan.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: kInk,
                        ),
                      ),
                      Text(
                        money.format(balance),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 2,
                      backgroundColor: kHairline,
                      valueColor: const AlwaysStoppedAnimation(kAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${loan.type.label} · ${loan.annualRate}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: kSubtle,
                        ),
                      ),
                      Text(
                        comparison.accelerated.neverPaysOff
                            ? 'never pays off'
                            : activeStrategies > 0
                                ? '${comparison.timeSavedLabel} sooner'
                                : 'payoff ${DateFormat('MMM yyyy').format(comparison.accelerated.payoffDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: comparison.accelerated.neverPaysOff
                              ? const Color(0xFFB3402E)
                              : activeStrategies > 0
                                  ? kAccent
                                  : kSubtle,
                        ),
                      ),
                    ],
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
