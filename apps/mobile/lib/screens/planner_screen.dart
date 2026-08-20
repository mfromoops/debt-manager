import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/extra_payment.dart';
import '../models/financial_profile.dart';
import '../services/app_state.dart';
import '../services/payoff_planner.dart';
import '../widgets/debt_curve_chart.dart';
import 'profile_screen.dart';

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
  final List<ExtraPayment> _addons = [];

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      for (var i = 0; i < _addons.length; i++) {
        final addon = _addons[i];
        if (addon.cadence == CadenceType.everyNMonths) {
          _addons[i] = addon.copyWith(startDate: _strategyStartDate);
        }
      }
    });
  }

  Future<void> _editAddon([ExtraPayment? existing]) async {
    final addon = await showModalBottomSheet<ExtraPayment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _PlanAddonEditor(
        existing: existing,
        defaultStart: _strategyStartDate,
      ),
    );
    if (addon == null) return;
    setState(() {
      final index = _addons.indexWhere((item) => item.id == addon.id);
      if (index == -1) {
        _addons.add(addon);
      } else {
        _addons[index] = addon;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final balances = {
      for (final l in state.loans) l.id: state.currentBalance(l),
    };

    final baseline = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: _method,
      monthlyBudget: 0,
      strategySchedule: state.strategySchedule,
      planStart: _strategyStartDate,
    );
    final planned = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: _method,
      monthlyBudget: _budget,
      addons: _addons,
      strategySchedule: state.strategySchedule,
      planStart: _strategyStartDate,
    );
    final altMethod = _method == PlanMethod.avalanche
        ? PlanMethod.snowball
        : PlanMethod.avalanche;
    final alternative = PayoffPlanner.plan(
      loans: state.loans,
      startingBalances: balances,
      method: altMethod,
      monthlyBudget: _budget,
      addons: _addons,
      strategySchedule: state.strategySchedule,
      planStart: _strategyStartDate,
    );

    final interestSaved = baseline.totalInterest - planned.totalInterest;
    final monthsSaved = baseline.monthsToDebtFree - planned.monthsToDebtFree;
    final methodDelta = alternative.totalInterest - planned.totalInterest;
    final monthlyIncome = state.monthlyIncome;
    final plannedMonthlyCommitment =
        state.minimumDue + _budget + _monthlyEquivalentAddons();
    final planDebtRatio = monthlyIncome == null || monthlyIncome <= 0
        ? null
        : plannedMonthlyCommitment / monthlyIncome;

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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CUSTOM ADD-ONS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                        color: kSubtle,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('add-plan-addon'),
                    onPressed: _editAddon,
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_addons.isEmpty)
                const Text(
                  'Add an annual installment, bonus, or periodic payment.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: kSubtle,
                  ),
                )
              else
                ..._addons.map(
                  (addon) => InkWell(
                    key: Key('plan-addon-${addon.id}'),
                    onTap: () => _editAddon(addon),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: kAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addon.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: kInk,
                                  ),
                                ),
                                Text(
                                  _addonDescription(addon, money),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300,
                                    color: kSubtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove add-on',
                            onPressed: () => setState(
                              () => _addons.removeWhere(
                                (item) => item.id == addon.id,
                              ),
                            ),
                            icon: const Icon(
                              Icons.close,
                              size: 17,
                              color: kSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              const Text(
                'PLAN AFFORDABILITY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                  color: kSubtle,
                ),
              ),
              const SizedBox(height: 12),
              if (planDebtRatio == null)
                InkWell(
                  key: const Key('planner-add-salary'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_add_alt, size: 18, color: kAccent),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add your salary to check whether this plan fits your monthly income.',
                            style: TextStyle(fontSize: 12, color: kAccent),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: kSubtle),
                      ],
                    ),
                  ),
                )
              else
                _affordabilityCard(
                  ratio: planDebtRatio,
                  monthlyCommitment: plannedMonthlyCommitment,
                  monthlyIncome: monthlyIncome!,
                  money: money,
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
              DebtCurveChart(baseline: baseline.curve, planned: planned.curve),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legendDot(kSubtle.withValues(alpha: 0.45)),
                  const SizedBox(width: 6),
                  const Text(
                    'No extra budget',
                    style: TextStyle(fontSize: 11, color: kSubtle),
                  ),
                  const SizedBox(width: 20),
                  _legendDot(kAccent),
                  const SizedBox(width: 6),
                  Text(
                    _addons.isEmpty
                        ? 'With ${money.format(_budget)}/mo'
                        : 'With budget + ${_addons.length} add-on${_addons.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 11, color: kSubtle),
                  ),
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
              _statRow('Total interest', money.format(planned.totalInterest)),
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
                      fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
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

  String _addonDescription(ExtraPayment addon, NumberFormat money) {
    final amount = money.format(addon.amount);
    switch (addon.cadence) {
      case CadenceType.annual:
        return '$amount every ${DateFormat('MMMM').format(DateTime(2024, addon.annualMonth))}';
      case CadenceType.everyNMonths:
        return '$amount every ${addon.interval} months';
      case CadenceType.oneTime:
        return '$amount in ${DateFormat('MMM yyyy').format(addon.oneTimeDate!)}';
      case CadenceType.monthly:
        return '$amount monthly';
      case CadenceType.everyNWeeks:
        return '$amount every ${addon.interval} weeks';
    }
  }

  double _monthlyEquivalentAddons() {
    return _addons.fold<double>(0, (sum, addon) {
      switch (addon.cadence) {
        case CadenceType.monthly:
          return sum + addon.amount;
        case CadenceType.annual:
          return sum + addon.amount / 12;
        case CadenceType.everyNMonths:
          return sum + addon.amount / addon.interval;
        case CadenceType.everyNWeeks:
          return sum + addon.amount * 52 / (12 * addon.interval);
        case CadenceType.oneTime:
          return sum;
      }
    });
  }

  Widget _affordabilityCard({
    required double ratio,
    required double monthlyCommitment,
    required double monthlyIncome,
    required NumberFormat money,
  }) {
    final band = debtIncomeBand(ratio);
    final color = switch (band) {
      DebtIncomeBand.healthy => kAccent,
      DebtIncomeBand.tight => const Color(0xFFB7791F),
      DebtIncomeBand.high => const Color(0xFFB3402E),
    };
    final remaining = monthlyIncome - monthlyCommitment;
    return Container(
      key: const Key('planner-income-ratio'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(ratio * 100).toStringAsFixed(1)}% of monthly income',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: kInk,
                  ),
                ),
              ),
              Text(
                band.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              backgroundColor: kHairline,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${money.format(monthlyCommitment)} toward debt · ${money.format(remaining)} remaining',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Based on gross monthly salary and the average monthly value of recurring add-ons. 36% or less is a common healthy guide.',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: kSubtle,
              height: 1.4,
            ),
          ),
        ],
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

