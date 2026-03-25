import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/popups/edit_record_popup.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRecordRepository extends Mock implements RecordRepository {}
class MockStorageService extends Mock implements StorageService {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordRepository mockRepository;
  late RecordProvider recordProvider;
  late MockStorageService mockStorageService;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockRepository = MockRecordRepository();
    recordProvider = RecordProvider(repository: mockRepository);
    mockStorageService = MockStorageService();
    mockLocaleProvider = MockLocaleProvider();
    
    when(() => mockStorageService.getString(any())).thenReturn(null);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      if (key == 'edit_record_title') return 'Edit Record';
      if (key == 'spent_label') return 'Spent';
      if (key == 'save_button') return 'Save';
      if (key == 'popup_cancel') return 'Cancel';
      if (key == 'amount_required_error') return 'Amount is required';
      if (key == 'description_required_error') return 'Description is required';
      if (key == 'invalid_amount_error') return 'Invalid amount';
      if (key == 'amount_positive_error') return 'Amount must be positive';
      return key;
    });
  });

  Widget createPopupWrapper(Record record) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
          ],
          child: EditRecordPopup(record: record),
        ),
      ),
    );
  }

  testWidgets('renders initial values correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final record = Record(
      recordId: 1,
      moneySourceId: 1,
      categoryId: 1,
      categoryName: 'Food',
      sourceName: 'Cash',
      amount: 100.0,
      currency: 'USD',
      description: 'Test description',
      type: 'expense',
    );

    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [
      MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0),
    ]);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 1, name: 'Food', type: 'expense'),
    ]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);

    await recordProvider.loadAll();

    await tester.pumpWidget(createPopupWrapper(record));
    await tester.pumpAndSettle();

    expect(find.text('Edit Record'), findsOneWidget);
    expect(find.text('100.0'), findsOneWidget);
    expect(find.text('Test description'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
  });

  testWidgets('shows error messages for invalid inputs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final record = Record(
      recordId: 1,
      moneySourceId: 1,
      categoryId: 1,
      amount: 100.0,
      currency: 'USD',
      description: 'Test description',
      type: 'expense',
    );

    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [
      MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0),
    ]);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 1, name: 'Food', type: 'expense'),
    ]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    await recordProvider.loadAll();

    await tester.pumpWidget(createPopupWrapper(record));
    await tester.pumpAndSettle();

    // Clear amount and description
    await tester.enterText(find.byType(TextField).at(0), ''); // Amount
    await tester.enterText(find.byType(TextField).at(1), ''); // Description

    // Press Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Amount is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);

    // Invalid amount
    await tester.enterText(find.byType(TextField).at(0), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid amount'), findsOneWidget);

    // Negative amount
    await tester.enterText(find.byType(TextField).at(0), '-10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Amount must be positive'), findsOneWidget);
  });

  testWidgets('returns updated record on Save', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final record = Record(
      recordId: 1,
      moneySourceId: 1,
      categoryId: 1,
      amount: 100.0,
      currency: 'USD',
      description: 'Test description',
      type: 'expense',
    );

    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [
      MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0),
      MoneySource(sourceId: 2, sourceName: 'Bank', amount: 1000.0),
    ]);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 1, name: 'Food', type: 'expense'),
      Category(categoryId: 2, name: 'Salary', type: 'income'),
    ]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    await recordProvider.loadAll();

    Record? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Record>(
                  context: context,
                  builder: (context) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
                      ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
                    ],
                    child: EditRecordPopup(record: record),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Update values
    await tester.enterText(find.byType(TextField).at(0), '150.0'); // Amount
    await tester.enterText(find.byType(TextField).at(1), 'New description'); // Description
    
    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.amount, 150.0);
    expect(result!.description, 'New description');
  });

  testWidgets('returns null on Cancel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final record = Record(
      recordId: 1,
      moneySourceId: 1,
      categoryId: 1,
      amount: 100.0,
      currency: 'USD',
      description: 'Test description',
      type: 'expense',
    );

    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [
      MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0),
    ]);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 1, name: 'Food', type: 'expense'),
    ]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    await recordProvider.loadAll();

    Record? result = record;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Record>(
                  context: context,
                  builder: (context) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
                      ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
                    ],
                    child: EditRecordPopup(record: record),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
