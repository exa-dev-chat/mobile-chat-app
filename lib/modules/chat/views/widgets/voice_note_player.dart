import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/voice_player_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';

class VoiceNotePlayer extends GetView<VoicePlayerService> {
  final String audioUrl;
  final bool isMe;

  const VoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  // Deterministically generate a realistic waveform based on audioUrl hash
  List<double> _generateWaveform(String url, int count) {
    final random = Random(url.hashCode.abs());
    return List.generate(count, (index) {
      // Natural speech distribution curve with slight variations
      final base = 0.25 + 0.65 * random.nextDouble();
      return base.clamp(0.18, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 26;
    final waveformHeights = _generateWaveform(audioUrl, barCount);

    return Obx(() {
      final isCurrent = controller.activeUrl.value == audioUrl;
      final isPlaying = isCurrent && controller.isPlaying.value;
      final currentDuration = isCurrent ? controller.duration.value : Duration.zero;
      final currentPosition = isCurrent ? controller.position.value : Duration.zero;

      final totalSecs = currentDuration.inMilliseconds > 0 ? currentDuration.inMilliseconds.toDouble() : 1.0;
      final progressFraction = isCurrent && totalSecs > 0
          ? (currentPosition.inMilliseconds / totalSecs).clamp(0.0, 1.0)
          : 0.0;

      final playedBarCount = (progressFraction * barCount).round();

      return Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Play / Pause Circle Button
                GestureDetector(
                  onTap: () {
                    AppHaptics.light();
                    controller.togglePlay(audioUrl);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Colors.white, Color(0xFFF1F5F9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isMe ? Colors.black : AppColors.primary).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: isMe ? AppColors.primary : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Dynamic Audio Waveform Bars
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      AppHaptics.selection();
                      final currentDuration = controller.duration.value;
                      if (currentDuration.inMilliseconds > 0) {
                        final localX = details.localPosition.dx;
                        const width = 140.0;
                        final ratio = (localX / width).clamp(0.0, 1.0);
                        final targetMs = (ratio * currentDuration.inMilliseconds).toInt();
                        controller.seek(Duration(milliseconds: targetMs));
                      }
                    },
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(barCount, (i) {
                          final isPlayed = isCurrent && i <= playedBarCount;
                          final h = waveformHeights[i] * 28.0;

                          return Container(
                            width: 2.8,
                            height: h,
                            decoration: BoxDecoration(
                              color: isPlayed
                                  ? (isMe ? Colors.white : AppColors.accent)
                                  : (isMe
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : AppColors.textMuted.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Speed Pill (1x / 1.5x / 2x)
                if (isCurrent && isPlaying)
                  GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      controller.cyclePlaybackRate();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${controller.playbackRate.value.toStringAsFixed(1).replaceAll(".0", "")}x',
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Time indicator
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCurrent && currentPosition > Duration.zero
                        ? controller.formatDuration(currentPosition)
                        : (currentDuration > Duration.zero
                            ? controller.formatDuration(currentDuration)
                            : '00:00'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isCurrent && currentDuration > Duration.zero)
                    Text(
                      controller.formatDuration(currentDuration),
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
      );
    });
  }
}
