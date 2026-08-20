import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../models/progress_entry.dart';
import '../services/app_state.dart';
import '../widgets/payoff_chart.dart';
import 'loan_edit_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Loan loan;
  const DashboardScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final comparison = state.comparisonFor(loan);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final money2 = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final currentBalance = state.currentBalance(loan);
    final paidDown = state.progressPaidDown(loan);
    final nextPaymentDate = state.nextPaymentDate(loan);
    final strategyPayment = state.nextPaymentWithStrategies(loan);
    final paidOffPct =
        ((loan.principal - currentBalance) / loan.principal * 100).clamp(
          0,
          100,
        );

    final activeStrategies = loan.extras.where((e) => e.enabled).length;
    final neverPaysOff = comparison.accelerated.neverPaysOff;
    final hasProgressHistory = loan.progressEntries.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kPagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, size: 20, color: kInk),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  loan.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: kInk,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: kSubtle),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoanEditScreen(existing: loan),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${loan.type.label} · ${loan.annualRate}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            money.format(currentBalance),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w500,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${money.format(paidDown)} paid down of ${money.format(loan.principal)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: paidOffPct.toDouble() / 100,
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
              fontWeight: FontWeight.w400,
              color: kSubtle,
            ),
          ),
          const SizedBox(height: 20),
          _DebtPaymentSummary(
            loan: loan,
            nextPaymentDate: nextPaymentDate,
            strategyPayment: strategyPayment,
            isPaidOff: currentBalance <= 0.005,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showProgressSheet(context, loan),
              icon: const Icon(Icons.add_chart_outlined, size: 18),
              label: const Text('Log progress'),
            ),
          ),
          if (neverPaysOff) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE8C4BC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Your payment doesn\'t reduce the balance — it never pays off at this rate. Increase the monthly payment or add strategies.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFB3402E),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
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
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(kSubtle.withValues(alpha: 0.45)),
                  const SizedBox(width: 6),
                  const Text(
                    'Standard',
                    style: TextStyle(fontSize: 11, color: kSubtle),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(kAccent),
                  const SizedBox(width: 6),
                  const Text(
                    'With strategies',
                    style: TextStyle(fontSize: 11, color: kSubtle),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(),
          if (hasProgressHistory) ...[
            _progressHistory(context, loan, money),
            const SizedBox(height: 40),
            const Divider(),
          ],
          _statRow(
            loan.paymentMode == PaymentMode.fixedPayment
                ? 'Monthly payment (set)'
                : 'Monthly payment',
            money2.format(loan.monthlyPayment),
          ),
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
            neverPaysOff
                ? '—'
                : DateFormat(
                    'MMM yyyy',
                  ).format(comparison.accelerated.payoffDate),
          ),
          const Divider(),
          _statRow(
            'Total interest',
            money.format(comparison.accelerated.totalInterest),
          ),
          const Divider(),
          _statRow('Active strategies', '$activeStrategies'),
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

  Widget _progressHistory(BuildContext context, Loan loan, NumberFormat money) {
    final entries = [...loan.progressEntries]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Text(
          'PROGRESS HISTORY',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w400,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map((entry) {
          final parts = <String>[
            if (entry.paymentAmount != null)
              '${money.format(entry.paymentAmount)} paid',
            if (entry.balance != null) '${money.format(entry.balance)} balance',
          ];
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  parts.join(' - '),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: kInk,
                  ),
                ),
                subtitle: Text(
                  [
                    DateFormat.yMMMd().format(entry.date),
                    if (entry.note.trim().isNotEmpty) entry.note.trim(),
                  ].join(' - '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: kSubtle,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: kSubtle),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showProgressSheet(context, loan, existing: entry);
                    } else if (value == 'delete') {
                      context.read<AppState>().removeProgressEntry(
                        loan.id,
                        entry.id,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
              const Divider(),
            ],
          );
        }),
      ],
    );
  }

  Widget _statRow(String label, String value, {Color valueColor = kInk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: kSubtle,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProgressSheet(
    BuildContext context,
    Loan loan, {
    ProgressEntry? existing,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      builder: (_) => _ProgressSheet(loan: loan, existing: existing),
    );
  }
}

class _DebtPaymentSummary extends StatelessWidget {
  final Loan loan;
  final DateTime nextPaymentDate;
  final double strategyPayment;
  final bool isPaidOff;

  const _DebtPaymentSummary({
    required this.loan,
    required this.nextPaymentDate,
    required this.strategyPayment,
    required this.isPaidOff,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final hasExtra = strategyPayment > loan.monthlyPayment + 0.005;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT PAYMENT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w500,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PaymentDetail(
                  label: 'MINIMUM DUE',
                  value: isPaidOff ? '—' : money.format(loan.monthlyPayment),
                  valueKey: const Key('detail-minimum-due'),
                ),
              ),
              const _PaymentDetailDivider(),
              Expanded(
                child: _PaymentDetail(
                  label: 'PAYMENT DATE',
                  value: isPaidOff
                      ? 'Paid off'
                      : DateFormat('MMM d').format(nextPaymentDate),
                  valueKey: const Key('detail-next-payment-date'),
                ),
              ),
              const _PaymentDetailDivider(),
              Expanded(
                child: _PaymentDetail(
                  label: 'WITH STRATEGY',
                  value: isPaidOff ? '—' : money.format(strategyPayment),
                  valueKey: const Key('detail-strategy-payment'),
                  highlighted: hasExtra && !isPaidOff,
                ),
              ),
            ],
          ),
          if (hasExtra && !isPaidOff) ...[
            const SizedBox(height: 14),
            Text(
              '${money.format(strategyPayment - loan.monthlyPayment)} extra is scheduled with your active strategies.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: kSubtle,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;
  final bool highlighted;

  const _PaymentDetail({
    required this.label,
    required this.value,
    required this.valueKey,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w500,
            color: kSubtle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: highlighted ? kAccent : kInk,
          ),
        ),
      ],
    );
  }
}

