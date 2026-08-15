import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/extra_payment.dart';
import '../services/amortization_engine.dart';
import '../services/app_state.dart';
import 'strategy_edit_screen.dart';

class StrategiesScreen extends StatelessWidget {
  const StrategiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mortgage = state.mortgage!;
    final comparison = state.comparison!;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Strategies',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w200,
                  color: kInk,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 22, color: kAccent),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StrategyEditScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
          child: Text(
            state.extras.isEmpty
                ? 'Add extra payments to pay off sooner.'
                : 'Saving ${money.format(comparison.interestSaved)} in interest · ${comparison.timeSavedLabel} sooner',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: state.extras.isEmpty ? kSubtle : kAccent,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: state.extras.isEmpty
              ? _emptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: state.extras.length,
                  separatorBuilder: (_, _) =>
                      const Divider(indent: 32, endIndent: 32),
                  itemBuilder: (context, i) {
                    final e = state.extras[i];
                    return _StrategyRow(
                      extra: e,
                      mortgage: mortgage,
                      allExtras: state.extras,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_down, size: 40, color: kHairline),
          const SizedBox(height: 16),
          const Text(
            'No strategies yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try monthly extras, annual bonuses,\nor a custom cadence like every 8 weeks.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StrategyEditScreen(),
                ),
              );
            },
            child: const Text('+ Add strategy'),
          ),
        ],
      ),
    );
  }
}

class _StrategyRow extends StatelessWidget {
  final ExtraPayment extra;
  final dynamic mortgage;
  final List<ExtraPayment> allExtras;

  const _StrategyRow({
    required this.extra,
    required this.mortgage,
    required this.allExtras,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // Marginal impact: interest saved by this strategy alone (on top of others)
    final withoutThis =
        allExtras.where((x) => x.id != extra.id && x.enabled).toList();
    final withThis = [...withoutThis, extra.copyWith(enabled: true)];
    final simWithout = AmortizationEngine.simulate(mortgage, withoutThis);
    final simWith = AmortizationEngine.simulate(mortgage, withThis);
    final marginalSaving = simWithout.totalInterest - simWith.totalInterest;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StrategyEditScreen(existing: extra),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    extra.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: extra.enabled ? kInk : kSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${extra.cadenceDescription()} · ${money.format(extra.amount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: kSubtle,
                    ),
                  ),
                  if (extra.enabled) ...[
                    const SizedBox(height: 4),
                    Text(
                      'saves ${money.format(marginalSaving)} interest',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: kAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: extra.enabled,
              onChanged: (v) =>
                  context.read<AppState>().toggleExtra(extra.id, v),
            ),
          ],
        ),
      ),
    );
  }
}
