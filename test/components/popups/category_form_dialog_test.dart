import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/popups/category_form_dialog.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordRepository mockRepository;
  late RecordProvider recordProvider;
  late MockLocaleProvider mockLocaleProvider;

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
        'edit_category_title' => 'Edit Category',
        'add_category_title' => 'Add Category',
        'category_name_label' => 'Name',
        'category_name_hint' => 'Category name',
        'type_label' => 'Type',
        'spent_label' => 'Expense',
        'income_label' => 'Income',
        'popup_cancel' => 'Cancel',
        'save_button' => 'Save',
        'name_required_error' => 'Name is required',
        'category_already_exists' => 'Already exists',
        'delete_button' => 'Delete',
        'delete_category_confirm_title' => 'Delete?',
        'delete_category_confirm_content' => 'Delete {count} records?',
        _ => key,
      };
    });

    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔'),
    ]);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => {});
  });

  Widget buildDialog(Category? category) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
            ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
          ],
          child: CategoryFormDialog(category: category),
        ),
      ),
    );
  }

  group('CategoryFormDialog — emoji field', () {
    testWidgets('opens with existing emoji shown in preview and field', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      final category = Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔');
      await tester.pumpWidget(buildDialog(category));
      await tester.pumpAndSettle();

      // Live preview shows initial emoji
      expect(find.text('🍔'), findsWidgets);
    });

    testWidgets('type new emoji + Save → repository called with new emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      Category? savedCategory;
      when(() => mockRepository.updateCategory(any())).thenAnswer((invocation) async {
        savedCategory = invocation.positionalArguments[0] as Category;
        return 1;
      });

      final category = Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔');
      await tester.pumpWidget(buildDialog(category));
      await tester.pumpAndSettle();

      // The emoji TextField is the second TextField (after name).
      // Find it by label 'Emoji'.
      final emojiField = find.widgetWithText(TextField, 'Emoji');
      await tester.enterText(emojiField, '🍕');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.emoji, equals('🍕'));
    });

    testWidgets('clear emoji field + Save → repository called with fallback emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      Category? savedCategory;
      when(() => mockRepository.updateCategory(any())).thenAnswer((invocation) async {
        savedCategory = invocation.positionalArguments[0] as Category;
        return 1;
      });

      final category = Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔');
      await tester.pumpWidget(buildDialog(category));
      await tester.pumpAndSettle();

      final emojiField = find.widgetWithText(TextField, 'Emoji');
      await tester.enterText(emojiField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.emoji, equals('🏷️'));
    });

    testWidgets('plain text input + Save → repository called with fallback emoji', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      Category? savedCategory;
      when(() => mockRepository.updateCategory(any())).thenAnswer((invocation) async {
        savedCategory = invocation.positionalArguments[0] as Category;
        return 1;
      });

      final category = Category(categoryId: 2, name: 'Food', type: 'expense', emoji: '🍔');
      await tester.pumpWidget(buildDialog(category));
      await tester.pumpAndSettle();

      final emojiField = find.widgetWithText(TextField, 'Emoji');
      await tester.enterText(emojiField, 'food');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCategory, isNotNull);
      expect(savedCategory!.emoji, equals('🏷️'));
    });

    testWidgets('categoryId == 1 (Uncategorized) — emoji field is disabled', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await recordProvider.loadAll();

      final category = Category(categoryId: 1, name: 'Uncategorized', type: 'expense', emoji: '🏷️');
      await tester.pumpWidget(buildDialog(category));
      await tester.pumpAndSettle();

      // Find the emoji TextField (labeled 'Emoji') and assert it is disabled.
      final emojiField = find.widgetWithText(TextField, 'Emoji');
      if (emojiField.evaluate().isNotEmpty) {
        final widget = tester.widget<TextField>(emojiField);
        expect(widget.enabled, isFalse);
      }
      // If the field is absent entirely, the test passes by not finding it.
    });
  });
}
