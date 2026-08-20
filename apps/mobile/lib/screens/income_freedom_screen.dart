import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/app_state.dart';
import 'profile_screen.dart';

enum _IncomeTimelineMode { minimum, strategy, comparison }

class IncomeFreedomScreen extends StatefulWidget {
  const IncomeFreedomScreen({super.key});

  @override
  State<IncomeFreedomScreen> createState() => _IncomeFreedomScreenState();
}

class _IncomeFreedomScreenState extends State<IncomeFreedomScreen> {
  _IncomeTimelineMode _mode = _IncomeTimelineMode.minimum;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final income = state.monthlyIncome;
    final releases = state.minimumPaymentReleases();
    final strategyReleases = state.strategyPaymentReleases();
    final strategyComparisons = state.strategyIncomeReleases();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Income freedom')),
      body: income == null || income <= 0
          ? const _MissingIncome()
          : _Timeline(
              income: income,
              minimumDue: state.minimumDue,
              releases: releases,
              strategyReleases: strategyReleases,
              strategyComparisons: strategyComparisons,
              hasStrategies: state.hasEnabledStrategies,
              mode: _mode,
              onModeChanged: (value) {
                setState(() => _mode = value);
              },
              money: money,
            ),
    );
  }
}

class _MissingIncome extends StatelessWidget {
  const _MissingIncome();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(kPagePadding, 16, kPagePadding, 40),
    children: [
      const Icon(Icons.trending_up, size: 42, color: kAccent),
      const SizedBox(height: 18),
      const Text(
        'See when your income opens up',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: kInk,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Add your salary to calculate the income remaining after minimum payments at every payoff milestone.',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: kSubtle,
        ),
      ),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: const Text('Add salary'),
      ),
    ],
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.income,
    required this.minimumDue,
    required this.releases,
    required this.strategyReleases,
    required this.strategyComparisons,
    required this.hasStrategies,
    required this.mode,
    required this.onModeChanged,
    required this.money,
  });

  final double income;
  final double minimumDue;
  final List<IncomeRelease> releases;
  final List<IncomeRelease> strategyReleases;
  final List<StrategyIncomeRelease> strategyComparisons;
  final bool hasStrategies;
  final _IncomeTimelineMode mode;
  final ValueChanged<_IncomeTimelineMode> onModeChanged;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final timelineReleases = mode == _IncomeTimelineMode.strategy
        ? strategyReleases
        : releases;
    final availableNow = income - minimumDue;
    final totalFreed = timelineReleases.fold<double>(
      0,
      (sum, release) => sum + release.amount,
    );
    final projectedAvailable = availableNow + totalFreed;

    return ListView(
      key: const Key('income-freedom-timeline'),
      padding: const EdgeInsets.fromLTRB(kPagePadding, 12, kPagePadding, 40),
      children: [
        Text(
          switch (mode) {
            _IncomeTimelineMode.minimum => 'Your minimum-only timeline',
            _IncomeTimelineMode.strategy => 'Your strategy timeline',
            _IncomeTimelineMode.comparison => 'Compare release timelines',
          },
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          switch (mode) {
            _IncomeTimelineMode.minimum =>
              'Extra-payment strategies are excluded, so every step below comes only from a required payment ending.',
            _IncomeTimelineMode.strategy =>
              'Active strategies move required-payment release dates earlier. Freed amounts count minimum payments only.',
            _IncomeTimelineMode.comparison =>
              'See each minimum-only payoff date beside its strategy-adjusted date and the time gained.',
          },
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 20),
        _TimelineModeToggle(
          mode: mode,
          hasStrategies: hasStrategies,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MONTHLY INCOME AVAILABLE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      label: 'NOW',
                      value: money.format(availableNow),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 17, color: kSubtle),
                  Expanded(
                    child: _SummaryValue(
                      label: 'AFTER PAYOFFS',
                      value: money.format(projectedAvailable),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${money.format(totalFreed)}/month returns to your budget across ${timelineReleases.length} milestone${timelineReleases.length == 1 ? '' : 's'}.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: kAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          mode == _IncomeTimelineMode.comparison
              ? 'STRATEGY COMPARISON'
              : 'FULL TIMELINE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w500,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 8),
        if (mode == _IncomeTimelineMode.comparison)
          _StrategyComparison(comparisons: strategyComparisons, money: money)
        else if (timelineReleases.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'No payoff releases can be projected. Check whether each minimum payment covers its monthly interest.',
              style: TextStyle(fontSize: 13, height: 1.5, color: kSubtle),
            ),
          )
        else
          ..._milestones(
            availableNow,
            timelineReleases,
            strategy: mode == _IncomeTimelineMode.strategy,
          ),
      ],
    );
  }

  List<Widget> _milestones(
    double availableNow,
    List<IncomeRelease> timelineReleases, {
    required bool strategy,
  }) {
    var available = availableNow;
    return [
      _TimelineRow(
        key: const Key('income-timeline-now'),
        date: 'Today',
        title: strategy
            ? 'Current strategy timeline'
            : 'Current minimum payments',
        detail: '${money.format(minimumDue)}/month committed to debt',
        available: money.format(available),
        first: true,
      ),
      for (var index = 0; index < timelineReleases.length; index++)
        _releaseRow(
          index,
          available += timelineReleases[index].amount,
          timelineReleases,
          strategy: strategy,
        ),
    ];
  }

  Widget _releaseRow(
    int index,
    double available,
    List<IncomeRelease> timelineReleases, {
    required bool strategy,
  }) {
    final release = timelineReleases[index];
    return _TimelineRow(
      key: Key(
        strategy
            ? 'income-strategy-timeline-release-$index'
            : 'income-timeline-release-$index',
      ),
      date: DateFormat('MMMM yyyy').format(release.date),
      title: release.loanNames.join(', '),
      detail: '+${money.format(release.amount)}/month freed',
      available: money.format(available),
      last: index == timelineReleases.length - 1,
    );
  }
}

