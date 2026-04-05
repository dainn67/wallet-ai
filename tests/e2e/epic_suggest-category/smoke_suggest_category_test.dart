// Phase B Smoke Tests — suggest-category epic
// Tier 1: Fast, happy-path checks on the primary feature components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/models/suggested_category.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/components/suggestion_banner.dart';

Record _makeRecord({int categoryId = -1, SuggestedCategory? sc}) => Record(
      recordId: 1,
      amount: 50000,
      description: 'Netflix',
      categoryId: categoryId,
      type: 'expense',
      moneySourceId: 1,
      currency: 'VND',
      suggestedCategory: sc,
    );

void main() {
  group('[Smoke] SuggestedCategory model — happy path', () {
    test('SC-01: fromJson returns populated instance for valid input', () {
      final sc = SuggestedCategory.fromJson({
        'name': 'Streaming',
        'type': 'expense',
        'parent_id': -1,
        'message': 'Want to create a Streaming category?',
      });

      expect(sc, isNotNull);
      expect(sc!.name, 'Streaming');
      expect(sc.type, 'expense');
      expect(sc.parentId, -1);
      expect(sc.message, 'Want to create a Streaming category?');
    });

    test('SC-02: fromJson returns null for malformed input (no name)', () {
      final sc = SuggestedCategory.fromJson({'type': 'expense', 'parent_id': -1, 'message': 'msg'});
      expect(sc, isNull);
    });

    test('SC-03: fromJson returns null for string input (not a map)', () {
      final sc = SuggestedCategory.fromJson('bad-json-string');
      expect(sc, isNull);
    });

    test('SC-04: fromJson returns null for null input', () {
      final sc = SuggestedCategory.fromJson(null);
      expect(sc, isNull);
    });
  });

  group('[Smoke] Record transient field — attach and clear', () {
    test('SC-05: Record.suggestedCategory is attached in memory and excluded from toMap', () {
      final sc = SuggestedCategory.fromJson({
        'name': 'Streaming',
        'type': 'expense',
        'parent_id': -1,
        'message': 'Create Streaming?',
      })!;

      final record = _makeRecord(categoryId: -1, sc: sc);

      expect(record.suggestedCategory, isNotNull);
      expect(record.suggestedCategory!.name, 'Streaming');
      expect(record.toMap().containsKey('suggested_category'), isFalse);
    });

    test('SC-06: copyWith(clearSuggestedCategory: true) sets field to null', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create?',
      );

      final record = _makeRecord(categoryId: -1, sc: sc);
      final cleared = record.copyWith(clearSuggestedCategory: true);

      expect(cleared.suggestedCategory, isNull);
      expect(record.suggestedCategory, isNotNull); // original unchanged
    });

    test('SC-07: Record without suggestedCategory works normally', () {
      final record = _makeRecord(categoryId: 3);

      expect(record.suggestedCategory, isNull);
      expect(record.categoryId, 3);
    });
  });

  group('[Smoke] SuggestionBanner widget rendering', () {
    final sc = SuggestedCategory(
      name: 'Streaming',
      type: 'expense',
      parentId: -1,
      message: 'Want to create a Streaming category?',
    );

    testWidgets('SC-08: Banner renders message and category name', (tester) async {
      final record = _makeRecord(sc: sc);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionBanner(
              record: record,
              messageId: 'msg-1',
              suggestion: sc,
              onConfirm: () async {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Want to create a Streaming category?'), findsOneWidget);
      expect(find.textContaining('Streaming'), findsWidgets);
    });

    testWidgets('SC-09: Banner shows Confirm and Cancel buttons', (tester) async {
      final record = _makeRecord(sc: sc);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionBanner(
              record: record,
              messageId: 'msg-1',
              suggestion: sc,
              onConfirm: () async {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Confirm'), findsOneWidget);
      expect(find.textContaining('Cancel'), findsOneWidget);
    });

    testWidgets('SC-10: Cancel callback fires on tap', (tester) async {
      bool cancelFired = false;
      final record = _makeRecord(sc: sc);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionBanner(
              record: record,
              messageId: 'msg-1',
              suggestion: sc,
              onConfirm: () async {},
              onCancel: () => cancelFired = true,
            ),
          ),
        ),
      );

      await tester.tap(find.textContaining('Cancel'));
      await tester.pump();

      expect(cancelFired, isTrue);
    });
  });
}
