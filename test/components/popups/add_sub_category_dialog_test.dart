import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/popups/add_sub_category_dialog.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordRepository mockRepository;
  late RecordProvider recordProvider;
  late MockLocaleProvider mockLocaleProvider;

  final parentCategory = Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔');

  setUpAll(() {
    registerFallbackValue(Category(name: 'fallback', type: 'expense'));
  });

  setUp(() {
    mockRepository = MockRecordRepository();
    recordProvider = RecordProvider(repository: mockRepository);
    mockLocaleProvider = MockLocaleProvider();

    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      return switch (key) {
        'add_sub_category' => 'Add Sub Category',
        'category_name_hint' => 'Category name',
        'popup_cancel' => 'Cancel',
        'save_button' => 'Save',
        _ => key,
      };
    });

    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [parentCategory]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => {});
  });

  Widget buildDialogLauncher() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAddSubCategoryDialog(context: context, parent: parentCategory),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  group('AddSubCategoryDialog — emoji field', () {
    testWidgets('dialog shows emoji field with default value', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();
      await tester.pumpWidget(buildDialogLauncher());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Sub Category'), findsOneWidget);
      // Emoji field should be present
      expect(find.widgetWithText(TextField, 'Emoji'), findsOneWidget);
    });

    testWidgets('opens → initial preview shows default emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();
      await tester.pumpWidget(buildDialogLauncher());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Default preview emoji should be visible
      expect(find.text('🏷️'), findsWidgets);
    });

    testWidgets('type new emoji + Save → repository called with new emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      Category? savedCategory;
      when(() => mockRepository.createCategory(any())).thenAnswer((invocation) async {
        savedCategory = invocation.positionalArguments[0] as Category;
        return 1;
      });

      await tester.pumpWidget(buildDialogLauncher());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter sub-category name
      await tester.enterText(find.byType(TextField).first, 'Fast Food');
      // Enter emoji
      final emojiField = find.widgetWithText(TextField, 'Emoji');
      await tester.enterText(emojiField, '🌮');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.emoji, equals('🌮'));
    });

    testWidgets('clear emoji field + Save → repository called with fallback emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      Category? savedCategory;
      when(() => mockRepository.createCategory(any())).thenAnswer((invocation) async {
        savedCategory = invocation.positionalArguments[0] as Category;
        return 1;
      });

      await tester.pumpWidget(buildDialogLauncher());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Sushi');
      final emojiField = find.widgetWithText(TextField, 'Emoji');
      await tester.enterText(emojiField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.emoji, equals('🏷️'));
    });
  });
}
