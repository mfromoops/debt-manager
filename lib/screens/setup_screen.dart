import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/mortgage.dart';
import '../services/app_state.dart';

class SetupScreen extends StatefulWidget {
  final Mortgage? existing;
  const SetupScreen({super.key, this.existing});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _principalCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _termCtrl;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _principalCtrl = TextEditingController(
        text: e != null ? e.principal.toStringAsFixed(0) : '');
    _rateCtrl =
        TextEditingController(text: e != null ? e.annualRate.toString() : '');
    _termCtrl =
        TextEditingController(text: e != null ? e.termYears.toString() : '30');
    _startDate = e?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
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
    final mortgage = Mortgage(
      principal: double.parse(_principalCtrl.text.replaceAll(',', '')),
      annualRate: double.parse(_rateCtrl.text),
      termYears: int.parse(_termCtrl.text),
      startDate: _startDate,
    );
    context.read<AppState>().setMortgage(mortgage);
    if (widget.existing != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: isEdit
          ? AppBar(
              title: const Text('Edit Mortgage'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEdit) ...[
                  const SizedBox(height: 40),
                  const Text(
                    'Mortgage',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w200,
                      color: kInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set up your loan to start tracking\nand simulating payoff strategies.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: kSubtle,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
                TextFormField(
                  controller: _principalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Loan amount',
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 18, color: kInk),
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
                  decoration: const InputDecoration(
                    labelText: 'Interest rate (annual)',
                    suffixText: '%',
                    suffixStyle: TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 18, color: kInk),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 30) {
                      return 'Enter a valid rate (0–30)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _termCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Term',
                    suffixText: 'years',
                    suffixStyle: TextStyle(color: kInk),
                  ),
                  style: const TextStyle(fontSize: 18, color: kInk),
                  validator: (v) {
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
                        const Text(
                          'First payment',
                          style: TextStyle(
                            color: kSubtle,
                            fontWeight: FontWeight.w300,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_startDate),
                          style:
                              const TextStyle(fontSize: 16, color: kInk),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save changes' : 'Start tracking'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
