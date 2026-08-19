class ProgressEntry {
  final String id;
  final DateTime date;
  final double? paymentAmount;
  final double? balance;
  final String note;

  const ProgressEntry({
    required this.id,
    required this.date,
    this.paymentAmount,
    this.balance,
    this.note = '',
  });

  bool get hasCheckpoint => balance != null;

  ProgressEntry copyWith({
    DateTime? date,
    double? paymentAmount,
    double? balance,
    String? note,
  }) {
    return ProgressEntry(
      id: id,
      date: date ?? this.date,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      balance: balance ?? this.balance,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'paymentAmount': paymentAmount,
        'balance': balance,
        'note': note,
      };

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        paymentAmount: (json['paymentAmount'] as num?)?.toDouble(),
        balance: (json['balance'] as num?)?.toDouble(),
        note: json['note'] as String? ?? '',
      );
}
