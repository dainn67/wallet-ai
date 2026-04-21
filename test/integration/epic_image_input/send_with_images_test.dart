// Integration test: epic/image-input — send path with images
//
// Strategy: mock at the service boundary using setMockInstance (for
// ImagePickerService / ImageProcessingService) and at the provider level using
// mocktail (for ChatProvider). This lets us drive the full ChatTab UI without
// wiring up a real ChatApiService or actual network.
//
// Scenarios covered:
//   A — happy path (2 images + caption)
//   B — oversize image → SnackBar
//   C — images-only (empty caption)
//   D — 5-cap enforcement
//
// Note: end-to-end ChatApiService body assertions are covered in
// test/services/chat_api_service_test.dart. The manual QA checklist
// (.claude/epics/image-input/qa-notes.md) backstops cases impractical here.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/services/image_picker_service.dart';
import 'package:wallet_ai/services/image_processing_service.dart';

// ---------------------------------------------------------------------------
// 1×1 JPEG fixture (same bytes as test/services/image_processing_service_test.dart)
// ---------------------------------------------------------------------------
final Uint8List _smallJpegBytes = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
  0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
  0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
  0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
  0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
  0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
  0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
  0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
  0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
  0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
  0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
  0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
  0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
  0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
  0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
  0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
  0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
  0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
  0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
  0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
  0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
  0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
  0x00, 0x00, 0x3F, 0x00, 0xFB, 0xD5, 0xFF, 0xD9,
]);

// ---------------------------------------------------------------------------
// Mock / fake helpers
// ---------------------------------------------------------------------------

class MockChatProvider extends Mock implements ChatProvider {}

class MockLocaleProvider extends Mock implements LocaleProvider {}

class MockImageProcessingService extends Mock implements ImageProcessingService {}

/// Fake XFile for mocktail fallback registration.
class _FakeXFile extends Fake implements XFile {}

/// Fake ImagePickerService that returns canned files without touching native.
class _FakePickerService extends ImagePickerService {
  final List<XFile> _files;

  _FakePickerService(this._files) : super.forTesting();

  @override
  Future<List<XFile>> pickFromGallery({int maxCount = 5}) async =>
      _files.take(maxCount).toList();

  @override
  Future<XFile?> pickFromCamera() async => null;
}

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrapChatTab(MockChatProvider chatProvider, MockLocaleProvider locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ChatTab()),
    ),
  );
}