class _PaymentDetailDivider extends StatelessWidget {
  const _PaymentDetailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: const Color(0xFFDCE8E0),
    );
  }
}

class _ProgressSheet extends StatefulWidget {
  final Loan loan;
  final ProgressEntry? existing;

  const _ProgressSheet({required this.loan, this.existing});

  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paymentCtrl;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    _date = entry?.date ?? DateTime.now();
    _paymentCtrl = TextEditingController(
      text: entry?.paymentAmount?.toStringAsFixed(0) ?? '',
    );
    _balanceCtrl = TextEditingController(
      text: entry?.balance?.toStringAsFixed(0) ?? '',
    );
    _noteCtrl = TextEditingController(text: entry?.note ?? '');
  }

  @override
  void dispose() {
    _paymentCtrl.dispose();
    _balanceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _date.isBefore(widget.loan.startDate)
        ? widget.loan.startDate
        : _date.isAfter(now)
        ? now
        : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: widget.loan.startDate,
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final payment = _amountOrNull(_paymentCtrl.text);
    final balance = _amountOrNull(_balanceCtrl.text);
    if (payment == null && balance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a payment or ending balance.')),
      );
      return;
    }

    final entry = ProgressEntry(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      paymentAmount: payment,
      balance: balance,
      note: _noteCtrl.text.trim(),
    );

    final state = context.read<AppState>();
    if (widget.existing == null) {
      state.addProgressEntry(widget.loan.id, entry);
    } else {
      state.updateProgressEntry(widget.loan.id, entry);
    }
    Navigator.of(context).pop();
  }

  double? _amountOrNull(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(kPagePadding, 24, kPagePadding, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Log progress' : 'Edit progress',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: kHairline)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(
                          color: kSubtle,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd().format(_date),
                        style: const TextStyle(fontSize: 16, color: kInk),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _paymentCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Payment amount',
                  prefixText: '\$ ',
                ),
                validator: _optionalPositiveAmount,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Ending balance',
                  prefixText: '\$ ',
                ),
                validator: _optionalPositiveAmount,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save progress'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _optionalPositiveAmount(String? value) {
    final cleaned = (value ?? '').trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final amount = double.tryParse(cleaned);
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }
}
