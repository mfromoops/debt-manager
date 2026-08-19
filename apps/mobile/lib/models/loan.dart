import 'extra_payment.dart';
import 'progress_entry.dart';

enum LoanType {
  mortgage,
  creditCard,
  personalLoan,
  autoLoan,
  studentLoan,
  other,
}

extension LoanTypeInfo on LoanType {
  String get label {
    switch (this) {
      case LoanType.mortgage:
        return 'Mortgage';
      case LoanType.creditCard:
        return 'Credit card';
      case LoanType.personalLoan:
        return 'Personal loan';
      case LoanType.autoLoan:
        return 'Auto loan';
      case LoanType.studentLoan:
        return 'Student loan';
      case LoanType.other:
        return 'Other';
    }
  }

  /// Credit cards have no fixed term — user sets a monthly payment instead.
  bool get usesFixedPayment => this == LoanType.creditCard;
}

/// How the required payment is determined.
enum PaymentMode {
  amortized, // fixed term -> computed monthly payment
  fixedPayment, // user-defined monthly payment (credit cards, flexible loans)
}

class Loan {
  final String id;
  final String name;
  final LoanType type;
  final double principal; // current balance being tracked
  final double annualRate; // percentage e.g. 6.5
  final DateTime startDate;
  final DateTime createdAt;
  final PaymentMode paymentMode;

  /// For amortized loans.
  final int termYears;

  /// For fixedPayment loans (credit cards etc.).
  final double fixedMonthlyPayment;

  final List<ExtraPayment> extras;
  final List<ProgressEntry> progressEntries;

  Loan({
    required this.id,
    required this.name,
    required this.type,
    required this.principal,
    required this.annualRate,
    required this.startDate,
    DateTime? createdAt,
    required this.paymentMode,
    this.termYears = 30,
    this.fixedMonthlyPayment = 0,
    this.extras = const [],
    this.progressEntries = const [],
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int get termMonths => termYears * 12;

  double get monthlyRate => annualRate / 100 / 12;

  /// The scheduled monthly payment (computed or user-defined).
  double get monthlyPayment {
    if (paymentMode == PaymentMode.fixedPayment) return fixedMonthlyPayment;
    if (monthlyRate == 0) return principal / termMonths;
    final r = monthlyRate;
    final n = termMonths;
    final pow = _powNum(1 + r, n);
    return principal * r * pow / (pow - 1);
  }

  /// True when the payment doesn't even cover monthly interest.
  bool get paymentTooLow =>
      paymentMode == PaymentMode.fixedPayment &&
      fixedMonthlyPayment <= principal * monthlyRate;

  static double _powNum(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  static DateTime _createdAtFromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    if (createdAt is String) return DateTime.parse(createdAt);
    final idMicros = int.tryParse(json['id'] as String? ?? '');
    if (idMicros != null) {
      return DateTime.fromMicrosecondsSinceEpoch(idMicros);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Loan copyWith({
    String? name,
    LoanType? type,
    double? principal,
    double? annualRate,
    DateTime? startDate,
    DateTime? createdAt,
    PaymentMode? paymentMode,
    int? termYears,
    double? fixedMonthlyPayment,
    List<ExtraPayment>? extras,
    List<ProgressEntry>? progressEntries,
  }) {
    return Loan(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      principal: principal ?? this.principal,
      annualRate: annualRate ?? this.annualRate,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
      paymentMode: paymentMode ?? this.paymentMode,
      termYears: termYears ?? this.termYears,
      fixedMonthlyPayment: fixedMonthlyPayment ?? this.fixedMonthlyPayment,
      extras: extras ?? this.extras,
      progressEntries: progressEntries ?? this.progressEntries,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'principal': principal,
        'annualRate': annualRate,
        'startDate': startDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'paymentMode': paymentMode.index,
        'termYears': termYears,
        'fixedMonthlyPayment': fixedMonthlyPayment,
        'extras': extras.map((e) => e.toJson()).toList(),
        'progressEntries': progressEntries.map((e) => e.toJson()).toList(),
      };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        name: json['name'] as String,
        type: LoanType.values[(json['type'] as num).toInt()],
        principal: (json['principal'] as num).toDouble(),
        annualRate: (json['annualRate'] as num).toDouble(),
        startDate: DateTime.parse(json['startDate'] as String),
        createdAt: _createdAtFromJson(json),
        paymentMode:
            PaymentMode.values[(json['paymentMode'] as num).toInt()],
        termYears: (json['termYears'] as num?)?.toInt() ?? 30,
        fixedMonthlyPayment:
            (json['fixedMonthlyPayment'] as num?)?.toDouble() ?? 0,
        extras: (json['extras'] as List<dynamic>? ?? [])
            .map((e) => ExtraPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
        progressEntries: (json['progressEntries'] as List<dynamic>? ?? [])
            .map((e) => ProgressEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
