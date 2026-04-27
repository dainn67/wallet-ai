import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'package:wallet_ai/helpers/currency_helper.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
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
    _selectedDateRange = DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999));
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

  /// Returns records whose [categoryId] is in [categoryIds], filtered to [range]
  /// (falls back to [_selectedDateRange] when null). Sorted occurredAt DESC.
  /// Pure in-memory read — no DB query, no notifyListeners.
  List<Record> getRecordsForCategory(List<int> categoryIds, DateTimeRange? range) {
    final r = range ?? _selectedDateRange;
    return _records.where((rec) {
      if (!categoryIds.contains(rec.categoryId)) return false;
      if (r == null) return true;
      final occurred = DateTime.fromMillisecondsSinceEpoch(rec.occurredAt);
      return !occurred.isBefore(r.start) && !occurred.isAfter(r.end);
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
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
        final occurred = DateTime.fromMillisecondsSinceEpoch(r.occurredAt);
        return !occurred.isBefore(_selectedDateRange!.start) && !occurred.isAfter(_selectedDateRange!.end);
      }).toList();
    }

    // Sort by occurredAt descending so position is stable after edits
    filtered.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return List.unmodifiable(filtered);
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([_repository.getAllRecords(), _repository.getAllMoneySources(), _repository.getAllCategories()]);

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

  // Computed getters
  double get filteredTotalIncome => filteredRecords.where((r) => r.type == 'income').fold<double>(0, (sum, r) => sum + r.amount);

  double get filteredTotalExpense => filteredRecords.where((r) => r.type == 'expense').fold<double>(0, (sum, r) => sum + r.amount);

  double get totalBalance => _moneySources.fold<double>(0, (sum, s) => sum + s.amount);

  void navigateMonth(int delta) {
    final current = _selectedDateRange?.start ?? DateTime.now();
    final newMonth = DateTime(current.year, current.month + delta);
    selectedDateRange = DateTimeRange(start: newMonth, end: DateTime(newMonth.year, newMonth.month + 1, 0, 23, 59, 59, 999));
  }

  Future<void> _performOperation(Future<void> Function() operation, {bool reloadAll = true, bool updateWidget = true, bool showToastOnError = false}) async {
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
      if (updateWidget && !reloadAll) _updateWidget();
    }
  }

  void _updateWidget() {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    // Calculate income and expense for the CURRENT month only, 
    // regardless of the provider's filter selection.
    final currentMonthStart = DateTime(now.year, now.month);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final currentMonthRecords = _records.where((r) {
      final occurred = DateTime.fromMillisecondsSinceEpoch(r.occurredAt);
      return !occurred.isBefore(currentMonthStart) && !occurred.isAfter(currentMonthEnd);
    });

    final currentMonthIncome = currentMonthRecords
        .where((r) => r.type == 'income')
        .fold<double>(0, (sum, r) => sum + r.amount);

    final currentMonthSpend = currentMonthRecords
        .where((r) => r.type == 'expense')
        .fold<double>(0, (sum, r) => sum + r.amount);

    HomeWidget.saveWidgetData<String>('total_balance', CurrencyHelper.format(totalBalance));
    HomeWidget.saveWidgetData<String>('total_income', CurrencyHelper.format(currentMonthIncome));
    HomeWidget.saveWidgetData<String>('total_spend', CurrencyHelper.format(currentMonthSpend));
    HomeWidget.saveWidgetData<String>('currency', StorageService().getString(StorageService.keyCurrency) ?? 'USD');
    HomeWidget.saveWidgetData<String>('current_month', monthLabel);
    HomeWidget.updateWidget(androidName: 'MyWidgetReceiver', iOSName: 'Quick_Chat_Widget');
  }

  // Record CRUD
  Future<void> addRecord(Record record) => _performOperation(() => _repository.createRecord(record));

  Future<void> updateRecord(Record record) => _performOperation(() async {
    final updatedRecord = record.copyWith(lastUpdated: DateTime.now().millisecondsSinceEpoch);
    await _repository.updateRecord(updatedRecord);
  });

  Future<void> deleteRecord(int id) => _performOperation(() => _repository.deleteRecord(id));

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
  Future<void> addCategory(Category category) => _performOperation(() => _repository.createCategory(category), showToastOnError: true, updateWidget: false);

  /// Finds an existing category by name (case-insensitive) + parentId, or creates it.
  /// Returns the categoryId in both cases, or null if creation fails.
  Future<int?> resolveCategoryByNameOrCreate(String name, String type, int parentId) async {
    final trimmedName = name.trim();

    // 1. Search in-memory cache (case-insensitive)
    final existing = _categories.firstWhereOrNull(
      (c) =>
          c.name.toLowerCase().trim() == trimmedName.toLowerCase() &&
          c.parentId == parentId,
    );
    if (existing != null) return existing.categoryId;

    // 2. Validate parentId — fall back to top-level if not found
    int resolvedParentId = parentId;
    if (parentId != -1) {
      final parentExists = _categories.any((c) => c.categoryId == parentId);
      if (!parentExists) {
        debugPrint('[SuggestCategory] parent_id $parentId not found locally — falling back to top-level');
        resolvedParentId = -1;
      }
    }

    // 3. Create and return new id
    try {
      final newId = await _repository.createCategory(
        Category(name: trimmedName, type: type, parentId: resolvedParentId),
      );
      // Refresh categories cache
      _categories = await _repository.getAllCategories();
      _subCategories = {};
      final subs = _categories.where((c) => c.parentId != -1).toList();
      for (var sub in subs) {
        _subCategories.putIfAbsent(sub.parentId, () => []).add(sub);
      }
      notifyListeners();
      return newId;
    } catch (e) {
      ToastService().showError('Failed to create category');
      return null;
    }
  }

  Future<void> updateCategory(Category category) => _performOperation(() => _repository.updateCategory(category), showToastOnError: true, updateWidget: false);

  Future<void> deleteCategory(int id) => _performOperation(() => _repository.deleteCategory(id), showToastOnError: true, updateWidget: false);

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
      final storage = StorageService();
      await storage.remove(StorageService.keyUserPattern);
      await storage.remove(StorageService.keyLastPatternUpdateTime);
    } catch (e) {
      debugPrint('Error resetting all data in RecordProvider: $e');
    } finally {
      await loadAll();
    }
  }
}
