// Integration test: epic/voice-input — mic recording flow
//
// Strategy: mock at service boundaries using setMockInstance:
//   - AudioRecordingService: overridden via forTesting() subclass
//   - ChatApiService: overridden via setMockInstance to control stream output
//   - ImageProcessingService: overridden for Scenario F (image error)
//   - ImagePickerService: overridden for Scenario F
// ChatProvider is mocked (mocktail) for Scenarios B, C, E where we only
// need to verify call presence/absence. Scenarios A and D require real
// ChatProvider to exercise stream parsing + voice-error detection logic;
// however, since ChatProvider._handleStream depends on RecordProvider for
// record persistence (and RecordRepository touches SQLite), Scenarios A and D
// use a MockChatProvider and assert on the sendMessage call instead — the
// end-to-end stream parsing path is already covered by unit tests in
// test/providers/chat_provider_test.dart.
//
// Scenarios covered:
//   A — happy path: mic → stop → sendMessage called with non-null audioBytes
//   B — cancel: mic → cancel → sendMessage NOT called
//   C — auto-stop: simulateAutoStop → sendMessage called automatically
//   D — voice error: mic → stop → sendMessage called (stream parsing in ChatProvider unit tests)
//   E — streaming guard: isStreaming==true → mic onPressed is null
//   F — image error: compress throws → SnackBar with image_load_failed appears

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/services/audio_recording_service.dart';
import 'package:wallet_ai/services/image_picker_service.dart';
import 'package:wallet_ai/services/image_processing_service.dart';

// ---------------------------------------------------------------------------
// Mock / fake classes
// ---------------------------------------------------------------------------

class MockChatProvider extends Mock implements ChatProvider {}

class MockLocaleProvider extends Mock implements LocaleProvider {}

class MockImageProcessingService extends Mock implements ImageProcessingService {}

/// Fake XFile for mocktail fallback registration.
class _FakeXFile extends Fake implements XFile {}

/// Fake picker that immediately returns a list of files without native UI.
class _FakePickerService extends ImagePickerService {
  final List<XFile> _files;

  _FakePickerService(this._files) : super.forTesting();

  @override
  Future<List<XFile>> pickFromGallery({int maxCount = 5}) async =>
      _files.take(maxCount).toList();

  @override
  Future<XFile?> pickFromCamera() async => null;
}

/// Fake AudioRecordingService that never touches the real `record` package.
class _MockAudioService extends AudioRecordingService {
  _MockAudioService() : super.forTesting();

  bool startCalled = false;
  bool stopCalled = false;
  bool cancelCalled = false;

  Uint8List? stopResult;

  final StreamController<Duration> _elapsedCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<double> _ampCtrl =
      StreamController<double>.broadcast();

  void Function(Uint8List? bytes)? _autoStopCallback;

  @override
  Stream<Duration> get elapsedStream => _elapsedCtrl.stream;

  @override
  Stream<double> get amplitudeStream => _ampCtrl.stream;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    startCalled = true;
  }

  @override
  Future<Uint8List?> stop() async {
    stopCalled = true;
    return stopResult;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  @override
  void onAutoStopped(void Function(Uint8List? bytes) callback) {
    _autoStopCallback = callback;
  }

  /// Simulate the 30-second auto-stop firing from the real service timer.
  void simulateAutoStop(Uint8List? bytes) {
    _autoStopCallback?.call(bytes);
  }

  void dispose() {
    _elapsedCtrl.close();
    _ampCtrl.close();
  }
}

// ---------------------------------------------------------------------------
// Small 1×1 JPEG fixture (same bytes used in image-input integration tests).
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
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrapChatTab(MockChatProvider chat, MockLocaleProvider locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ChatTab()),
    ),
  );
}

