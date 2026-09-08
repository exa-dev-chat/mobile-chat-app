import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/voice_player_service.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceNotePlayer extends StatelessWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final playerService = Get.isRegistered<VoicePlayerService>()
        ? Get.find<VoicePlayerService>()
        : Get.put(VoicePlayerService());

    return Obx(() {
      final isCurrent = playerService.activeUrl.value == audioUrl;
      final isPlaying = isCurrent && playerService.isPlaying.value;
      final currentDuration = isCurrent ? playerService.duration.value : Duration.zero;
      final currentPosition = isCurrent ? playerService.position.value : Duration.zero;

      final totalSecs = currentDuration.inSeconds > 0 ? currentDuration.inSeconds.toDouble() : 1.0;
      final currentSecs = currentPosition.inSeconds.toDouble().clamp(0.0, totalSecs);

      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause Button
            GestureDetector(
              onTap: () => playerService.togglePlay(audioUrl),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isMe ? AppColors.primary : Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Progress Bar & Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      trackHeight: 3,
                      activeTrackColor: isMe ? Colors.white : AppColors.primaryLight,
                      inactiveTrackColor: isMe
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppColors.borderLight,
                      thumbColor: isMe ? Colors.white : AppColors.accent,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: currentSecs,
                      min: 0.0,
                      max: totalSecs,
                      onChanged: (val) {
                        if (isCurrent) {
                          playerService.seek(Duration(seconds: val.toInt()));
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          playerService.formatDuration(currentPosition),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textMuted,
                          ),
                        ),
                        Text(
                          playerService.formatDuration(currentDuration),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
