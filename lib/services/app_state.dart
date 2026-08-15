import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mortgage.dart';
import '../models/extra_payment.dart';
import 'amortization_engine.dart';

class AppState extends ChangeNotifier {
  Mortgage? _mortgage;
  List<ExtraPayment> _extras = [];
  bool _loaded = false;

  Mortgage? get mortgage => _mortgage;
  List<ExtraPayment> get extras => List.unmodifiable(_extras);
  bool get loaded => _loaded;
  bool get hasMortgage => _mortgage != null;

  ComparisonResult? _cachedComparison;

  ComparisonResult? get comparison {
    if (_mortgage == null) return null;
    _cachedComparison ??= AmortizationEngine.compare(_mortgage!, _extras);
    return _cachedComparison;
  }

  void _invalidate() {
    _cachedComparison = null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mortgageJson = prefs.getString('mortgage');
      if (mortgageJson != null) {
        _mortgage = Mortgage.fromJson(
            jsonDecode(mortgageJson) as Map<String, dynamic>);
      }
      final extrasJson = prefs.getString('extras');
      if (extrasJson != null) {
        final list = jsonDecode(extrasJson) as List<dynamic>;
        _extras = list
            .map((e) => ExtraPayment.fromJson(e as Map<String, dynamic>))
            .toList();
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
      if (_mortgage != null) {
        await prefs.setString('mortgage', jsonEncode(_mortgage!.toJson()));
      } else {
        await prefs.remove('mortgage');
      }
      await prefs.setString(
          'extras', jsonEncode(_extras.map((e) => e.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist state: $e');
      }
    }
  }

  Future<void> setMortgage(Mortgage m) async {
    _mortgage = m;
    _invalidate();
    notifyListeners();
    await _persist();
  }

  Future<void> clearMortgage() async {
    _mortgage = null;
    _extras = [];
    _invalidate();
    notifyListeners();
    await _persist();
  }

  Future<void> addExtra(ExtraPayment e) async {
    _extras = [..._extras, e];
    _invalidate();
    notifyListeners();
    await _persist();
  }

  Future<void> updateExtra(ExtraPayment e) async {
    _extras = _extras.map((x) => x.id == e.id ? e : x).toList();
    _invalidate();
    notifyListeners();
    await _persist();
  }

  Future<void> removeExtra(String id) async {
    _extras = _extras.where((x) => x.id != id).toList();
    _invalidate();
    notifyListeners();
    await _persist();
  }

  Future<void> toggleExtra(String id, bool enabled) async {
    _extras = _extras
        .map((x) => x.id == id ? x.copyWith(enabled: enabled) : x)
        .toList();
    _invalidate();
    notifyListeners();
    await _persist();
  }
}
