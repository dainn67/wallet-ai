import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/categories_tab.dart';
import 'package:wallet_ai/models/models.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockLocaleProvider = MockLocaleProvider();

    // Mock translations
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      return key;
    });

    final parentCategory = Category(categoryId: 1, name: 'Food', type: 'expense', parentId: -1);
    final subCategory = Category(categoryId: 2, name: 'Coffee', type: 'expense', parentId: 1);

    when(() => mockRecordProvider.categories).thenReturn([parentCategory, subCategory]);
    when(() => mockRecordProvider.getSubCategories(1)).thenReturn([subCategory]);
    when(() => mockRecordProvider.isLoading).thenReturn(false);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
          ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
        ],
        child: const Scaffold(body: CategoriesTab()),
      ),
    );
  }

  testWidgets('Expand parent category and see sub-category and add button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Find parent category "Food"
    expect(find.text('Food'), findsOneWidget);
    
    // Tap to expand
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // Sub-category "Coffee" should be visible
    expect(find.text('Coffee'), findsOneWidget);
    
    // "Add Sub-category" button should be visible (using translated text)
    expect(find.text('add_sub_category'), findsOneWidget);
  });

  testWidgets('Click Add Sub-category shows dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('add_sub_category'));
    await tester.pumpAndSettle();

    // Dialog should show
    expect(find.text('add_sub_category_to Food'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
