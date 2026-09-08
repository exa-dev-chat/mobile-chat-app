import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/models/call_log_model.dart';
import '../../../call/models/call_session_model.dart';
import '../../controllers/chat_controller.dart';
import '../../models/message_model.dart';

class CallLogBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const CallLogBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final currentUserId = chatController.currentUserId;
    final callData = parseCallLog(message.content);

    if (callData == null) {
      return Text(
        message.content,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      );
    }

    final info = getCallLogDisplay(callData, currentUserId);

    final Color statusColor = info.isCompleted
        ? const Color(0xFF10B981) // Emerald
        : info.isMissed
            ? const Color(0xFFF43F5E) // Rose
            : const Color(0xFFF59E0B); // Amber

    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.isMissed
              ? const Color(0xFFF43F5E).withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Icon Badge with mini direction badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        callData.callType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          info.isMissed
                              ? Icons.close_rounded
                              : info.isOutgoing
                                  ? Icons.arrow_outward_rounded
                                  : Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Call Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Call Back Action Button
              InkWell(
                onTap: () {
                  final callType = callData.callType == 'video'
                      ? CallType.video
                      : CallType.audio;
                  chatController.startCall(callType);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        callData.callType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: const Color(0xFF10B981),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Panggil',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),

          // Footer bar with direction and timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    info.isOutgoing ? 'Panggilan Keluar' : 'Panggilan Masuk',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (message.createdAt != null)
                Text(
                  _formatTime(message.createdAt!),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
