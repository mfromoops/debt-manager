import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/app_state.dart';
import '../widgets/payoff_chart.dart';
import 'setup_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mortgage = state.mortgage!;
    final comparison = state.comparison!;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final money2 = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    // Current position: months elapsed since start
    final now = DateTime.now();
    final elapsed = (now.year - mortgage.startDate.year) * 12 +
        (now.month - mortgage.startDate.month) +
        1;
    final schedule = comparison.accelerated.schedule;
    final clampedElapsed = elapsed.clamp(0, schedule.length);
    final currentBalance = clampedElapsed <= 0
        ? mortgage.principal
        : schedule[clampedElapsed - 1].balance;
    final paidOffPct =
        ((mortgage.principal - currentBalance) / mortgage.principal * 100)
            .clamp(0, 100);

    final activeStrategies = state.extras.where((e) => e.enabled).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Mortgage',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w200,
                  color: kInk,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: kSubtle),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetupScreen(existing: mortgage),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Big balance
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
            'remaining of ${money.format(mortgage.principal)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 20),
          // Thin progress line
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
          const SizedBox(height: 40),
          // Chart section
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
          _statRow('Monthly payment', money2.format(mortgage.monthlyPayment)),
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
            DateFormat('MMM yyyy')
                .format(comparison.accelerated.payoffDate),
          ),
          const Divider(),
          _statRow(
            'Total interest',
            money.format(comparison.accelerated.totalInterest),
          ),
          const Divider(),
          _statRow(
            'Active strategies',
            '$activeStrategies',
          ),
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