void _stubProviderDefaults(MockChatProvider chat, MockLocaleProvider locale) {
  when(() => chat.messages).thenReturn([]);
  when(() => chat.isStreaming).thenReturn(false);
  when(() => chat.suggestedPrompts).thenReturn([]);
  when(() => chat.activePromptIndex).thenReturn(null);
  when(() => chat.showingActions).thenReturn(false);
  when(() => locale.translate(any()))
      .thenAnswer((i) => i.positionalArguments[0] as String);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockChatProvider mockChat;
  late MockLocaleProvider mockLocale;

  setUpAll(() {
    registerFallbackValue(_FakeXFile());
  });

  setUp(() {
    mockChat = MockChatProvider();
    mockLocale = MockLocaleProvider();
    _stubProviderDefaults(mockChat, mockLocale);
  });

  tearDown(() {
    ImagePickerService.setMockInstance(null);
    ImageProcessingService.setMockInstance(null);
  });

  // -------------------------------------------------------------------------
  // Scenario A — happy path: 2 images + caption → sendMessage receives bytes
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario A: 2 images + caption → sendMessage called with 2 imageBytes',
      (tester) async {
    final bytes1 = Uint8List.fromList([..._smallJpegBytes]);
    final bytes2 = Uint8List.fromList([..._smallJpegBytes, 0x00]);

    final file1 =
        XFile.fromData(bytes1, name: 'img1.jpg', mimeType: 'image/jpeg');
    final file2 =
        XFile.fromData(bytes2, name: 'img2.jpg', mimeType: 'image/jpeg');

    ImagePickerService.setMockInstance(_FakePickerService([file1, file2]));

    final mockProcessing = MockImageProcessingService();
    when(() => mockProcessing.processPickedImage(any()))
        .thenAnswer((inv) async {
      final f = inv.positionalArguments[0] as XFile;
      return f.name == 'img1.jpg' ? bytes1 : bytes2;
    });
    ImageProcessingService.setMockInstance(mockProcessing);

    List<Uint8List>? capturedImages;
    String? capturedText;

    when(() => mockChat.sendMessage(any(), imageBytes: any(named: 'imageBytes')))
        .thenAnswer((invocation) async {
      capturedText = invocation.positionalArguments[0] as String;
      capturedImages =
          invocation.namedArguments[#imageBytes] as List<Uint8List>?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    // Open attachment sheet.
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();

    // Tap "Choose from library".
    await tester.tap(find.text('choose_from_library'));
    await tester.pumpAndSettle();

    // Thumbnails should now be visible (Image widgets in preview strip).
    expect(find.byType(Image), findsWidgets);

    // Enter caption and send.
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(); // microtask flush

    expect(capturedText, equals('hello'));
    expect(capturedImages, isNotNull);
    expect(capturedImages!.length, equals(2));

    // After send: text field cleared.
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text ?? '', equals(''));
  });

  // -------------------------------------------------------------------------
  // Scenario B — oversize image → SnackBar shown, strip stays empty
  // -------------------------------------------------------------------------
  testWidgets('Scenario B: oversize image → SnackBar, strip stays empty',
      (tester) async {
    final file = XFile.fromData(_smallJpegBytes,
        name: 'big.jpg', mimeType: 'image/jpeg');
    ImagePickerService.setMockInstance(_FakePickerService([file]));

    final mockProcessing = MockImageProcessingService();
    when(() => mockProcessing.processPickedImage(any())).thenThrow(
        OversizeImageException('big.jpg', 2_000_000));
    ImageProcessingService.setMockInstance(mockProcessing);

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('choose_from_library'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Image too large'), findsOneWidget);

    // No thumbnails in the strip.
    expect(find.byType(Image), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Scenario C — images-only (empty caption) → sendMessage receives images +
  //              empty query string
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario C: images-only send → sendMessage called with empty query',
      (tester) async {
    final bytes = Uint8List.fromList([..._smallJpegBytes]);
    final file =
        XFile.fromData(bytes, name: 'photo.jpg', mimeType: 'image/jpeg');

    ImagePickerService.setMockInstance(_FakePickerService([file]));

    final mockProcessing = MockImageProcessingService();
    when(() => mockProcessing.processPickedImage(any()))
        .thenAnswer((_) async => bytes);
    ImageProcessingService.setMockInstance(mockProcessing);

    List<Uint8List>? capturedImages;
    String? capturedText;

    when(() => mockChat.sendMessage(any(), imageBytes: any(named: 'imageBytes')))
        .thenAnswer((invocation) async {
      capturedText = invocation.positionalArguments[0] as String;
      capturedImages =
          invocation.namedArguments[#imageBytes] as List<Uint8List>?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('choose_from_library'));
    await tester.pumpAndSettle();

    // Leave caption empty, tap send.
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(capturedText, equals(''));
    expect(capturedImages, isNotNull);
    expect(capturedImages!.length, equals(1));
  });

  // -------------------------------------------------------------------------
  // Scenario D — 5-cap: picker offers 7 files, at most 5 reach sendMessage
  // -------------------------------------------------------------------------
  testWidgets('Scenario D: 5-cap enforced — 7 files offered, ≤5 added',
      (tester) async {
    final files = List.generate(
      7,
      (i) => XFile.fromData(
        Uint8List.fromList([..._smallJpegBytes, i]),
        name: 'img_$i.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    ImagePickerService.setMockInstance(_FakePickerService(files));

    final mockProcessing = MockImageProcessingService();
    when(() => mockProcessing.processPickedImage(any()))
        .thenAnswer((inv) async {
      final f = inv.positionalArguments[0] as XFile;
      // Return distinct bytes per file.
      return Uint8List.fromList([
        ..._smallJpegBytes,
        files.indexWhere((x) => x.name == f.name),
      ]);
    });
    ImageProcessingService.setMockInstance(mockProcessing);

    List<Uint8List>? capturedImages;
    when(() => mockChat.sendMessage(any(), imageBytes: any(named: 'imageBytes')))
        .thenAnswer((invocation) async {
      capturedImages =
          invocation.namedArguments[#imageBytes] as List<Uint8List>?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('choose_from_library'));
    await tester.pumpAndSettle();

    // Send.
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(capturedImages, isNotNull);
    expect(capturedImages!.length, lessThanOrEqualTo(5));
  });
}
