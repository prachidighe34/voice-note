import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Wraps the `record` package: handles mic permission, starts/stops
/// recording to a local file, and reports elapsed duration while active.
///
/// Files are saved under the app's documents directory (persists across
/// app restarts, survives being backgrounded) — not a temp/cache dir,
/// since a recording made offline needs to still be there days later
/// when sync finally gets a chance to upload it.
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final _uuid = const Uuid();

  StreamController<Duration>? _elapsedController;
  Timer? _elapsedTimer;
  DateTime? _startedAt;

  Stream<Duration>? get elapsedStream => _elapsedController?.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts recording. Returns the note ID that will also be the filename
  /// (so the audio path and the note's client-generated ID line up,
  /// matching the server's convention of naming files by note ID).
  Future<String> start() async {
    if (!await hasPermission()) {
      throw RecorderPermissionException();
    }

    final noteId = _uuid.v4();
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    final path = '${recordingsDir.path}/$noteId.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _startedAt = DateTime.now();
    _elapsedController = StreamController<Duration>.broadcast();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt != null) {
        _elapsedController?.add(DateTime.now().difference(_startedAt!));
      }
    });

    return noteId;
  }

  /// Stops recording and returns the local file path, or null if nothing
  /// was recorded (e.g. stop() called without a prior start()).
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _startedAt = null;
    await _elapsedController?.close();
    _elapsedController = null;
    return path;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _startedAt = null;
    await _elapsedController?.close();
    _elapsedController = null;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedController?.close();
    _recorder.dispose();
  }
}

class RecorderPermissionException implements Exception {
  @override
  String toString() =>
      'Microphone permission was denied. Enable it in system settings to record.';
}
