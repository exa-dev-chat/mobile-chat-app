import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/models/call_log_model.dart';
import '../../models/message_model.dart';
import 'call_log_bubble.dart';
import 'voice_note_player.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (isCallLog(message.content)) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: CallLogBubble(
          message: message,
          isMe: isMe,
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.myMessageBubble : AppColors.otherMessageBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppColors.primaryLight.withValues(alpha: 0.3) : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Content body according to messageType
            _buildMessageContent(),

            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.createdAt != null)
                  Text(
                    _formatTime(message.createdAt!),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: message.isRead ? AppColors.accent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    if (message.messageType == 'audio') {
      return VoiceNotePlayer(
        audioUrl: message.content,
        isMe: isMe,
      );
    }

    if (message.messageType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          message.content,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 220,
              height: 160,
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, _, _) => Container(
            width: 220,
            height: 120,
            color: AppColors.surfaceVariant,
            child: const Center(
              child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    if (message.messageType == 'file') {
      final fileName = message.content.split('/').last.split('?').first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.attach_file_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              fileName.isNotEmpty ? fileName : 'Lampiran Berkas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      message.content,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 1.35,
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
