import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../services/app_state.dart';

class ScheduleScreen extends StatefulWidget {
  final Loan loan;
  const ScheduleScreen({super.key, required this.loan});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _yearly = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final comparison = state.comparisonFor(widget.loan);
    final schedule = comparison.accelerated.schedule;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back,
                        size: 20, color: kInk),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Schedule',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w200,
                      color: kInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _toggle('Yearly', _yearly, () {
                    setState(() => _yearly = true);
                  }),
                  const SizedBox(width: 16),
                  _toggle('Monthly', !_yearly, () {
                    setState(() => _yearly = false);
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            comparison.accelerated.neverPaysOff
                ? '${widget.loan.name} · balance not decreasing'
                : '${widget.loan.name} · payoff ${DateFormat('MMMM yyyy').format(comparison.accelerated.payoffDate)} · ${schedule.length} payments',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Header row
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('PERIOD', style: _headerStyle),
              ),
              Expanded(
                flex: 3,
                child:
                    Text('INTEREST', style: _headerStyle, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 3,
                child:
                    Text('EXTRA', style: _headerStyle, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 4,
                child:
                    Text('BALANCE', style: _headerStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        const Divider(indent: 32, endIndent: 32),
        Expanded(
          child: _yearly
              ? _yearlyList(schedule, money)
              : _monthlyList(schedule, money),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 10,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w400,
    color: kSubtle,
  );

  Widget _toggle(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
              color: selected ? kAccent : kSubtle,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 24,
            height: 2,
            color: selected ? kAccent : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _yearlyList(List schedule, NumberFormat money) {
    // Group by calendar year
    final years = <int, List<dynamic>>{};
    for (final row in schedule) {
      years.putIfAbsent(row.date.year as int, () => []).add(row);
    }
    final yearKeys = years.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: yearKeys.length,
      separatorBuilder: (_, _) => const Divider(indent: 32, endIndent: 32),
      itemBuilder: (context, i) {
        final year = yearKeys[i];
        final rows = years[year]!;
        final interest =
            rows.fold<double>(0, (s, r) => s + (r.interest as double));
        final extra = rows.fold<double>(0, (s, r) => s + (r.extra as double));
        final endBalance = rows.last.balance as double;
        return _scheduleRow(
          '$year',
          money.format(interest),
          extra > 0 ? money.format(extra) : '—',
          money.format(endBalance),
          extraHighlight: extra > 0,
        );
      },
    );
  }

  Widget _monthlyList(List schedule, NumberFormat money) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: schedule.length,
      separatorBuilder: (_, _) => const Divider(indent: 32, endIndent: 32),
      itemBuilder: (context, i) {
        final row = schedule[i];
        final extra = row.extra as double;
        return _scheduleRow(
          DateFormat('MMM yyyy').format(row.date),
          money.format(row.interest),
          extra > 0 ? money.format(extra) : '—',
          money.format(row.balance),
          extraHighlight: extra > 0,
        );
      },
    );
  }

  Widget _scheduleRow(
    String period,
    String interest,
    String extra,
    String balance, {
    bool extraHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              period,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: kInk,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              interest,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: kSubtle,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              extra,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    extraHighlight ? FontWeight.w400 : FontWeight.w300,
                color: extraHighlight ? kAccent : kSubtle,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              balance,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
