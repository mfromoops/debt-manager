import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/loan.dart';
import '../services/app_state.dart';

class LoanEditScreen extends StatefulWidget {
  final Loan? existing;
  const LoanEditScreen({super.key, this.existing});

  @override
  State<LoanEditScreen> createState() => _LoanEditScreenState();
}

class _LoanEditScreenState extends State<LoanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _principalCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _termCtrl;
  late final TextEditingController _paymentCtrl;
  late LoanType _type;
  late PaymentMode _paymentMode;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _principalCtrl = TextEditingController(
        text: e != null ? e.principal.toStringAsFixed(0) : '');
    _rateCtrl =
        TextEditingController(text: e != null ? e.annualRate.toString() : '');
    _termCtrl =
        TextEditingController(text: e != null ? e.termYears.toString() : '30');
    _paymentCtrl = TextEditingController(
        text: e != null && e.fixedMonthlyPayment > 0
            ? e.fixedMonthlyPayment.toStringAsFixed(0)
            : '');
    _type = e?.type ?? LoanType.mortgage;
    _paymentMode = e?.paymentMode ??
        (_type.usesFixedPayment
            ? PaymentMode.fixedPayment
            : PaymentMode.amortized);
    _startDate =
        e?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(LoanType t) {
    setState(() {
      _type = t;
      _paymentMode = t.usesFixedPayment
          ? PaymentMode.fixedPayment
          : PaymentMode.amortized;
    });
  }

  String _defaultName() {
    switch (_type) {
      case LoanType.mortgage:
        return 'My Mortgage';
      case LoanType.creditCard:
        return 'Credit Card';
      case LoanType.personalLoan:
        return 'Personal Loan';
      case LoanType.autoLoan:
        return 'Auto Loan';
      case LoanType.studentLoan:
        return 'Student Loan';
      case LoanType.other:
        return 'Loan';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2060),
    );
    if (picked != null) {
      setState(() => _startDate = DateTime(picked.year, picked.month));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final principal = double.parse(_principalCtrl.text.replaceAll(',', ''));
    final rate = double.parse(_rateCtrl.text);
    final isFixed = _paymentMode == PaymentMode.fixedPayment;
    final fixedPayment = isFixed
        ? double.parse(_paymentCtrl.text.replaceAll(',', ''))
        : 0.0;

    // Warn if payment doesn't cover interest
    if (isFixed && fixedPayment <= principal * rate / 100 / 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment must exceed monthly interest (\$${(principal * rate / 100 / 12).toStringAsFixed(2)}) to pay this off.',
          ),
        ),
      );
      return;
    }

    final name =
        _nameCtrl.text.trim().isEmpty ? _defaultName() : _nameCtrl.text.trim();

    if (widget.existing != null) {
      state.updateLoan(widget.existing!.copyWith(
        name: name,
        type: _type,
        principal: principal,
        annualRate: rate,
        startDate: _startDate,
        paymentMode: _paymentMode,
        termYears: int.tryParse(_termCtrl.text) ?? widget.existing!.termYears,
        fixedMonthlyPayment: fixedPayment,
      ));
    } else {
      state.addLoan(Loan(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        type: _type,
        principal: principal,
        annualRate: rate,
        startDate: _startDate,
        paymentMode: _paymentMode,
        termYears: int.tryParse(_termCtrl.text) ?? 30,
        fixedMonthlyPayment: fixedPayment,
      ));
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final loan = widget.existing!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete loan?',
            style: TextStyle(fontWeight: FontWeight.w300)),
        content: Text('“${loan.name}” and its strategies will be removed.',
            style: const TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AppState>().removeLoan(loan.id);
              // Pop edit screen and (if present) the loan detail below it.
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFB3402E))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final isFixed = _paymentMode == PaymentMode.fixedPayment;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Loan' : 'New Loan'),
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
                const Text(
                  'TYPE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: kSubtle,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LoanType.values.map((t) {
                    final selected = _type == t;
                    return InkWell(
                      onTap: () => _onTypeChanged(t),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: selected ? kAccent : kHairline),
                          borderRadius: BorderRadius.circular(4),
                          color: selected
                              ? kAccent.withValues(alpha: 0.06)
                              : Colors.white,
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w400 : FontWeight.w300,
                            color: selected ? kAccent : kSubtle,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name (optional)',
                    hintText: _defaultName(),
                    hintStyle: const TextStyle(
                        color: kHairline, fontWeight: FontWeight.w300),
                  ),
                  style: const TextStyle(fontSize: 16, color: kInk),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _principalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: isFixed ? 'Current balance' : 'Loan amount',
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 16, color: kInk),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', ''));
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: isFixed
                        ? 'Interest rate (APR)'
                        : 'Interest rate (annual)',
                    suffixText: '%',
                    suffixStyle: const TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 16, color: kInk),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 100) {
                      return 'Enter a valid rate';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                if (isFixed)
                  TextFormField(
                    controller: _paymentCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monthly payment',
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: kInk),
                      helperText:
                          'Credit cards have no fixed term — set what you pay each month.',
                      helperStyle: TextStyle(
                          color: kSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w300),
                    ),
                    style: const TextStyle(fontSize: 16, color: kInk),
                    validator: (v) {
                      if (!isFixed) return null;
                      final n =
                          double.tryParse((v ?? '').replaceAll(',', ''));
                      if (n == null || n <= 0) return 'Enter a valid payment';
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _termCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Term',
                      suffixText: 'years',
                      suffixStyle: TextStyle(color: kInk),
                    ),
                    style: const TextStyle(fontSize: 16, color: kInk),
                    validator: (v) {
                      if (isFixed) return null;
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0 || n > 50) {
                        return 'Enter a valid term (1–50)';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 28),
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
                        Text(
                          isFixed ? 'Tracking from' : 'First payment',
                          style: const TextStyle(
                            color: kSubtle,
                            fontWeight: FontWeight.w300,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_startDate),
                          style: const TextStyle(fontSize: 16, color: kInk),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save changes' : 'Add loan'),
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
}
