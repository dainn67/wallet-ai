import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/popups/edit_source_popup.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRecordRepository extends Mock implements RecordRepository {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockRecordRepository mockRepository;
  late RecordProvider recordProvider;
  late MockStorageService mockStorageService;
  late LocaleProvider localeProvider;

  setUp(() {
    mockRepository = MockRecordRepository();
    recordProvider = RecordProvider(repository: mockRepository);
    mockStorageService = MockStorageService();
    when(() => mockStorageService.getString(any())).thenReturn(null);
    localeProvider = LocaleProvider(mockStorageService);
  });

  Widget createPopupWrapper(MoneySource source) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: EditSourcePopup(source: source),
        ),
      ),
    );
  }

  testWidgets('renders initial values correctly', (WidgetTester tester) async {
    final source = MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0);

    await tester.pumpWidget(createPopupWrapper(source));
    await tester.pump();

    // The title is 'Edit' + sourceName now in the localized version
    expect(find.text('Edit Cash'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('tapping delete icon opens confirmation dialog', (WidgetTester tester) async {
    final source = MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0);

    await tester.pumpWidget(createPopupWrapper(source));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmationDialog), findsOneWidget);
    expect(find.text('Delete Source'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to delete this source?'), findsOneWidget);
  });

  testWidgets('confirming delete calls deleteMoneySource and closes popup', (WidgetTester tester) async {
    final source = MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0);
    
    when(() => mockRepository.deleteMoneySource(1)).thenAnswer((_) async => 1);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);

    await tester.pumpWidget(createPopupWrapper(source));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockRepository.deleteMoneySource(1)).called(1);
    expect(find.byType(EditSourcePopup), findsNothing);
  });

  testWidgets('returns updated amount on Save', (WidgetTester tester) async {
    final source = MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0);
    double? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<double>(
                  context: context,
                  builder: (context) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
                      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
                    ],
                    child: EditSourcePopup(source: source),
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

    await tester.enterText(find.byType(TextField), '600.0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 600.0);
  });

  testWidgets('returns null on Cancel', (WidgetTester tester) async {
    final source = MoneySource(sourceId: 1, sourceName: 'Cash', amount: 500.0);
    double? result = 500.0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<double>(
                  context: context,
                  builder: (context) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
                      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
                    ],
                    child: EditSourcePopup(source: source),
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

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
