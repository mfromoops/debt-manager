enum SalaryPeriod { monthly, annual }

enum DebtIncomeBand { healthy, tight, high }

DebtIncomeBand debtIncomeBand(double ratio) {
  if (ratio <= 0.36) return DebtIncomeBand.healthy;
  if (ratio <= 0.43) return DebtIncomeBand.tight;
  return DebtIncomeBand.high;
}

extension DebtIncomeBandInfo on DebtIncomeBand {
  String get label {
    switch (this) {
      case DebtIncomeBand.healthy:
        return 'Healthy';
      case DebtIncomeBand.tight:
        return 'Getting tight';
      case DebtIncomeBand.high:
        return 'High';
    }
  }
}

extension SalaryPeriodInfo on SalaryPeriod {
  String get label => this == SalaryPeriod.monthly ? 'Monthly' : 'Annual';
}

class FinancialProfile {
  final double salary;
  final SalaryPeriod salaryPeriod;

  const FinancialProfile({required this.salary, required this.salaryPeriod});

  double get monthlyIncome =>
      salaryPeriod == SalaryPeriod.annual ? salary / 12 : salary;

  double debtRatio(double monthlyDebtPayment) =>
      monthlyIncome <= 0 ? 0 : monthlyDebtPayment / monthlyIncome;

  Map<String, dynamic> toJson() => {
    'salary': salary,
    'salaryPeriod': salaryPeriod.name,
  };

  factory FinancialProfile.fromJson(Map<String, dynamic> json) {
    final periodName = json['salaryPeriod'] as String?;
    return FinancialProfile(
      salary: (json['salary'] as num).toDouble(),
      salaryPeriod: SalaryPeriod.values.firstWhere(
        (period) => period.name == periodName,
        orElse: () => SalaryPeriod.monthly,
      ),
    );
  }
}
