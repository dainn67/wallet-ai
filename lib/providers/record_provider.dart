import 'package:flutter/foundation.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class RecordProvider extends ChangeNotifier {
  final RecordRepository _repository;

  List<Record> _records = [];
  List<MoneySource> _moneySources = [];
  bool _isLoading = false;

  RecordProvider({RecordRepository? repository})
      : _repository = repository ?? RecordRepository();

  List<Record> get records => List.unmodifiable(_records);
  List<MoneySource> get moneySources => List.unmodifiable(_moneySources);
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getAllRecords(),
        _repository.getAllMoneySources(),
      ]);

      _records = results[0] as List<Record>;
      _moneySources = results[1] as List<MoneySource>;
    } catch (e) {
      debugPrint('Error loading data in RecordProvider: $e');
      // Keep existing data or clear? Acceptance criteria says "Initialize with empty lists" for edge cases.
      // If it fails, we might want to keep what we have or clear it. 
      // Given "Initial Load" task, clearing or keeping empty is fine.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
