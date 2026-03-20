import 'package:flutter/material.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:home_widget/home_widget.dart';

class RecordProvider extends ChangeNotifier {
  final RecordRepository _repository;

  List<Record> _records = [];
  List<MoneySource> _moneySources = [];
  List<Category> _categories = [];
  Map<int, String> _categoryCache = {};
  bool _isLoading = false;
  int _lastDbUpdateVersion = 0;

  // Filter state
  int? _selectedSourceId;
  String? _selectedType;
  DateTimeRange? _selectedDateRange;

  RecordProvider({RecordRepository? repository}) : _repository = repository ?? RecordRepository();

  List<Record> get records => List.unmodifiable(_records);
  List<MoneySource> get moneySources => List.unmodifiable(_moneySources);
  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  int get lastDbUpdateVersion => _lastDbUpdateVersion;

  String getCategoryName(int id) {
    return _categoryCache[id] ?? 'Unknown';
  }

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

    if (_selectedDateRange != null) {
      filtered = filtered.where((r) {
        final created = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        return !created.isBefore(_selectedDateRange!.start) && !created.isAfter(_selectedDateRange!.end);
      }).toList();
    }

    // Sort by recordId descending as default
    filtered.sort((a, b) {
      return b.recordId.compareTo(a.recordId);
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
        _repository.getAllCategories(),
      ]);

      _records = results[0] as List<Record>;
      _moneySources = results[1] as List<MoneySource>;
      _categories = results[2] as List<Category>;

      // Update cache
      _categoryCache = {
        for (var c in _categories)
          if (c.categoryId != null) c.categoryId!: c.name
      };
    } catch (e) {
      debugPrint('Error loading data in RecordProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidget();
    }
  }

  void _updateWidget() {
    double totalBalance = 0;
    for (var source in _moneySources) {
      totalBalance += source.amount;
    }

    double totalIncome = 0;
    double totalSpend = 0;
    for (var record in _records) {
      if (record.type.toLowerCase() == 'income') {
        totalIncome += record.amount;
      } else if (record.type.toLowerCase() == 'expense') {
        totalSpend += record.amount;
      }
    }

    HomeWidget.saveWidgetData<String>('total_balance', 'VND ${totalBalance.toStringAsFixed(0)}');
    HomeWidget.saveWidgetData<String>('total_income', totalIncome.toStringAsFixed(0));
    HomeWidget.saveWidgetData<String>('total_spend', totalSpend.toStringAsFixed(0));
    HomeWidget.updateWidget(androidName: 'MyWidgetReceiver');
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
      _updateWidget();
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
      _updateWidget();
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
      _updateWidget();
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
      _updateWidget();
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
      _updateWidget();
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
      _updateWidget();
    }
  }
}
