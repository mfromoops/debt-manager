class Mortgage {
  final double principal;
  final double annualRate; // percentage e.g. 6.5
  final int termYears;
  final DateTime startDate;

  const Mortgage({
    required this.principal,
    required this.annualRate,
    required this.termYears,
    required this.startDate,
  });

  int get termMonths => termYears * 12;

  double get monthlyRate => annualRate / 100 / 12;

  /// Standard fixed monthly payment (principal + interest).
  double get monthlyPayment {
    if (monthlyRate == 0) return principal / termMonths;
    final r = monthlyRate;
    final n = termMonths;
    final pow = _powNum(1 + r, n);
    return principal * r * pow / (pow - 1);
  }

  static double _powNum(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'principal': principal,
        'annualRate': annualRate,
        'termYears': termYears,
        'startDate': startDate.toIso8601String(),
      };

  factory Mortgage.fromJson(Map<String, dynamic> json) => Mortgage(
        principal: (json['principal'] as num).toDouble(),
        annualRate: (json['annualRate'] as num).toDouble(),
        termYears: (json['termYears'] as num).toInt(),
        startDate: DateTime.parse(json['startDate'] as String),
      );
}
