import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../services/app_state.dart';
import '../widgets/payoff_chart.dart';
import 'loan_edit_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Loan loan;
  const DashboardScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final comparison = state.comparisonFor(loan);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final money2 = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final currentBalance = state.currentBalance(loan);
    final paidOffPct =
        ((loan.principal - currentBalance) / loan.principal * 100)
            .clamp(0, 100);

    final activeStrategies = loan.extras.where((e) => e.enabled).length;
    final neverPaysOff = comparison.accelerated.neverPaysOff;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, size: 20, color: kInk),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  loan.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w200,
                    color: kInk,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.edit_outlined, size: 18, color: kSubtle),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoanEditScreen(existing: loan),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${loan.type.label} · ${loan.annualRate}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            money.format(currentBalance),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w200,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'remaining of ${money.format(loan.principal)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: paidOffPct / 100,
              minHeight: 3,
              backgroundColor: kHairline,
              valueColor: const AlwaysStoppedAnimation(kAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${paidOffPct.toStringAsFixed(1)}% paid off',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          if (neverPaysOff) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE8C4BC)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Your payment doesn\'t reduce the balance — it never pays off at this rate. Increase the monthly payment or add strategies.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFB3402E),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          const Text(
            'PAYOFF PROJECTION',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 20),
          PayoffChart(comparison: comparison),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(kSubtle.withValues(alpha: 0.45)),
              const SizedBox(width: 6),
              const Text('Standard',
                  style: TextStyle(fontSize: 11, color: kSubtle)),
              const SizedBox(width: 20),
              _legendDot(kAccent),
              const SizedBox(width: 6),
              const Text('With strategies',
                  style: TextStyle(fontSize: 11, color: kSubtle)),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(),
          _statRow(
            loan.paymentMode == PaymentMode.fixedPayment
                ? 'Monthly payment (set)'
                : 'Monthly payment',
            money2.format(loan.monthlyPayment),
          ),
          const Divider(),
          _statRow(
            'Interest saved',
            money.format(comparison.interestSaved),
            valueColor: kAccent,
          ),
          const Divider(),
          _statRow(
            'Time saved',
            comparison.timeSavedLabel,
            valueColor: kAccent,
          ),
          const Divider(),
          _statRow(
            'Payoff date',
            neverPaysOff
                ? '—'
                : DateFormat('MMM yyyy')
                    .format(comparison.accelerated.payoffDate),
          ),
          const Divider(),
          _statRow(
            'Total interest',
            money.format(comparison.accelerated.totalInterest),
          ),
          const Divider(),
          _statRow('Active strategies', '$activeStrategies'),
          const Divider(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _statRow(String label, String value, {Color valueColor = kInk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
