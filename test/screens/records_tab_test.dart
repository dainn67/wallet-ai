import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/records_tab.dart';
import 'package:wallet_ai/components/month_divider.dart';
import 'package:wallet_ai/components/record_widget.dart';

class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late MockRecordProvider mockRecordProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
  });

  Widget createRecordsTab() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<RecordProvider>.value(
          value: mockRecordProvider,
          child: const RecordsTab(),
        ),
      ),
    );
  }

  testWidgets('RecordsTab groups records by month', (tester) async {
    // March 2026
    final marchDate = DateTime(2026, 3, 15).millisecondsSinceEpoch;
    // February 2026
    final febDate = DateTime(2026, 2, 10).millisecondsSinceEpoch;

    final records = [
      Record(
        recordId: 1,
        createdAt: marchDate,
        moneySourceId: 1,
        amount: 100,
        currency: 'USD',
        description: 'March Record 1',
        type: 'expense',
      ),
      Record(
        recordId: 2,
        createdAt: marchDate,
        moneySourceId: 1,
        amount: 200,
        currency: 'USD',
        description: 'March Record 2',
        type: 'income',
      ),
      Record(
        recordId: 3,
        createdAt: febDate,
        moneySourceId: 1,
        amount: 300,
        currency: 'USD',
        description: 'February Record 1',
        type: 'expense',
      ),
    ];

    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());

    // Should find two MonthDividers
    expect(find.byType(MonthDivider), findsNWidgets(2));
    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('February 2026'), findsOneWidget);

    // Should find three RecordWidgets
    expect(find.byType(RecordWidget), findsNWidgets(3));
  });

  testWidgets('RecordsTab shows only one divider for single month', (tester) async {
    final marchDate = DateTime(2026, 3, 15).millisecondsSinceEpoch;

    final records = [
      Record(
        recordId: 1,
        createdAt: marchDate,
        moneySourceId: 1,
        amount: 100,
        currency: 'USD',
        description: 'March Record 1',
        type: 'expense',
      ),
    ];

    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());

    expect(find.byType(MonthDivider), findsOneWidget);
    expect(find.text('March 2026'), findsOneWidget);
  });

  testWidgets('Records remain sorted descending within each month', (tester) async {
    final march15 = DateTime(2026, 3, 15).millisecondsSinceEpoch;
    final march10 = DateTime(2026, 3, 10).millisecondsSinceEpoch;

    final records = [
      Record(
        recordId: 2,
        createdAt: march15,
        moneySourceId: 1,
        amount: 200,
        currency: 'USD',
        description: 'March 15',
        type: 'income',
      ),
      Record(
        recordId: 1,
        createdAt: march10,
        moneySourceId: 1,
        amount: 100,
        currency: 'USD',
        description: 'March 10',
        type: 'expense',
      ),
    ];

    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());

    // Check order by finding text
    final march15Finder = find.text('March 15');
    final march10Finder = find.text('March 10');

    expect(tester.getCenter(march15Finder).dy < tester.getCenter(march10Finder).dy, isTrue);
  });
}