class _PlanAddonEditor extends StatefulWidget {
  final ExtraPayment? existing;
  final DateTime defaultStart;

  const _PlanAddonEditor({this.existing, required this.defaultStart});

  @override
  State<_PlanAddonEditor> createState() => _PlanAddonEditorState();
}

class _PlanAddonEditorState extends State<_PlanAddonEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _intervalController;
  late CadenceType _cadence;
  late int _annualMonth;
  DateTime? _oneTimeDate;

  static const _supportedCadences = [
    CadenceType.annual,
    CadenceType.everyNMonths,
    CadenceType.oneTime,
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    _intervalController = TextEditingController(
      text: (existing?.interval ?? 3).toString(),
    );
    _cadence = _supportedCadences.contains(existing?.cadence)
        ? existing!.cadence
        : CadenceType.annual;
    _annualMonth = existing?.annualMonth ?? widget.defaultStart.month;
    _oneTimeDate = existing?.oneTimeDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  String get _defaultName {
    switch (_cadence) {
      case CadenceType.annual:
        return 'Annual installment';
      case CadenceType.everyNMonths:
        return 'Periodic payment';
      case CadenceType.oneTime:
        return 'One-time payment';
      case CadenceType.monthly:
        return 'Monthly add-on';
      case CadenceType.everyNWeeks:
        return 'Periodic payment';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_cadence == CadenceType.oneTime && _oneTimeDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the payment month.')),
      );
      return;
    }
    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final interval = int.tryParse(_intervalController.text) ?? 1;
    Navigator.of(context).pop(
      ExtraPayment(
        id:
            widget.existing?.id ??
            'planner-${DateTime.now().microsecondsSinceEpoch}',
        name: _nameController.text.trim().isEmpty
            ? _defaultName
            : _nameController.text.trim(),
        amount: amount,
        cadence: _cadence,
        interval: interval,
        annualMonth: _annualMonth,
        oneTimeDate: _oneTimeDate,
        startDate: _cadence == CadenceType.everyNMonths
            ? widget.defaultStart
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'New add-on' : 'Edit add-on',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: kInk,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'e.g. Year-end bonus',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('plan-addon-amount'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').replaceAll(',', ''),
                  );
                  return amount == null || amount <= 0
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<CadenceType>(
                initialValue: _cadence,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: _supportedCadences
                    .map(
                      (cadence) => DropdownMenuItem(
                        value: cadence,
                        child: Text(
                          cadence == CadenceType.everyNMonths
                              ? 'Periodic (every N months)'
                              : cadence.label,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _cadence = value);
                },
              ),
              if (_cadence == CadenceType.annual) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _annualMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        DateFormat('MMMM').format(DateTime(2024, index + 1)),
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setState(() => _annualMonth = value);
                  },
                ),
              ],
              if (_cadence == CadenceType.everyNMonths) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Repeat every',
                    suffixText: 'months',
                  ),
                  validator: (value) {
                    if (_cadence != CadenceType.everyNMonths) return null;
                    final interval = int.tryParse(value ?? '');
                    return interval == null || interval < 1 || interval > 120
                        ? 'Enter 1–120 months'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Starts ${DateFormat('MMM yyyy').format(widget.defaultStart)}',
                  style: const TextStyle(fontSize: 11, color: kSubtle),
                ),
              ],
              if (_cadence == CadenceType.oneTime) ...[
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment month'),
                  trailing: Text(
                    _oneTimeDate == null
                        ? 'Choose…'
                        : DateFormat('MMM yyyy').format(_oneTimeDate!),
                    style: const TextStyle(color: kAccent),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _oneTimeDate ?? widget.defaultStart,
                      firstDate: DateTime(1990),
                      lastDate: DateTime(2070),
                    );
                    if (picked != null) setState(() => _oneTimeDate = picked);
                  },
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('save-plan-addon'),
                  onPressed: _save,
                  child: Text(
                    widget.existing == null ? 'Add to plan' : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
