// Integration Tests — Epic: home-widgets
//
// Verifies that ChatProvider.pickImageFromCamera (added by T004) is publicly
// callable with the contract the widget cold-start path (T003 → T005) relies on.
//
// Why integration instead of unit: this method composes ChatProvider state,
// the ImagePickerService singleton, and the upload/send code path. We don't
// drive the platform camera in this test — we verify the SHAPE of the surface
// area the widget consumes.

// ignore_for_file: invalid_use_of_visible_for_testing_member
// (this file IS a test; it lives under tests/ not test/ which the analyzer
// doesn't auto-recognise.)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/services/services.dart';

class MockChatApiService extends Mock implements ChatApiService {}
class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late ChatProvider chatProvider;

  setUp(() {
    final mockApi = MockChatApiService();
    final mockRecord = MockRecordProvider();
    ChatApiService.setMockInstance(mockApi);
    when(() => mockRecord.categories).thenReturn([]);
    when(() => mockRecord.moneySources).thenReturn([]);
    chatProvider = ChatProvider(recordProvider: mockRecord);
  });

  tearDown(() {
    ChatApiService.setMockInstance(null);
  });

  group('home-widgets epic / ChatProvider.pickImageFromCamera surface', () {
    test('IT-1: method exists with the right signature', () {
      // Compile-time check via tear-off — if T004 ever removes or renames the
      // method, or changes the signature (e.g. makes BuildContext required),
      // this test fails to compile. That's the contract the widget deep-link
      // path (T003 → T005) depends on.
      final Future<void> Function({BuildContext? context}) ref =
          chatProvider.pickImageFromCamera;
      expect(ref, isA<Function>(),
          reason: 'pickImageFromCamera must remain a public method on ChatProvider');
    });

    // NOTE: runtime headless-safety (calling with context: null doesn't throw)
    // is verified manually per the SMOKE_CHECKLIST since invoking the method
    // triggers a platform channel call into image_picker, which requires a
    // running emulator. Mocking the entire ImagePickerService surface to make
    // this a unit test would couple to internals more than it's worth.
  });
}
