import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/call_controller.dart';
import '../models/call_session_model.dart';

class CallView extends GetView<CallController> {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        final call = controller.currentCall.value;
        if (call == null) {
          return const Center(
            child: Text('Panggilan berakhir', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        final isVideo = call.callType == CallType.video;
        final isConnected = call.state == CallState.connected;

        return Stack(
          children: [
            // 1. Video / Audio Main Display
            if (isVideo && isConnected)
              Positioned.fill(
                child: RTCVideoView(
                  controller.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              // Audio Call Background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.cardGradient,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              call.targetUserName.isNotEmpty
                                  ? call.targetUserName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          call.targetUserName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isConnected ? call.formattedDuration : 'Menghubungkan...',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Local Video PIP (if Video Call)
            if (isVideo && isConnected)
              Positioned(
                top: 50,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 100,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryLight, width: 2),
                    ),
                    child: RTCVideoView(
                      controller.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // 3. Top Info Overlay (for video)
            if (isVideo && isConnected)
              Positioned(
                top: 50,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: AppColors.onlineIndicator, size: 10),
                      const SizedBox(width: 8),
                      Text(
                        call.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Bottom Controls Bar
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mute Mic Toggle
                      IconButton(
                        icon: Icon(
                          controller.isMuted.value ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: controller.isMuted.value ? AppColors.error : Colors.white,
                          size: 26,
                        ),
                        onPressed: controller.toggleMute,
                      ),
                      const SizedBox(width: 12),

                      // Speaker Toggle
                      IconButton(
                        icon: Icon(
                          controller.isSpeakerOn.value ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          color: controller.isSpeakerOn.value ? AppColors.accent : Colors.white,
                          size: 26,
                        ),
                        onPressed: controller.toggleSpeaker,
                      ),

                      if (isVideo) ...[
                        const SizedBox(width: 12),
                        // Video Cam Toggle
                        IconButton(
                          icon: Icon(
                            controller.isVideoEnabled.value ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                            color: controller.isVideoEnabled.value ? Colors.white : AppColors.error,
                            size: 26,
                          ),
                          onPressed: controller.toggleVideo,
                        ),
                        const SizedBox(width: 12),
                        // Switch Camera
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                          onPressed: controller.switchCamera,
                        ),
                      ],

                      const SizedBox(width: 16),

                      // Hangup Button
                      FloatingActionButton.small(
                        heroTag: 'btn_hangup',
                        backgroundColor: AppColors.error,
                        elevation: 4,
                        onPressed: controller.hangup,
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
