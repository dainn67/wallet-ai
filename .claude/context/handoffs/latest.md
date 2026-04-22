# Handoff: Task #181 — Chat composer mic icon + recording bar
Completed: 2026-04-22T12:44:48Z

## What was done
- Added `bool _isRecording = false;` and `final AudioRecordingService _audioService = AudioRecordingService();` to `_ChatTabState`
- Registered `_audioService.onAutoStopped(_handleAutoStopped)` in `initState`; `_audioService.cancel()` called in `dispose`
- Added mic icon (`Icons.mic_none_outlined`) inside the composer pill, beside the attachment icon; wrapped in `Semantics(label: 'Record voice message')`
- Mic and camera both disabled (`onPressed: null`) when `isStreaming == true` OR `_isRecording == true`
- Replaced the composer row with `AnimatedSwitcher(duration: 200ms)` that swaps to `_RecordingBar` (key `ValueKey('recording')`) when recording, and `_buildComposer` (key `ValueKey('composer')`) otherwise
- Implemented `_onMicTap` with permission rationale dialog + snackbar fallback
- Implemented `_stopAndSend`, `_cancelRecording`, `_handleAutoStopped`
- `_RecordingBar` StatelessWidget: `Icons.close` (cancel left), amplitude-driven `Transform.scale` mic icon, elapsed `StreamBuilder<Duration>` M:SS label, `Icons.stop_circle` (stop-and-send right)
- All `context.read` calls captured before `await` to avoid `use_build_context_synchronously` lint
- Wrote 7 widget tests covering FR-1, FR-2, FR-3 acceptance criteria — all pass

## Files changed
- `lib/screens/home/tabs/chat_tab.dart` — mic icon, recording bar, AnimatedSwitcher, audio lifecycle
- `test/screens/home/tabs/chat_tab_voice_test.dart` — 7 new widget tests (all pass)
- `.claude/epics/voice-input/181.md` — status closed

## Decisions
- AnimatedSwitcher with 200ms swap between composer and recording bar
- Amplitude stream drives `Transform.scale(scale: 0.9 + amplitude * 0.3)`
- Auto-stop handler (`_handleAutoStopped`) receives `Uint8List? bytes` directly from `onAutoStopped` callback
- Permission rationale dialog shown before system prompt on first tap; snackbar if user declines
- `context.read<ChatProvider>()` captured before any `await` in async handlers to avoid build-context lint

## UI hook points (for #185 integration tests)
- Find mic icon via: `find.byIcon(Icons.mic_none_outlined)`
- Recording bar key: `ValueKey('recording')`
- Cancel button: `find.byIcon(Icons.close)` inside recording bar
- Stop-and-send button: `find.byIcon(Icons.stop_circle)` inside recording bar
- Composer key: `ValueKey('composer')`

## Warnings for #185
- `MockAudioRecordingService` in tests overrides `onAutoStopped` to capture callback; call `simulateAutoStop(bytes)` to fire it
- `pumpAndSettle()` needed after tap on mic (async permission + setState)
- The `_RecordingBar` height is fixed at 56px to match composer height — verify no layout jitter on real device
- `hasPermission()` in `AudioRecordingService` internally calls `Permission.microphone.request()` which will always be true in tests using the mock; real device will show system dialog
