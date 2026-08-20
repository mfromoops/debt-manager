import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/extra_payment.dart';
import '../services/app_state.dart';

class StrategyEditScreen extends StatefulWidget {
  final String loanId;
  final ExtraPayment? existing;
  const StrategyEditScreen({super.key, required this.loanId, this.existing});

  @override
  State<StrategyEditScreen> createState() => _StrategyEditScreenState();
}

class _StrategyEditScreenState extends State<StrategyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _intervalCtrl;
  late CadenceType _cadence;
  late int _annualMonth;
  DateTime? _oneTimeDate;
  DateTime? _startDate;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(0) : '');
    _intervalCtrl =
        TextEditingController(text: e != null ? e.interval.toString() : '8');
    _cadence = e?.cadence ?? CadenceType.monthly;
    _annualMonth = e?.annualMonth ?? 12;
    _oneTimeDate = e?.oneTimeDate;
    _startDate = e?.startDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  String _defaultName() {
    final amount = _amountCtrl.text.isEmpty ? '' : ' \$${_amountCtrl.text}';
    switch (_cadence) {
      case CadenceType.monthly:
        return 'Monthly extra$amount';
      case CadenceType.annual:
        return 'Annual payment$amount';
      case CadenceType.everyNWeeks:
        return 'Every ${_intervalCtrl.text} weeks$amount';
      case CadenceType.everyNMonths:
        return 'Every ${_intervalCtrl.text} months$amount';
      case CadenceType.oneTime:
        return 'One-time payment$amount';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_cadence == CadenceType.oneTime && _oneTimeDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date for the one-time payment')),
      );
      return;
    }
    final state = context.read<AppState>();
    final name =
        _nameCtrl.text.trim().isEmpty ? _defaultName() : _nameCtrl.text.trim();
    final interval = int.tryParse(_intervalCtrl.text) ?? 1;

    if (widget.existing != null) {
      state.updateExtra(widget.loanId, widget.existing!.copyWith(
        name: name,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        cadence: _cadence,
        interval: interval,
        annualMonth: _annualMonth,
        oneTimeDate: _oneTimeDate,
        startDate: _startDate,
      ));
    } else {
      state.addExtra(widget.loanId, ExtraPayment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        cadence: _cadence,
        interval: interval,
        annualMonth: _annualMonth,
        oneTimeDate: _oneTimeDate,
        startDate: _startDate,
      ));
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    context.read<AppState>().removeExtra(widget.loanId, widget.existing!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final needsInterval = _cadence == CadenceType.everyNWeeks ||
        _cadence == CadenceType.everyNMonths;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Strategy' : 'New Strategy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: kSubtle),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    hintText: 'e.g. Year-end bonus',
                    hintStyle: TextStyle(
                        color: kHairline, fontWeight: FontWeight.w300),
                  ),
                  style: const TextStyle(fontSize: 16, color: kInk),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 16, color: kInk),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', ''));
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 36),
                const Text(
                  'CADENCE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: kSubtle,
                  ),
                ),
                const SizedBox(height: 12),
                ...CadenceType.values.map(_cadenceOption),
                if (needsInterval) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Every',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: kSubtle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 64,
                        child: TextFormField(
                          controller: _intervalCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style:
                              const TextStyle(fontSize: 18, color: kInk),
                          validator: (v) {
                            if (!needsInterval) return null;
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 104) {
                              return '';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _cadence == CadenceType.everyNWeeks
                            ? 'weeks'
                            : 'months',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: kSubtle,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_cadence == CadenceType.annual) ...[
                  const SizedBox(height: 24),
                  _pickerRow(
                    'Month of year',
                    _months[_annualMonth - 1],
                    _pickAnnualMonth,
                  ),
                ],
                if (_cadence == CadenceType.oneTime) ...[
                  const SizedBox(height: 24),
                  _pickerRow(
                    'Payment date',
                    _oneTimeDate == null
                        ? 'Select…'
                        : DateFormat('MMM yyyy').format(_oneTimeDate!),
                    _pickOneTimeDate,
                  ),
                ],
                if (_cadence != CadenceType.oneTime) ...[
                  const SizedBox(height: 24),
                  _pickerRow(
                    'Starts',
                    _startDate == null
                        ? 'From loan start'
                        : DateFormat('MMM yyyy').format(_startDate!),
                    _pickStartDate,
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save changes' : 'Add strategy'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cadenceOption(CadenceType type) {
    final selected = _cadence == type;
    return InkWell(
      onTap: () => setState(() => _cadence = type),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
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
            const SizedBox(width: 16),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
                color: selected ? kInk : kSubtle,
              ),
            ),
            if (type == CadenceType.everyNWeeks) ...[
              const SizedBox(width: 8),
              const Text(
                'e.g. every 8 weeks',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: kHairline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pickerRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kHairline)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kSubtle,
                fontWeight: FontWeight.w300,
                fontSize: 15,
              ),
            ),
            Text(value, style: const TextStyle(fontSize: 15, color: kInk)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAnnualMonth() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => ListView.separated(
        itemCount: 12,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (ctx, i) => ListTile(
          title: Text(
            _months[i],
            style: const TextStyle(fontWeight: FontWeight.w300),
          ),
          onTap: () => Navigator.of(ctx).pop(i + 1),
        ),
      ),
    );
    if (picked != null) setState(() => _annualMonth = picked);
  }

  Future<void> _pickOneTimeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2070),
    );
    if (picked != null) setState(() => _oneTimeDate = picked);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2070),
    );
    if (picked != null) setState(() => _startDate = picked);
  }
}
