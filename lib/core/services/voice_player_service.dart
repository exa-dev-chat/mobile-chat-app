import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'logger_service.dart';

class VoicePlayerService extends GetxService {
  static VoicePlayerService get to => Get.find<VoicePlayerService>();

  late final AudioPlayer _player;
  final activeUrl = ''.obs;
  final isPlaying = false.obs;
  final duration = Duration.zero.obs;
  final position = Duration.zero.obs;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  @override
  void onInit() {
    super.onInit();
    _player = AudioPlayer();

    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      duration.value = dur;
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      position.value = pos;
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      isPlaying.value = false;
      position.value = Duration.zero;
    });
  }

  Future<void> togglePlay(String url) async {
    try {
      if (activeUrl.value == url) {
        if (isPlaying.value) {
          await _player.pause();
        } else {
          if (position.value >= duration.value && duration.value > Duration.zero) {
            await _player.seek(Duration.zero);
          }
          await _player.resume();
        }
      } else {
        await _player.stop();
        activeUrl.value = url;
        position.value = Duration.zero;
        duration.value = Duration.zero;
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      LoggerService.e('Failed to toggle audio playback: $e', tag: 'VoicePlayerService');
      isPlaying.value = false;
    }
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    isPlaying.value = false;
    activeUrl.value = '';
    position.value = Duration.zero;
  }

  String formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}
