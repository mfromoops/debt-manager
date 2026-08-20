import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../models/extra_payment.dart';
import '../services/amortization_engine.dart';
import '../services/app_state.dart';
import 'strategy_edit_screen.dart';

class StrategiesScreen extends StatelessWidget {
  final Loan loan;
  const StrategiesScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final comparison = state.comparisonFor(loan);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 16, 0),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, size: 20, color: kInk),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Strategies',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w200,
                    color: kInk,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 22, color: kAccent),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StrategyEditScreen(loanId: loan.id),
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
            loan.extras.isEmpty
                ? '${loan.name} · add extra payments to pay off sooner.'
                : '${loan.name} · saving ${money.format(comparison.interestSaved)} · ${comparison.timeSavedLabel} sooner',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: loan.extras.isEmpty ? kSubtle : kAccent,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: loan.extras.isEmpty
              ? _emptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: loan.extras.length,
                  separatorBuilder: (_, _) =>
                      const Divider(indent: 32, endIndent: 32),
                  itemBuilder: (context, i) {
                    final e = loan.extras[i];
                    return _StrategyRow(extra: e, loan: loan);
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
                  builder: (_) => StrategyEditScreen(loanId: loan.id),
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
  final Loan loan;

  const _StrategyRow({required this.extra, required this.loan});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // Marginal impact: interest saved by this strategy alone (on top of others)
    final withoutThis =
        loan.extras.where((x) => x.id != extra.id && x.enabled).toList();
    final withThis = [...withoutThis, extra.copyWith(enabled: true)];
    final simWithout = AmortizationEngine.simulate(loan, withoutThis);
    final simWith = AmortizationEngine.simulate(loan, withThis);
    final marginalSaving = simWithout.totalInterest - simWith.totalInterest;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                StrategyEditScreen(loanId: loan.id, existing: extra),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: extra.enabled,
                  onChanged: (v) => context
                      .read<AppState>()
                      .toggleExtra(loan.id, extra.id, v),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: kSubtle),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StrategyEditScreen(
                            loanId: loan.id,
                            existing: extra,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete strategy?'),
        content: Text('Remove ${extra.name} from ${loan.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AppState>().removeExtra(loan.id, extra.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Strategy deleted.')),
    );
  }
}
