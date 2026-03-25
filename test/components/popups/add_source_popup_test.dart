import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/popups/add_source_popup.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocaleProvider extends Mock implements LocaleProvider {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockLocaleProvider mockLocaleProvider;
  late MockStorageService mockStorageService;

  setUp(() {
    mockLocaleProvider = MockLocaleProvider();
    mockStorageService = MockStorageService();
    
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      if (key == 'add_source_title') return 'Add New Source';
      if (key == 'source_name_label') return 'Source Name';
      if (key == 'initial_amount_label') return 'Initial Amount';
      if (key == 'popup_cancel') return 'Cancel';
      if (key == 'save_button') return 'Save';
      if (key == 'name_required_error') return 'Name is required';
      if (key == 'amount_required_error') return 'Amount is required';
      if (key == 'invalid_amount_error') return 'Invalid amount';
      if (key == 'amount_positive_error') return 'Amount must be positive';
      if (key == 'source_name_hint') return 'e.g. Cash, Bank Account';
      return key;
    });
  });

  Widget createWidgetUnderTest(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('AddSourcePopup renders correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    expect(find.text('Add New Source'), findsOneWidget);
    expect(find.text('Source Name'), findsOneWidget);
    expect(find.text('Initial Amount'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('AddSourcePopup returns MoneySource on save', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    MoneySource? result;
    await tester.pumpWidget(createWidgetUnderTest(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<MoneySource>(
              context: context,
              builder: (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
                ],
                child: const AddSourcePopup(),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Bank');
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.sourceName, 'Bank');
    expect(result!.amount, 1000.0);
  });

  testWidgets('AddSourcePopup returns null on cancel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    MoneySource? result = MoneySource(sourceName: 'dummy', amount: 0);
    await tester.pumpWidget(createWidgetUnderTest(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<MoneySource>(
              context: context,
              builder: (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
                ],
                child: const AddSourcePopup(),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('AddSourcePopup shows error when name is empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    // Enter only amount
    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error when amount is empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    // Enter only name
    await tester.enterText(find.byType(TextField).at(0), 'Cash');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Amount is required'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error when amount is invalid', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    await tester.enterText(find.byType(TextField).at(0), 'Cash');
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Invalid amount'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error when amount is negative', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    await tester.enterText(find.byType(TextField).at(0), 'Cash');
    await tester.enterText(find.byType(TextField).at(1), '-50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Amount must be positive'), findsOneWidget);
  });

  testWidgets('AddSourcePopup clears error when text changes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest(const AddSourcePopup()));

    // Trigger name error
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);

    // Change name
    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.pumpAndSettle();

    // Error should be gone
    expect(find.text('Name is required'), findsNothing);
  });
}
