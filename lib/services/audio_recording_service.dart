import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  static final AudioRecordingService _instance =
      AudioRecordingService._internal();
  static AudioRecordingService? _mockInstance;

  factory AudioRecordingService() => _mockInstance ?? _instance;

  AudioRecordingService._internal();

  /// For subclassing in tests only.
  @visibleForTesting
  AudioRecordingService.forTesting();

  @visibleForTesting
  static void setMockInstance(AudioRecordingService? instance) {
    _mockInstance = instance;
  }

  final AudioRecorder _recorder = AudioRecorder();

  String? _tmpPath;
  bool _recording = false;

  Timer? _autoStopTimer;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  final StreamController<Duration> _elapsedController =
      StreamController<Duration>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  Timer? _amplitudePollTimer;

  void Function(Uint8List? bytes)? _onAutoStopped;

  /// Registers a callback invoked when the 30-second auto-stop fires.
  /// The callback receives the recorded bytes (or null on error).
  void onAutoStopped(void Function(Uint8List? bytes) callback) {
    _onAutoStopped = callback;
  }

  /// Returns true if microphone permission is granted.
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Broadcast stream of elapsed recording duration, ticking every 200 ms.
  Stream<Duration> get elapsedStream => _elapsedController.stream;

  /// Broadcast stream of amplitude normalized to 0..1 from -45..0 dBFS floor.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Starts recording. Throws [StateError] if microphone permission is denied.
  /// No-op (with warning) if already recording.
  Future<void> start() async {
    if (_recording) {
      debugPrint('AudioRecordingService: start() called while already recording — ignoring');
      return;
    }

    final granted = await hasPermission();
    if (!granted) {
      throw StateError('Microphone permission denied');
    }

    final dir = await getTemporaryDirectory();
    _tmpPath =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _tmpPath!,
      );
    } catch (e) {
      _tmpPath = null;
      rethrow;
    }

    _recording = true;
    _elapsed = Duration.zero;

    // Elapsed ticks every 200 ms
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed += const Duration(milliseconds: 200);
      if (!_elapsedController.isClosed) {
        _elapsedController.add(_elapsed);
      }
    });

    // Amplitude polling every 200 ms, normalized from -45..0 dBFS to 0..1
    _amplitudePollTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        const double floor = -45.0;
        final normalized = ((amp.current - floor) / (-floor)).clamp(0.0, 1.0);
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      } catch (_) {}
    });

    // Auto-stop after 30 seconds
    _autoStopTimer = Timer(const Duration(seconds: 30), _handleAutoStop);
  }

  /// Stops recording and returns the audio bytes, or null if not recording.
  Future<Uint8List?> stop() async {
    if (!_recording) return null;

    _cancelTimers();
    _recording = false;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('AudioRecordingService: recorder.stop() failed — $e');
    }

    final path = _tmpPath;
    _tmpPath = null;

    if (path == null) return null;

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      try {
        await file.delete();
      } catch (_) {}
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('AudioRecordingService: failed to read temp file — $e');
      return null;
    }
  }

  /// Cancels recording without returning bytes.
  Future<void> cancel() async {
    if (!_recording) return;

    _cancelTimers();
    _recording = false;

    try {
      await _recorder.stop();
    } catch (_) {}

    final path = _tmpPath;
    _tmpPath = null;

    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  void _cancelTimers() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _amplitudePollTimer?.cancel();
    _amplitudePollTimer = null;
  }

  Future<void> _handleAutoStop() async {
    final bytes = await stop();
    _onAutoStopped?.call(bytes);
  }
}
