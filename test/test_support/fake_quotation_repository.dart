import 'dart:async';

import 'package:qouta_calculator/features/quotations/domain/quotation_repository.dart';
import 'package:qouta_calculator/models/saved_quotation.dart';

/// In-memory stand-in for FirestoreQuotationRepository — same shape as the
/// old ArchiveStore.withQuotations these tests used to build directly.
/// Shared by test/widget_test.dart and integration_test/app_test.dart.
class FakeQuotationRepository implements QuotationRepository {
  final List<SavedQuotation> _quotations;
  int _counter;
  final _controller = StreamController<List<SavedQuotation>>.broadcast();

  FakeQuotationRepository(List<SavedQuotation> initial, {this._counter = 0})
      : _quotations = List.of(initial);

  List<SavedQuotation> get _newestFirst {
    final sorted = List<SavedQuotation>.from(_quotations);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Synchronous snapshot for test assertions (mirrors the old
  /// ArchiveStore.quotations getter these tests used to read directly).
  List<SavedQuotation> get quotations => _newestFirst;

  @override
  Future<String> reserveNextQuotaNumber() async {
    _counter += 1;
    return 'QT-${DateTime.now().year}-${_counter.toString().padLeft(3, '0')}';
  }

  @override
  Future<void> add(SavedQuotation quotation, {required String createdBy}) async {
    _quotations.add(quotation);
    _controller.add(_newestFirst);
  }

  @override
  Future<bool> quotaNumberExists(String quotaNumber) async {
    return _quotations.any((q) => q.quotaNumber == quotaNumber);
  }

  @override
  Future<void> delete(String id) async {
    _quotations.removeWhere((q) => q.id == id);
    _controller.add(_newestFirst);
  }

  @override
  Stream<List<SavedQuotation>> watchQuotations() async* {
    yield _newestFirst;
    yield* _controller.stream;
  }
}
