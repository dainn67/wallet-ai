import 'package:flutter/material.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:home_widget/home_widget.dart';
import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:wallet_ai/services/toast_service.dart';

class RecordProvider extends ChangeNotifier {
  final RecordRepository _repository;

  List<Record> _records = [];
  List<MoneySource> _moneySources = [];
  List<Category> _categories = [];
  Map<int, List<Category>> _subCategories = {};

  Map<int, double> _categoryTotals = {};
  bool _isLoading = false;
  int lastDbUpdateVersion = 0;

  // Filter state
  int? _selectedSourceId;
  String? _selectedType;
  DateTimeRange? _selectedDateRange;

  RecordProvider({RecordRepository? repository}) : _repository = repository ?? RecordRepository() {
    // Set initial date range to current month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
    );
  }

  List<Record> get records => List.unmodifiable(_records);
  List<MoneySource> get moneySources => List.unmodifiable(_moneySources);
  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> getSubCategories(int parentId) => _subCategories[parentId] ?? [];
  bool get isLoading => _isLoading;

  String getCategoryName(int id) {
    final category = _categories.firstWhere(
      (c) => c.categoryId == id,
      orElse: () => Category(name: 'Unknown', type: 'expense'),
    );

    if (category.name == 'Unknown') return 'Unknown';

    if (category.parentId != -1) {
      final parent = _categories.firstWhere(
        (c) => c.categoryId == category.parentId,
        orElse: () => Category(name: '', type: 'expense'),
      );
      if (parent.name.isNotEmpty) {
        return '${parent.name} - ${category.name}';
      }
    }

    return category.name;
  }

  double getCategoryTotal(int id) => _categoryTotals[id] ?? 0.0;

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
    _calculateCategoryTotals();
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
        final created = DateTime.fromMillisecondsSinceEpoch(r.lastUpdated);
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

      // Populate _subCategories
      _subCategories = {};
      final subs = _categories.where((c) => c.parentId != -1).toList();
      for (var sub in subs) {
        _subCategories.putIfAbsent(sub.parentId, () => []).add(sub);
      }

      _calculateCategoryTotals();

      print("Log: RecordProvider loaded ${_records.length} records and ${_moneySources.length} sources");
    } catch (e) {
      debugPrint('Error loading data in RecordProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidget();
    }
  }

  void _calculateCategoryTotals() {
    _categoryTotals = {};
    final filtered = filteredRecords;
    
    // 1. Calculate base totals for all categories
    for (var record in filtered) {
      _categoryTotals[record.categoryId] = (_categoryTotals[record.categoryId] ?? 0.0) + record.amount;
    }

    // 2. Aggregate child totals into parents
    // We do this by iterating over parent categories and adding their sub-category totals
    final parents = _categories.where((c) => c.parentId == -1).toList();
    for (var parent in parents) {
      final parentId = parent.categoryId!;
      final subs = getSubCategories(parentId);
      double aggregatedTotal = _categoryTotals[parentId] ?? 0.0;
      for (var sub in subs) {
        aggregatedTotal += _categoryTotals[sub.categoryId!] ?? 0.0;
      }
      _categoryTotals[parentId] = aggregatedTotal;
    }
  }

  Future<void> _performOperation(
    Future<void> Function() operation, {
    bool reloadAll = true,
    bool updateWidget = true,
    bool showToastOnError = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await operation();
      if (reloadAll) await loadAll();
    } catch (e) {
      debugPrint('Error in RecordProvider: $e');
      if (showToastOnError) ToastService().showError(e.toString());
      if (reloadAll) await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
      if (updateWidget) _updateWidget();
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

    HomeWidget.saveWidgetData<String>('total_balance', CurrencyHelper.format(totalBalance));
    HomeWidget.saveWidgetData<String>('total_income', CurrencyHelper.format(totalIncome));
    HomeWidget.saveWidgetData<String>('total_spend', CurrencyHelper.format(totalSpend));
    HomeWidget.saveWidgetData<String>('currency', StorageService().getString(StorageService.keyCurrency) ?? 'USD');
    HomeWidget.updateWidget(androidName: 'MyWidgetReceiver', iOSName: 'Quick_Chat_Widget');
  }

  // Record CRUD
  Future<void> addRecord(Record record) =>
      _performOperation(() => _repository.createRecord(record));

  Future<void> updateRecord(Record record) => _performOperation(() async {
        final updatedRecord = record.copyWith(lastUpdated: DateTime.now().millisecondsSinceEpoch);
        await _repository.updateRecord(updatedRecord);
      });

  Future<void> deleteRecord(int id) =>
      _performOperation(() => _repository.deleteRecord(id));

  // MoneySource CRUD
  Future<void> addMoneySource(MoneySource source) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.createMoneySource(source);
      _moneySources.add(source.copyWith(sourceId: id));
      if (source.amount > 0) await loadAll();
    } catch (e) {
      debugPrint('Error in RecordProvider: $e');
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
      if (index != -1) _moneySources[index] = source;
    } catch (e) {
      debugPrint('Error in RecordProvider: $e');
      await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidget();
    }
  }

  Future<void> deleteMoneySource(int id) => _performOperation(() async {
        _moneySources.removeWhere((ms) => ms.sourceId == id);
        await _repository.deleteMoneySource(id);
      });

  // Category CRUD
  Future<void> addCategory(Category category) => _performOperation(
        () => _repository.createCategory(category),
        showToastOnError: true,
        updateWidget: false,
      );

  Future<void> updateCategory(Category category) => _performOperation(
        () => _repository.updateCategory(category),
        showToastOnError: true,
        updateWidget: false,
      );

  Future<void> deleteCategory(int id) => _performOperation(
        () => _repository.deleteCategory(id),
        showToastOnError: true,
        updateWidget: false,
      );

  /// Lightweight record creation for batch use (e.g., ChatProvider).
  /// Returns the inserted record ID. Does NOT call loadAll() or notifyListeners().
  Future<int> createRecord(Record record) async {
    return await _repository.createRecord(record);
  }

  Future<int> getRecordCountByCategoryId(int id) async {
    return await _repository.getRecordCountByCategoryId(id);
  }

  Future<void> resetAllData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.resetAllData();
    } catch (e) {
      debugPrint('Error resetting all data in RecordProvider: $e');
    } finally {
      await loadAll();
    }
  }
}
