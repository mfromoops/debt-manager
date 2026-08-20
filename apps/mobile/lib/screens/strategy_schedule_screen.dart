import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/strategy_schedule_override.dart';
import '../services/amortization_engine.dart';
import '../services/app_state.dart';

class StrategyScheduleScreen extends StatelessWidget {
  const StrategyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = [...state.strategySchedule]
      ..sort((a, b) => a.startMonth.compareTo(b.startMonth));

    return Scaffold(
      appBar: AppBar(title: const Text('Strategy schedule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(kPagePadding, 12, kPagePadding, 40),
        children: [
          const Text(
            'Plan time away from extra payments without changing your debt minimums. Your projections update as soon as a window is scheduled.',
            style: TextStyle(
              color: kSubtle,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            key: const Key('schedule-strategy-override'),
            onPressed: () => _showAddSheet(context),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: const Text('Schedule a change'),
          ),
          const SizedBox(height: 32),
          const Text(
            'SCHEDULED WINDOWS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: kHairline,
                    size: 38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No pauses or reductions scheduled',
                    style: TextStyle(
                      color: kSubtle,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _ScheduleCard(item: item)),
          const SizedBox(height: 24),
          const Text(
            'When windows overlap, the more conservative setting is used. Required minimum payments always continue.',
            style: TextStyle(
              color: kSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kSurface,
      builder: (_) => const _ScheduleOverrideSheet(),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.item});

  final StrategyScheduleOverride item;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = item.appliesTo(now);
    final month = DateFormat('MMM yyyy');
    final range = item.endMonth == null
        ? '${month.format(item.startMonth)} onward'
        : '${month.format(item.startMonth)} – ${month.format(item.endMonth!)}';
    final detail = item.mode == StrategyOverrideMode.paused
        ? 'Extra payments paused'
        : '${(item.factor * 100).round()}% of planned extras';

    return Container(
      key: Key('strategy-window-${item.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border.all(color: active ? kAccent : kHairline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            item.mode == StrategyOverrideMode.paused
                ? Icons.pause_circle_outline
                : Icons.trending_down,
            color: active ? kAccent : kSubtle,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: kAccent,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$detail · $range',
                  style: const TextStyle(
                    color: kSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final state = context.read<AppState>();
              if (value == 'resume') {
                await state.resumeStrategyScheduleOverride(item.id);
              } else if (value == 'remove') {
                await state.removeStrategyScheduleOverride(item.id);
              }
            },
            itemBuilder: (_) => [
              if (active && item.endMonth == null)
                const PopupMenuItem(value: 'resume', child: Text('Resume now')),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleOverrideSheet extends StatefulWidget {
  const _ScheduleOverrideSheet();

  @override
  State<_ScheduleOverrideSheet> createState() => _ScheduleOverrideSheetState();
}

class _ScheduleOverrideSheetState extends State<_ScheduleOverrideSheet> {
  late final TextEditingController _nameController;
  late DateTime _startMonth;
  late DateTime _endMonth;
  StrategyOverrideMode _mode = StrategyOverrideMode.paused;
  double _factor = 0.5;
  bool _openEnded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startMonth = DateTime(now.year, now.month);
    _endMonth = DateTime(now.year, now.month + 2);
    _nameController = TextEditingController(text: 'Planned break');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  StrategyScheduleOverride get _draft => StrategyScheduleOverride(
    id: 'schedule-${DateTime.now().microsecondsSinceEpoch}',
    name: _nameController.text.trim().isEmpty
        ? 'Planned break'
        : _nameController.text.trim(),
    startMonth: _startMonth,
    endMonth: _openEnded ? null : _endMonth,
    mode: _mode,
    factor: _mode == StrategyOverrideMode.paused ? 0 : _factor,
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final impact = _calculateImpact(state, _draft);
    final month = DateFormat('MMM yyyy');
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule a strategy change',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            SegmentedButton<StrategyOverrideMode>(
              segments: const [
                ButtonSegment(
                  value: StrategyOverrideMode.paused,
                  label: Text('Pause'),
                  icon: Icon(Icons.pause_outlined),
                ),
                ButtonSegment(
                  value: StrategyOverrideMode.reduced,
                  label: Text('Reduce'),
                  icon: Icon(Icons.trending_down),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            if (_mode == StrategyOverrideMode.reduced) ...[
              const SizedBox(height: 20),
              Text(
                'Pay ${(100 * _factor).round()}% of planned extras',
                style: const TextStyle(color: kInk, fontSize: 14),
              ),
              Slider(
                value: _factor,
                min: 0.1,
                max: 0.9,
                divisions: 8,
                label: '${(_factor * 100).round()}%',
                onChanged: (value) => setState(() => _factor = value),
              ),
            ],
            const SizedBox(height: 20),
            _MonthRow(
              label: 'Starts',
              value: month.format(_startMonth),
              onTap: () => _pickMonth(start: true),
            ),
            if (!_openEnded)
              _MonthRow(
                label: 'Ends',
                value: month.format(_endMonth),
                onTap: () => _pickMonth(start: false),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _openEnded,
              title: const Text(
                'Until I resume',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => setState(() => _openEnded = value ?? false),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF5F7F5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROJECTED IMPACT',
                    style: TextStyle(
                      color: kSubtle,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    impact.monthsDelayed == 0
                        ? 'No change to the projected debt-free month'
                        : '${_monthsLabel(impact.monthsDelayed)} later to become debt-free',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${money.format(impact.additionalInterest)} estimated additional interest',
                    style: const TextStyle(color: kSubtle, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('save-strategy-override'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Add to schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth({required bool start}) async {
    final current = start ? _startMonth : _endMonth;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      helpText: start ? 'Select starting month' : 'Select ending month',
    );
    if (picked == null) return;
    setState(() {
      final normalized = DateTime(picked.year, picked.month);
      if (start) {
        _startMonth = normalized;
        if (_endMonth.isBefore(_startMonth)) _endMonth = _startMonth;
      } else {
        _endMonth = normalized.isBefore(_startMonth) ? _startMonth : normalized;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().addStrategyScheduleOverride(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kSubtle)),
          Text(value, style: const TextStyle(color: kInk)),
        ],
      ),
    ),
  );
}

class _ScheduleImpact {
  const _ScheduleImpact(this.monthsDelayed, this.additionalInterest);
  final int monthsDelayed;
  final double additionalInterest;
}

_ScheduleImpact _calculateImpact(
  AppState state,
  StrategyScheduleOverride draft,
) {
  var currentInterest = 0.0;
  var proposedInterest = 0.0;
  var currentPayoffKey = 0;
  var proposedPayoffKey = 0;
  final proposedSchedule = [...state.strategySchedule, draft];

  for (final loan in state.loans) {
    final projected = state.projectedLoan(loan);
    final current = AmortizationEngine.simulate(
      projected,
      projected.extras,
      strategySchedule: state.strategySchedule,
    );
    final proposed = AmortizationEngine.simulate(
      projected,
      projected.extras,
      strategySchedule: proposedSchedule,
    );
    currentInterest += current.totalInterest;
    proposedInterest += proposed.totalInterest;
    currentPayoffKey = _max(currentPayoffKey, _monthKey(current.payoffDate));
    proposedPayoffKey = _max(proposedPayoffKey, _monthKey(proposed.payoffDate));
  }

  return _ScheduleImpact(
    (proposedPayoffKey - currentPayoffKey).clamp(0, 10000),
    (proposedInterest - currentInterest).clamp(0, double.infinity),
  );
}

int _monthKey(DateTime date) => date.year * 12 + date.month - 1;
int _max(int a, int b) => a > b ? a : b;

String _monthsLabel(int months) {
  final years = months ~/ 12;
  final remainder = months % 12;
  if (years == 0) return '$remainder month${remainder == 1 ? '' : 's'}';
  if (remainder == 0) return '$years year${years == 1 ? '' : 's'}';
  return '$years yr $remainder mo';
}
