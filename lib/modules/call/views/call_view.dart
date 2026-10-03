import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/call_controller.dart';
import '../models/call_session_model.dart';

class CallView extends StatefulWidget {
  const CallView({super.key});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  final CallController controller = Get.find<CallController>();
  Worker? _callStateWorker;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    // Automatically close CallView when call ends or becomes null
    _callStateWorker = ever<CallSessionModel?>(controller.currentCall, (call) {
      if (call == null || call.state == CallState.ended) {
        _safePop();
      }
    });
  }

  void _safePop() {
    if (_hasPopped) return;
    _hasPopped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _callStateWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _hasPopped = true;
          // Trigger hangup if the call is still active when user navigated back
          if (controller.currentCall.value != null &&
              controller.currentCall.value!.state != CallState.ended) {
            controller.hangup();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          final call = controller.currentCall.value;
          if (call == null || call.state == CallState.ended) {
            _safePop();
            return const SizedBox.shrink();
          }

          final isVideo = call.callType == CallType.video;
          final isConnected = call.state == CallState.connected;

          return Stack(
            children: [
              // 1. Video / Audio Main Display
              if (isVideo && isConnected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RTCVideoView(
                      controller.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                )
              else
                // Audio or Dialing Call Display
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.cardGradient,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // User Avatar with glowing halo
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

                          // Target User Name
                          Text(
                            call.targetUserName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Dynamic Status: "Memanggil...", "00:15", etc.
                          Text(
                            call.statusDisplay,
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

              // 2. Local Video PIP (Video Call)
              if (isVideo)
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
                      child: IgnorePointer(
                        child: RTCVideoView(
                          controller.localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Top Info Overlay (Video call duration timer)
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
                          tooltip: controller.isMuted.value ? 'Buka Mikrofon' : 'Bisukan',
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
                          tooltip: controller.isSpeakerOn.value ? 'Speaker Aktif' : 'Speaker Mati',
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
                            tooltip: controller.isVideoEnabled.value ? 'Matikan Kamera' : 'Nyalakan Kamera',
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
                            tooltip: 'Putar Kamera',
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                            onPressed: controller.switchCamera,
                          ),
                        ],

                        if (isConnected) ...[
                          const SizedBox(width: 12),
                          // Screen Share Toggle
                          IconButton(
                            tooltip: controller.isScreenSharing.value ? 'Hentikan Berbagi Layar' : 'Bagikan Layar',
                            icon: Icon(
                              controller.isScreenSharing.value ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                              color: controller.isScreenSharing.value ? AppColors.accent : Colors.white,
                              size: 26,
                            ),
                            onPressed: controller.toggleScreenShare,
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
      ),
    );
  }
}
