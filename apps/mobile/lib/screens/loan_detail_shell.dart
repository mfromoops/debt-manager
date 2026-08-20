import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'dashboard_screen.dart';
import 'strategies_screen.dart';
import 'schedule_screen.dart';

/// Per-loan detail with Overview / Strategies / Schedule tabs.
class LoanDetailShell extends StatefulWidget {
  final String loanId;
  const LoanDetailShell({super.key, required this.loanId});

  @override
  State<LoanDetailShell> createState() => _LoanDetailShellState();
}

class _LoanDetailShellState extends State<LoanDetailShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final loan = state.loanById(widget.loanId);

    // Loan was deleted while this screen was open.
    if (loan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final screens = [
      DashboardScreen(loan: loan),
      StrategiesScreen(loan: loan),
      ScheduleScreen(loan: loan),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kHairline)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _navItem(0, Icons.insights_outlined, Icons.insights,
                    'Overview'),
                _navItem(1, Icons.tune_outlined, Icons.tune, 'Strategies'),
                _navItem(2, Icons.calendar_view_month_outlined,
                    Icons.calendar_view_month, 'Schedule'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, IconData activeIcon, String label) {
    final selected = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? kAccent : kSubtle,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.4,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? kAccent : kSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
