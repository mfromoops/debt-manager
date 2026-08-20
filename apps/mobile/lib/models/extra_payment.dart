/// Cadence types for extra payments.
enum CadenceType {
  monthly, // every month
  annual, // once a year in a chosen month
  everyNWeeks, // e.g. every 8 weeks
  everyNMonths, // e.g. every 3 months
  oneTime, // single payment at a specific date
}

extension CadenceTypeLabel on CadenceType {
  String get label {
    switch (this) {
      case CadenceType.monthly:
        return 'Monthly';
      case CadenceType.annual:
        return 'Annual';
      case CadenceType.everyNWeeks:
        return 'Every N weeks';
      case CadenceType.everyNMonths:
        return 'Every N months';
      case CadenceType.oneTime:
        return 'One-time';
    }
  }
}

class ExtraPayment {
  final String id;
  final String name;
  final double amount;
  final CadenceType cadence;

  /// For everyNWeeks / everyNMonths: the interval N.
  final int interval;

  /// For annual: month of year (1-12). For oneTime: exact date used instead.
  final int annualMonth;

  /// For oneTime payments.
  final DateTime? oneTimeDate;

  /// Start date for the recurring payment (defaults to mortgage start).
  final DateTime? startDate;

  final bool enabled;

  const ExtraPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.cadence,
    this.interval = 1,
    this.annualMonth = 1,
    this.oneTimeDate,
    this.startDate,
    this.enabled = true,
  });

  ExtraPayment copyWith({
    String? name,
    double? amount,
    CadenceType? cadence,
    int? interval,
    int? annualMonth,
    DateTime? oneTimeDate,
    DateTime? startDate,
    bool? enabled,
  }) {
    return ExtraPayment(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      cadence: cadence ?? this.cadence,
      interval: interval ?? this.interval,
      annualMonth: annualMonth ?? this.annualMonth,
      oneTimeDate: oneTimeDate ?? this.oneTimeDate,
      startDate: startDate ?? this.startDate,
      enabled: enabled ?? this.enabled,
    );
  }

  String cadenceDescription() {
    switch (cadence) {
      case CadenceType.monthly:
        return 'Every month';
      case CadenceType.annual:
        return 'Every year (month $annualMonth)';
      case CadenceType.everyNWeeks:
        return 'Every $interval weeks';
      case CadenceType.everyNMonths:
        return 'Every $interval months';
      case CadenceType.oneTime:
        return 'One-time';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'cadence': cadence.index,
        'interval': interval,
        'annualMonth': annualMonth,
        'oneTimeDate': oneTimeDate?.toIso8601String(),
        'startDate': startDate?.toIso8601String(),
        'enabled': enabled,
      };

  factory ExtraPayment.fromJson(Map<String, dynamic> json) => ExtraPayment(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        cadence: CadenceType.values[(json['cadence'] as num).toInt()],
        interval: (json['interval'] as num?)?.toInt() ?? 1,
        annualMonth: (json['annualMonth'] as num?)?.toInt() ?? 1,
        oneTimeDate: json['oneTimeDate'] != null
            ? DateTime.parse(json['oneTimeDate'] as String)
            : null,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        enabled: json['enabled'] as bool? ?? true,
      );
}
