import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan.dart';
import '../models/extra_payment.dart';
import '../models/progress_entry.dart';
import 'amortization_engine.dart';
import 'sync_service.dart';

enum LoanSortOption {
  nextPayment,
  loanAmount,
  payoffDate,
  addedRecently,
}

extension LoanSortOptionInfo on LoanSortOption {
  String get label {
    switch (this) {
      case LoanSortOption.nextPayment:
        return 'Next payment';
      case LoanSortOption.loanAmount:
        return 'Loan amount';
      case LoanSortOption.payoffDate:
        return 'Payoff date';
      case LoanSortOption.addedRecently:
        return 'Added recently';
    }
  }
}

class AppState extends ChangeNotifier {
  static const _loansKey = 'loans';
  static const _loanSortKey = 'loans.sort';
  static const _syncUpdatedAtKey = 'loans.syncUpdatedAt';
  static const _syncRevKey = 'loans.syncRev';
  static const _syncDeviceIdKey = 'loans.syncDeviceId';

  List<Loan> _loans = [];
  LoanSortOption _loanSort = LoanSortOption.nextPayment;
  bool _loaded = false;
  DateTime _syncUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String _syncRev = '0';
  String? _syncDeviceId;
  SyncService? _syncService;
  Future<String?> Function({bool forceRefresh})? _accessTokenProvider;
  bool _syncing = false;
  String? _syncError;

  List<Loan> get loans => List.unmodifiable(_loans);
  LoanSortOption get loanSort => _loanSort;
  List<Loan> get sortedLoans {
    final sorted = [..._loans];
    sorted.sort(_compareLoans);
    return List.unmodifiable(sorted);
  }
  bool get loaded => _loaded;
  bool get hasLoans => _loans.isNotEmpty;
  bool get syncing => _syncing;
  String? get syncError => _syncError;

  final Map<String, ComparisonResult> _cache = {};

  Loan? loanById(String id) {
    for (final l in _loans) {
      if (l.id == id) return l;
    }
    return null;
  }

  ComparisonResult comparisonFor(Loan loan) {
    return _cache.putIfAbsent(
      loan.id,
      () => AmortizationEngine.compare(projectedLoan(loan)),
    );
  }

  void _invalidate(String id) => _cache.remove(id);

  // ---- Aggregates across all loans ----
  double get totalDebt =>
      _loans.fold(0.0, (s, l) => s + currentBalance(l));

  double get totalMonthlyPayment =>
      _loans.fold(0.0, (s, l) => s + l.monthlyPayment);

  double get totalInterestSaved =>
      _loans.fold(0.0, (s, l) => s + comparisonFor(l).interestSaved);

