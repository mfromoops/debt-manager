import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/financial_profile.dart';
import '../services/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _salaryController;
  late SalaryPeriod _salaryPeriod;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    _salaryController = TextEditingController(
      text: profile == null ? '' : profile.salary.toStringAsFixed(0),
    );
    _salaryPeriod = profile?.salaryPeriod ?? SalaryPeriod.monthly;
    _salaryController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _salaryController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  double? get _salary =>
      double.tryParse(_salaryController.text.replaceAll(',', ''));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().saveProfile(
      FinancialProfile(salary: _salary!, salaryPeriod: _salaryPeriod),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final salary = _salary;
    final monthlyIncome = salary == null
        ? null
        : (_salaryPeriod == SalaryPeriod.annual ? salary / 12 : salary);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INCOME',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: kSubtle,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your gross salary to see how debt payments fit into your monthly income.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: kSubtle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const Key('profile-salary'),
                  controller: _salaryController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Salary',
                    prefixText: '\$ ',
                  ),
                  style: const TextStyle(fontSize: 20, color: kInk),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').replaceAll(',', ''),
                    );
                    return amount == null || amount <= 0
                        ? 'Enter a valid salary'
                        : null;
                  },
                ),
                const SizedBox(height: 28),
                const Text(
                  'SALARY PERIOD',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: kSubtle,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<SalaryPeriod>(
                  key: const Key('salary-period'),
                  segments: SalaryPeriod.values
                      .map(
                        (period) => ButtonSegment(
                          value: period,
                          label: Text(period.label),
                        ),
                      )
                      .toList(),
                  selected: {_salaryPeriod},
                  onSelectionChanged: (selection) {
                    setState(() => _salaryPeriod = selection.first);
                  },
                ),
                if (monthlyIncome != null && monthlyIncome > 0) ...[
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MONTHLY INCOME USED FOR RATIOS',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            color: kSubtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money.format(monthlyIncome),
                          key: const Key('monthly-income-preview'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('save-profile'),
                    onPressed: _save,
                    child: const Text('Save profile'),
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
