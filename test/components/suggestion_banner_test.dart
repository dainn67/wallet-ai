import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/suggestion_banner.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';

void main() {
  final testRecord = Record(
    recordId: 1,
    moneySourceId: 1,
    categoryId: -1,
    amount: 50000,
    currency: 'VND',
    description: 'Netflix',
    type: 'expense',
  );

  final testSuggestion = SuggestedCategory(
    name: 'Streaming',
    type: 'expense',
    parentId: -1,
    message: "I couldn't find a category. Want to create Streaming?",
  );

  Widget buildBanner({
    Future<void> Function()? onConfirm,
    VoidCallback? onCancel,
    SuggestedCategory? suggestion,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SuggestionBanner(
          record: testRecord,
          messageId: 'msg1',
          suggestion: suggestion ?? testSuggestion,
          onConfirm: onConfirm ?? () async {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  group('SuggestionBanner rendering', () {
    testWidgets('renders suggestion message text', (tester) async {
      await tester.pumpWidget(buildBanner());

      expect(find.text("I couldn't find a category. Want to create Streaming?"), findsOneWidget);
    });

    testWidgets('renders suggested category name', (tester) async {
      await tester.pumpWidget(buildBanner());

      expect(find.text('Streaming'), findsOneWidget);
    });

    testWidgets('renders type badge for expense', (tester) async {
      await tester.pumpWidget(buildBanner());

      expect(find.text('expense'), findsOneWidget);
    });

    testWidgets('renders type badge for income suggestion', (tester) async {
      final incomeSuggestion = SuggestedCategory(
        name: 'Freelance',
        type: 'income',
        parentId: -1,
        message: 'Add Freelance income category?',
      );
      await tester.pumpWidget(buildBanner(suggestion: incomeSuggestion));

      expect(find.text('income'), findsOneWidget);
    });

    testWidgets('renders Confirm and Cancel buttons', (tester) async {
      await tester.pumpWidget(buildBanner());

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('SuggestionBanner interactions', () {
    testWidgets('Confirm tap fires onConfirm once', (tester) async {
      int confirmCount = 0;
      await tester.pumpWidget(buildBanner(
        onConfirm: () async {
          confirmCount++;
        },
      ));

      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmCount, 1);
    });

    testWidgets('Cancel tap fires onCancel once', (tester) async {
      int cancelCount = 0;
      await tester.pumpWidget(buildBanner(
        onCancel: () {
          cancelCount++;
        },
      ));

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelCount, 1);
    });

    testWidgets('double-tap Confirm fires onConfirm exactly once (double-tap guard)', (tester) async {
      int confirmCount = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(buildBanner(
        onConfirm: () async {
          confirmCount++;
          await completer.future;
        },
      ));

      // First tap — starts processing
      await tester.tap(find.text('Confirm'));
      await tester.pump(); // triggers setState(_isProcessing = true)

      // Button now shows a progress indicator — tap by button type, which is disabled
      final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      expect(buttons.first.onPressed, isNull); // disabled

      // Complete the future and allow async to resolve
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmCount, 1);
    });

    testWidgets('Confirm button re-enabled after onConfirm throws', (tester) async {
      int confirmCount = 0;

      await tester.pumpWidget(buildBanner(
        onConfirm: () async {
          confirmCount++;
          throw Exception('Network error');
        },
      ));

      await tester.tap(find.text('Confirm'));
      await tester.pump(); // starts processing
      await tester.pump(const Duration(milliseconds: 100)); // processes the throw + setState re-enable

      // After error, button should be re-enabled (shows 'Confirm' text again)
      final confirmButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(confirmButton.onPressed, isNotNull);
      expect(confirmCount, 1);
    });
  });
}
