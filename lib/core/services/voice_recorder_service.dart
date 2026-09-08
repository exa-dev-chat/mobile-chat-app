import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'logger_service.dart';

class VoiceRecorderService extends GetxService {
  late final AudioRecorder _recorder;
  Timer? _durationTimer;

  final isRecording = false.obs;
  final recordDuration = 0.obs;
  String? _currentPath;

  String get formattedDuration {
    final mins = (recordDuration.value ~/ 60).toString().padLeft(2, '0');
    final secs = (recordDuration.value % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void onInit() {
    super.onInit();
    _recorder = AudioRecorder();
  }

  Future<bool> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        LoggerService.w('Microphone permission denied', tag: 'VoiceRecorderService');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      _currentPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      isRecording.value = true;
      recordDuration.value = 0;
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordDuration.value++;
      });

      LoggerService.i('Started voice recording: $_currentPath', tag: 'VoiceRecorderService');
      return true;
    } catch (e) {
      LoggerService.e('Failed to start voice recording: $e', tag: 'VoiceRecorderService');
      isRecording.value = false;
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;
      isRecording.value = false;

      final path = await _recorder.stop();
      final duration = recordDuration.value;
      recordDuration.value = 0;

      if (duration < 1) {
        // Less than 1s, discard
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        return null;
      }

      LoggerService.i('Stopped voice recording: $path ($duration sec)', tag: 'VoiceRecorderService');
      return path ?? _currentPath;
    } catch (e) {
      LoggerService.e('Failed to stop recording: $e', tag: 'VoiceRecorderService');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;
      isRecording.value = false;
      recordDuration.value = 0;

      await _recorder.stop();
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentPath = null;
      LoggerService.i('Cancelled voice recording', tag: 'VoiceRecorderService');
    } catch (e) {
      LoggerService.e('Error cancelling voice recording: $e', tag: 'VoiceRecorderService');
    }
  }

  @override
  void onClose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    super.onClose();
  }
}
