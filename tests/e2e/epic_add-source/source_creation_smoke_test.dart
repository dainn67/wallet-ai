import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/components/records_overview.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/record_provider.dart';

class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late MockRecordProvider mockProvider;

  setUp(() {
    mockProvider = MockRecordProvider();
    
    // Default stubs
    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.addMoneySource(any())).thenAnswer((_) async => {});
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<RecordProvider>.value(
          value: mockProvider,
          child: const RecordsOverview(
            totalBalance: 1000.0,
            totalIncome: 1500.0,
            totalExpense: 500.0,
            sources: [],
          ),
        ),
      ),
    );
  }

  group('Source Creation Smoke Test', () {
    testWidgets('Smoke: RecordsOverview displays Add button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. Check if "Sources" title is present
      expect(find.text('Sources'), findsOneWidget);

      // 2. Check if the add icon button is present
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('Smoke: Tapping Add button opens AddSourcePopup and saves', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. Tap the add button
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // 2. Verify popup is open
      expect(find.text('Add New Source'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      // 3. Fill in the data
      await tester.enterText(find.byType(TextField).at(0), 'Personal Savings');
      await tester.enterText(find.byType(TextField).at(1), '500.0');
      
      // 4. Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 5. Verify provider was called
      verify(() => mockProvider.addMoneySource(any(
        that: isA<MoneySource>()
            .having((s) => s.sourceName, 'name', 'Personal Savings')
            .having((s) => s.amount, 'amount', 500.0),
      ))).called(1);
      
      // 6. Verify popup is closed
      expect(find.text('Add New Source'), findsNothing);
    });

    testWidgets('Smoke: Tapping Cancel closes the popup without saving', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. Tap the add button
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // 2. Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 3. Verify provider was NOT called
      verifyNever(() => mockProvider.addMoneySource(any()));
      
      // 4. Verify popup is closed
      expect(find.text('Add New Source'), findsNothing);
    });
  });
}