void _stubDefaults(MockChatProvider chat, MockLocaleProvider locale) {
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
  late _MockAudioService mockAudio;

  setUpAll(() {
    registerFallbackValue(_FakeXFile());
  });

  setUp(() {
    mockChat = MockChatProvider();
    mockLocale = MockLocaleProvider();
    mockAudio = _MockAudioService();
    _stubDefaults(mockChat, mockLocale);
    AudioRecordingService.setMockInstance(mockAudio);
  });

  tearDown(() {
    AudioRecordingService.setMockInstance(null);
    ImagePickerService.setMockInstance(null);
    ImageProcessingService.setMockInstance(null);
    mockAudio.dispose();
  });

  // -------------------------------------------------------------------------
  // Scenario A — happy path: mic → stop → sendMessage called with audioBytes
  //
  // Note: end-to-end stream parsing (ChatProvider receiving the stream,
  // parsing records, rendering RecordWidget) requires a real ChatProvider
  // wired to RecordRepository (SQLite). That path is covered by unit tests
  // in test/providers/. Here we verify the UI layer correctly calls
  // sendMessage with non-null audioBytes after a successful stop().
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario A: mic tap → stop → sendMessage called with non-null audioBytes',
      (tester) async {
    final fakeBytes = Uint8List.fromList([1, 2, 3]);
    mockAudio.stopResult = fakeBytes;

    Uint8List? capturedAudio;
    when(() => mockChat.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        )).thenAnswer((invocation) async {
      capturedAudio =
          invocation.namedArguments[#audioBytes] as Uint8List?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    // Tap mic → verify start() called and recording bar appears.
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    expect(mockAudio.startCalled, isTrue,
        reason: 'start() must be called on mic tap');
    expect(find.byIcon(Icons.stop_circle), findsOneWidget,
        reason: 'recording bar must appear with stop button');

    // Tap stop.
    await tester.tap(find.byIcon(Icons.stop_circle));
    await tester.pumpAndSettle();

    expect(mockAudio.stopCalled, isTrue,
        reason: 'stop() must be called on stop tap');
    expect(capturedAudio, isNotNull,
        reason: 'sendMessage must receive non-null audioBytes');
    expect(capturedAudio, equals(fakeBytes));

    // Composer should be restored (mic icon back, stop gone).
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Scenario B — cancel: mic → cancel → sendMessage NOT called
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario B: mic tap → cancel → cancel() called and sendMessage NOT called',
      (tester) async {
    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    // Tap mic.
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget,
        reason: 'cancel button must appear in recording bar');

    // Tap cancel.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(mockAudio.cancelCalled, isTrue,
        reason: 'cancel() must be called');
    verifyNever(() => mockChat.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        ));

    // Composer restored.
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Scenario C — auto-stop (30 s): simulateAutoStop → sendMessage called
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario C: simulateAutoStop fires → sendMessage called with audioBytes, bar disappears',
      (tester) async {
    final fakeBytes = Uint8List.fromList([1, 2, 3]);

    Uint8List? capturedAudio;
    when(() => mockChat.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        )).thenAnswer((invocation) async {
      capturedAudio =
          invocation.namedArguments[#audioBytes] as Uint8List?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    // Start recording.
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop_circle), findsOneWidget,
        reason: 'recording bar must be visible before auto-stop');

    // Trigger auto-stop directly via mock.
    mockAudio.simulateAutoStop(fakeBytes);
    await tester.pumpAndSettle();

    expect(capturedAudio, isNotNull,
        reason: 'sendMessage must be called after auto-stop');
    expect(capturedAudio, equals(fakeBytes));

    // Recording bar must disappear.
    expect(find.byIcon(Icons.stop_circle), findsNothing);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Scenario D — voice error path
  //
  // The voice-error logic (hadAudio && records.isEmpty → voice_didnt_catch_that)
  // lives inside ChatProvider._handleStream and requires a real ChatProvider
  // wired to ChatApiService + RecordProvider. Full end-to-end testing of that
  // path is done in test/providers/chat_provider_test.dart.
  //
  // Here we verify the UI correctly calls sendMessage with audioBytes when
  // a recording is stopped — the upstream provider layer then decides what
  // message to display. The mock locale translate() falls back to returning
  // the key, so we verify the sendMessage call rather than the final text.
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario D: mic → stop (small bytes) → sendMessage called (voice-error parsing in provider unit tests)',
      (tester) async {
    final fakeBytes = Uint8List.fromList([9, 9, 9]);
    mockAudio.stopResult = fakeBytes;

    Uint8List? capturedAudio;
    when(() => mockChat.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        )).thenAnswer((invocation) async {
      capturedAudio =
          invocation.namedArguments[#audioBytes] as Uint8List?;
    });

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stop_circle));
    await tester.pumpAndSettle();

    expect(capturedAudio, equals(fakeBytes),
        reason:
            'sendMessage must be invoked with the audio bytes; voice-error '
            'detection (empty records + hadAudio → voice_didnt_catch_that) is '
            'exercised in chat_provider_test.dart');
  });

  // -------------------------------------------------------------------------
  // Scenario E — streaming guard: isStreaming == true → mic onPressed is null
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario E: isStreaming == true → mic IconButton.onPressed is null, tap has no effect',
      (tester) async {
    when(() => mockChat.isStreaming).thenReturn(true);

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    final micButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.mic_none_outlined),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(micButton.onPressed, isNull,
        reason: 'mic must be disabled while streaming');

    // Tapping a disabled button should not call start().
    await tester.tap(find.byIcon(Icons.mic_none_outlined),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(mockAudio.startCalled, isFalse,
        reason: 'start() must NOT be called when streaming guard is active');
  });

  // -------------------------------------------------------------------------
  // Scenario F — image error (retroactive FR-5)
  //
  // Mock ImageProcessingService.processPickedImage to throw, then trigger
  // the image pick flow. Verify a SnackBar with the image_load_failed
  // localisation key appears.
  // -------------------------------------------------------------------------
  testWidgets(
      'Scenario F: image processing error → SnackBar with image_load_failed appears',
      (tester) async {
    final file = XFile.fromData(_smallJpegBytes,
        name: 'photo.jpg', mimeType: 'image/jpeg');
    ImagePickerService.setMockInstance(_FakePickerService([file]));

    final mockProcessing = MockImageProcessingService();
    when(() => mockProcessing.processPickedImage(any()))
        .thenThrow(Exception('compress failed'));
    ImageProcessingService.setMockInstance(mockProcessing);

    await tester.pumpWidget(_wrapChatTab(mockChat, mockLocale));

    // Open attachment sheet.
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();

    // Tap "choose_from_library" (translate() returns the key unchanged).
    await tester.tap(find.text('choose_from_library'));
    await tester.pumpAndSettle();

    // A SnackBar with the image_load_failed key should be visible.
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'SnackBar must appear when image processing throws');
    expect(find.textContaining('image_load_failed'), findsOneWidget,
        reason: 'SnackBar must contain the image_load_failed localisation key');
  });
}
