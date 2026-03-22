import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/popups/add_source_popup.dart';
import 'package:wallet_ai/models/models.dart';

void main() {
  testWidgets('AddSourcePopup displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Check title
    expect(find.text('Add New Source'), findsOneWidget);

    // Check input field labels (using text widgets for labels)
    expect(find.text('Source Name'), findsOneWidget);
    expect(find.text('Initial Amount'), findsOneWidget);
    
    // Check TextFields (should be 2)
    expect(find.byType(TextField), findsNWidgets(2));

    // Check buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('AddSourcePopup returns data when Save is pressed', (WidgetTester tester) async {
    MoneySource? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<MoneySource>(
                    context: context,
                    builder: (context) => const AddSourcePopup(),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open the popup
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Fill the fields
    // First TextField is Source Name
    await tester.enterText(find.byType(TextField).at(0), 'Bank Account');
    // Second TextField is Initial Amount
    await tester.enterText(find.byType(TextField).at(1), '1000');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, isNotNull);
    expect(result!.sourceName, 'Bank Account');
    expect(result!.amount, 1000.0);
  });

  testWidgets('AddSourcePopup returns null when Cancel is pressed', (WidgetTester tester) async {
    bool resultCalled = false;
    MoneySource? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<MoneySource>(
                    context: context,
                    builder: (context) => const AddSourcePopup(),
                  );
                  resultCalled = true;
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open the popup
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify result
    expect(resultCalled, isTrue);
    expect(result, isNull);
  });

  testWidgets('AddSourcePopup shows error for empty name', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Leave name empty, fill amount
    await tester.enterText(find.byType(TextField).at(1), '100');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Verify error message
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error for empty amount', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Fill name, leave amount empty
    await tester.enterText(find.byType(TextField).at(0), 'Cash');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Verify error message
    expect(find.text('Amount is required'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error for invalid amount', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Fill name, fill invalid amount
    await tester.enterText(find.byType(TextField).at(0), 'Cash');
    await tester.enterText(find.byType(TextField).at(1), 'abc');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Verify error message
    expect(find.text('Invalid amount'), findsOneWidget);
  });

  testWidgets('AddSourcePopup shows error for negative amount', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Fill name, fill negative amount
    await tester.enterText(find.byType(TextField).at(0), 'Cash');
    await tester.enterText(find.byType(TextField).at(1), '-50');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Verify error message
    expect(find.text('Amount must be positive'), findsOneWidget);
  });

  testWidgets('AddSourcePopup clears error when text changes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddSourcePopup(),
        ),
      ),
    );

    // Trigger name error
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);

    // Change name
    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.pump();

    // Error should be gone
    expect(find.text('Name is required'), findsNothing);
  });
}
