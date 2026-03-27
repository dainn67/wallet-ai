import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/records_tab.dart';
import 'package:wallet_ai/configs/configs.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockLocaleProvider = MockLocaleProvider();

    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.getCategoryName(any())).thenReturn('Test Category');
    when(() => mockRecordProvider.isLoading).thenReturn(false);
    
    when(() => mockLocaleProvider.language).thenReturn(AppLanguage.english);
    when(() => mockLocaleProvider.currency).thenReturn(AppCurrency.usd);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      if (key == 'no_records') return 'No records yet';
      if (key == 'no_records_subtitle') return 'Your income and expense records will appear here.';
      if (key == 'drawer_records') return 'Records';
      if (key == 'recent_records') return 'Recent Records';
      return key;
    });
  });

  Widget createRecordsTab() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: RecordsTab(),
        ),
      ),
    );
  }

  testWidgets('RecordsTab displays empty state when no records', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createRecordsTab());

    expect(find.text('No records yet'), findsOneWidget);
    expect(find.text('Your income and expense records will appear here.'), findsOneWidget);
  });

  testWidgets('RecordsTab displays records list', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final records = [
      Record(
        recordId: 1,
        moneySourceId: 1,
        categoryId: 1,
        categoryName: 'Food',
        sourceName: 'Cash',
        amount: 100.0,
        currency: 'USD',
        description: 'Coffee',
        type: 'expense',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ),
    ];

    when(() => mockRecordProvider.records).thenReturn(records);
    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());

    expect(find.textContaining('100'), findsWidgets);
    expect(find.textContaining('100').last, findsOneWidget);
  });

  testWidgets('RecordsTab shows only one divider for single month', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final date = DateTime(2024, 3, 15);
    final records = [
      Record(
        recordId: 1,
        moneySourceId: 1,
        categoryId: 1,
        categoryName: 'Food',
        sourceName: 'Cash',
        amount: 50.0,
        currency: 'USD',
        description: 'Lunch',
        type: 'expense',
        lastUpdated: date.millisecondsSinceEpoch,
      ),
      Record(
        recordId: 2,
        moneySourceId: 1,
        categoryId: 1,
        categoryName: 'Food',
        sourceName: 'Cash',
        amount: 30.0,
        currency: 'USD',
        description: 'Dinner',
        type: 'expense',
        lastUpdated: date.add(const Duration(hours: 5)).millisecondsSinceEpoch,
      ),
    ];

    when(() => mockRecordProvider.records).thenReturn(records);
    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());
    
    expect(find.text('March 2024'), findsOneWidget);
  });

  testWidgets('Records remain sorted descending within each month', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final date = DateTime(2024, 3, 15);
    final records = [
      Record(
        recordId: 2,
        moneySourceId: 1,
        categoryId: 1,
        categoryName: 'Food',
        sourceName: 'Cash',
        amount: 30.0,
        currency: 'USD',
        description: 'Later',
        type: 'expense',
        lastUpdated: date.add(const Duration(hours: 5)).millisecondsSinceEpoch,
      ),
      Record(
        recordId: 1,
        moneySourceId: 1,
        categoryId: 1,
        categoryName: 'Food',
        sourceName: 'Cash',
        amount: 50.0,
        currency: 'USD',
        description: 'Earlier',
        type: 'expense',
        lastUpdated: date.millisecondsSinceEpoch,
      ),
    ];

    when(() => mockRecordProvider.records).thenReturn(records);
    when(() => mockRecordProvider.filteredRecords).thenReturn(records);

    await tester.pumpWidget(createRecordsTab());

    final laterFinder = find.text('Later');
    final earlierFinder = find.text('Earlier');

    expect(tester.getCenter(laterFinder).dy, lessThan(tester.getCenter(earlierFinder).dy));
  });
}
