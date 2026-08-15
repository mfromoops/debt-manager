import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'setup_screen.dart';
import 'dashboard_screen.dart';
import 'strategies_screen.dart';
import 'schedule_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.loaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
      );
    }

    if (!state.hasMortgage) {
      return const SetupScreen();
    }

    final screens = const [
      DashboardScreen(),
      StrategiesScreen(),
      ScheduleScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kHairline)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
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
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                color: selected ? kAccent : kSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
