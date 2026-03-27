import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/components/record_widget.dart';
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

    when(() => mockRecordProvider.getCategoryName(2)).thenReturn('Food - Coffee');
  });

  Widget createWidgetUnderTest(Record record) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
          ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
        ],
        child: Scaffold(
          body: RecordWidget(record: record),
        ),
      ),
    );
  }

  testWidgets('RecordWidget displays hierarchical category name from provider', (WidgetTester tester) async {
    final record = Record(
      recordId: 1,
      amount: 50000,
      type: 'expense',
      categoryId: 2,
      categoryName: 'Coffee', // This should be overridden by Provider.getCategoryName
      note: 'Afternoon coffee',
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(createWidgetUnderTest(record));

    // Should display hierarchical name from provider
    expect(find.text('Food - Coffee'), findsOneWidget);
  });
}
