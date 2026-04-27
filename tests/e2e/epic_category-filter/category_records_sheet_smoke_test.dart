// Smoke tests — CategoryRecordsBottomSheet UI
// Covers: FR-1 (popup opens), FR-2 (grouped/flat layout), NTH-1 (empty state)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/models/category.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/components/popups/category_records_bottom_sheet.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class _RecordFake extends Fake implements Record {}

// Helper: milliseconds for a date within March 2026
int _ms(int year, int month, int day) =>
    DateTime(year, month, day, 12).millisecondsSinceEpoch;

final _march2026 = DateTimeRange(
  start: DateTime(2026, 3, 1),
  end: DateTime(2026, 3, 31, 23, 59, 59),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_RecordFake());
  });

  late MockRecordProvider provider;

  setUp(() {
    provider = MockRecordProvider();
    when(() => provider.selectedDateRange).thenReturn(_march2026);
    when(() => provider.updateRecord(any())).thenAnswer((_) async {});
    when(() => provider.getCategoryName(any())).thenReturn('Food');
  });

  Widget buildSheet({
    required Category category,
    required List<int> categoryIds,
    required List<Category> subCategories,
    required List<Record> records,
  }) {
    when(() => provider.getRecordsForCategory(any(), any()))
        .thenReturn(records);

    // Wrap in showModalBottomSheet context so DraggableScrollableSheet lays out correctly
    return MaterialApp(
      home: ChangeNotifierProvider<RecordProvider>.value(
        value: provider,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider<RecordProvider>.value(
                  value: provider,
                  child: CategoryRecordsBottomSheet(
                    category: category,
                    categoryIds: categoryIds,
                    subCategories: subCategories,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester, {
    required Category category,
    required List<int> categoryIds,
    required List<Category> subCategories,
    required List<Record> records,
  }) async {
    await tester.pumpWidget(buildSheet(
      category: category,
      categoryIds: categoryIds,
      subCategories: subCategories,
      records: records,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final parentCategory = Category(
    categoryId: 10,
    name: 'Food',
    type: 'expense',
    parentId: -1,
  );
  final subGroceries = Category(
    categoryId: 11,
    name: 'Groceries',
    type: 'expense',
    parentId: 10,
  );
  final subDining = Category(
    categoryId: 12,
    name: 'Dining',
    type: 'expense',
    parentId: 10,
  );

  final recordParentDirect = Record(
    recordId: 1,
    moneySourceId: 1,
    categoryId: 10,
    amount: 200000,
    currency: 'VND',
    description: 'Misc food',
    type: 'expense',
    occurredAt: _ms(2026, 3, 15),
  );
  final recordGroceries = Record(
    recordId: 2,
    moneySourceId: 1,
    categoryId: 11,
    amount: 150000,
    currency: 'VND',
    description: 'Supermarket',
    type: 'expense',
    occurredAt: _ms(2026, 3, 20),
  );
  final recordDining = Record(
    recordId: 3,
    moneySourceId: 1,
    categoryId: 12,
    amount: 80000,
    currency: 'VND',
    description: 'Restaurant',
    type: 'expense',
    occurredAt: _ms(2026, 3, 10),
  );

  testWidgets('S1: parent tap — sheet shows category name in header', (tester) async {
    await openSheet(tester,
      category: parentCategory,
      categoryIds: [10, 11, 12],
      subCategories: [subGroceries, subDining],
      records: [recordParentDirect, recordGroceries, recordDining],
    );
    expect(find.text('Food'), findsAtLeastNWidgets(1));
  });

  testWidgets('S2: parent tap — shows grouped sections with sub-category names', (tester) async {
    await openSheet(tester,
      category: parentCategory,
      categoryIds: [10, 11, 12],
      subCategories: [subGroceries, subDining],
      records: [recordParentDirect, recordGroceries, recordDining],
    );
    // Verify first visible section
    expect(find.text('Groceries'), findsAtLeastNWidgets(1));
    expect(find.text('Supermarket'), findsOneWidget);

    // Scroll down to reveal Dining section (may be off-screen due to lazy ListView)
    await tester.scrollUntilVisible(find.text('Dining'), 100.0);
    await tester.pump();
    expect(find.text('Dining'), findsAtLeastNWidgets(1));
    expect(find.text('Restaurant'), findsOneWidget);
  });

  testWidgets('S3: sub tap — sheet shows flat list without sub-group labels', (tester) async {
    await openSheet(tester,
      category: subGroceries,
      categoryIds: [11],
      subCategories: const [],
      records: [recordGroceries],
    );
    expect(find.text('Supermarket'), findsOneWidget);
    expect(find.text('Dining'), findsNothing);
  });

  testWidgets('S4 (NTH-1): empty category shows empty-state message', (tester) async {
    await openSheet(tester,
      category: parentCategory,
      categoryIds: [10],
      subCategories: const [],
      records: const [],
    );
    expect(find.textContaining('No records in this category for'), findsOneWidget);
  });

  testWidgets('S5: grouped view shows bordered containers for each sub-group', (tester) async {
    await openSheet(tester,
      category: parentCategory,
      categoryIds: [10, 11, 12],
      subCategories: [subGroceries, subDining],
      records: [recordParentDirect, recordGroceries, recordDining],
    );
    final containers = tester.widgetList<Container>(find.byType(Container));
    final borderedContainers = containers.where((c) {
      final deco = c.decoration;
      return deco is BoxDecoration && deco.border != null;
    }).toList();
    expect(borderedContainers.length, greaterThanOrEqualTo(2));
  });
}
