enum StrategyOverrideMode { paused, reduced }

class StrategyScheduleOverride {
  final String id;
  final String name;
  final DateTime startMonth;
  final DateTime? endMonth;
  final StrategyOverrideMode mode;

  /// Portion of every planned extra payment that remains during this window.
  /// Pauses always use zero; reductions use a value between zero and one.
  final double factor;

  const StrategyScheduleOverride({
    required this.id,
    required this.name,
    required this.startMonth,
    required this.mode,
    this.endMonth,
    this.factor = 0,
  });

  bool appliesTo(DateTime date) {
    final key = _monthKey(date);
    return key >= _monthKey(startMonth) &&
        (endMonth == null || key <= _monthKey(endMonth!));
  }

  StrategyScheduleOverride copyWith({
    String? name,
    DateTime? startMonth,
    DateTime? endMonth,
    bool clearEndMonth = false,
    StrategyOverrideMode? mode,
    double? factor,
  }) => StrategyScheduleOverride(
    id: id,
    name: name ?? this.name,
    startMonth: startMonth ?? this.startMonth,
    endMonth: clearEndMonth ? null : endMonth ?? this.endMonth,
    mode: mode ?? this.mode,
    factor: factor ?? this.factor,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startMonth': startMonth.toIso8601String(),
    'endMonth': endMonth?.toIso8601String(),
    'mode': mode.index,
    'factor': factor,
  };

  factory StrategyScheduleOverride.fromJson(Map<String, dynamic> json) {
    final modeIndex = (json['mode'] as num?)?.toInt() ?? 0;
    final mode =
        modeIndex >= 0 && modeIndex < StrategyOverrideMode.values.length
        ? StrategyOverrideMode.values[modeIndex]
        : StrategyOverrideMode.paused;
    return StrategyScheduleOverride(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Strategy pause',
      startMonth: DateTime.parse(json['startMonth'] as String),
      endMonth: json['endMonth'] == null
          ? null
          : DateTime.parse(json['endMonth'] as String),
      mode: mode,
      factor: mode == StrategyOverrideMode.paused
          ? 0
          : ((json['factor'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
    );
  }

  static double factorFor(
    DateTime date,
    Iterable<StrategyScheduleOverride> overrides,
  ) {
    var factor = 1.0;
    for (final override in overrides) {
      if (override.appliesTo(date) && override.factor < factor) {
        factor = override.factor;
      }
    }
    return factor;
  }

  static int _monthKey(DateTime date) => date.year * 12 + date.month - 1;
}
