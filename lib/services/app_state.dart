import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan.dart';
import '../models/extra_payment.dart';
import 'amortization_engine.dart';

class AppState extends ChangeNotifier {
  List<Loan> _loans = [];
  bool _loaded = false;

  List<Loan> get loans => List.unmodifiable(_loans);
  bool get loaded => _loaded;
  bool get hasLoans => _loans.isNotEmpty;

  final Map<String, ComparisonResult> _cache = {};

  Loan? loanById(String id) {
    for (final l in _loans) {
      if (l.id == id) return l;
    }
    return null;
  }

  ComparisonResult comparisonFor(Loan loan) {
    return _cache.putIfAbsent(loan.id, () => AmortizationEngine.compare(loan));
  }

  void _invalidate(String id) => _cache.remove(id);

  // ---- Aggregates across all loans ----
  double get totalDebt =>
      _loans.fold(0.0, (s, l) => s + currentBalance(l));

  double get totalMonthlyPayment =>
      _loans.fold(0.0, (s, l) => s + l.monthlyPayment);

  double get totalInterestSaved =>
      _loans.fold(0.0, (s, l) => s + comparisonFor(l).interestSaved);

  /// Balance as of today according to the accelerated schedule.
  double currentBalance(Loan loan) {
    final schedule = comparisonFor(loan).accelerated.schedule;
    if (schedule.isEmpty) return loan.principal;
    final now = DateTime.now();
    final elapsed = (now.year - loan.startDate.year) * 12 +
        (now.month - loan.startDate.month) +
        1;
    if (elapsed <= 0) return loan.principal;
    if (elapsed >= schedule.length) return schedule.last.balance;
    return schedule[elapsed - 1].balance;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final loansJson = prefs.getString('loans');
      if (loansJson != null) {
        final list = jsonDecode(loansJson) as List<dynamic>;
        _loans = list
            .map((e) => Loan.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // ---- Migration from v1 single-mortgage format ----
        final mortgageJson = prefs.getString('mortgage');
        if (mortgageJson != null) {
          final m = jsonDecode(mortgageJson) as Map<String, dynamic>;
          List<ExtraPayment> extras = [];
          final extrasJson = prefs.getString('extras');
          if (extrasJson != null) {
            final list = jsonDecode(extrasJson) as List<dynamic>;
            extras = list
                .map((e) => ExtraPayment.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          _loans = [
            Loan(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: 'My Mortgage',
              type: LoanType.mortgage,
              principal: (m['principal'] as num).toDouble(),
              annualRate: (m['annualRate'] as num).toDouble(),
              startDate: DateTime.parse(m['startDate'] as String),
              paymentMode: PaymentMode.amortized,
              termYears: (m['termYears'] as num).toInt(),
              extras: extras,
            ),
          ];
          await prefs.remove('mortgage');
          await prefs.remove('extras');
          await _persist();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load state: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'loans', jsonEncode(_loans.map((l) => l.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist state: $e');
      }
    }
  }

  Future<void> addLoan(Loan loan) async {
    _loans = [..._loans, loan];
    notifyListeners();
    await _persist();
  }

  Future<void> updateLoan(Loan loan) async {
    _loans = _loans.map((l) => l.id == loan.id ? loan : l).toList();
    _invalidate(loan.id);
    notifyListeners();
    await _persist();
  }

  Future<void> removeLoan(String id) async {
    _loans = _loans.where((l) => l.id != id).toList();
    _cache.remove(id);
    notifyListeners();
    await _persist();
  }

  // ---- Extra payment operations on a specific loan ----
  Future<void> addExtra(String loanId, ExtraPayment e) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(loan.copyWith(extras: [...loan.extras, e]));
  }

  Future<void> updateExtra(String loanId, ExtraPayment e) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(loan.copyWith(
      extras: loan.extras.map((x) => x.id == e.id ? e : x).toList(),
    ));
  }

  Future<void> removeExtra(String loanId, String extraId) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(loan.copyWith(
      extras: loan.extras.where((x) => x.id != extraId).toList(),
    ));
  }

  Future<void> toggleExtra(String loanId, String extraId, bool enabled) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(loan.copyWith(
      extras: loan.extras
          .map((x) => x.id == extraId ? x.copyWith(enabled: enabled) : x)
          .toList(),
    ));
  }
}