  int _compareLoans(Loan a, Loan b) {
    final result = switch (_loanSort) {
      LoanSortOption.nextPayment =>
        nextPaymentDate(a).compareTo(nextPaymentDate(b)),
      LoanSortOption.loanAmount => b.principal.compareTo(a.principal),
      LoanSortOption.payoffDate =>
        _payoffSortDate(a).compareTo(_payoffSortDate(b)),
      LoanSortOption.addedRecently => b.createdAt.compareTo(a.createdAt),
    };
    if (result != 0) return result;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  DateTime _payoffSortDate(Loan loan) {
    final result = comparisonFor(loan).accelerated;
    return result.neverPaysOff ? DateTime(9999) : result.payoffDate;
  }

  Loan projectedLoan(Loan loan) {
    final checkpoint = latestCheckpoint(loan);
    final projectionStart = checkpoint?.date ?? loan.startDate;
    final progressExtras = _progressPaymentExtras(loan, projectionStart);
    if (checkpoint == null || checkpoint.balance == null) {
      return loan.copyWith(extras: [...loan.extras, ...progressExtras]);
    }
    if (loan.paymentMode == PaymentMode.amortized) {
      return loan.copyWith(
        principal: checkpoint.balance,
        startDate: checkpoint.date,
        paymentMode: PaymentMode.fixedPayment,
        fixedMonthlyPayment: loan.monthlyPayment,
        extras: [...loan.extras, ...progressExtras],
      );
    }
    return loan.copyWith(
      principal: checkpoint.balance,
      startDate: checkpoint.date,
      extras: [...loan.extras, ...progressExtras],
    );
  }

  List<ExtraPayment> _progressPaymentExtras(Loan loan, DateTime start) {
    return loan.progressEntries
        .where((entry) =>
            entry.paymentAmount != null &&
            entry.balance == null &&
            !entry.date.isBefore(start))
        .map(
          (entry) => ExtraPayment(
            id: 'progress-${entry.id}',
            name: 'Logged payment',
            amount: entry.paymentAmount!,
            cadence: CadenceType.oneTime,
            oneTimeDate: entry.date,
          ),
        )
        .toList();
  }

  ProgressEntry? latestCheckpoint(Loan loan) {
    final checkpoints = loan.progressEntries
        .where((entry) => entry.balance != null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return checkpoints.isEmpty ? null : checkpoints.first;
  }

  DateTime nextPaymentDate(Loan loan) {
    final now = DateTime.now();
    var candidate = loan.startDate;
    while (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
      final nextMonth = DateTime(candidate.year, candidate.month + 1);
      candidate = DateTime(
        nextMonth.year,
        nextMonth.month,
        _clampDay(loan.startDate.day, nextMonth.year, nextMonth.month),
      );
    }
    return candidate;
  }

  int _clampDay(int day, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day > lastDay ? lastDay : day;
  }

  /// Balance as of today according to the accelerated schedule.
  double currentBalance(Loan loan) {
    final projected = projectedLoan(loan);
    final schedule = comparisonFor(loan).accelerated.schedule;
    if (schedule.isEmpty) return projected.principal;
    final now = DateTime.now();
    final elapsed = (now.year - projected.startDate.year) * 12 +
        (now.month - projected.startDate.month) +
        1;
    if (elapsed <= 0) return projected.principal;
    if (elapsed >= schedule.length) return schedule.last.balance;
    return schedule[elapsed - 1].balance;
  }

  double progressPaidDown(Loan loan) => (loan.principal - currentBalance(loan))
      .clamp(0, loan.principal)
      .toDouble();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortIndex = prefs.getInt(_loanSortKey);
      if (sortIndex != null &&
          sortIndex >= 0 &&
          sortIndex < LoanSortOption.values.length) {
        _loanSort = LoanSortOption.values[sortIndex];
      }
      _syncUpdatedAt = DateTime.tryParse(
            prefs.getString(_syncUpdatedAtKey) ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      _syncRev = prefs.getString(_syncRevKey) ?? '0';
      _syncDeviceId = prefs.getString(_syncDeviceIdKey);

      final loansJson = prefs.getString(_loansKey);
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
    if (_accessTokenProvider != null) {
      unawaited(syncNow());
    }
  }

  void configureSync(SyncService syncService) {
    _syncService = syncService;
  }

  void setSyncSession(Future<String?> Function({bool forceRefresh})? tokenProvider) {
    _accessTokenProvider = tokenProvider;
    if (tokenProvider != null && _loaded) {
      unawaited(syncNow());
    }
  }

  Future<void> syncNow() async {
    final syncService = _syncService;
    final tokenProvider = _accessTokenProvider;
    if (syncService == null ||
        tokenProvider == null ||
        !syncService.isConfigured ||
        _syncing) {
      return;
    }

    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final accessToken = await tokenProvider();
      if (accessToken == null) return;
      final remote = await _fetchStateWithRefresh(
        syncService,
        tokenProvider,
        accessToken,
      );
      if (remote == null) {
        if (_loans.isNotEmpty) {
          await _pushSync();
        }
        return;
      }

      if (remote.updatedAt.isAfter(_syncUpdatedAt)) {
        _loans = remote.loans
            .map((e) => Loan.fromJson(e as Map<String, dynamic>))
            .toList();
        _syncUpdatedAt = remote.updatedAt;
        _syncRev = remote.rev;
        _syncDeviceId = remote.deviceId ?? _syncDeviceId;
        _cache.clear();
        await _persist(markDirty: false);
        notifyListeners();
      } else if (_syncUpdatedAt.isAfter(remote.updatedAt)) {
        await _pushSync();
      }
    } catch (e) {
      _syncError = e.toString();
      if (kDebugMode) {
        debugPrint('Sync failed: $e');
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _persist({bool markDirty = true}) async {
    try {
      if (markDirty) {
        _syncUpdatedAt = DateTime.now().toUtc();
        _syncRev = _syncUpdatedAt.microsecondsSinceEpoch.toString();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _loansKey, jsonEncode(_loans.map((l) => l.toJson()).toList()));
      await prefs.setInt(_loanSortKey, _loanSort.index);
      await prefs.setString(_syncUpdatedAtKey, _syncUpdatedAt.toIso8601String());
      await prefs.setString(_syncRevKey, _syncRev);
      await prefs.setString(_syncDeviceIdKey, _deviceId());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist state: $e');
      }
    }
    if (markDirty) {
      unawaited(_pushSync());
    }
  }

  Future<void> _pushSync() async {
    final syncService = _syncService;
    final tokenProvider = _accessTokenProvider;
    if (syncService == null || tokenProvider == null || !syncService.isConfigured) {
      return;
    }
    try {
      final accessToken = await tokenProvider();
      if (accessToken == null) return;
      final response = await _pushStateWithRefresh(
        syncService,
        tokenProvider,
        accessToken,
        SyncDocument(
          loans: _loans.map((l) => l.toJson()).toList(),
          updatedAt: _syncUpdatedAt,
          rev: _syncRev,
          deviceId: _deviceId(),
        ),
      );
      if (response.updatedAt.isAfter(_syncUpdatedAt)) {
        _loans = response.loans
            .map((e) => Loan.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache.clear();
      }
      _syncUpdatedAt = response.updatedAt;
      _syncRev = response.rev;
      _syncDeviceId = response.deviceId ?? _syncDeviceId;
      _syncError = null;
      await _persist(markDirty: false);
      notifyListeners();
    } catch (e) {
      _syncError = e.toString();
      if (kDebugMode) {
      debugPrint('Sync push failed: $e');
      }
    }
  }

  Future<SyncDocument?> _fetchStateWithRefresh(
    SyncService syncService,
    Future<String?> Function({bool forceRefresh}) tokenProvider,
    String accessToken,
  ) async {
    try {
      return await syncService.fetchState(accessToken);
    } on SyncUnauthorizedException {
      final refreshedToken = await tokenProvider(forceRefresh: true);
      if (refreshedToken == null) rethrow;
      return syncService.fetchState(refreshedToken);
    }
  }

  Future<SyncDocument> _pushStateWithRefresh(
    SyncService syncService,
    Future<String?> Function({bool forceRefresh}) tokenProvider,
    String accessToken,
    SyncDocument document,
  ) async {
    try {
      return await syncService.pushState(accessToken, document);
    } on SyncUnauthorizedException {
      final refreshedToken = await tokenProvider(forceRefresh: true);
      if (refreshedToken == null) rethrow;
      return syncService.pushState(refreshedToken, document);
    }
  }

  String _deviceId() {
    return _syncDeviceId ??= DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<void> addLoan(Loan loan) async {
    _loans = [..._loans, loan];
    notifyListeners();
    await _persist();
  }

  Future<void> setLoanSort(LoanSortOption option) async {
    if (_loanSort == option) return;
    _loanSort = option;
    notifyListeners();
    await _persist(markDirty: false);
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

  Future<void> addProgressEntry(String loanId, ProgressEntry entry) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(
      loan.copyWith(progressEntries: [...loan.progressEntries, entry]),
    );
  }

  Future<void> updateProgressEntry(
    String loanId,
    ProgressEntry entry,
  ) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(
      loan.copyWith(
        progressEntries: loan.progressEntries
            .map((x) => x.id == entry.id ? entry : x)
            .toList(),
      ),
    );
  }

  Future<void> removeProgressEntry(String loanId, String entryId) async {
    final loan = loanById(loanId);
    if (loan == null) return;
    await updateLoan(
      loan.copyWith(
        progressEntries:
            loan.progressEntries.where((x) => x.id != entryId).toList(),
      ),
    );
  }
}
