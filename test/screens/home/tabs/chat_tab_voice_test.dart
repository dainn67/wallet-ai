import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/services/audio_recording_service.dart';

class MockChatProvider extends Mock implements ChatProvider {}

class MockLocaleProvider extends Mock implements LocaleProvider {}

class MockAudioRecordingService extends AudioRecordingService {
  MockAudioRecordingService() : super.forTesting();

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

  bool permissionResult = true;

  @override
  Future<bool> hasPermission() async => permissionResult;

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

  /// Simulate auto-stop firing from service.
  void simulateAutoStop(Uint8List? bytes) {
    _autoStopCallback?.call(bytes);
  }

  void dispose() {
    _elapsedCtrl.close();
    _ampCtrl.close();
  }
}

void main() {
  late MockChatProvider mockChatProvider;
  late MockLocaleProvider mockLocaleProvider;
  late MockAudioRecordingService mockAudio;

  setUp(() {
    mockChatProvider = MockChatProvider();
    mockLocaleProvider = MockLocaleProvider();
    mockAudio = MockAudioRecordingService();

    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
    when(() => mockChatProvider.suggestedPrompts).thenReturn([]);
    when(() => mockChatProvider.activePromptIndex).thenReturn(null);
    when(() => mockChatProvider.showingActions).thenReturn(false);
    when(() => mockLocaleProvider.translate(any()))
        .thenAnswer((inv) => inv.positionalArguments[0] as String);

    AudioRecordingService.setMockInstance(mockAudio);
  });

  tearDown(() {
    AudioRecordingService.setMockInstance(null);
  });

  Widget buildChatTab() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ChatTab()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Permission denied → info dialog with Open Settings
  // ---------------------------------------------------------------------------

  testWidgets(
      'permission denied: shows info dialog with Open Settings, start() not called',
      (tester) async {
    mockAudio.permissionResult = false;

    await tester.pumpWidget(buildChatTab());

    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    // Info dialog should be visible
    expect(find.text('Microphone Access Required'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Recording should NOT have started
    expect(mockAudio.startCalled, isFalse);
    expect(find.byIcon(Icons.stop_circle), findsNothing);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Microphone Access Required'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // FR-1: Mic icon visibility and semantics
  // ---------------------------------------------------------------------------

  testWidgets('FR-1: mic icon is visible when not streaming and not recording',
      (tester) async {
    await tester.pumpWidget(buildChatTab());
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
  });

  testWidgets('FR-1: mic icon has correct Semantics label', (tester) async {
    await tester.pumpWidget(buildChatTab());
    // Find all Semantics ancestors of the mic icon, check at least one has the label.
    final semanticsWidgets = tester.widgetList<Semantics>(
      find.ancestor(
        of: find.byIcon(Icons.mic_none_outlined),
        matching: find.byType(Semantics),
      ),
    );
    final labels = semanticsWidgets
        .map((s) => s.properties.label)
        .whereType<String>()
        .toList();
    expect(labels, contains('Record voice message'));
  });

  testWidgets('FR-1: mic icon onPressed is null when isStreaming == true',
      (tester) async {
    when(() => mockChatProvider.isStreaming).thenReturn(true);
    await tester.pumpWidget(buildChatTab());

    final micButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.mic_none_outlined),
        matching: find.byType(IconButton),
      ).first,
    );
    expect(micButton.onPressed, isNull);
  });

  // ---------------------------------------------------------------------------
  // FR-2: Tap mic → recording bar appears
  // ---------------------------------------------------------------------------

  testWidgets(
      'FR-2: tapping mic calls AudioRecordingService.start() and shows recording bar',
      (tester) async {
    await tester.pumpWidget(buildChatTab());

    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    expect(mockAudio.startCalled, isTrue);
    // Recording bar should be visible (has the close and send icons)
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // FR-2: Stop-and-send
  // ---------------------------------------------------------------------------

  testWidgets(
      'FR-2: tapping stop (■) calls stop() and sendMessage with audioBytes',
      (tester) async {
    final fakeBytes = Uint8List.fromList([1, 2, 3]);
    mockAudio.stopResult = fakeBytes;

    when(() => mockChatProvider.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(buildChatTab());

    // Start recording
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    // Tap send (stop-and-send)
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(mockAudio.stopCalled, isTrue);
    verify(() => mockChatProvider.sendMessage('', audioBytes: fakeBytes))
        .called(1);

    // Composer should be restored (cancel button gone)
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // FR-3: Cancel
  // ---------------------------------------------------------------------------

  testWidgets(
      'FR-3: tapping cancel (×) calls cancel() and does NOT call sendMessage',
      (tester) async {
    await tester.pumpWidget(buildChatTab());

    // Start recording
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    // Tap cancel
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(mockAudio.cancelCalled, isTrue);
    verifyNever(() => mockChatProvider.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        ));

    // Composer should be restored
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // FR-2: onAutoStopped fires send automatically
  // ---------------------------------------------------------------------------

  testWidgets('FR-2: onAutoStopped callback triggers sendMessage automatically',
      (tester) async {
    final fakeBytes = Uint8List.fromList([9, 8, 7]);

    when(() => mockChatProvider.sendMessage(
          any(),
          audioBytes: any(named: 'audioBytes'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(buildChatTab());

    // Start recording so _isRecording == true
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();

    // Simulate service auto-stop
    mockAudio.simulateAutoStop(fakeBytes);
    await tester.pumpAndSettle();

    verify(() => mockChatProvider.sendMessage('', audioBytes: fakeBytes))
        .called(1);

    // Composer restored (cancel button gone)
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