class _TimelineModeToggle extends StatelessWidget {
  const _TimelineModeToggle({
    required this.mode,
    required this.hasStrategies,
    required this.onChanged,
  });

  final _IncomeTimelineMode mode;
  final bool hasStrategies;
  final ValueChanged<_IncomeTimelineMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F5F3),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeButton(
            key: const Key('income-mode-minimum'),
            label: 'Minimum',
            selected: mode == _IncomeTimelineMode.minimum,
            onTap: () => onChanged(_IncomeTimelineMode.minimum),
          ),
        ),
        Expanded(
          child: _ModeButton(
            key: const Key('income-mode-strategy-only'),
            label: 'Strategy',
            selected: mode == _IncomeTimelineMode.strategy,
            onTap: hasStrategies
                ? () => onChanged(_IncomeTimelineMode.strategy)
                : null,
          ),
        ),
        Expanded(
          child: _ModeButton(
            key: const Key('income-mode-strategies'),
            label: 'Compare',
            selected: mode == _IncomeTimelineMode.comparison,
            onTap: hasStrategies
                ? () => onChanged(_IncomeTimelineMode.comparison)
                : null,
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: onTap == null
              ? kSubtle.withValues(alpha: 0.65)
              : selected
              ? kAccent
              : kSubtle,
        ),
      ),
    ),
  );
}

class _StrategyComparison extends StatelessWidget {
  const _StrategyComparison({required this.comparisons, required this.money});

  final List<StrategyIncomeRelease> comparisons;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (comparisons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'There are no active debts to compare.',
          style: TextStyle(fontSize: 13, color: kSubtle),
        ),
      );
    }

    return Column(
      key: const Key('income-strategy-comparison'),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 4),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('DEBT', style: _comparisonHeaderStyle),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'MINIMUM',
                  textAlign: TextAlign.right,
                  style: _comparisonHeaderStyle,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'STRATEGY',
                  textAlign: TextAlign.right,
                  style: _comparisonHeaderStyle,
                ),
              ),
            ],
          ),
        ),
        for (var index = 0; index < comparisons.length; index++) ...[
          if (index > 0) const Divider(),
          _StrategyComparisonRow(
            key: Key('income-strategy-row-$index'),
            comparison: comparisons[index],
            money: money,
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'The amount freed is always the required minimum. Strategies change when that income returns, not how much permanent income is counted.',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: kSubtle,
          ),
        ),
      ],
    );
  }
}

const _comparisonHeaderStyle = TextStyle(
  fontSize: 9,
  letterSpacing: 1,
  fontWeight: FontWeight.w500,
  color: kSubtle,
);

class _StrategyComparisonRow extends StatelessWidget {
  const _StrategyComparisonRow({
    super.key,
    required this.comparison,
    required this.money,
  });

  final StrategyIncomeRelease comparison;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final monthsSooner = _monthsSooner(
      comparison.minimumOnlyDate,
      comparison.strategyDate,
    );
    final impact = monthsSooner == null
        ? comparison.minimumOnlyDate == null && comparison.strategyDate != null
              ? 'Now reaches payoff'
              : 'No projected payoff'
        : monthsSooner > 0
        ? '${_monthsLabel(monthsSooner)} sooner'
        : 'Same payoff month';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comparison.loanName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: kInk),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${money.format(comparison.minimumPayment)}/mo freed',
                      style: const TextStyle(fontSize: 10, color: kSubtle),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _dateLabel(comparison.minimumOnlyDate),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: kSubtle),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _dateLabel(comparison.strategyDate),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              impact,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: monthsSooner != null && monthsSooner > 0
                    ? kAccent
                    : kSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime? date) =>
      date == null ? 'Not projected' : DateFormat('MMM yyyy').format(date);

  static int? _monthsSooner(DateTime? baseline, DateTime? strategy) {
    if (baseline == null || strategy == null) return null;
    final baselineKey = baseline.year * 12 + baseline.month;
    final strategyKey = strategy.year * 12 + strategy.month;
    return (baselineKey - strategyKey).clamp(0, 1000000);
  }

  static String _monthsLabel(int months) {
    if (months < 12) return '$months mo';
    final years = months ~/ 12;
    final remainder = months % 12;
    if (remainder == 0) return '$years yr';
    return '$years yr $remainder mo';
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 9, letterSpacing: 1, color: kSubtle),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w400,
          color: kInk,
          letterSpacing: -0.3,
        ),
      ),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.date,
    required this.title,
    required this.detail,
    required this.available,
    this.first = false,
    this.last = false,
  });

  final String date;
  final String title;
  final String detail;
  final String available;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 22,
          child: Column(
            children: [
              if (!first)
                Expanded(child: Container(width: 1, color: kHairline)),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: first ? Colors.white : kAccent,
                  border: Border.all(color: kAccent, width: 1.5),
                ),
              ),
              if (!last) Expanded(child: Container(width: 1, color: kHairline)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w500,
                    color: kSubtle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: kAccent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                available,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'available / mo',
                style: TextStyle(fontSize: 9, color: kSubtle),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
