import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_quotation.dart';

class ArchiveStore extends ChangeNotifier {
  static const _storageKey = 'quotation_archive';
  static const _counterKey = 'quotation_counter';

  final List<SavedQuotation> _quotations;
  int _counter;

  ArchiveStore._(this._quotations, this._counter);

  /// For tests: builds a store in-memory without touching shared_preferences.
  @visibleForTesting
  ArchiveStore.withQuotations(List<SavedQuotation> quotations, {this._counter = 0})
      : _quotations = List.of(quotations);

  /// Newest-first.
  List<SavedQuotation> get quotations {
    final sorted = List<SavedQuotation>.from(_quotations);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  static Future<ArchiveStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final quotations = raw == null
        ? <SavedQuotation>[]
        : (jsonDecode(raw) as List<dynamic>)
            .map((e) => SavedQuotation.fromJson(e as Map<String, dynamic>))
            .toList();
    final counter = prefs.getInt(_counterKey) ?? 0;
    return ArchiveStore._(quotations, counter);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_quotations.map((q) => q.toJson()).toList()));
    await prefs.setInt(_counterKey, _counter);
  }

  /// Reserves and returns the next sequential quota number, e.g. QT-2026-001.
  /// The reservation is only persisted once the quotation is [add]ed.
  String nextQuotaNumber({DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    _counter += 1;
    return 'QT-$year-${_counter.toString().padLeft(3, '0')}';
  }

  Future<void> add(SavedQuotation quotation) async {
    _quotations.add(quotation);
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _quotations.removeWhere((q) => q.id == id);
    notifyListeners();
    await _persist();
  }
}
