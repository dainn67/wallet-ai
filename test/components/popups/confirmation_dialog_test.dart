import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';

void main() {
  group('ConfirmationDialog', () {
    testWidgets('renders title and content correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationDialog(
              title: 'Test Title',
              content: 'Test Content',
              confirmLabel: 'Confirm',
              cancelLabel: 'Cancel',
              onConfirm: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('onConfirm is called and dialog is popped when confirm button is tapped', (WidgetTester tester) async {
      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ConfirmationDialog(
                      title: 'Test Title',
                      content: 'Test Content',
                      confirmLabel: 'Confirm',
                      cancelLabel: 'Cancel',
                      onConfirm: () {
                        confirmed = true;
                      },
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            }),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('onConfirm is NOT called and dialog is popped when cancel button is tapped', (WidgetTester tester) async {
      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ConfirmationDialog(
                      title: 'Test Title',
                      content: 'Test Content',
                      confirmLabel: 'Confirm',
                      cancelLabel: 'Cancel',
                      onConfirm: () {
                        confirmed = true;
                      },
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            }),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse);
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('uses red background for destructive confirm button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationDialog(
              title: 'Test Title',
              content: 'Test Content',
              confirmLabel: 'Confirm',
              cancelLabel: 'Cancel',
              onConfirm: () {},
              isDestructive: true,
            ),
          ),
        ),
      );

      final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
      final Color? color = button.style?.backgroundColor?.resolve({});
      expect(color, Colors.red.shade600);
    });
  });
}
