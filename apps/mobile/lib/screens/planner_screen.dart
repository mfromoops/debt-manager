import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/app_state.dart';
import '../services/payoff_planner.dart';
import '../widgets/debt_curve_chart.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  PlanMethod _method = PlanMethod.avalanche;
  double _budget = 200;
  DateTime _strategyStartDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late final TextEditingController _budgetCtrl;

  @override
  void initState() {
    super.initState();
    _budgetCtrl = TextEditingController(text: _budget.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _onBudgetChanged(String v) {
    final n = double.tryParse(v.replaceAll(',', ''));
    if (n != null && n >= 0) {
      setState(() => _budget = n);
    }
  }

  Future<void> _applyPlan(PlanResult planned) async {
    if (planned.neverPaysOff || planned.loanResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This plan needs a full payoff before it can be applied.',
          ),
        ),
      );
      return;
    }

    final addedCount = await context.read<AppState>().applyPayoffPlan(
          planned,
          startDate: _strategyStartDate,
        );
    if (!mounted) return;
    final message = addedCount == 0
        ? 'No strategies needed to be added.'
        : addedCount == 1
            ? 'Added 1 ${planned.method.label.toLowerCase()} strategy.'
            : 'Added $addedCount '
                '${planned.method.label.toLowerCase()} strategies.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _pickStrategyStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _strategyStartDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2070),
    );
    if (picked == null) return;
    setState(() {
      _strategyStartDate = DateTime(picked.year, picked.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final balances = {
      for (final l in state.loans) l.id: state.currentBalance(l)
    };

    final baseline = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: _method,
      monthlyBudget: 0,
    );
    final planned = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: _method,
      monthlyBudget: _budget,
    );
    final altMethod = _method == PlanMethod.avalanche
        ? PlanMethod.snowball
        : PlanMethod.avalanche;
    final alternative = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: altMethod,
      monthlyBudget: _budget,
    );

    final interestSaved = baseline.totalInterest - planned.totalInterest;
    final monthsSaved =
        baseline.monthsToDebtFree - planned.monthsToDebtFree;
    final methodDelta =
        alternative.totalInterest - planned.totalInterest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payoff Planner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One shared monthly budget, aimed at the right loan. When a loan is paid off, its payment rolls into the next one.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: kSubtle,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'EXTRA MONTHLY BUDGET',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                onChanged: _onBudgetChanged,
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: kInk, fontSize: 22),
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'METHOD',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 12),
              ...PlanMethod.values.map(_methodOption),
              if (methodDelta.abs() > 0.5) ...[
                const SizedBox(height: 8),
                Text(
                  methodDelta > 0
                      ? '${_method.label} saves ${money.format(methodDelta)} more than ${altMethod.label.toLowerCase()}.'
                      : '${altMethod.label} would save ${money.format(-methodDelta)} more.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: methodDelta >= 0 ? kAccent : const Color(0xFFB3402E),
                  ),
                ),
              ],
              const SizedBox(height: 36),
              const Text(
                'TOTAL DEBT PROJECTION',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 20),
              DebtCurveChart(
                baseline: baseline.curve,
                planned: planned.curve,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legendDot(kSubtle.withValues(alpha: 0.45)),
                  const SizedBox(width: 6),
                  const Text('No extra budget',
                      style: TextStyle(fontSize: 11, color: kSubtle)),
                  const SizedBox(width: 20),
                  _legendDot(kAccent),
                  const SizedBox(width: 6),
                  Text('With ${money.format(_budget)}/mo',
                      style:
                          const TextStyle(fontSize: 11, color: kSubtle)),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              _statRow(
                'Debt-free',
                planned.neverPaysOff
                    ? '—'
                    : DateFormat('MMM yyyy').format(planned.debtFreeDate),
              ),
              const Divider(),
              _statRow(
                'Time saved',
                monthsSaved > 0
                    ? PayoffPlanner.monthsLabel(monthsSaved)
                    : '0 mo',
                valueColor: kAccent,
              ),
              const Divider(),
              _statRow(
                'Interest saved',
                money.format(interestSaved),
                valueColor: kAccent,
              ),
              const Divider(),
              _statRow(
                'Total interest',
                money.format(planned.totalInterest),
              ),
              const Divider(),
              _pickerRow(
                'Strategy starts',
                DateFormat('MMM yyyy').format(_strategyStartDate),
                _pickStrategyStartDate,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: planned.neverPaysOff || planned.loanResults.isEmpty
                      ? null
                      : () => _applyPlan(planned),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Apply strategy'),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'PAYOFF ORDER',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 8),
              if (planned.loanResults.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No loan pays off within 50 years at this budget.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFFB3402E),
                    ),
                  ),
                )
              else
                ...planned.loanResults.expand((r) sync* {
                  yield const Divider();
                  yield _orderRow(r);
                }),
              if (planned.loanResults.isNotEmpty) const Divider(),
              if (planned.neverPaysOff) ...[
                const SizedBox(height: 16),
                const Text(
                  'Some loans never pay off with this budget — increase it or raise their scheduled payments.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFFB3402E),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodOption(PlanMethod method) {
    final selected = _method == method;
    return InkWell(
      onTap: () => setState(() => _method = method),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? kAccent : kHairline,
                    width: selected ? 5.5 : 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w400 : FontWeight.w300,
                      color: selected ? kInk : kSubtle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: kSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(PlanLoanResult r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${r.payoffOrder}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w200,
                color: kAccent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.loanName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: kInk,
              ),
            ),
          ),
          Text(
            '${DateFormat('MMM yyyy').format(r.payoffDate)} · ${PayoffPlanner.monthsLabel(r.monthsToPayoff)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _pickerRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kHairline)),
        ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
