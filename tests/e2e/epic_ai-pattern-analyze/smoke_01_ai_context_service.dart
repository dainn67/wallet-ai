// Smoke Test 01: AiContextService basic contract verification
// Verifies that AiContextService exists, returns a singleton, and produces
// a valid snapshot structure that can be jsonEncoded.
// Uses mock RecordRepository — no real database required.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/ai_context_service.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepo;

  setUp(() async {
    mockRepo = MockRecordRepository();
    RecordRepository.setMockInstance(mockRepo);
    SharedPreferences.setMockInitialValues({
      'user_language': 'en',
      'user_currency': 'VND',
    });
    await StorageService.init();
  });

  tearDown(() {
    RecordRepository.setMockInstance(null);
  });

  final baseRecord = Record(
    recordId: 1,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    moneySourceId: 1,
    categoryId: 2,
    categoryName: 'Food - Dining Out',
    sourceName: 'Wallet',
    amount: 45000,
    currency: 'VND',
    description: 'Phở bò',
    type: 'expense',
  );

  group('Smoke: Singleton (FR-1)', () {
    test('AiContextService() returns the same singleton instance', () {
      final a = AiContextService();
      final b = AiContextService();
      expect(identical(a, b), isTrue,
          reason: 'Factory must return same singleton instance');
    });
  });

  group('Smoke: Snapshot structure (FR-1, FR-6, FR-7)', () {
    setUp(() {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [baseRecord]);
    });

    test('daily snapshot has required top-level keys', () async {
      final snapshot = await AiContextService().getAiContext();
      expect(snapshot.containsKey('client_metadata'), isTrue);
      expect(snapshot.containsKey('records'), isTrue);
      expect(snapshot.containsKey('summary'), isTrue);
    });

    test('initial snapshot has required top-level keys', () async {
      final snapshot = await AiContextService().getAiContext(isInitial: true);
      expect(snapshot.containsKey('client_metadata'), isTrue);
      expect(snapshot.containsKey('records'), isTrue);
      expect(snapshot.containsKey('summary'), isTrue);
    });

    test('records is a List', () async {
      final snapshot = await AiContextService().getAiContext();
      expect(snapshot['records'], isA<List>());
    });

    test('summary has all required keys (FR-6)', () async {
      final snapshot = await AiContextService().getAiContext();
      final summary = snapshot['summary'] as Map<String, dynamic>;
      for (final key in ['period_days', 'total_income', 'total_expense', 'by_category', 'by_time_of_day', 'by_money_source']) {
        expect(summary.containsKey(key), isTrue,
            reason: 'summary must contain key: $key');
      }
    });

    test('client_metadata has all required keys (FR-7)', () async {
      final snapshot = await AiContextService().getAiContext();
      final meta = snapshot['client_metadata'] as Map<String, dynamic>;
      for (final key in ['sync_type', 'current_time', 'timezone', 'language', 'currency']) {
        expect(meta.containsKey(key), isTrue,
            reason: 'client_metadata must contain key: $key');
      }
    });

    test('daily sync_type is "daily" (FR-7)', () async {
      final snapshot = await AiContextService().getAiContext();
      expect((snapshot['client_metadata'] as Map)['sync_type'], equals('daily'));
    });

    test('initial sync_type is "initial" (FR-7)', () async {
      final snapshot = await AiContextService().getAiContext(isInitial: true);
      expect((snapshot['client_metadata'] as Map)['sync_type'], equals('initial'));
    });
  });

  group('Smoke: JSON serializable (NFR-3)', () {
    setUp(() {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [baseRecord]);
    });

    test('daily snapshot can be jsonEncoded without error', () async {
      final snapshot = await AiContextService().getAiContext();
      expect(() => jsonEncode(snapshot), returnsNormally);
    });

    test('initial snapshot can be jsonEncoded without error', () async {
      final snapshot = await AiContextService().getAiContext(isInitial: true);
      expect(() => jsonEncode(snapshot), returnsNormally);
    });
  });

  group('Smoke: NFR-2 — zero UI dependency', () {
    test('ai_context_service.dart contains no BuildContext or Widget imports', () {
      final file = File('lib/services/ai_context_service.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/services/ai_context_service.dart must exist');
      final content = file.readAsStringSync();
      expect(content.contains('BuildContext'), isFalse,
          reason: 'AiContextService must not use BuildContext');
      expect(content.contains("package:flutter/material.dart"), isFalse,
          reason: 'AiContextService must not import flutter/material');
      expect(content.contains("package:flutter/widgets.dart"), isFalse,
          reason: 'AiContextService must not import flutter/widgets');
    });

    test('ai_context_service.dart is exported from services barrel', () {
      final barrel = File('lib/services/services.dart');
      expect(barrel.existsSync(), isTrue);
      expect(barrel.readAsStringSync().contains("ai_context_service.dart"), isTrue,
          reason: 'services.dart must export ai_context_service.dart');
    });
  });
}
