import 'package:flutter/material.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class RecordProvider extends ChangeNotifier {
  final RecordRepository _repository;

  List<Record> _records = [];
  List<MoneySource> _moneySources = [];
  bool _isLoading = false;
  int _lastDbUpdateVersion = 0;

  // Filter state
  int? _selectedSourceId;
  String? _selectedType;
  DateTimeRange? _selectedDateRange;

  RecordProvider({RecordRepository? repository}) : _repository = repository ?? RecordRepository();

  List<Record> get records => List.unmodifiable(_records);
  List<MoneySource> get moneySources => List.unmodifiable(_moneySources);
  bool get isLoading => _isLoading;
  int get lastDbUpdateVersion => _lastDbUpdateVersion;

  set lastDbUpdateVersion(int value) {
    _lastDbUpdateVersion = value;
  }

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
      final results = await Future.wait([_repository.getAllRecords(), _repository.getAllMoneySources()]);

      _records = results[0] as List<Record>;
      _moneySources = results[1] as List<MoneySource>;
    } catch (e) {
      debugPrint('Error loading data in RecordProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Record CRUD
  Future<void> addRecord(Record record) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.createRecord(record);
      _records.add(record.copyWith(recordId: id));
    } catch (e) {
      debugPrint('Error adding record in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRecord(Record record) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.updateRecord(record);
      final index = _records.indexWhere((r) => r.recordId == record.recordId);
      if (index != -1) {
        _records[index] = record;
      }
    } catch (e) {
      debugPrint('Error updating record in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRecord(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.deleteRecord(id);
      _records.removeWhere((r) => r.recordId == id);
    } catch (e) {
      debugPrint('Error deleting record in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // MoneySource CRUD
  Future<void> addMoneySource(MoneySource source) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.createMoneySource(source);
      _moneySources.add(source.copyWith(sourceId: id));
    } catch (e) {
      debugPrint('Error adding money source in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMoneySource(MoneySource source) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.updateMoneySource(source);
      final index = _moneySources.indexWhere((ms) => ms.sourceId == source.sourceId);
      if (index != -1) {
        _moneySources[index] = source;
      }
    } catch (e) {
      debugPrint('Error updating money source in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMoneySource(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.deleteMoneySource(id);
      _moneySources.removeWhere((ms) => ms.sourceId == id);
    } catch (e) {
      debugPrint('Error deleting money source in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
