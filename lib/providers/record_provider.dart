import 'package:flutter/material.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class RecordProvider extends ChangeNotifier {
  final RecordRepository _repository;

  List<Record> _records = [];
  List<MoneySource> _moneySources = [];
  bool _isLoading = false;

  // Filter state
  int? _selectedSourceId;
  String? _selectedType;
  DateTimeRange? _selectedDateRange;

  RecordProvider({RecordRepository? repository})
      : _repository = repository ?? RecordRepository();

  List<Record> get records => List.unmodifiable(_records);
  List<MoneySource> get moneySources => List.unmodifiable(_moneySources);
  bool get isLoading => _isLoading;

  // Filter getters
  int? get selectedSourceId => _selectedSourceId;
  String? get selectedType => _selectedType;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  // Filter setters
  set selectedSourceId(int? value) {
    _selectedSourceId = value;
    notifyListeners();
  }

  set selectedType(String? value) {
    _selectedType = value;
    notifyListeners();
  }

  set selectedDateRange(DateTimeRange? value) {
    _selectedDateRange = value;
    notifyListeners();
  }

  void clearFilters() {
    _selectedSourceId = null;
    _selectedType = null;
    _selectedDateRange = null;
    notifyListeners();
  }

  List<Record> get filteredRecords {
    List<Record> filtered = List.from(_records);

    if (_selectedSourceId != null) {
      filtered = filtered.where((r) => r.moneySourceId == _selectedSourceId).toList();
    }

    if (_selectedType != null) {
      filtered = filtered.where((r) => r.type.toLowerCase() == _selectedType!.toLowerCase()).toList();
    }

    // Note: Record model currently lacks a date field. 
    // If it's added in the future, apply date range filtering here.
    // For now, we ignore _selectedDateRange as record.date does not exist.

    // Sort by recordId descending as default
    filtered.sort((a, b) {
      final idA = a.recordId ?? 0;
      final idB = b.recordId ?? 0;
      return idB.compareTo(idA);
    });

    return List.unmodifiable(filtered);
  }

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
